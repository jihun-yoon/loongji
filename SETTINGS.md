# Loongji — Project Settings

## Overview

Loongji works out of the box by reading your project's `CLAUDE.md` for context. For projects that need workflow customization, create an optional settings file.

## Setup (Optional)

Create `.claude/loongji.local.md` in your project root:

```yaml
---
# Plan document management
plans_dir: docs/plans                    # Where plan documents live
sprint_file: docs/plans/SPRINT.md       # Sprint tracking file
plan_index: docs/plans/README.md        # Plan index file

# Worktree configuration
worktree_prefix: myproject              # Prefix for worktree directories (default: repo name)
max_worktrees: 3                        # Maximum concurrent worktrees

# Loongji execution configuration
loongji:
  plan_iterations: 3                    # Number of planning iterations before build
  max_workers: 2                        # Parallel workers for Mode C build
  max_build_iterations: 30             # Max build iterations per worker

# Verification commands (override auto-detection)
commands:
  install: pnpm install                 # Dependency install
  build: pnpm build                     # Full build
  build_shared: pnpm --filter @org/shared build  # Shared package build (monorepo)
  test: pnpm test                       # Run tests
  test_single: pnpm --filter server vitest run  # Single test file prefix
  typecheck: npx tsc --noEmit          # Type checking
  dev: pnpm dev                         # Start dev servers
  migrate: pnpm db:migrate              # Database migration
  seed: pnpm db:seed                    # Database seed

# Dev server configuration
dev:
  ports: [3000, 4000]                   # Ports to kill/monitor
  health_checks:                        # Health check URLs
    - http://localhost:4000/health
    - http://localhost:3000

# Post-merge configuration
post_merge:
  skip_smoke_test: false                # Skip API smoke test phase
  skip_db_sync: false                   # Skip database sync phase
  extra_steps: []                       # Additional commands after merge
  known_failures:                       # Test failures to ignore (pre-existing)
    - "rate-limiter export"

# Smoke test endpoints (project-specific)
smoke_test:
  auth_command: "curl -s -X POST http://localhost:4000/api/v1/auth/login"
  endpoints:
    - { path: "/api/v1/sessions", name: "Sessions" }
    - { path: "/api/v1/projects", name: "Projects" }
---

Additional project-specific notes for the Loongji workflow.
For example: migration gotchas, merge checklist items, codebase patterns.
```

## All settings are optional

If `.claude/loongji.local.md` doesn't exist, Loongji will:
- Auto-detect package manager from lockfiles
- Use `docs/plans/` as default plan directory
- Derive worktree prefix from repository name
- Default to 3 planning iterations and 2 build workers
- Read CLAUDE.md for command context (Claude does this automatically)

Settings file is useful when:
- Your project uses non-standard paths
- You want explicit, repeatable commands
- You need to tune worker count or iteration limits
- You have project-specific smoke test endpoints
- You want to document known test failures to ignore
