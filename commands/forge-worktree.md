---
description: "Sprint-aware worktree: create worktree + tmux pane + launch Claude with plan"
arguments:
  - name: target
    description: "'next' (auto-select), 'all' (all ready items), or branch/plan name. Default: next"
    required: false
  - name: pane_width
    description: "Pane width percentage (default: auto-balanced)"
    required: false
---

Sprint-aware worktree management: $ARGUMENTS

## Step 1: Read Sprint Context

Read `docs/plans/SPRINT.md` to understand:
- **Active Worktrees**: what's already running
- **Execution Queue**: what's next, in priority order
- **Blocked/Dependencies**: what can't start yet

## Step 2: Determine Target(s)

### If no arguments or `next`:
1. Find the first item in Execution Queue that is:
   - Not already in Active Worktrees
   - Not blocked by unmerged dependencies
2. **Dependency check** — for each candidate:
   - Read its Dependencies column
   - If dependency plan is in Active Worktrees (not Done) → **BLOCKED**
   - If dependency plan is not in Done This Sprint → **BLOCKED**
   - Show blocked reason and skip to next candidate
3. If the next ready item found, show:
   ```
   Next in queue: [plan-name] (priority)
   Branch: <branch>
   Plan: <link>
   Dependencies: <none or list>
   Status: Ready
   ```
4. Ask for confirmation before proceeding
5. **If ALL remaining items are blocked**:
   ```
   All remaining queue items are blocked:
   - storage-quota: Blocked by token-quota (not yet merged)
   - 1000-user-scale: Blocked by token-quota (recommended)

   No worktree created. Resolve dependencies first or use `/forge-worktree <branch>` to force.
   ```
   **Stop here — do not create worktree.**

### If `all`:
1. Scan entire queue for all non-blocked, non-active items
2. Show list with Ready/Blocked status for each:
   ```
   ## Ready to Start (will create worktrees)
   1. ops-bugfix → fix/ops-bugfix (Urgent)
   2. token-quota → feat/token-quota (High)

   ## Blocked (will skip)
   3. storage-quota — Blocked by: token-quota merge
   4. 1000-user-scale — Blocked by: token-quota (recommended)

   Create 2 worktrees? [y/n]
   ```
3. On confirmation, create all ready worktrees sequentially

### If argument is a plan/branch name:
- Match against Execution Queue entries
- If the item is blocked, show warning:
  ```
  This plan has unresolved dependencies:
  - Depends on: token-quota (not yet merged)

  Proceeding anyway may cause merge conflicts.
  Continue? [y/n]
  ```
- Proceed only with user confirmation

## Step 3: Create Branch and Worktree

For each target:

1. Parse branch name — apply prefix rules:
   - Plans starting with `fix/` or `feat/` → use as-is
   - Otherwise → prefix with `feat/`

2. Determine project directory name from repo:
   ```bash
   REPO_NAME=$(basename $(git rev-parse --show-toplevel))
   ```

3. Create branch (if not exists):
   ```bash
   git branch <branch> 2>/dev/null || true
   ```

4. Create worktree:
   ```bash
   git worktree add ../${REPO_NAME}-<short-name> <branch>
   ```
   - `<short-name>`: branch name without prefix (e.g., `feat/ops-bugfix` → `${REPO_NAME}-ops-bugfix`)
   - If worktree directory already exists, skip creation

5. Install dependencies in worktree (if package manager lockfile exists):
   ```bash
   cd ../${REPO_NAME}-<short-name>
   # Detect package manager and install
   [ -f pnpm-lock.yaml ] && pnpm install
   [ -f package-lock.json ] && npm install
   [ -f yarn.lock ] && yarn install
   cd -
   ```

## Step 4: Create tmux Pane and Launch Claude

1. Split horizontally (side by side):
   ```bash
   tmux split-window -h -c <worktree-path>
   ```

2. Rebalance all panes:
   ```bash
   tmux select-layout even-horizontal
   ```

3. Adjust width (if pane_width specified):
   ```bash
   tmux resize-pane -t <pane_id> -x <columns>
   ```

4. **Launch Claude with auto-prompt in the new pane**:
   ```bash
   tmux send-keys -t <pane_id> 'claude --dangerously-skip-permissions -p "/forge-work"' Enter
   ```

   This launches Claude in the worktree directory with the `/forge-work` skill,
   which auto-detects the branch → reads the plan → starts executing.

## Step 5: Update SPRINT.md

After successful worktree creation, update `docs/plans/SPRINT.md`:

1. **Active Worktrees table** — add new row:
   ```markdown
   | <branch> | ../${REPO_NAME}-<short-name> | <plan-name> | In Progress |
   ```

2. **Execution Queue** — update status column to `In Progress`

3. **Plan file** — update the plan's status header:
   ```markdown
   > **Status**: In Progress
   ```

4. **README.md** — update plan status if listed

## Step 6: Verify and Report

1. Run `tmux list-panes` to show final layout
2. Display summary:

```
## Worktree Created + Claude Launched

| Item | Value |
|------|-------|
| Branch | feat/ops-bugfix |
| Directory | ../${REPO_NAME}-ops-bugfix |
| Plan | PLAN-20260310-ops-bugfix.md |
| Sprint Status | Updated |
| Claude | Launched with /forge-work |

### Active Worktrees
| Branch | Directory | Plan | Status |
|--------|-----------|------|--------|
| fix/ops-bugfix | ../${REPO_NAME}-ops-bugfix | ops-bugfix | In Progress |
```

## Rules
- Always rebalance panes with `even-horizontal` after creating
- If the branch already exists, use it instead of creating a new one
- If the worktree directory already exists, skip creation and just create the pane
- Clean up any stale panes pointing to non-existent directories
- Always update SPRINT.md after worktree creation — this is the source of truth
- **Never start a blocked plan without explicit user confirmation and warning**
- If SPRINT.md doesn't exist, fall back to asking user for target branch
- Always launch Claude with `/forge-work` in the new pane
- Maximum 3-4 concurrent worktrees (resource limit) — warn if exceeding
