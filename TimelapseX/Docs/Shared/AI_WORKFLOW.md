# AI Workflow

## General Rule
AI is an assistant, not an authority.

All AI-generated code must:
- Follow RULES.md
- Follow ARCHITECTURE_PRINCIPLES.md
- Respect MVP_SCOPE.md (project-specific)

---

## Prompting Strategy

### Initial Project Prompt
- Full context
- Architecture
- Folder structure
- Explicit non-goals

Used once.

---

### Task-Based Prompts (Default)

Each task prompt should be as small as possible.
For Version 2 work, the prompt may be only the task number, for example:

`Task: 2.2.7`

The assistant should then:
1. Read the task from `TASKS.md`
2. Follow `RULES.md`, `GIT_PRACTICES.md`, `MVP_SCOPE.md`, and
   `DATA_MODEL.md`
3. Describe the approach and file list before coding
4. Follow the git workflow in `GIT_PRACTICES.md` for branch creation,
   checkout, and commit

Example:

"Task: 2.2.7
Follow `RULES.md` and `ARCHITECTURE_PRINCIPLES.md`.
Before writing code, describe the approach."

---

### Batch Task Prompts

Multiple tasks may be provided as an ordered list or as an inclusive
range such as `2.2.7 - 2.2.9`.

The assistant should:
1. Expand any range into individual task numbers in order.
2. Process exactly one task at a time.
3. For each task, analyze first, then follow the git workflow in
   `GIT_PRACTICES.md`, implement, commit, and return to `version/v2`
   before moving to the next task.
4. Stop if a task is blocked or needs approval before proceeding.

---

## When AI Fails
- Stop immediately
- Identify the failure mode
- Add a rule to RULES.md
- Retry with tighter constraints
