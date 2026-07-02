# Git Practices

## Commit Philosophy
- Small, focused commits
- One logical change per commit
- No “misc” commits

## Commit Messages
Format:
<type>: <short description>

Examples:
- feat: add task archiving
- fix: prevent duplicate completions
- docs: clarify data model rules

## What NOT to Commit
- DerivedData
- Build artifacts
- Local SwiftData stores
- Secrets or tokens

## Branching
- main: always stable
- feature branches for non-trivial work
- Version 2 work must branch from `version/v2`.
- Branch names must follow `tasks/<task-number>-<task-name>`.
- Use hyphens only in the branch suffix; spaces are not valid in Git ref names.
- Example: `tasks/2.2.7-task-settings-popup-presentation`.
- Check out the branch before any implementation work starts.
- If branch creation fails, stop and resolve the branch issue before continuing implementation.

## Pushing Rules
- WIP commits allowed on feature branches
- main must be clean and buildable
- Finish each task branch with a focused commit before handoff.
