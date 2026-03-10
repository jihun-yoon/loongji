#!/bin/bash
# Loongji — Iterative Loop (Ralph + C Compiler style)
#
# Each iteration spawns a fresh Claude session with the prompt file.
# Disk files (IMPLEMENTATION_PLAN.md, specs/) carry state between iterations.
# Parallelism happens INSIDE each iteration via Claude's Agent tool.
#
# Usage: ./loop.sh [plan] [max_iterations]
# Examples:
#   ./loop.sh              # Build mode, unlimited iterations
#   ./loop.sh 5            # Build mode, max 5 iterations
#   ./loop.sh plan         # Plan mode, unlimited iterations
#   ./loop.sh plan 2       # Plan mode, max 2 iterations

# ─── Parse arguments ──────────────────────────────────────────

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
LOG_DIR=".lj-worktrees"
mkdir -p "$LOG_DIR"
PROGRESS_LOG="$LOG_DIR/progress.log"

# Verify prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    echo "Run /lj-cook first to scaffold project files."
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:    $MODE"
echo "Prompt:  $PROMPT_FILE"
echo "Branch:  $CURRENT_BRANCH"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:     $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Initialize progress log
echo "[$(date '+%H:%M:%S')] STARTED mode=$MODE max=$MAX_ITERATIONS branch=$CURRENT_BRANCH" >> "$PROGRESS_LOG"

# ─── Main Loop ───────────────────────────────────────────────

ITERATION=0

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    ITERATION=$((ITERATION + 1))
    ITER_START=$(date +%s)
    echo "[$(date '+%H:%M:%S')] ITERATION $ITERATION/$MAX_ITERATIONS started (mode=$MODE)" >> "$PROGRESS_LOG"

    # Run iteration with fresh context
    # Claude uses Agent tool internally for parallel task execution
    cat "$PROMPT_FILE" | claude -p \
        --dangerously-skip-permissions \
        --output-format=stream-json \
        --model opus \
        --verbose

    ITER_END=$(date +%s)
    ITER_DURATION=$(( ITER_END - ITER_START ))

    # Count tasks
    TASKS_DONE=$(grep -c '^\s*- \[x\]' IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
    TASKS_LEFT=$(grep -c '^\s*- \[ \]' IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
    echo "[$(date '+%H:%M:%S')] ITERATION $ITERATION/$MAX_ITERATIONS done (${ITER_DURATION}s) tasks=$TASKS_DONE/$((TASKS_DONE + TASKS_LEFT))" >> "$PROGRESS_LOG"

    # Push changes after each iteration
    git push origin "$CURRENT_BRANCH" || {
        echo "Failed to push. Creating remote branch..."
        git push -u origin "$CURRENT_BRANCH"
    }

    echo -e "\n\n======================== LOOP $ITERATION ========================\n"

    # Stop condition: all tasks complete (no unchecked items remain)
    if [[ -f "IMPLEMENTATION_PLAN.md" ]] && ! grep -qE '^\s*- \[ \]' "IMPLEMENTATION_PLAN.md"; then
        echo "[$(date '+%H:%M:%S')] ALL_TASKS_COMPLETE" >> "$PROGRESS_LOG"
        echo "All tasks in IMPLEMENTATION_PLAN.md are complete. Stopping."
        break
    fi
done

echo "[$(date '+%H:%M:%S')] FINISHED iterations=$ITERATION" >> "$PROGRESS_LOG"
