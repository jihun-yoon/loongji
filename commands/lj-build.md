---
description: "Iterative build with parallel agent teams. Reads IMPLEMENTATION_PLAN.md, groups independent tasks, spawns parallel agents, collects results, repeats."
allowed-tools: Agent, Read, Edit, Write, Bash, Glob, Grep, Skill
---

# /lj-build

Iterative build executor with parallel agent teams.

**Usage**: `/lj-build [max_iterations]` (default: 3)

Parse max_iterations from `$ARGUMENTS` (default 3 if empty or non-numeric).

---

## Iteration Loop

Repeat the following steps up to max_iterations times. Stop early if all tasks are complete.

### Step 1: Read State

Read these files:
- `IMPLEMENTATION_PLAN.md` — task list with `- [ ]` (pending) and `- [x]` (done)
- `AGENTS.md` — build/test/typecheck commands

Count pending tasks (`- [ ]`). If zero, skip to Step 5 (Done).

### Step 2: Analyze & Group

Identify all pending `- [ ]` tasks. Group them by file dependency:

**Rule**: Two tasks are INDEPENDENT if they modify completely different files. Tasks that share any file must be in the same group (sequential).

For each task, extract the `Files:` line to determine which files it touches.

Example grouping:
```
Group A (independent): Task 1 (types.ts), Task 2 (session-active-run.ts)
Group B (independent): Task 5 (choice-manager.ts)
Group C (sequential): Task 3, Task 4 (both touch sessions.ts)
```

Report the grouping:
```
## Iteration N — Task Analysis

| Group | Tasks | Files | Strategy |
|-------|-------|-------|----------|
| A | Task 1, 2 | types.ts, session-active-run.ts | parallel |
| B | Task 5 | choice-manager.ts | parallel |
| C | Task 3 → 4 | sessions.ts, messages.ts | sequential |

Spawning 3 agents (2 parallel groups + 1 sequential group)
```

### Step 3: Execute — Parallel Agent Spawn

For each group, call the Agent tool. **All independent groups MUST be spawned in a single message** to maximize parallelism.

Each Agent receives this prompt template (fill in the variables):

```
You are implementing tasks for the session-reconnection feature.

## Your Tasks
{task_descriptions from IMPLEMENTATION_PLAN.md — full text including context, acceptance criteria, files}

## Build & Validation Commands
{contents of AGENTS.md}

## Rules
1. Test first: write/update a failing test (RED), implement to pass (GREEN), refactor (REFACTOR).
2. Only modify files listed in your tasks. Do NOT touch other files.
3. After implementation, run the validation commands from AGENTS.md.
4. Stage only your changed files (NOT `git add -A`). Commit with a descriptive message.
5. If stuck after 3 attempts on the same issue, commit what you have with a note about what's failing.

## Working Directory
This is a monorepo. Key paths:
- Server: apps/server/src/
- Web: apps/web/src/
- Shared: packages/shared/src/
- Tests: apps/server/src/__tests__/

Start by reading the existing files you need to modify, then implement.
```

**Agent parameters**:
- `subagent_type`: use default (general-purpose)
- `mode`: "bypassPermissions"
- Sequential groups: single Agent that does tasks in order
- All Agents run in foreground (need results before proceeding)

### Step 4: Collect Results & Update

After all agents complete:

1. **Check results**: Read each agent's output. Note successes and failures.
2. **Update IMPLEMENTATION_PLAN.md**: Mark completed tasks as `- [x]`. Add failure notes for stuck tasks.
3. **Run full validation** (from AGENTS.md): typecheck + test to verify nothing is broken.
4. **Commit**: Stage IMPLEMENTATION_PLAN.md + any remaining changes. Commit with message: `feat: iteration N — M/N tasks complete`
5. **Report**:

```
## Iteration N Complete

| Group | Tasks | Status |
|-------|-------|--------|
| A | Task 1, 2 | ✅ Done |
| B | Task 5 | ✅ Done |
| C | Task 3, 4 | ⚠️ Task 4 failed (type error in X) |

Progress: 8/13 tasks complete
Remaining: 5 tasks
```

6. **Count remaining**: If all `- [ ]` are gone → go to Step 5. Otherwise → next iteration (back to Step 1).

### Step 5: Done

All tasks complete or max iterations reached.

```
## Build Complete

| Item | Value |
|------|-------|
| Iterations | N |
| Tasks | M/T complete |
| Status | ✅ All done / ⚠️ N remaining |

Remaining tasks (if any):
- [ ] Task description (reason stuck)
```

Run final validation (typecheck + test + build) and report results.

---

## Important Rules

- **Never skip Step 2 grouping.** Incorrect grouping causes file conflicts between agents.
- **All independent agents in ONE message.** Do not spawn them across multiple messages — that makes them sequential.
- **Do not modify IMPLEMENTATION_PLAN.md inside agents.** Only the main session updates it in Step 4.
- **Agents must not use `git add -A`.** Only stage their specific files.
- **If an agent fails, do not retry in the same iteration.** Note the failure and move to the next iteration where it can be re-attempted with fresh context.
