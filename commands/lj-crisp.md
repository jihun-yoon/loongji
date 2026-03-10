---
description: "Show Loongji workflow status: active worktrees, sprint queue, worker status"
---

Display the current Loongji workflow status.

## Path Resolution

If `.claude/loongji.local.md` exists and has `plans_dir`, use that. Otherwise default:
- **PLANS_DIR**: `docs/plans/`
- **PLANS_DIR/SPRINT.md**: sprint state

All path references below use these resolved paths.

## Steps

### 1. Read Sprint State

Read `docs/plans/SPRINT.md` to get:
- Active Worktrees (what's running)
- Execution Queue (what's next)
- Done This Sprint (completed)

If SPRINT.md doesn't exist, report "No active sprint" and stop.

### 2. Check Progress Log and Running Workers

For each active worktree directory, check the progress log:
```bash
# Progress log — shows iteration history with timestamps and durations
cat <worktree-dir>/.lj-worktrees/progress.log 2>/dev/null
```

Parse the log to determine:
- **Current phase**: `STARTED mode=plan` or `STARTED mode=build`
- **Iteration progress**: count `ITERATION ... done` lines vs max
- **Task counts**: latest `tasks=N/M` entry
- **Running processes**: check for active `loop.sh` or `claude -p` processes

Also check worker-level details:
```bash
# Worker logs (parallel mode)
ls <worktree-dir>/.lj-worktrees/worker-*.log 2>/dev/null

# Task claiming status
ls <worktree-dir>/.lj-tasks/claimed/*.lock 2>/dev/null

# Completed tasks
ls <worktree-dir>/.lj-tasks/completed/*.done 2>/dev/null
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
## Loongji Status

### Sprint Overview
| Metric | Count |
|--------|-------|
| Active Worktrees | N |
| Queued | N |
| Done This Sprint | N |
| Blocked | N |

### Active Worktrees
| Branch | Directory | Plan | Phase | Iteration | Tasks | Duration |
|--------|-----------|------|-------|-----------|-------|----------|
| feat/x | ../repo-x | PLAN-x | Planning | 2/2 | 0/16 | 12m |

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
- If active worktrees are done: "Run `/lj-serve <branch>` to merge"
- If queue has ready items and no active worktrees: "Run `/lj-worktree next` to start"
- If all items blocked: "Merge active worktrees first to unblock"
- If everything is done: "Sprint complete! Run `/lj-sprint new` for a new sprint"
