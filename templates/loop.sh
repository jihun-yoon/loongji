#!/bin/bash
# Usage: ./loop.sh [--workers N] [plan] [max_iterations]
# Examples:
#   ./loop.sh              # Build mode, single worker, unlimited iterations
#   ./loop.sh 20           # Build mode, single worker, max 20 iterations
#   ./loop.sh plan         # Plan mode, unlimited iterations
#   ./loop.sh plan 5       # Plan mode, max 5 iterations
#   ./loop.sh --workers 4 50   # Mode C: 4 parallel workers, 50 iterations each
#   ./loop.sh -w 4 50          # Same as above (short flag)

# ─── Parse arguments ──────────────────────────────────────────

WORKERS=1

# Extract --workers / -w flag first
ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --workers|-w)
            WORKERS="$2"
            shift 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done
set -- "${ARGS[@]}"

# Parse remaining positional args
if [ "${1:-}" = "plan" ]; then
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=$1
else
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=0
fi

CURRENT_BRANCH=$(git branch --show-current)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Verify prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    echo "Run /lj-cook first to scaffold project files."
    exit 1
fi

# Warn: plan mode + parallel workers not supported
if [[ "$MODE" = "plan" ]] && [[ $WORKERS -gt 1 ]]; then
    echo "Warning: Parallel workers are not supported in plan mode."
    echo "Plan mode requires sequential reasoning. Falling back to single worker."
    WORKERS=1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:    $MODE"
echo "Prompt:  $PROMPT_FILE"
echo "Branch:  $CURRENT_BRANCH"
echo "Workers: $WORKERS"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:     $MAX_ITERATIONS iterations per worker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Mode B: Single Worker (backward compatible) ──────────────

if [[ $WORKERS -le 1 ]]; then
    ITERATION=0

    while true; do
        if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
            echo "Reached max iterations: $MAX_ITERATIONS"
            break
        fi

        # Run Loongji iteration with selected prompt
        # -p: Headless mode (non-interactive, reads from stdin)
        # --dangerously-skip-permissions: Auto-approve all tool calls (YOLO mode)
        # --output-format=stream-json: Structured output for logging/monitoring
        # --model opus: Primary agent uses Opus for complex reasoning (task selection, prioritization)
        #               Can use 'sonnet' in build mode for speed if plan is clear and tasks well-defined
        # --verbose: Detailed execution logging
        cat "$PROMPT_FILE" | claude -p \
            --dangerously-skip-permissions \
            --output-format=stream-json \
            --model opus \
            --verbose

        # Push changes after each iteration
        git push origin "$CURRENT_BRANCH" || {
            echo "Failed to push. Creating remote branch..."
            git push -u origin "$CURRENT_BRANCH"
        }

        ITERATION=$((ITERATION + 1))
        echo -e "\n\n======================== LOOP $ITERATION ========================\n"

        # Stop condition: all tasks complete (no unchecked items remain)
        if [[ -f "IMPLEMENTATION_PLAN.md" ]] && ! grep -qE '^\s*- \[ \]' "IMPLEMENTATION_PLAN.md"; then
            echo "All tasks in IMPLEMENTATION_PLAN.md are complete. Stopping."
            break
        fi
    done

    exit 0
fi

# ─── Mode C: Parallel Workers ─────────────────────────────────

WORKTREE_DIR=".lj-worktrees"
WORKER_PIDS=()
WORKER_DIRS=()
REPO_ROOT=$(git rev-parse --show-toplevel)

# Locate worker.sh — check local copy first, then plugin templates
if [[ -f "./worker.sh" ]]; then
    WORKER_SCRIPT="$(cd "$(dirname "./worker.sh")" && pwd)/worker.sh"
elif [[ -f "${SCRIPT_DIR}/worker.sh" ]]; then
    WORKER_SCRIPT="${SCRIPT_DIR}/worker.sh"
else
    echo "Error: worker.sh not found"
    echo "Run /lj-cook to scaffold project files."
    exit 1
fi

# ─── Cleanup function ─────────────────────────────────────────

cleanup() {
    echo ""
    echo "━━━ Shutting down workers ━━━"

    # Send SIGTERM to all worker processes
    for pid in "${WORKER_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping worker PID $pid..."
            kill -TERM "$pid" 2>/dev/null
        fi
    done

    # Wait for workers to finish (up to 30 seconds)
    local timeout=30
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local all_stopped=true
        for pid in "${WORKER_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                all_stopped=false
                break
            fi
        done
        if $all_stopped; then
            break
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    # Force kill any remaining
    for pid in "${WORKER_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            echo "Force killing PID $pid..."
            kill -9 "$pid" 2>/dev/null
        fi
    done

    # Clean up stale lock files
    if [[ -d ".lj-tasks/claimed" ]]; then
        echo "Cleaning stale lock files..."
        rm -f .lj-tasks/claimed/worker-*.lock
        git add .lj-tasks/claimed/ 2>/dev/null
        git commit -m "cleanup: remove stale worker locks" --no-verify 2>/dev/null || true
        git push origin "$CURRENT_BRANCH" 2>/dev/null || true
    fi

    # Remove worktrees and their branches
    echo "Removing worktrees..."
    for idx in "${!WORKER_DIRS[@]}"; do
        dir="${WORKER_DIRS[$idx]}"
        worker_num=$((idx + 1))
        if [[ -d "$dir" ]]; then
            git worktree remove "$dir" --force 2>/dev/null || rm -rf "$dir"
        fi
        git branch -D "lj-worktree-${worker_num}" 2>/dev/null || true
    done
    git worktree prune 2>/dev/null || true
    rmdir "$WORKTREE_DIR" 2>/dev/null || true

    echo "━━━ All workers stopped ━━━"
}

