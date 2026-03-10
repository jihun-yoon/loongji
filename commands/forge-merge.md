---
description: "Merge completed worktree: resolve conflicts, verify, test, cleanup"
arguments:
  - name: branch
    description: "Branch to merge (e.g., 'fix/ops-bugfix'). Auto-detects from SPRINT.md Done items if omitted."
    required: false
---

Merge a completed feature branch: $ARGUMENTS

If `.claude/forge.local.md` exists, read it for explicit command overrides.

## Step 1: Identify Merge Target

### If branch specified:
- Use the provided branch name

### If no branch specified:
1. Read `docs/plans/SPRINT.md`
2. Find items in Active Worktrees with Status = `Done`
3. If multiple Done items, show list and ask which to merge:
   ```
   ## Ready to Merge
   1. fix/ops-bugfix — PLAN-20260310-ops-bugfix (Done)
   2. feat/token-quota — PLAN-20260310-token-quota (Done)

   Which branch to merge? (or 'all' for sequential merge)
   ```
4. If merging `all`, order by dependency (merge dependencies first)

## Step 2: Pre-Merge Checks

1. **Verify we're on main branch**:
   ```bash
   git branch --show-current
   ```
   - If not on main: `git checkout main`

2. **Check branch status**:
   ```bash
   git log main..<branch> --oneline
   ```
   - If no commits: warn "Branch has no changes to merge"

3. **Check for unresolved dependencies**:
   - Read SPRINT.md for dependency info
   - If this branch has dependents (other plans depending on it), note them:
     ```
     After merging, these items become unblocked:
     - storage-quota (was waiting for token-quota)
     ```

4. **Preview conflicts**:
   ```bash
   git merge --no-commit --no-ff <branch> 2>&1 || true
   git diff --name-only --diff-filter=U
   git merge --abort 2>/dev/null || true
   ```
   - If conflicts exist, show the list and plan resolution

## Step 3: Execute Merge

```bash
git merge <branch> --no-ff
```

### If merge conflicts:
1. List all conflicting files
2. For each conflict:
   - Read the file to understand both sides
   - **Server code conflicts**: preserve both changes, merge logic carefully
   - **Schema/migration conflicts**: check migration sequence numbers, may need renumbering
   - **Type conflicts**: merge type definitions, ensure no duplicates
   - **Config conflicts**: typically take both additions
3. After resolving all conflicts:
   ```bash
   git add <resolved-files>
   git commit
   ```

### If merge succeeds cleanly:
Continue to verification.

## Step 4: Post-Merge Verification

Read the project's CLAUDE.md and AGENTS.md (if it exists) for project-specific commands.

### Phase 1: Dependencies
Detect and run the project's dependency install command:
```bash
# Detect package manager
[ -f pnpm-lock.yaml ] && pnpm install
[ -f package-lock.json ] && npm install
[ -f yarn.lock ] && yarn install
```

### Phase 2: Build
Run the project's build command from CLAUDE.md or AGENTS.md.

### Phase 3: Database
- Check for new migrations (if applicable)
- If new migrations exist: run the project's migration command

### Phase 4: Tests
Run the project's test command from CLAUDE.md or AGENTS.md.
- Only fix NEW failures (known pre-existing failures are OK)

### Phase 5: Smoke Test (if dev servers available)
- Start servers if not running
- Test critical endpoints (project-specific)

## Step 5: Generate Result Section

Before updating status, generate a structured result record in the PLAN file.

### 5.1: Gather Data

Run in parallel:
```bash
# Commit list
git log main..<branch> --oneline

# File change stats
git diff --stat main..<branch>

# Changed file count
git diff --name-only main..<branch> | wc -l
```

### 5.2: Compare Plan vs Implementation

1. Read the PLAN file's Phase sections (planned work)
2. Read the commit log (actual work)
3. Identify:
   - **Delivered**: Items actually implemented (extracted from commits)
   - **Deviated**: Differences from plan (planned but not done, or unplanned additions)
   - **Files Changed**: `git diff --stat` summary

### 5.3: Write Result Section

Add `## Result` section at the bottom of the PLAN file:

```markdown
---

## Result

> Merged: YYYY-MM-DD | Branch: <branch> | Commits: N

### Delivered
- <implemented item 1>
- <implemented item 2>
- ...

### Deviated from Plan
- <differences, or "Implemented as planned" if none>

### Files Changed
- N files added, M modified
- Key files: <list 3-5 most important files>
```

### 5.4: Show to User for Confirmation

Show the Result draft to the user and allow edits before saving.

## Step 6: Update Sprint State

After successful merge and verification:

1. **SPRINT.md** — update:
   - Remove from Active Worktrees table
   - Add to Done This Sprint:
     ```markdown
     - [x] <branch> — <plan-name> merged
     ```
   - Update any items that were blocked by this plan → mark as `Ready`

2. **Plan file** — status already updated, Result already added in Step 5

3. **README.md** — move plan from Planned to Done table:
   ```markdown
   | [PLAN-YYYYMMDD-<name>](done/PLAN-YYYYMMDD-<name>.md) | <description> | YYYY-MM |
   ```

4. **Move plan file** to done directory:
   ```bash
   git mv docs/plans/planned/PLAN-YYYYMMDD-<name>.md docs/plans/done/
   ```

5. **Commit** the state updates:
   ```
   docs: mark <plan-name> as done, update sprint state
   ```

## Step 7: Worktree Cleanup

**Ask the user before cleaning up**:
```
## Merge Complete: <branch>

| Phase | Status |
|-------|--------|
| Merge | Clean / Conflicts resolved |
| Dependencies | Synced |
| Build | Passed |
| Tests | N passed (M known failures) |
| Sprint Updated | Done |

### Worktree Cleanup
The worktree at `../<repo>-<short-name>` is no longer needed.

Clean up worktree and branch? [y/n]
- Removes worktree directory
- Deletes local branch
- Closes tmux pane (if identifiable)
```

If user confirms:
```bash
REPO_NAME=$(basename $(git rev-parse --show-toplevel))
git worktree remove ../${REPO_NAME}-<short-name>
git branch -d <branch>
```

If user declines:
```
Worktree preserved at ../${REPO_NAME}-<short-name>.
To clean up later: git worktree remove ../${REPO_NAME}-<short-name> && git branch -d <branch>
```

## Step 8: Unblock Check

After merge, check if any sprint items are now unblocked:
```
## Newly Unblocked Items

| Plan | Was Blocked By | Status |
|------|---------------|--------|
| storage-quota | token-quota | Now Ready |

Start next item? Use `/forge-worktree next`
```

## Rules
- Always verify we're on main before merging
- Never force-push or rebase published history
- Resolve ALL merge conflicts before proceeding to verification
- Run full post-merge verification — don't skip phases
- **Always ask before cleaning up worktrees** — user may want to keep them
- Update all 3 tracking files: SPRINT.md, plan file, README.md
- If merge introduces test failures, fix them before committing
- Migration sequence conflicts must be resolved (renumber if needed)
- After merge, always check what items are now unblocked
