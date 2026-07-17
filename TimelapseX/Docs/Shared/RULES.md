# Rules

These rules apply to all projects unless explicitly overridden
in project-specific documentation.

---

## Core Rules

1. **Git Branching First**: Before writing any code, modifying any files, or starting implementation work, you **must** create and check out the correct task branch. If branch creation or checkout fails, you **must stop immediately** and resolve the branch issue before continuing. Follow the naming and branching workflow rules in `GIT_PRACTICES.md`.

2. Before writing any code, describe the approach and wait for approval.
   If requirements are ambiguous, ask clarifying questions first.

3. Prefer keeping implementation work to 3 files or fewer.
   If a cohesive task genuinely needs more files, document the reason
   and keep the scope narrow instead of splitting it artificially.

4. Keep one primary module, view, or view model per file when practical.
   If a file intentionally groups related types, the filename must still
   match the primary type and the grouping must be justified.

5. After writing code, list:
   - Approach summary
   - Files modified
   - Possible breakpoints
   - Edge cases
   - Suggested manual tests 
   Record the final notes in `docs/project/ENGINEERING_NOTES.md`.
   Do not rely on chat memory.

6. When there is a bug:
   - First write a test that reproduces the bug
   - Then fix the code until the test passes

7. Every time a mistake is corrected, a new rule must be added to this
   file so it never happens again.

8. When multiple tasks are provided, expand any inclusive range and
   execute them one at a time in the given order, returning to
   `version/v2` between tasks.

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

10. **Branch required for every task, including bug fixes.** Rule 1 applies to all work — feature implementation, bug fixes, UI tweaks, and refactors alike. There is no exception for "small" or "quick" changes. If you are about to modify a source file and you are not on a task branch, stop and create one first.
11. **Keep SwiftPM platform constants compatible with the manifest tools version.** When a test-only package uses `swift-tools-version: 6.0`, do not use platform constants introduced by a later PackageDescription release; use an older compatible minimum or raise the tools version deliberately.
12. **Declare the host platform for cross-platform SwiftPM tests.** If app logic is tested with `swift test` on macOS, set an explicit supported macOS version in `Package.swift` before using APIs gated by a host OS availability requirement.
13. **Mark pure policies nonisolated under default MainActor isolation.** Stateless constants and functions used by persistence or detached export work must be explicitly `nonisolated` so builds stay warning-free and Swift 6 compatible.
14. **Present system pickers from a stable screen-level view.** A toolbar `Menu` item should toggle picker presentation instead of embedding `PhotosPicker` or another modal presenter directly inside the menu.
15. **Model slider ranges and steps as tested policy.** When a setting has domain-specific bounds or increments, define them outside the view and cover clamping and conversion with unit tests.
