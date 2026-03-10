---
description: "Auto-detect branch → read plan → setup ralph workflow → execute"
---

Sprint work session. Detect current branch, find the matching plan, and execute using ralph-multiverse iterative workflow.

## Step 1: Self-Orient

1. **Detect current branch**:
   ```bash
   git branch --show-current
   ```

2. **Read SPRINT.md** (`docs/plans/SPRINT.md`):
   - Find this branch in the Active Worktrees or Execution Queue table
   - Extract the plan name and plan file path
   - Check if this branch's plan has dependencies marked as "must merge first"

3. **Dependency gate check**:
   - If this plan's dependencies are NOT yet in "Done This Sprint": **STOP immediately**
   ```
   Cannot proceed: This plan depends on [dependency-name] which has not been merged yet.

   Status of dependency:
   - [dependency-name]: [In Progress / Not Started]

   This worktree was likely created before dependencies were resolved.
   Wait for the dependency to be merged, then run `/forge-work` again.
   ```
   - If dependencies are in Done or have no dependencies: proceed

4. **Read the plan file** (e.g., `docs/plans/planned/PLAN-20260310-feature-name.md`):
   - Understand the full scope: phases, files to modify, architecture decisions

5. **Report orientation**:
   ```
   ## Sprint Work Session

   | Item | Value |
   |------|-------|
   | Branch | feat/feature-name |
   | Plan | PLAN-20260310-feature-name |
   | Phases | 3 |
   | Dependencies | None / All resolved |
   | Execution | Ralph Multiverse Mode C |
   ```

## Step 2: Check Prior Work

```bash
git log main..<branch> --oneline
```

- If ralph files already exist (IMPLEMENTATION_PLAN.md, specs/, loop.sh): **resume** — skip to Step 4
- If commits exist but no ralph files: check what's done, adjust accordingly
- If clean: proceed to Step 3

## Step 3: Setup Ralph Workflow

Convert the PLAN into ralph-multiverse format using the forge plugin's actual templates.

### 3.1: Copy Ralph Templates

Copy templates from the forge plugin's templates directory:
```bash
FORGE_TEMPLATES="${CLAUDE_PLUGIN_ROOT}/templates"
```

Copy these files to the worktree root:
- `PROMPT_plan.md` (template)
- `PROMPT_build.md` (template — use verbatim, do NOT modify the 15 guardrails)
- `AGENTS.md` (template)
- `IMPLEMENTATION_PLAN.md` (template)
- `loop.sh` + `worker.sh` (make executable)

```bash
cp "${FORGE_TEMPLATES}/PROMPT_plan.md" .
cp "${FORGE_TEMPLATES}/PROMPT_build.md" .
cp "${FORGE_TEMPLATES}/AGENTS.md" .
cp "${FORGE_TEMPLATES}/IMPLEMENTATION_PLAN.md" .
cp "${FORGE_TEMPLATES}/loop.sh" .
cp "${FORGE_TEMPLATES}/worker.sh" .
chmod +x loop.sh worker.sh
```

### 3.2: Fill PROMPT_plan.md PROJECT CONTEXT

Read the PLAN file and the project's CLAUDE.md, then fill the PROJECT CONTEXT section at the top of PROMPT_plan.md:

```markdown
## PROJECT CONTEXT
- Goal: [Extract from PLAN's Overview section]
- Key features: [Extract from PLAN's Phase titles/goals]
- Tech stack: [Extract from project's CLAUDE.md]
- Constraints: [Extract from PLAN — migration sequences, file conflicts, dependencies]
```

**Do NOT modify the rest of PROMPT_plan.md** — the subagent instructions, task format rules, and "IMPORTANT: Plan only" directive must remain exactly as the template.

### 3.3: Fill AGENTS.md

Populate AGENTS.md from the project's CLAUDE.md. Extract:
- Build commands (dev, build, install)
- Test commands (unit, integration, e2e)
- Typecheck and lint commands
- Operational notes (monorepo structure, import conventions, patterns)

```markdown
## Build & Run

Succinct rules for how to BUILD the project:
[Extract from CLAUDE.md commands section]

## Validation

Run these after implementing to get immediate feedback:

- Tests: `[test command from CLAUDE.md]`
- Typecheck: `[typecheck command from CLAUDE.md]`
- Lint: `[lint command from CLAUDE.md]`

## Operational Notes

[Extract key patterns, conventions, gotchas from CLAUDE.md]

### Codebase Patterns

[Extract architecture patterns from CLAUDE.md]
```

### 3.4: Convert PLAN Phases → specs/*.md

Create `specs/` directory. For each Phase in the PLAN file, create a spec file following ralph's required format:

```markdown
# [Phase Title]

## Job To Be Done
[What this phase accomplishes — extract from PLAN's Phase description]

## Functional Requirements
- FR-1: [Requirement from PLAN]
  - FR-1.1: [Sub-requirement if any]
- FR-2: [Next requirement]

## Acceptance Criteria
- [ ] [Testable criterion derived from PLAN's expected behavior]
- [ ] [Another criterion]

## Technical Notes
- Files: [From PLAN's Files section]
- Approach: [From PLAN's Fix/Implementation section]
```

