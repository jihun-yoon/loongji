0a. Study `specs/*` with up to 500 parallel Sonnet subagents to learn the application specifications.
0b. Study @IMPLEMENTATION_PLAN.md.
0c. For reference, the application source code is in `src/*`.

1. Your task is to implement functionality per the specifications. Study @IMPLEMENTATION_PLAN.md and identify ALL unchecked `- [ ]` items. Before making changes, search the codebase (don't assume not implemented) using Sonnet subagents.

2. **Parallelize independent tasks.** Group unchecked items into independent sets (no shared file modifications). For each independent group, spawn a background Agent with `isolation: "worktree"` to implement the task. Each agent should receive: the task description, relevant spec files, and AGENTS.md contents. Use Opus subagents when complex reasoning is needed (debugging, architectural decisions). For dependent tasks (must happen in order), execute them sequentially after their dependencies complete.

3. **Test first.** Each agent must write or update a failing test first (Red), write minimum code to pass (Green), then tidy (Refactor). Ultrathink.

4. When you discover issues, immediately update @IMPLEMENTATION_PLAN.md with your findings. When resolved, mark the item as complete (`- [x]`).

5. **Separate structural and behavioral commits.** If you need to refactor before implementing, commit the refactor first (structural change), then commit the new functionality (behavioral change). Never mix both in one commit. Stage only the files you changed — do NOT use `git add -A`. After the commit, `git push`.

6. When the tasks pass, update @IMPLEMENTATION_PLAN.md, then commit and push.

99999. Important: When authoring documentation, capture the why — tests and implementation importance.
999999. Important: Single sources of truth, no migrations/adapters. If tests unrelated to your work fail, resolve them as part of the increment.
99999999. You may add extra logging if required to debug issues.
999999999. Keep @IMPLEMENTATION_PLAN.md current with learnings — future iterations depend on this to avoid duplicating efforts. Update especially after finishing your turn.
9999999999. When you learn something new about how to run the application, update @AGENTS.md but keep it brief.
99999999999. For any bugs you notice, resolve them or document them in @IMPLEMENTATION_PLAN.md even if unrelated to the current piece of work.
999999999999. Implement functionality completely. Placeholders and stubs waste efforts and time redoing the same work.
9999999999999. When @IMPLEMENTATION_PLAN.md becomes large, periodically clean out completed items from the file.
99999999999999. If you find inconsistencies in the specs/* then use an Opus subagent with 'ultrathink' to update the specs.
999999999999999. IMPORTANT: Keep @AGENTS.md operational only — status updates and progress notes belong in `IMPLEMENTATION_PLAN.md`. A bloated AGENTS.md pollutes every future loop's context.
9999999999999999. **Stop if stuck.** If you have attempted the same fix 3 times without progress, commit what you have with a description of what is failing and why, then move on to a different item. Do NOT delete, disable, or weaken tests to force a pass.
