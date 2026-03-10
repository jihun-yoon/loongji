---
description: "Clean restart dev servers: kill ports, sync deps, start fresh"
---

Clean restart of development servers.

If `.claude/forge.local.md` exists, read it for explicit command overrides.

## Steps

### 1. Detect Dev Server Configuration

Read the project's CLAUDE.md to determine:
- Which ports are used (common: 3000, 4000, 5173, 8080)
- Dev server start command (e.g., `pnpm dev`, `npm run dev`, `yarn dev`)
- Any shared package build requirements
- Health check endpoints (if available)

### 2. Kill Existing Processes

```bash
# Kill processes on detected ports
lsof -ti:<port1>,<port2> | xargs kill -9 2>/dev/null || true
```
- Wait 2 seconds for ports to release
- Verify ports are free: `lsof -ti:<ports>` should return empty

### 3. Dependency Sync

Check if dependencies are stale:
```bash
# Compare lockfile modification time vs node_modules
```
- If lockfile is newer than node_modules: run install command
- If install adds/removes packages: report the changes
- Otherwise: skip (already synced)

### 4. Shared Package Build (if applicable)

If the project has shared packages that must be rebuilt (check CLAUDE.md):
```bash
# Example: pnpm --filter @org/shared build
```
- Only rebuild if source is newer than dist
- Skip if dist is up to date

### 5. Start Dev Servers

```bash
# Use the project's dev command from CLAUDE.md
```
- Run in background
- Wait up to 15 seconds for servers to respond
- Check health endpoints if available

### 6. Quick Health Check

Once servers respond:
- Check for recurring errors in server output
- If background errors appear: warn but don't block

### 7. Report

```
## Dev Restart Report

| Component | Status | Details |
|-----------|--------|---------|
| Port cleanup | OK | ports freed |
| Dependencies | OK/SYNC | N packages updated |
| Shared build | OK/SKIP | rebuilt / up to date |
| Server | OK/FAIL | healthy / error |
| Web | OK/FAIL | ready / error |
| Background errors | NONE/WARN | list if any |
```

## Rules
- Read CLAUDE.md for all project-specific commands and ports
- Never run full project builds speculatively — only shared packages if needed
- If port kill fails (no process), that's OK — just proceed
- Do NOT run database operations — use `/forge db-sync` for that
