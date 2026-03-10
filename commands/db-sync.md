---
description: "Sync database: migrate, detect schema drift, seed, verify"
---

Synchronize the database schema and seed data.

If `.claude/forge.local.md` exists, read it for explicit command overrides.

## Steps

### 1. Pre-check: Database Server

Check if the database is running. Read the project's CLAUDE.md for the specific database setup command.

```bash
# Common patterns — adapt to the project
docker ps --format '{{.Names}} {{.Status}}' | grep -i postgres
```
- If not running: suggest the project's infrastructure start command
- If running but unhealthy: warn and continue (may still work)

### 2. Run Migrations

Use the project's migration command from CLAUDE.md:
```bash
# Example: pnpm db:migrate, npx prisma migrate deploy, etc.
```

### 3. Detect Migration Sequence Conflicts

Check for duplicate sequence numbers in migration files:
```bash
# Find migration directory from CLAUDE.md
ls <migration-dir>/*.sql 2>/dev/null || ls <migration-dir>/*.ts 2>/dev/null
```
- If two files share the same sequence prefix, warn that one may have been skipped
- Compare applied migrations against migration files if possible

### 4. Verify Schema Completeness

For each migration file that was potentially skipped:
1. Extract the ALTER/CREATE statements
2. Check if the columns/tables already exist
3. If missing: apply the statements manually
4. Report what was applied

### 5. Run Seed

Use the project's seed command from CLAUDE.md:
```bash
# Example: pnpm db:seed, npx prisma db seed, etc.
```
- If seed fails with missing column/table: parse the error and find the migration
- If seed fails with other errors: report and stop

### 6. Report

```
## DB Sync Report

| Step | Status | Details |
|------|--------|---------|
| Database | OK/WARN | running / unhealthy |
| Migrations | OK/WARN | N applied, M files total |
| Schema Check | OK/FIX | N columns added manually |
| Seed | OK/FAIL | N records upserted |
```

## Rules
- Never drop tables or columns — only additive operations
- If a migration creates an index that already exists, it's safe to skip (IF NOT EXISTS)
- Read CLAUDE.md for all project-specific database commands
