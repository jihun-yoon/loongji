---
description: "Auto-detect branch → read plan → iterative spec/plan/build execution"
---

Loongji cook session. Detect current branch, find the matching plan, and execute using iterative spec → plan → build workflow.

## Path Resolution

If `.claude/loongji.local.md` exists and has `plans_dir`, use that. Otherwise default:
- **PLANS_DIR**: `docs/plans/`
- **PLANS_DIR/planned/**: upcoming plans
- **PLANS_DIR/SPRINT.md**: sprint state

All path references below use these resolved paths.

## Configuration

Read the project's `CLAUDE.md` for project context.
If `.claude/loongji.local.md` exists, read it for explicit overrides:
- `loongji.plan_iterations`: Number of planning iterations (default: 2)
- `loongji.max_workers`: Parallel workers for build (default: 2)
- `commands.*`: Explicit build/test/typecheck commands

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
   Wait for the dependency to be merged, then run `/lj-cook` again.
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
   | Execution | Loongji iterative (parallel workers) |
   ```

## Step 2: Check Prior Work

```bash
git log main..<branch> --oneline
```

- If Loongji workflow files already exist (IMPLEMENTATION_PLAN.md, specs/, loop.sh): **resume** — skip to Step 4
- If commits exist but no workflow files: check what's done, adjust accordingly
- If clean: proceed to Step 3

## Step 3: Setup Loongji Workflow

Convert the PLAN into iterative execution format using Loongji's templates.

### 3.1: Copy Loongji Templates

Copy templates from the Loongji plugin's templates directory:
```bash
LJ_TEMPLATES="${CLAUDE_PLUGIN_ROOT}/templates"
```

Copy these files to the worktree root:
- `PROMPT_plan.md` (template)
- `PROMPT_build.md` (template — use verbatim, do NOT modify the 15 guardrails)
- `AGENTS.md` (template)
- `IMPLEMENTATION_PLAN.md` (template)
- `loop.sh` (make executable)

```bash
cp "${LJ_TEMPLATES}/PROMPT_plan.md" .
cp "${LJ_TEMPLATES}/PROMPT_build.md" .
cp "${LJ_TEMPLATES}/AGENTS.md" .
cp "${LJ_TEMPLATES}/IMPLEMENTATION_PLAN.md" .
cp "${LJ_TEMPLATES}/loop.sh" .
chmod +x loop.sh
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

Create `specs/` directory. For each Phase in the PLAN file, create a spec file following Loongji's required format:

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

Use the template format header (with the regex parsing comments), then convert PLAN phases into tasks:

```markdown
# Implementation Plan

<!-- [template comments — copy verbatim from template] -->

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
git add PROMPT_plan.md PROMPT_build.md AGENTS.md IMPLEMENTATION_PLAN.md loop.sh specs/
git commit -m "chore: setup Loongji workflow from PLAN"
```

## Step 4: Execute Loongji Workflow

### Important: Nested Claude Sessions

`loop.sh` spawns `claude -p` subprocesses. When `/lj-cook` runs inside a Claude session, the `CLAUDECODE` environment variable blocks nested Claude launches. **All loop.sh invocations MUST use the `CLAUDECODE=` prefix** to unset this variable:

```bash
CLAUDECODE= ./loop.sh plan 2
CLAUDECODE= ./loop.sh 2
```

This is critical — without it, loop.sh will fail silently or error with "cannot launch inside another Claude Code session".

### 4.1: Planning Iterations (2 rounds)

Run 2 planning iterations to refine IMPLEMENTATION_PLAN.md:

```bash
chmod +x loop.sh
CLAUDECODE= ./loop.sh plan 2
```

This runs `claude -p` headless with PROMPT_plan.md, which:
- Studies specs/* with up to 500 Sonnet subagents
- Compares against actual source code
- Refines IMPLEMENTATION_PLAN.md with precise tasks
- Orders by dependency, groups independent tasks for parallel execution

Each iteration gets a **fresh context window** — disk files (IMPLEMENTATION_PLAN.md, specs/) carry state between iterations, keeping each run efficient.

**Wait for completion** before proceeding to build.

### 4.2: Build Iterations (5 rounds, agent team parallelism)

```bash
CLAUDECODE= ./loop.sh 5
```

Each iteration gets a fresh context window. Within each iteration, Claude uses **Agent tool to parallelize independent tasks**:
- Reads IMPLEMENTATION_PLAN.md → identifies independent task groups
- Spawns Agent(background, worktree) for each independent task
- Each agent: implements + tests + commits
- Results collected → IMPLEMENTATION_PLAN.md updated → push
- Next iteration picks up where previous left off

15 guardrails enforced per iteration:
- Test-first (Red → Green → Refactor)
- Separate structural/behavioral commits
- Update IMPLEMENTATION_PLAN.md after each task
- Stop if stuck after 3 attempts

loop.sh auto-stops when all tasks are `- [x]` in IMPLEMENTATION_PLAN.md.

### 4.3: Monitor Progress

While loop.sh runs, check status periodically:
```bash
# Completed tasks
grep -c '^\- \[x\]' IMPLEMENTATION_PLAN.md

# Remaining tasks
grep -c '^\- \[ \]' IMPLEMENTATION_PLAN.md

# Progress log
cat .lj-worktrees/progress.log
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

1. **Clean up Loongji execution artifacts** (don't merge to main):
   Add to `.gitignore` if not already:
   ```
   PROMPT_plan.md
   PROMPT_build.md
   AGENTS.md
   IMPLEMENTATION_PLAN.md
   loop.sh
   .lj-worktrees/
   .lj-tasks/
   ```
   ```bash
   git rm --cached PROMPT_plan.md PROMPT_build.md AGENTS.md IMPLEMENTATION_PLAN.md loop.sh 2>/dev/null || true
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
   | Loongji artifacts | Cleaned (not merged) |

   To merge, run in the main pane:
   /lj-serve <branch>
   ```

## Rules
- Always read the plan file completely before starting any work
- **Use Loongji templates verbatim** — do NOT rewrite PROMPT_plan.md or PROMPT_build.md guardrails
- Only fill in PROJECT CONTEXT, AGENTS.md, specs, and IMPLEMENTATION_PLAN.md from the PLAN
- **Dependency gate**: If dependencies aren't merged, STOP and report — don't proceed
- Loongji execution artifacts are ephemeral — never merge them to main
- If loop.sh fails or workers crash, check logs before retrying
- Read AGENTS.md for all project-specific commands — do not hardcode build/test commands
- Maximum 3 workers recommended (diminishing returns beyond that)