**Important**: Include code snippets from the PLAN's implementation sections — these are valuable context for workers.

### 3.5: Generate IMPLEMENTATION_PLAN.md

Use ralph's template format header (with the regex parsing comments), then convert PLAN phases into tasks:

```markdown
# Implementation Plan

<!-- [ralph's template comments — copy verbatim from template] -->

## Phase 1: [Title from PLAN]
- [ ] [Task derived from Phase 1 steps]
  [Context, acceptance criteria, relevant files from PLAN]

- [ ] [Next task]
  [Context]

## Phase 2: [Title from PLAN]
- [ ] [Task]
  [Context]
```

**Task sizing rule**: Each `- [ ]` item must be completable in one context window. If a PLAN Phase has multiple distinct changes, split into separate tasks.

### 3.6: Commit Setup Files

```bash
git add PROMPT_plan.md PROMPT_build.md AGENTS.md IMPLEMENTATION_PLAN.md loop.sh worker.sh specs/
git commit -m "chore: setup ralph-multiverse workflow from PLAN"
```

## Step 4: Execute Ralph Workflow

### 4.1: Planning Iterations (Mode B — sequential)

Run 3 planning iterations to refine IMPLEMENTATION_PLAN.md:

```bash
chmod +x loop.sh worker.sh
./loop.sh plan 3
```

This runs `claude -p` headless with PROMPT_plan.md, which:
- Studies specs/* with up to 500 Sonnet subagents
- Compares against actual source code
- Refines IMPLEMENTATION_PLAN.md with precise tasks
- Orders by dependency, groups independent tasks for parallel execution

**Wait for completion** before proceeding to build.

### 4.2: Build Iterations (Mode C — parallel workers)

```bash
./loop.sh --workers 2 30
```

This runs 2 parallel workers, each using PROMPT_build.md's 15 guardrails:
- Test-first (Red -> Green -> Refactor)
- Separate structural/behavioral commits
- Update IMPLEMENTATION_PLAN.md after each task
- Stop if stuck after 3 attempts
- Git-based atomic task locking

**Worker count guidance**:
- Small plan (1-2 phases, < 5 tasks): 1 worker (Mode B)
- Medium plan (3-4 phases, 5-15 tasks): 2 workers
- Large plan (5+ phases, 15+ tasks): 3 workers (max recommended)

### 4.3: Monitor Progress

While loop.sh runs, check status periodically:
```bash
# Completed tasks
ls .ralph-tasks/completed/ 2>/dev/null | wc -l

# Remaining tasks
grep -c '^\- \[ \]' IMPLEMENTATION_PLAN.md

# Worker logs
tail -20 .ralph-worktrees/worker-1.log 2>/dev/null
```

## Step 5: Post-Build Verification

When loop.sh completes (all tasks checked or max iterations reached):

1. **Run full test suite**: Read AGENTS.md for the test command
2. **Build check**: Read AGENTS.md for the build command
3. **TypeScript check**: Read AGENTS.md for the typecheck command
4. **Review IMPLEMENTATION_PLAN.md**: Check for remaining `- [ ]` items
   - If remaining: assess if critical or nice-to-have
   - If all `- [x]`: fully complete

## Step 6: Plan Completion

1. **Clean up ralph artifacts** (don't merge to main):
   Add to `.gitignore` if not already:
   ```
   PROMPT_plan.md
   PROMPT_build.md
   AGENTS.md
   IMPLEMENTATION_PLAN.md
   loop.sh
   worker.sh
   .ralph-worktrees/
   .ralph-tasks/
   ```
   ```bash
   git rm --cached PROMPT_plan.md PROMPT_build.md AGENTS.md IMPLEMENTATION_PLAN.md loop.sh worker.sh 2>/dev/null || true
   ```

2. **Update plan file**: Status → `Done`
3. **Update SPRINT.md**: Active Worktrees status → `Done`
4. **Report**:
   ```
   ## Plan Complete: <plan-name>

   All phases done. Ready for merge to main.

   | Item | Status |
   |------|--------|
   | Tasks | N/N complete |
   | Tests | Passed |
   | Build | Passed |
   | Ralph artifacts | Cleaned (not merged) |

   To merge, run in the main pane:
   /forge-merge <branch>
   ```

## Rules
- Always read the plan file completely before starting any work
- **Use ralph's templates verbatim** — do NOT rewrite PROMPT_plan.md or PROMPT_build.md guardrails
- Only fill in PROJECT CONTEXT, AGENTS.md, specs, and IMPLEMENTATION_PLAN.md from the PLAN
- **Dependency gate**: If dependencies aren't merged, STOP and report — don't proceed
- Ralph artifacts are ephemeral — never merge them to main
- If loop.sh fails or workers crash, check logs before retrying
- Read AGENTS.md for all project-specific commands — do not hardcode build/test commands
- Maximum 3 workers recommended (diminishing returns beyond that)
