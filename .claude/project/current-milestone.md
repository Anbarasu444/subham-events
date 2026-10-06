# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M4** |
| Milestone name | Splash & App Bootstrap |
| Phase | User App (M3–M23) |
| Status | **NOT_STARTED** |
| Spec | `.claude/project/milestones/M4-splash-app-bootstrap.md` (status: DRAFT — ratified by `START MILESTONE M4`) |
| Started date | — |
| Completed date | — |
| Approval status | Not started — awaiting `START MILESTONE M4` |

## Objective
Branded native splash, ordered bootstrap with failure handling, global error capture, FreeRASP in observe mode, real app version, and a cold-start baseline.

## Completed work
- None for M4.

## In-progress work
- None.

## Blocked work
- None. M4 open questions answered (placeholder logo, theme `#FF7E7E`, packages approved, Android build + DB confirmed).

## Tests completed
- N/A (not started).

## Reviews
| Review | Status |
|---|---|
| Security review | NOT_STARTED |
| Performance review | NOT_STARTED |
| Notification review | NOT_STARTED |
| Documentation | NOT_STARTED |

## Known issues
- See `known-issues.md`: GI-4, GI-5 (package ID), GI-7 (version — M4 scope), GI-8…GI-12. GI-6 and GI-13 resolved (user confirmed).
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21. Assumptions A1–A12, O1, O2 per `domain-model.md` §9.

## Files changed
- None for M4.

## Files pending approval
- M3 files are staged but not committed; the user commits personally.

## Next milestone
- M5 — Authentication (spec drafted at the M4 gate).

## Do NOT start
- M4 work before `START MILESTONE M4`
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M3 User App Foundation: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-06 |
| Completed / approved | 2026-10-06 — `APPROVE MILESTONE M3` issued by the user |
| Spec | `milestones/M3-user-app-foundation.md` (CONFIRMED) |

Evidence at approval: backend lint/typecheck/format clean, 33 unit + 9 e2e tests, build OK, prod deps 0 vulnerabilities; Flutter analyze clean, 32 tests, iOS simulator build + launch OK; code and security reviews PASS WITH FINDINGS (fixed or recorded GI-9…GI-12). Not confirmed at approval: Android build (GI-6) and DB migration run against the local databases (GI-13). Deviations (a)–(f) in the M3 spec change log accepted with the approval.

## Earlier milestones
- M2 Global Domain Model: COMPLETED 2026-10-06 (committed `658d59d`).
- M1 Global Architecture: COMPLETED 2026-10-06 (committed `1c21c35`).
