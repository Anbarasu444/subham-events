# Milestone Rules
Statuses: NOT_STARTED, IN_PROGRESS, BLOCKED, IN_REVIEW, FAILED, COMPLETED.

- The first milestone is M1. There is no M0.
- Every milestone needs a spec at `.claude/project/milestones/Mxx-<slug>.md` (template: `_TEMPLATE.md`) with objective, in-scope, out-of-scope, deliverables, cross-layer impact, acceptance criteria, required reviews, risks and open questions.
- Specs are drafted as DRAFT when the user asks, or at the gate after the previous milestone is approved. `START MILESTONE <ID>` ratifies the spec (CONFIRMED). Refuse START if no spec exists.
- Scope changes after START need an explicit user request and an entry in the spec's change log.
- A milestone needs architecture, functionality, UI/UX, state/data correctness, tests, security, performance, notification and documentation checks, with evidence for every acceptance criterion.
- On reaching review: set IN_REVIEW, report, stop. On `APPROVE MILESTONE <ID>`: mark COMPLETED, update progress, set next milestone NOT_STARTED, stop. Never auto-advance.
