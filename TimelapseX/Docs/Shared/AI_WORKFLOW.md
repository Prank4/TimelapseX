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
1. Read the task from `TASKS.md`.
2. Follow `RULES.md`, `GIT_PRACTICES.md`, `MVP_SCOPE.md`, and `DATA_MODEL.md`.
3. **Check out the task branch**: Create and check out the correct task branch following the naming convention in `GIT_PRACTICES.md` *before* describing any approach or writing code. If branch creation/checkout fails, stop immediately.
4. Describe the approach and file list on the correct task branch before coding.
5. Implement, test, and commit the changes on the task branch.

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
3. For each task:
   a. Create and check out the correct task branch following the naming convention in `GIT_PRACTICES.md` *before* doing any research/analysis or writing any code.
   b. Analyze the task on the checked out branch and describe the approach.
   c. Implement, test, and commit the changes on the task branch.
   d. Return to `version/v2` (or the appropriate base branch) before moving to the next task.
4. Stop if a task is blocked or needs approval before proceeding.

---

## When AI Fails
- Stop immediately
- Identify the failure mode
- Add a rule to RULES.md
- Retry with tighter constraints
