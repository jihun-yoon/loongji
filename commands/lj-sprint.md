---
description: "Manage sprint queue: add plans, reorder priorities, update status"
arguments:
  - name: action
    description: "Action: 'add <plan-name>', 'reorder', 'status', or 'new' to create fresh sprint"
    required: false
---

Sprint management: $ARGUMENTS

## Path Resolution

If `.claude/loongji.local.md` exists and has `plans_dir`, use that. Otherwise default:
- **PLANS_DIR**: `docs/plans/`
- **PLANS_DIR/planned/**: upcoming plans
- **PLANS_DIR/done/**: completed plans
- **PLANS_DIR/README.md**: plan index
- **PLANS_DIR/SPRINT.md**: sprint state

All path references below use these resolved paths.

## Step 0: Bootstrap if Needed

If `docs/plans/SPRINT.md` doesn't exist:

1. Create directory:
   ```bash
   mkdir -p docs/plans/{done,planned,reference}
   touch docs/plans/done/.gitkeep docs/plans/planned/.gitkeep docs/plans/reference/.gitkeep
   ```
2. Create SPRINT.md:
```markdown
# Sprint

> Last updated: YYYY-MM-DD

## Active Worktrees

| Branch | Directory | Plan | Status |
|--------|-----------|------|--------|

## Execution Queue

| Order | Plan | Branch | Priority | Dependencies | Status |
|-------|------|--------|----------|--------------|--------|

## Merge Conflicts Risk

| File | Plans | Resolution |
|------|-------|------------|

## Blocked / Notes

(none)

## Done This Sprint

(none yet)
```
3. If `docs/plans/README.md` also doesn't exist, create it (same template as `/lj-plan` Step 0)
4. Commit: `git commit -m "chore: bootstrap Loongji document structure"`

If the structure already exists, skip silently.

## Step 1: Read Current State

Read these files:
1. `docs/plans/SPRINT.md` — current sprint state
2. `docs/plans/README.md` — all available plans

## Step 2: Determine Action

### If no arguments or `status`:
Display the current sprint state as a formatted table:
```
## Current Sprint Status

### Active Worktrees
| Branch | Plan | Status |
...

### Queue (next up)
| Order | Plan | Branch | Priority | Dependencies | Blocked? |
...

### Done This Sprint
- [x] item 1
...
```

Mark each queue item as `Ready` or `Blocked (reason)` based on dependency analysis.

### If `add <plan-name>`:
1. Find the plan in `docs/plans/planned/` (fuzzy match on name)
2. Read the plan to extract: branch name, priority, dependencies
3. Determine queue position based on priority and dependencies:
   - **Urgent** → top of queue
   - **High** → after urgent items, before medium
   - **Medium/Low** → end of queue
4. Check for conflicts:
   - Same files modified by other queued plans?
   - Migration sequence conflicts?
   - Schema / index / types file contention?
5. Add to SPRINT.md Execution Queue table
6. Add conflict info to Merge Conflicts Risk table if any

### If `reorder`:
1. Show current queue with numbered items
2. Ask user for new order (e.g., "2,1,3,4")
3. Validate: blocked items can't come before their dependencies
4. Update SPRINT.md with new order

### If `new`:
1. Archive current sprint:
   - Confirm with user first
   - Move all Done items to README.md Done table (if not already there)
2. Create fresh SPRINT.md:
   - Empty Active Worktrees
   - Keep any remaining queue items
   - Clear Done section
3. Ask user which planned items to add to the new sprint queue

## Step 3: Dependency Analysis

For each item in the queue, check:
1. **Explicit dependencies**: listed in Dependencies column
2. **Implicit dependencies**:
   - Migration sequence: plans with sequential migrations must be ordered
   - Schema conflicts: multiple plans modifying schema files → sequential merge
   - Shared file conflicts: check Merge Conflicts Risk table
3. Mark items as:
   - `Ready` — no unresolved dependencies
   - `Blocked (reason)` — waiting for another plan to merge
   - `Parallel OK` — can run simultaneously with adjacent items

## Step 4: Update SPRINT.md

Write changes to `docs/plans/SPRINT.md`:
- Update `> Last updated: YYYY-MM-DD` with today's date
- Maintain table formatting
- Keep file under 50 lines when possible

## Step 5: Report

```
## Sprint Updated

| Action | Details |
|--------|---------|
| Added/Reordered/Status | description |
| Queue Size | N items |
| Ready Now | N items (list) |
| Blocked | N items (list with reasons) |

Next: `/lj-worktree next` to start the first ready item
```

## Rules
- SPRINT.md is the single source of truth for current work state
- Never have more than 3-4 items in Active Worktrees (resource limit)
- Always validate dependencies before allowing queue changes
- Keep the file concise — no prose, just tables and lists
- Update the `Last updated` date on every modification
