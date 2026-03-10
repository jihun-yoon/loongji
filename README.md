# Loongji — The Golden-Crispy SDLC

An AI-native SDLC methodology for Claude Code. Loongji combines sprint-based project management with iterative, parallel code generation.

**"Only serve code that's been perfectly crisped."**

**Loong (龍)** — A legion of dragons: 500 subagents moving in parallel.
**Ji (누룽지)** — Nurungji, the golden-crispy rice: code pressed and perfected to the very bottom.

## Philosophy

Traditional SDLC: Humans plan → Humans build → Humans test
Loongji SDLC: Humans scope → AI specs → AI plans → AI builds (parallel) → AI verifies → Humans merge

**Key principle**: Humans define *what* and *why*. AI handles *how*, iteratively and in parallel.

## The Loongji Pipeline

```
 +----------+    +----------+    +----------+    +----------+    +----------+
 |  DESIGN  |--->|   SPEC   |--->|   PLAN   |--->|  COOK    |--->|  SERVE   |
 | /lj-plan |    | Auto-gen |    | Iterative|    | Parallel |    | /lj-     |
 |          |    | from plan|    | refinement|   | workers  |    |  serve   |
 +----------+    +----------+    +----------+    +----------+    +----------+
   Human -------------- AI ---------------------------------------- Human
```

### Stage 1: Design (`/lj-plan`)
Human describes what they want. AI agent team researches the codebase, identifies risks, creates a PLAN document.

### Stage 2: Spec (automatic)
PLAN phases are converted to detailed specifications following the Job To Be Done framework:
- Functional Requirements (FR-1, FR-2, ...)
- Acceptance Criteria
- Technical Notes

### Stage 3: Plan (iterative)
AI runs 3+ planning iterations, studying specs and existing code with up to 500 parallel subagents. Produces a refined IMPLEMENTATION_PLAN.md with dependency-ordered, parallel-safe task checklist.

### Stage 4: Cook (`/lj-cook`)
Multiple AI workers execute tasks in parallel via git worktrees:
- Each worker claims a task atomically (git-based locking)
- Test-first workflow (Red → Green → Refactor)
- 15 guardrails prevent common AI coding mistakes
- Workers merge results back to the feature branch

### Stage 5: Serve (`/lj-serve`)
Merge to main with full verification pipeline, auto-generated result documentation, and worktree cleanup.

## Installation

```bash
claude plugin install loongji
# Or with --plugin-dir for local development:
claude --plugin-dir ~/path/to/loongji
```

## Quick Start

```bash
/lj-plan "add per-user token quota"   # 1. Create plan (auto-bootstraps docs/plans/)
/lj-sprint add token-quota             # 2. Add to sprint queue
/lj-worktree next                      # 3. Create worktree + auto-launch Claude
/lj-crisp                              # 4. Check progress
/lj-serve feat/token-quota             # 5. Merge + verify + record results
```

See [GUIDE.md](GUIDE.md) for detailed scenarios (greenfield, brownfield, parallel execution, etc.).
한국어 가이드: [GUIDE.ko.md](GUIDE.ko.md)

## Commands

| Command | Stage | Description |
|---------|-------|-------------|
| `/lj-plan <feature>` | Design | Create plan with agent team analysis |
| `/lj-sprint [action]` | Queue | Manage sprint queue (add, status, reorder) |
| `/lj-worktree [target]` | Launch | Create worktree + start execution |
| `/lj-cook` | Cook | (Auto) Iterative spec → plan → build |
| `/lj-crisp` | Check | Show active workers, progress, queue |
| `/lj-serve [branch]` | Serve | Merge + verify + result docs + cleanup |

## Document Management

Loongji expects a `docs/plans/` directory structure in your project:

```
docs/plans/
├── README.md           ← Plan index (Done / Planned / Reference tables)
├── SPRINT.md           ← Current sprint state (Active / Queue / Done)
├── done/               ← Completed plans
├── planned/            ← Upcoming plans
├── in-progress/        ← Currently executing (optional)
└── reference/          ← Analysis docs, architecture notes
```

### Plan File Convention

**Naming**: `PLAN-YYYYMMDD-<feature-name>.md` (date = creation date)

**Required headers** (lines 3-4, after title):
```markdown
# PLAN: Feature Title

> **Status**: Planned | In Progress | Done | Deferred
> **Type**: feature | bugfix | infra | refactor
> Branch: `feat/feature-name`
```

**Status values**:
- `Planned` — Scope defined, not yet started
- `In Progress` — Worktree created, actively being built
- `Done` — All phases complete, ready for or already merged
- `Deferred` — Postponed to a future sprint

**Type values**:
- `feature` — New functionality (requires design across layers)
- `bugfix` — Bug fix (code location already identified)
- `infra` — Infrastructure/architecture change (scaling, deployment)
- `refactor` — Code structure improvement (no behavior change)

### Plan Index (`docs/plans/README.md`)

Tracks all plans in tables by status. `/lj-plan` and `/lj-serve` update this automatically.

### Sprint File (`docs/plans/SPRINT.md`)