trap cleanup SIGINT SIGTERM EXIT

# ─── Create task directories ──────────────────────────────────

mkdir -p .lj-tasks/claimed .lj-tasks/completed
git add .lj-tasks/ 2>/dev/null
git commit -m "init: create .lj-tasks directory for parallel workers" --no-verify 2>/dev/null || true
git push origin "$CURRENT_BRANCH" 2>/dev/null || true

# ─── Create worktrees and launch workers ──────────────────────

mkdir -p "$WORKTREE_DIR"

echo ""
echo "Creating $WORKERS worktrees..."

for i in $(seq 1 "$WORKERS"); do
    WTREE_PATH="${WORKTREE_DIR}/worker-${i}"

    # Create worktree — each worker gets a dedicated branch based on current HEAD
    if [[ -d "$WTREE_PATH" ]]; then
        git worktree remove "$WTREE_PATH" --force 2>/dev/null || rm -rf "$WTREE_PATH"
    fi
    # Delete stale worktree branch if it exists
    git branch -D "lj-worktree-${i}" 2>/dev/null || true
    git worktree add -b "lj-worktree-${i}" "$WTREE_PATH" HEAD 2>/dev/null || {
        # Fallback: detached HEAD
        git worktree add --detach "$WTREE_PATH" HEAD 2>/dev/null
    }

    WORKER_DIRS+=("$WTREE_PATH")
    echo "  Created worktree: $WTREE_PATH"
done

echo ""
echo "Launching $WORKERS workers..."

for i in $(seq 1 "$WORKERS"); do
    WTREE_PATH="${WORKTREE_DIR}/worker-${i}"
    LOG_FILE="${WORKTREE_DIR}/worker-${i}.log"

    # Protect shared files from concurrent modification
    # Make IMPLEMENTATION_PLAN.md and AGENTS.md read-only in each worktree.
    # Workers can still READ them for context, but writes will fail at the filesystem level.
    # Structural enforcement: make shared files read-only in worktrees.
    # Workers can READ them for context but filesystem blocks writes —
    # no need to rely on prompt instructions for these.
    chmod a-w "$WTREE_PATH/IMPLEMENTATION_PLAN.md" 2>/dev/null || true
    chmod a-w "$WTREE_PATH/AGENTS.md" 2>/dev/null || true
    # Remove .lj-tasks/ from worktrees — task locking happens in main repo only
    rm -rf "$WTREE_PATH/.lj-tasks" 2>/dev/null || true

    # Launch worker in its worktree
    (
        cd "$WTREE_PATH"
        bash "$WORKER_SCRIPT" "$i" "$MAX_ITERATIONS" "$CURRENT_BRANCH"
    ) > "$LOG_FILE" 2>&1 &

    WORKER_PIDS+=($!)
    echo "  Worker $i: PID $! (log: $LOG_FILE)"
done

echo ""
echo "━━━ All workers running ━━━"
echo "Press Ctrl+C to stop all workers"
echo "Logs: ${WORKTREE_DIR}/worker-*.log"
echo ""

# ─── Monitor workers (PID tracking + crash recovery) ──────────

while true; do
    all_done=true
    for idx in "${!WORKER_PIDS[@]}"; do
        pid="${WORKER_PIDS[$idx]}"
        worker_num=$((idx + 1))

        if kill -0 "$pid" 2>/dev/null; then
            all_done=false
        else
            # Worker process ended — check if it was expected
            wait "$pid" 2>/dev/null
            exit_code=$?

            if [[ $exit_code -ne 0 ]]; then
                echo "[Coordinator] Worker $worker_num (PID $pid) crashed with exit code $exit_code"

                # Clean up stale lock for crashed worker
                lockfile=".lj-tasks/claimed/worker-${worker_num}.lock"
                if [[ -f "$lockfile" ]]; then
                    echo "[Coordinator] Cleaning stale lock for worker $worker_num"
                    rm -f "$lockfile"
                    git add "$lockfile" 2>/dev/null
                    git commit -m "cleanup: remove stale lock for crashed worker-${worker_num}" --no-verify 2>/dev/null || true
                    git push origin "$CURRENT_BRANCH" 2>/dev/null || true
                fi

                # Restart the worker
                echo "[Coordinator] Restarting worker $worker_num..."
                WTREE_PATH="${WORKTREE_DIR}/worker-${worker_num}"
                LOG_FILE="${WORKTREE_DIR}/worker-${worker_num}.log"

                (
                    cd "$WTREE_PATH"
                    bash "$WORKER_SCRIPT" "$worker_num" "$MAX_ITERATIONS" "$CURRENT_BRANCH"
                ) >> "$LOG_FILE" 2>&1 &

                WORKER_PIDS[$idx]=$!
                all_done=false
                echo "[Coordinator] Worker $worker_num restarted: PID ${WORKER_PIDS[$idx]}"
            fi
        fi
    done

    if $all_done; then
        echo "[Coordinator] All workers completed"
        break
    fi

    sleep 5
done
