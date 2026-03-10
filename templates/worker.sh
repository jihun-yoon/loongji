#!/bin/bash
# Loongji — Parallel Worker
# Runs inside a git worktree, claims tasks from IMPLEMENTATION_PLAN.md via git-based locking,
# invokes Claude to implement them, and merges results back to main.
#
# Usage: worker.sh <worker_id> <max_iterations> <main_branch>
# Called by loop.sh — not intended for direct invocation.

set -uo pipefail

WORKER_ID="$1"
MAX_ITERATIONS="${2:-0}"
MAIN_BRANCH="${3:-main}"
WORKER_BRANCH="worker-${WORKER_ID}"
PROMPT_FILE="PROMPT_build.md"
TASKS_DIR=".lj-tasks"
ITERATION=0
EMPTY_TASK_COUNT=0
MAX_EMPTY_TASKS=3
SHUTDOWN_REQUESTED=0

# ─── Logging ──────────────────────────────────────────────────

log() {
    echo "[Worker-${WORKER_ID}] $(date '+%H:%M:%S') $*"
}

log_error() {
    echo "[Worker-${WORKER_ID}] $(date '+%H:%M:%S') ERROR: $*" >&2
}

# ─── Graceful Shutdown ────────────────────────────────────────

trap 'SHUTDOWN_REQUESTED=1; log "Shutdown requested, finishing current iteration..."' SIGTERM SIGINT

# ─── Git Helpers ──────────────────────────────────────────────

git_pull_rebase() {
    local retries=3
    for i in $(seq 1 $retries); do
        if git pull --rebase origin "$MAIN_BRANCH" 2>/dev/null; then
            return 0
        fi
        log "Pull rebase attempt $i/$retries failed, retrying..."
        sleep 1
    done
    log_error "Failed to pull after $retries attempts"
    return 1
}

git_push_with_retry() {
    local branch="$1"
    local retries=3
    for i in $(seq 1 $retries); do
        if git push origin "$branch" 2>/dev/null; then
            return 0
        fi
        log "Push attempt $i/$retries failed, rebasing..."
        git pull --rebase origin "$branch" 2>/dev/null || true
        sleep 1
    done
    log_error "Failed to push $branch after $retries attempts"
    return 1
}

# ─── Task Claiming ────────────────────────────────────────────
# Uses .lj-tasks/claimed/worker-N.lock files + git push as atomic CAS.
# IMPLEMENTATION_PLAN.md itself is never modified by the locking mechanism.

