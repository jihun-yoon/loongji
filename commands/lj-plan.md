---
description: "Analyze user request → create plan document with agent team"
arguments:
  - name: feature
    description: "Feature description or problem statement (e.g., 'token quota system', 'fix analytics errors')"
    required: true
---

Create a feature plan for: $ARGUMENTS

## Path Resolution

If `.claude/loongji.local.md` exists and has `plans_dir`, use that. Otherwise default:
- **PLANS_DIR**: `docs/plans/`
- **PLANS_DIR/planned/**: upcoming plans
- **PLANS_DIR/done/**: completed plans
- **PLANS_DIR/reference/**: analysis docs
- **PLANS_DIR/README.md**: plan index
- **PLANS_DIR/SPRINT.md**: sprint state

All path references below use these resolved paths.

## Step 0: Bootstrap Document Structure

Check if `docs/plans/` exists. If not, create the full structure:

```bash
mkdir -p docs/plans/{done,planned,reference}
touch docs/plans/done/.gitkeep docs/plans/planned/.gitkeep docs/plans/reference/.gitkeep
```

If `docs/plans/README.md` doesn't exist, create it:
```markdown
# Feature Plans Index

Feature plans for this project. Organized by status: `done/`, `planned/`, `reference/`.

**Naming convention**: `PLAN-YYYYMMDD-<feature-name>.md` (date = creation date).

---

## Done (`done/`)

| Plan | Description | Merged |
|------|-------------|--------|

## Planned (`planned/`)

| Plan | Description | Priority |
|------|-------------|----------|

## Reference (`reference/`)

| Document | Description |
|----------|-------------|
```

If `docs/plans/SPRINT.md` doesn't exist, create it:
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

If any files were created, commit:
```bash
git add docs/plans/
git commit -m "chore: bootstrap Loongji document structure"
```

If the structure already exists, skip this step silently.

## Step 1: Understand the Request

Parse the user's feature description. Identify:
- **Type**: feature | bugfix | infra | refactor
- **Scope**: which packages/files are likely affected
- **Complexity**: small (1 phase), medium (2-3 phases), large (4+ phases)

## Step 2: Research with Agent Team

Launch 3 parallel agents to gather context:

### Agent 1: Codebase Analysis
- Search for existing code related to the feature
- Identify files that will need modification
- Find patterns and conventions used in similar features
- Check for existing utilities that can be reused

### Agent 2: Architecture Review
- Review how similar features are structured in this project
- Check `docs/plans/done/` for completed plans with similar scope
- Identify dependencies and integration points
- Note any migration or schema changes needed

### Agent 3: Risk & Dependency Check
- Check for potential conflicts with other planned work (read `SPRINT.md`)
- Identify migration sequence conflicts
- Check for shared file conflicts (schema files, index files, types files)
- Note any blocking dependencies

## Step 3: Draft Plan Document

Using the agent team's findings, create the plan file:

**File path**: `docs/plans/planned/PLAN-YYYYMMDD-<feature-name>.md`
- YYYYMMDD = today's date
- feature-name = kebab-case summary

**Type classification** (auto-detect from content):
- `feature` — New functionality (requires design across layers)
- `bugfix` — Bug fix (code location is already identified)
- `infra` — Infrastructure/architecture change (scaling, deployment, workers)
- `refactor` — Code structure improvement (no behavior change)

**Template**:
```markdown
# PLAN: <Title>

> **Status**: Planned
> **Type**: <feature|bugfix|infra|refactor>
> Branch: `<feat|fix>/<feature-name>`

## Overview

<1-2 paragraph description of what this plan accomplishes and why>

### Goals
- <goal 1>
- <goal 2>

---

## Phase N: <Phase Title>

### Problem
<What needs to be done and why>

### Fix / Implementation
<Technical approach with code snippets if helpful>

### Files
- `path/to/file.ts`: description of change

---

## File Changes Summary

| File | Change | Phase |
|------|--------|-------|
| `path/to/file.ts` | description | N |
```

**Rules for plan content**:
- Each phase should be completable in one TDD cycle (RED -> GREEN -> REFACTOR)
- Include specific file paths, not vague descriptions
- Show code snippets for non-obvious changes
- Note migration sequence numbers if DB changes are needed
- Phases ordered by dependency (independent phases first)

## Step 4: Update README.md

Add the new plan to `docs/plans/README.md` in the Planned table:
```markdown
| [PLAN-YYYYMMDD-<name>](planned/PLAN-YYYYMMDD-<name>.md) | <description> | <priority> |
```

## Step 5: Present to User

Show the plan summary and ask for review:
```
## Plan Created

| Item | Value |
|------|-------|
| File | docs/plans/planned/PLAN-YYYYMMDD-<name>.md |
| Type | feature / bugfix / infra / refactor |
| Branch | feat/<name> |
| Phases | N |
| Files Affected | M |
| Migration | Yes/No (sequence NNNN) |
| Conflicts | None / list |

### Phase Summary
1. Phase 1 — <title> (N files)
2. Phase 2 — <title> (N files)
...

Review the plan and let me know if you want to:
- Adjust scope or phases
- Add to SPRINT.md (use `/lj-sprint`)
- Start work immediately (use `/lj-worktree`)
```

## Rules
- Always read existing plans in `docs/plans/done/` for style reference
- Follow the `PLAN-YYYYMMDD-<name>.md` naming convention
- Include a branch name suggestion using `feat/` or `fix/` prefix
- Every plan MUST have `> **Status**: Planned` on line 3
- Do not create overly large plans — split into multiple plans if > 6 phases
- Check SPRINT.md for potential conflicts before finalizing
