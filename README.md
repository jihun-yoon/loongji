# Loongji -- The Golden-Crispy SDLC

An AI-native SDLC methodology for Claude Code. Loongji combines sprint-based project management with iterative, parallel code generation.

**"가장 완벽하게 익은 코드만을 내놓는다."**

**Loong (龍)** — 500개의 서브에이전트가 병렬로 움직이는 용의 군단.
**Ji (누룽지)** — 바닥까지 제대로 눌러 붙여 만든 완성도 높은 결과물.

## Philosophy

Traditional SDLC: Humans plan -> Humans build -> Humans test
Loongji SDLC: Humans scope -> AI specs -> AI plans -> AI builds (parallel) -> AI verifies -> Humans merge

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
- Test-first workflow (Red -> Green -> Refactor)
- 15 guardrails prevent common AI coding mistakes
- Workers merge results back to the feature branch

### Stage 5: Serve (`/lj-serve`)
Merge to main with full verification pipeline, auto-generated result documentation, and worktree cleanup.

## Installation

```bash
claude plugins add ~/Documents/Projects/loongji
```

## Quick Start

```bash
/lj-plan "add per-user token quota"   # 1. 계획 생성 (docs/plans/ 자동 부트스트랩)
/lj-sprint add token-quota             # 2. 스프린트 큐에 추가
/lj-worktree next                      # 3. 워크트리 + Claude 자동 실행
/lj-crisp                              # 4. 진행 상황 확인
/lj-serve feat/token-quota             # 5. 머지 + 검증 + Result 기록
```

See [GUIDE.md](GUIDE.md) for detailed scenarios (greenfield, brownfield, parallel execution, etc.).

## Commands

| Command | Stage | Description |
|---------|-------|-------------|
| `/lj-plan <feature>` | Design | Create plan with agent team analysis |
| `/lj-sprint [action]` | Queue | Manage sprint queue (add, status, reorder) |
| `/lj-worktree [target]` | Launch | Create worktree + start execution |
| `/lj-cook` | Cook | (Auto) Iterative spec -> plan -> build |
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

`/lj-plan` or `/lj-sprint`을 처음 실행하면 자동으로 부트스트랩됩니다. 수동 설정 불필요.

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

### Parallel Execution (Mode C)

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
1. Test first (Red -> Green -> Refactor)
2. Separate structural and behavioral commits
3. No `git add -A` -- stage specific files
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
