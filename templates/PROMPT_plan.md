## PROJECT CONTEXT
- Goal: [project-specific goal]
- Key features: [key features]
- Tech stack: [tech stack]
- Constraints: [constraints]

---

0a. Study `specs/*` with up to 250 parallel Sonnet subagents to learn the application specifications.
0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand the plan so far.
0c. Study `src/lib/*` with up to 250 parallel Sonnet subagents to understand shared utilities & components.
0d. For reference, the application source code is in `src/*`.

1. Study @IMPLEMENTATION_PLAN.md (if present; it may be incorrect) and use up to 500 Sonnet subagents to study existing source code in `src/*` and compare it against `specs/*`. Use an Opus subagent to analyze findings, prioritize tasks, and create/update @IMPLEMENTATION_PLAN.md. Ultrathink. Consider searching for TODO, minimal implementations, placeholders, skipped/flaky tests, and inconsistent patterns. Study @IMPLEMENTATION_PLAN.md to determine starting point for research and keep it up to date with items considered complete/incomplete using subagents.

TASK FORMAT — parallel workers (Mode C) parse this file with regex, so follow these rules exactly:
- Use `- [ ]` for pending items and `- [x]` for completed items. No other bullet styles.
- Each task should be small enough to complete in one iteration (one context window). If you cannot describe the change in 2-3 sentences, split it.
- Below each `- [ ]` line, add indented context: what to implement, acceptance criteria, and relevant files. Workers read the full file for context.
- Order tasks by dependency: foundational work (schema, shared utilities) before features that depend on them.
- Group independent tasks at the same level so parallel workers can safely grab them simultaneously. Tasks within the same group must not modify the same files.
- Mark dependency chains clearly — if task B requires task A, place A above B under the same section header.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search first. Treat `src/lib` as the project's standard library for shared utilities and components. Prefer consolidated, idiomatic implementations there over ad-hoc copies.

ULTIMATE GOAL: Refer to the PROJECT CONTEXT above. Consider missing elements and plan accordingly. If an element is missing, search first to confirm it doesn't exist, then if needed author the specification at specs/FILENAME.md. If you create a new element then document the plan to implement it in @IMPLEMENTATION_PLAN.md using a subagent.