Tracks the current sprint cycle:
- **Active Worktrees** — branches currently being worked on
- **Execution Queue** — priority-ordered queue with dependency tracking
- **Done This Sprint** — completed items

`/lj-sprint` manages this file.

### Initial Setup

Running `/lj-plan` or `/lj-sprint` for the first time auto-bootstraps the entire structure. No manual setup required.

## How It Works

### Document Lifecycle

```
PLAN-*.md (permanent)          Loongji artifacts (ephemeral)
+---------------------+       +------------------------+
| > Status: Planned   |------>| specs/*.md              |
| > Type: feature     |       | IMPLEMENTATION_PLAN.md  |
|                     |       | PROMPT_plan.md          |
| ## Overview         |       | PROMPT_build.md         |
| ## Phase 1          |       | AGENTS.md               |
| ## Phase 2          |       | loop.sh / worker.sh     |
|                     |       +------------------------+
| ---                 |              | (deleted on merge)
| ## Result           |<-------------+
| > Merged: date      |
| ### Delivered       |
| ### Deviated        |
| ### Files Changed   |
+---------------------+
```

- **PLAN-*.md** is the permanent record (what was planned + what was delivered)
- Execution artifacts (specs, tasks, prompts) live in the worktree and are cleaned up on merge
- The Result section is auto-generated by `/lj-serve` from git history

### Sprint Management

SPRINT.md tracks current work state:
- **Active Worktrees**: what's running
- **Execution Queue**: what's next (priority + dependency ordered)
- **Done This Sprint**: completed items

### Parallel Execution

```
Feature Branch (worktree)
+-- Worker 1: claude -p (task A) --> commit --> merge to branch
+-- Worker 2: claude -p (task B) --> commit --> merge to branch
+-- Worker 3: claude -p (task C) --> commit --> merge to branch
```

Workers coordinate via:
- **Git-based atomic locking** (git push = compare-and-swap)
- **Task claiming** from IMPLEMENTATION_PLAN.md
- **Crash recovery** (coordinator detects dead PIDs, restarts)

### 15 Build Guardrails

The build prompt includes battle-tested guardrails:
1. Test first (Red → Green → Refactor)
2. Separate structural and behavioral commits
3. No `git add -A` — stage specific files
4. Keep IMPLEMENTATION_PLAN.md current
5. Stop if stuck after 3 attempts (don't weaken tests)
6. Complete implementations (no stubs/placeholders)
7. Single source of truth (no adapters/migrations)
8. Update AGENTS.md with operational learnings
9. Resolve unrelated bugs when found
10. Clean completed items periodically
...and more

## Configuration

Loongji reads project context from three layers:

1. **`CLAUDE.md`** — build/test/dev commands, project structure (Claude reads automatically)
2. **`docs/plans/`** — plan index + sprint state (managed by Loongji commands)
3. **`.claude/loongji.local.md`** — optional explicit overrides ([SETTINGS.md](SETTINGS.md))

Most projects need only `CLAUDE.md`. Settings file is useful for monorepos, non-standard paths, or tuning worker count.

## Requirements

- Claude Code with plugin support
- Git 2.20+ (for worktrees)
- tmux (for pane management)
- Project with CLAUDE.md and docs/plans/ structure

## Inspiration & Credits

Loongji builds on ideas and techniques from these projects:

- **[Augmented Coding: Beyond the Vibes](https://tidyfirst.substack.com/p/augmented-coding-beyond-the-vibes)** by Kent Beck — The distinction between "vibe coding" and "augmented coding": maintaining code quality, TDD discipline, and architectural oversight while leveraging AI capabilities. Loongji's test-first guardrails and human-in-the-loop design philosophy are directly influenced by this framework.

- **[Claude's C Compiler](https://github.com/anthropics/claudes-c-compiler)** by Anthropic — Demonstrated that Claude can autonomously implement complex systems (a full C compiler in Rust) given clear test-driven specifications, without interactive pair programming. Loongji's spec-driven, test-first worker execution model follows this pattern.

- **[The Ralph Technique](https://github.com/ghuntley/how-to-ralph-wiggum)** by Geoffrey Huntley — The loop-based execution methodology: a bash script repeatedly feeds instructions to Claude with a fresh context window each iteration, reading current state from a persistent plan file on disk. Loongji's `loop.sh`/`worker.sh` architecture, JTBD-based spec generation, AGENTS.md operational learnings, and backpressure-through-tests approach are directly derived from this technique.

## Comparison

| Feature | Manual Dev | Sprint Skills | Loongji |
|---------|-----------|--------------|---------|
| Planning | Human | Agent team (1 session) | Agent team (1 session) |
| Spec writing | Human | N/A | Auto from plan |
| Task breakdown | Human | Plan phases | Iterative (500 subagents) |
| Execution | Human | Agent team (1 session) | Parallel workers (N sessions) |
| Context limits | N/A | Single window | Unlimited (fresh per iteration) |
| Merge verification | Manual | `/merge` auto | `/lj-serve` auto |
| Result tracking | Git log | PLAN Result section | PLAN Result section |

## License

MIT
