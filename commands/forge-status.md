---
description: "Show forge workflow status: active worktrees, sprint queue, worker status"
---

Display the current forge workflow status.

## Steps

### 1. Read Sprint State

Read `docs/plans/SPRINT.md` to get:
- Active Worktrees (what's running)
- Execution Queue (what's next)
- Done This Sprint (completed)

If SPRINT.md doesn't exist, report "No active sprint" and stop.

### 2. Check for Running Workers

```bash
# Ralph worktree workers
ls .ralph-worktrees/*/worker-*.log 2>/dev/null

# Task claiming status
ls .ralph-tasks/claimed/*.lock 2>/dev/null

# Completed tasks
ls .ralph-tasks/completed/*.done 2>/dev/null
```

### 3. Check Implementation Plan Progress

For each active worktree, check if an IMPLEMENTATION_PLAN.md exists:
```bash
# In main repo
REMAINING=$(grep -c '^\s*- \[ \]' IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
COMPLETED=$(grep -c '^\s*- \[x\]' IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
```

Also check worktree directories:
```bash
REPO_NAME=$(basename $(git rev-parse --show-toplevel))
for worktree in $(git worktree list --porcelain | grep "^worktree " | cut -d' ' -f2); do
  if [[ -f "$worktree/IMPLEMENTATION_PLAN.md" ]]; then
    echo "$worktree:"
    grep -c '^\s*- \[ \]' "$worktree/IMPLEMENTATION_PLAN.md" 2>/dev/null || echo "0 remaining"
    grep -c '^\s*- \[x\]' "$worktree/IMPLEMENTATION_PLAN.md" 2>/dev/null || echo "0 completed"
  fi
done
```

### 4. Check Git Worktree State

```bash
git worktree list
```

### 5. Display Summary

```
## Forge Status

### Sprint Overview
| Metric | Count |
|--------|-------|
| Active Worktrees | N |
| Queued | N |
| Done This Sprint | N |
| Blocked | N |

### Active Worktrees
| Branch | Directory | Plan | Tasks Done | Tasks Left | Workers |
|--------|-----------|------|-----------|-----------|---------|
| feat/x | ../repo-x | PLAN-x | 5 | 3 | 2 running |

### Execution Queue
| Order | Plan | Priority | Status |
|-------|------|----------|--------|
| 1 | plan-a | High | Ready |
| 2 | plan-b | Medium | Blocked (by plan-a) |

### Done This Sprint
- [x] feat/y — plan-y merged
- [x] fix/z — plan-z merged
```

### 6. Actionable Suggestions

Based on the status, suggest next actions:
- If active worktrees are done: "Run `/forge-merge <branch>` to merge"
- If queue has ready items and no active worktrees: "Run `/forge-worktree next` to start"
- If all items blocked: "Merge active worktrees first to unblock"
- If everything is done: "Sprint complete! Run `/forge-sprint new` for a new sprint"
