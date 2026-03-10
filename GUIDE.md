# Loongji Usage Guide

## Scenario A: Greenfield (New Project)

A brand-new project with no existing plan documents.

### Prerequisites

1. Git repository initialized
2. `CLAUDE.md` written (build/test/dev commands, tech stack)

```bash
git init my-project && cd my-project
# Write CLAUDE.md (project overview, commands, conventions)
```

### Step 1: Install Plugin

```bash
claude plugin install loongji
```

### Step 2: Create First Plan

```bash
/lj-plan "implement user authentication system"
```

`/lj-plan` automatically:
- Creates `docs/plans/{done,planned,reference}/` directories
- Creates `docs/plans/README.md` (plan index)
- Creates `docs/plans/SPRINT.md` (sprint state)
- Writes `PLAN-YYYYMMDD-user-auth.md`

### Step 3: Add to Sprint

```bash
/lj-sprint add user-auth
```

### Step 4: Execute

```bash
/lj-worktree next     # Create worktree + auto-launch Claude
/lj-crisp              # Check progress
/lj-serve              # Merge when complete
```

### Greenfield Tips

- If CLAUDE.md is empty, `/lj-cook` will struggle to infer build/test commands — write at least the commands section
- Start small (2-3 phases) for your first plan — scale up after you're comfortable with the workflow
- `.claude/loongji.local.md` is unnecessary at first — defaults are sufficient

---

## Scenario B: Brownfield (Existing Project, First Loongji Adoption)

An existing codebase with no plan document structure.

### Prerequisites

1. Git repository with existing code
2. `CLAUDE.md` exists (or write one)

### Step 1: Install Plugin

```bash
claude plugin install loongji
```

### Step 2: (Optional) Document Existing Work

No need to retroactively create plan documents for existing code. Just start managing future work with Loongji.

If you want to record existing history:
```bash
mkdir -p docs/plans/done
# Manually write PLAN files for completed work (optional)
```

### Step 3: Plan New Feature

```bash
/lj-plan "add rate limiting to existing API"
```

Auto-bootstrap creates the `docs/plans/` structure. The agent team **analyzes the existing codebase** and reflects patterns in the plan.

### Step 4: Execute

Same as greenfield:
```bash
/lj-sprint add rate-limiting
/lj-worktree next
```

### Brownfield Tips

- `/lj-plan`'s agent team analyzes existing code patterns, so plans are generated to match project conventions
- For monorepos, configure `build_shared` command in `.claude/loongji.local.md`
- If there are pre-existing test failures, register them in `post_merge.known_failures` to skip during `/lj-serve` verification

---

## Scenario C: Brownfield (Existing Project, Already Using docs/plans/)

A project that already uses Loongji's document structure or a similar system.

### If Existing Structure is Compatible

If you already have `docs/plans/` + `PLAN-*.md` + `SPRINT.md` in the expected format:

```bash
claude plugin install loongji
/lj-crisp   # Check current state
```

Ready to use immediately. Bootstrap won't touch existing files.

### If Existing Structure Differs

If plan documents live in a different location, specify paths via `.claude/loongji.local.md`:

```yaml
---
plans_dir: my-docs/features
sprint_file: my-docs/features/CURRENT.md
plan_index: my-docs/features/INDEX.md
---
```

If existing document format differs (e.g., RFC, ADR style):
- Loongji expects `PLAN-YYYYMMDD-*.md` format
- Keep existing documents in `reference/` and write new plans in Loongji format

---

## Scenario D: Quick Single Feature (No Sprint)

Small bug fix or simple feature without sprint management overhead.

```bash
# 1. Create plan
/lj-plan "fix: login page password validation bug"

# 2. Skip sprint, create worktree directly
/lj-worktree fix/login-validation

# 3. Merge when complete
/lj-serve fix/login-validation
```

`/lj-sprint` is useful when managing multiple plans. For single tasks, it can be skipped entirely.

---

## Scenario E: Large-Scale Parallel Execution

Running multiple plans concurrently.

```bash
# Create 3 plans
/lj-plan "token quota system"
/lj-plan "storage quota system"
/lj-plan "fix ops dashboard bugs"

# Add to sprint queue (dependency analysis is automatic)
/lj-sprint add token-quota
/lj-sprint add storage-quota      # → detects dependency on token-quota
/lj-sprint add ops-bugfix

# Launch all parallelizable plans simultaneously
/lj-worktree all                  # Only creates worktrees for unblocked items

# Check status
/lj-crisp

# Merge completed plans in order
/lj-serve fix/ops-bugfix          # Independent items first
/lj-serve feat/token-quota        # Dependency resolved → unblocks storage-quota
/lj-serve feat/storage-quota
```

### Parallel Execution Notes

- Recommended maximum: 3-4 concurrent worktrees (system resource limit)
- Plans modifying the same files must be merged sequentially (see SPRINT.md Merge Conflicts Risk)
- Monitor overall progress with `/lj-crisp`

---

## Scenario F: Worker Count Tuning

Configure workers based on plan size.

| Plan Size | Phases | Tasks | Recommended Workers |
|-----------|--------|-------|---------------------|
| Small | 1-2 | < 5 | 1 (sequential) |
| Medium | 3-4 | 5-15 | 2 |
| Large | 5+ | 15+ | 3 |

Override defaults via `.claude/loongji.local.md`:
```yaml
---
loongji:
  max_workers: 3
  plan_iterations: 5
---
```

Or pass directly to loop.sh during `/lj-cook`:
```bash
./loop.sh --workers 3 30    # 3 workers, max 30 iterations each
```

---

## Command Flow Summary

```
/lj-plan ─── Create plan document
    │
    ▼
/lj-sprint ── Manage sprint queue (optional)
    │
    ▼
/lj-worktree ─ Create worktree + launch Claude
    │
    ▼ (automatic)
/lj-cook ──── spec → plan iterations → parallel build
    │
    ├── /lj-crisp ── Check progress (anytime)
    │
    ▼
/lj-serve ─── Merge + verify + record results + cleanup
```
