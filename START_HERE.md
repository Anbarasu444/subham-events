# Claude Milestone Control Commands

Read the root `CLAUDE.md` (authoritative project context) together with this file.

There is **no M0**. Governance setup is project initialization, not a milestone. The roadmap starts at **M1 — Global Architecture**.

## Start a Milestone

Use this command to explicitly start the next approved milestone:

START MILESTONE <MILESTONE_ID>

Example:

START MILESTONE M3

Claude MUST validate before starting:

1. The milestone exists in `.claude/project/milestones.md`.
2. It is the next allowed milestone.
3. The previous milestone is COMPLETED. (M1 has no previous milestone; instead, governance initialization must be recorded as complete in `.claude/project/progress.md`.)
4. The previous milestone has explicit user approval (`APPROVE MILESTONE <ID>`). Not applicable to M1.
5. No blocking issue exists.
6. The milestone is not already completed.
7. The milestone is not locked by project governance (phase locks in `CLAUDE.md` §10).
8. A milestone spec exists at `.claude/project/milestones/<ID>-*.md` with scope and acceptance criteria. Issuing START ratifies that spec (status → CONFIRMED).

If validation fails, Claude MUST NOT start the milestone and must explain why.

---

## Approve a Milestone

After implementation, testing, security review, performance review, notification review, and documentation are complete, Claude must set the milestone to IN_REVIEW and stop.

The ONLY valid approval command is:

APPROVE MILESTONE <MILESTONE_ID>

Example:

APPROVE MILESTONE M3

Claude MUST NOT treat these as formal approval:

- Looks good
- Good
- Fine
- Okay
- Continue
- Proceed
- Great
- Nice
- Approved
- Go ahead
- Continue development
- Move forward

Only:

APPROVE MILESTONE <MILESTONE_ID>

is valid.

---

## Milestone Lifecycle

Spec DRAFT / NOT_STARTED
    ↓
START MILESTONE M3   (spec → CONFIRMED)
    ↓
IN_PROGRESS
    ↓
Implementation
    ↓
Testing
    ↓
Security Review
    ↓
Performance Review
    ↓
Notification Review
    ↓
Documentation
    ↓
IN_REVIEW
    ↓
APPROVE MILESTONE M3
    ↓
COMPLETED
    ↓
STOP

Claude MUST NOT automatically start the next milestone after approval.

The user must separately issue:

START MILESTONE <NEXT_MILESTONE_ID>

---

## Important Rule

Do not alter anything without explicit user permission.

Do not skip an incomplete milestone.

Do not start a new milestone until the previous milestone is:

- Implemented
- Tested
- Reviewed
- Documented
- Marked COMPLETED
- Explicitly approved by the user

When in doubt:

DO NOTHING.

Ask for permission.
