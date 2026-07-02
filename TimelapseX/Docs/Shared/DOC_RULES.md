# Documentation Rules

This document defines how documentation is created, organized, and
finalized for StreakX and future projects that copy this doc set.

---

## Purpose

- Keep shared documentation reusable across projects.
- Keep project documentation specific to one app or one scope snapshot.
- Reduce duplication by giving each document a single job.
- Turn rough project notes into stable project docs before implementation.

---

## Document Types

### Shared Documents

Use shared documents for rules and workflows that apply across projects.

- `README.md`: high-level index of the shared doc set.
- `README.md` also carries the shared snapshot version and status.
- `ARCHITECTURE_PRINCIPLES.md`: architecture and design constraints.
- `RULES.md`: operating rules for AI and contributors.
- `GIT_PRACTICES.md`: branching, commit, and git workflow.
- `AI_WORKFLOW.md`: prompt format and task execution flow.
- `DOC_RULES.md`: documentation structure and governance.

### Project Documents

Use project documents for information that belongs to one project only.

- `MVP_SCOPE.md`: project scope and explicit non-goals.
- `DATA_MODEL.md`: project data entities, relationships, and invariants.
- `TASKS.md`: task roadmap and execution order.
- `ENGINEERING_NOTES.md`: implementation notes and task handoff history.
- `MY_NOTES.md`: local project notes that are not part of the shared playbook.

---

## How To Classify A New Document

Choose `shared` when the document will be copied to other projects
without rewriting its meaning.

Choose `project` when the document depends on this app’s features,
models, scope, or implementation details.

If a document mixes both, split it into:

- one shared document for the reusable rule or process
- one project document for the project-specific details

---

## Documentation Workflow

1. Start with rough notes, feature ideas, and open questions.
2. Convert them into the appropriate project documents.
3. Move any reusable process or rule into a shared document.
4. Keep each document focused on one concern.
5. Remove duplicated guidance instead of repeating it in multiple docs.
6. Finalize the wording before implementation starts.

---

## Writing Rules

- Every document should state its purpose near the top.
- Every document should use clear headings and short sections.
- Every document should avoid re-explaining rules that already exist
  in another canonical doc.
- Every doc should link to the authoritative source instead of copying
  the same policy verbatim.
- Project documents should describe what this project needs, not how
  every future project should work.
- Shared documents should describe stable policy, not temporary project
  decisions.

---

## Maintenance Rules

- Update shared documents only when the shared rule itself changes.
- Bump the shared snapshot version in `README.md` by `0.0.1` for every
  shared rules or workflow change, even if the change is minor.
- Update project documents when the project scope, data, or tasks
  change.
- When a new repeated pattern appears in project work, promote it into a
  shared document if it should apply to future projects.
- When a rule no longer applies, remove it from the canonical document
  and leave a short note in the relevant project history if needed.
