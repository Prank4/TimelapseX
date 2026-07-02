# Rules

These rules apply to all projects unless explicitly overridden
in project-specific documentation.

---

## Core Rules

1. For git workflow, follow `GIT_PRACTICES.md`.

2. Before writing any code, describe the approach and wait for approval.
   If requirements are ambiguous, ask clarifying questions first.

3. Prefer keeping implementation work to 3 files or fewer.
   If a cohesive task genuinely needs more files, document the reason
   and keep the scope narrow instead of splitting it artificially.

4. After writing code, list:
   - Approach summary
   - Files modified
   - Possible breakpoints
   - Edge cases
   - Suggested manual tests 
   Record the final notes in `docs/project/ENGINEERING_NOTES.md`.
   Do not rely on chat memory.

5. When there is a bug:
   - First write a test that reproduces the bug
   - Then fix the code until the test passes

6. Every time a mistake is corrected, a new rule must be added to this
   file so it never happens again.

7. When multiple tasks are provided, expand any inclusive range and
   execute them one at a time in the given order, returning to
   `version/v2` between tasks.

8. Before implementation work starts, create and check out the correct
   task branch. If branch creation fails, stop and resolve the branch
   issue before writing more code.

---

## Documentation Authority Rule

- Documentation is the source of truth.
- If documentation and code disagree, documentation wins
  until explicitly updated.

---

## Change Discipline Rule

- Shared documentation is updated only **between features**,
  never during feature implementation.

---

## Learned Rules

(Empty by design. This section grows over time.)