get_claimed_tasks() {
    # Return list of already-claimed task descriptions
    local claimed=""
    if [[ -d "${TASKS_DIR}/claimed" ]]; then
        for lockfile in "${TASKS_DIR}/claimed"/*.lock; do
            [[ -f "$lockfile" ]] && claimed+="$(cat "$lockfile")|"
        done
    fi
    echo "$claimed"
}

get_completed_tasks() {
    # Return list of completed task descriptions
    local completed=""
    if [[ -d "${TASKS_DIR}/completed" ]]; then
        for donefile in "${TASKS_DIR}/completed"/*.done; do
            [[ -f "$donefile" ]] && completed+="$(cut -d'|' -f3 < "$donefile")|"
        done
    fi
    echo "$completed"
}

find_unclaimed_task() {
    # Parse IMPLEMENTATION_PLAN.md for unchecked items, skip claimed/completed ones
    if [[ ! -f "IMPLEMENTATION_PLAN.md" ]]; then
        echo ""
        return
    fi

    local claimed
    claimed=$(get_claimed_tasks)
    local completed
    completed=$(get_completed_tasks)

    # Extract unchecked items: lines matching "- [ ] ..."
    while IFS= read -r line; do
        # Strip the "- [ ] " prefix to get task description
        local task_desc
        task_desc=$(echo "$line" | sed 's/^[[:space:]]*- \[ \] //')

        # Skip if already claimed
        if echo "$claimed" | grep -qF "$task_desc"; then
            continue
        fi

        # Skip if already completed
        if echo "$completed" | grep -qF "$task_desc"; then
            continue
        fi

        echo "$task_desc"
        return
    done < <(grep -E '^\s*- \[ \]' "IMPLEMENTATION_PLAN.md")

    echo ""
}

claim_task() {
    local task_desc="$1"
    if [[ -z "$task_desc" ]]; then
        return 1
    fi

    # Ensure directories exist
    mkdir -p "${TASKS_DIR}/claimed" "${TASKS_DIR}/completed"

    # Create lock file
    local lockfile="${TASKS_DIR}/claimed/worker-${WORKER_ID}.lock"
    echo "$task_desc" > "$lockfile"

    # Atomic claim via git push
    git add "$lockfile"
    git commit -m "claim: Worker-${WORKER_ID} claims task" --no-verify 2>/dev/null || true

    if git_push_with_retry "$MAIN_BRANCH"; then
        log "Claimed: $task_desc"
        return 0
    else
        # Push failed — another worker beat us. Remove lock and retry.
        rm -f "$lockfile"
        git reset HEAD~1 --soft 2>/dev/null || true
        git checkout -- "$lockfile" 2>/dev/null || true
        log "Claim race lost, will pick another task"
        return 1
    fi
}

release_task() {
    local task_desc="$1"
    local lockfile="${TASKS_DIR}/claimed/worker-${WORKER_ID}.lock"

    mkdir -p "${TASKS_DIR}/completed"

    # Create completion record
    local safe_name
    safe_name=$(echo "$task_desc" | tr ' ' '-' | tr -cd '[:alnum:]-' | head -c 50)
    local donefile="${TASKS_DIR}/completed/${safe_name}.done"
    echo "worker-${WORKER_ID}|$(date -u '+%Y-%m-%dT%H:%M:%SZ')|${task_desc}" > "$donefile"

    # Remove lock
    rm -f "$lockfile"

    git add "${TASKS_DIR}/"
    git commit -m "release: Worker-${WORKER_ID} completed task" --no-verify 2>/dev/null || true
    git_push_with_retry "$MAIN_BRANCH" || log_error "Failed to push task release"
}

# ─── Merge Worker Changes to Main ─────────────────────────────

merge_worker_changes() {
    log "Merging ${WORKER_BRANCH} to ${MAIN_BRANCH}..."

    # Switch to main and pull latest
    git checkout "$MAIN_BRANCH" 2>/dev/null
    git_pull_rebase || true

    # Attempt rebase merge
    if git merge "$WORKER_BRANCH" --no-edit 2>/dev/null; then
        if git_push_with_retry "$MAIN_BRANCH"; then
            log "Merge successful"
            # Clean up worker branch
            git branch -d "$WORKER_BRANCH" 2>/dev/null || true
            return 0
        fi
    fi

    # Merge failed — try rebase approach
    log "Merge failed, attempting rebase..."
    git merge --abort 2>/dev/null || true
    git checkout "$WORKER_BRANCH" 2>/dev/null
    if git rebase "$MAIN_BRANCH" 2>/dev/null; then
        git checkout "$MAIN_BRANCH" 2>/dev/null
        if git merge "$WORKER_BRANCH" --no-edit 2>/dev/null; then
            if git_push_with_retry "$MAIN_BRANCH"; then
                log "Rebase merge successful"
                git branch -d "$WORKER_BRANCH" 2>/dev/null || true
                return 0
            fi
        fi
    fi

    # All merge strategies failed — preserve branch
    git rebase --abort 2>/dev/null || true
    git merge --abort 2>/dev/null || true
    git checkout "$MAIN_BRANCH" 2>/dev/null || true
    log_error "Could not merge ${WORKER_BRANCH}. Branch preserved for manual resolution."
    log_error "Run: git merge ${WORKER_BRANCH}"
    return 1
}

# ─── Build Worker Prompt ──────────────────────────────────────

build_worker_prompt() {
    local task_desc="$1"
    local worker_instruction
    # Write worker instruction to temp file (avoids heredoc quoting issues inside $())
    local tmpfile
    tmpfile=$(mktemp)
    cat <<TMPL > "$tmpfile"
# Worker Assignment — THESE RULES OVERRIDE ANY CONFLICTING INSTRUCTIONS BELOW

You are **Worker ${WORKER_ID}** in a parallel build system. Other workers are running simultaneously on different tasks in separate git worktrees.

## Your Assigned Task
${task_desc}

## Context
Read IMPLEMENTATION_PLAN.md (read-only) to understand your task in context — look for descriptions, acceptance criteria, or notes below the checkbox line. Also read AGENTS.md for build/test commands.

## Parallel Worker Rules (override the general build prompt below)

1. **ONLY implement the assigned task above.** Do NOT pick a different item from IMPLEMENTATION_PLAN.md — your task has already been selected and locked by the coordinator.

2. **IMPLEMENTATION_PLAN.md and AGENTS.md are read-only** (enforced by filesystem). Read them for context, but do not attempt to update them. If you learn something important, include it in your commit message instead.

3. **Minimize file scope.** Other workers are making changes in parallel. Keep your edits to files directly related to your assigned task. Avoid refactoring shared utilities, renaming exports, or reformatting unrelated code — these create merge conflicts.

4. **If your task depends on code another worker might be building**, implement your part with clear interfaces and leave a TODO comment at the integration point. Do not wait or block.

## Development Discipline

5. **Test first.** Write or update a failing test BEFORE writing implementation code. Then write the minimum code to make the test pass. Then tidy. (Red-Green-Refactor)

6. **Separate structural and behavioral changes.** If you need to refactor before implementing, commit the refactor first (structural), then commit the new functionality (behavioral). Never mix both in one commit.

7. **Commit discipline.** Only commit when: ALL tests pass, no compiler/linter warnings, and the change is a single logical unit. Do NOT use git add -A — stage only the files you changed. Do NOT run git push or create git tags — the coordinator handles these.

8. **Stop if you are going in circles.** If you have attempted the same fix 3 times without progress, commit what you have with a clear description of what is failing and why, then stop. Do not delete or disable tests to force a pass.

---

TMPL
    worker_instruction=$(cat "$tmpfile")
    rm -f "$tmpfile"
    # Prepend worker instruction to the build prompt
    echo "${worker_instruction}"
    cat "$PROMPT_FILE"
}

# ─── Main Worker Loop ─────────────────────────────────────────

log "Starting (branch: ${MAIN_BRANCH}, max iterations: ${MAX_ITERATIONS:-unlimited})"

# Verify prompt file exists
if [[ ! -f "$PROMPT_FILE" ]]; then
    log_error "$PROMPT_FILE not found in worktree"
    exit 1
fi

while true; do
    # Check shutdown
    if [[ $SHUTDOWN_REQUESTED -eq 1 ]]; then
        log "Shutting down gracefully"
        break
    fi

    # Check iteration limit
    if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
        log "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    # Sync with main
    git_pull_rebase || {
        log_error "Cannot sync with main, waiting..."
        sleep 5
        continue
    }

    # Find and claim a task
    local_task=""
    claim_attempts=0
    while [[ -z "$local_task" ]] && [[ $claim_attempts -lt 3 ]]; do
        candidate=$(find_unclaimed_task)
        if [[ -z "$candidate" ]]; then
            EMPTY_TASK_COUNT=$((EMPTY_TASK_COUNT + 1))
            if [[ $EMPTY_TASK_COUNT -ge $MAX_EMPTY_TASKS ]]; then
                log "No tasks available for $MAX_EMPTY_TASKS consecutive checks. Exiting."
                exit 0
            fi
            log "No unclaimed tasks found (attempt $((EMPTY_TASK_COUNT))/$MAX_EMPTY_TASKS)"
            sleep 5
            git_pull_rebase || true
            break
        fi

        if claim_task "$candidate"; then
            local_task="$candidate"
            EMPTY_TASK_COUNT=0
        else
            claim_attempts=$((claim_attempts + 1))
            git_pull_rebase || true
        fi
    done

    # No task claimed this round — skip to next iteration
    if [[ -z "$local_task" ]]; then
        continue
    fi

    # Create worker branch for this task
    git checkout -b "$WORKER_BRANCH" 2>/dev/null || git checkout "$WORKER_BRANCH" 2>/dev/null || {
        # Branch might exist from a previous failed run
        git branch -D "$WORKER_BRANCH" 2>/dev/null
        git checkout -b "$WORKER_BRANCH"
    }

    # Build prompt and invoke Claude
    log "Working on: $local_task"
    WORKER_PROMPT=$(build_worker_prompt "$local_task")

    echo "$WORKER_PROMPT" | claude -p \
        --dangerously-skip-permissions \
        --disallowedTools "Bash(git push *)" "Bash(git push)" \
                          "Bash(git tag *)" "Bash(git tag)" \
                          "Bash(rm -rf *)" "Bash(rm -rf /)" \
                          "Bash(curl *)" "Bash(wget *)" \
        --output-format=stream-json \
        --model opus \
        --verbose

    # Push worker branch
    git_push_with_retry "$WORKER_BRANCH" || log_error "Failed to push worker branch"

    # Merge back to main
    merge_worker_changes

    # Release the task
    release_task "$local_task"

    ITERATION=$((ITERATION + 1))
    log "━━━ Iteration $ITERATION complete ━━━"
done

log "Worker finished after $ITERATION iterations"
