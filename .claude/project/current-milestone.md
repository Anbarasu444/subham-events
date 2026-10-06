# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M2** |
| Milestone name | Global Domain Model |
| Phase | Governance & Architecture (M1–M2) |
| Status | **NOT_STARTED** |
| Spec | `.claude/project/milestones/M2-global-domain-model.md` (status: DRAFT — ratified by `START MILESTONE M2`) |
| Started date | — |
| Completed date | — |
| Approval status | Not started — awaiting `START MILESTONE M2` |

## Objective
Define the complete domain model — entities, relationships, invariants, state machines and the logical PostgreSQL schema — documentation only.

## Completed work
- None for M2.

## In-progress work
- None.

## Blocked work
- None. Note: M2 must resolve ADR-0014 (money storage type: exact decimal rupees vs double) before any money field is modelled.

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
- See `known-issues.md` (GI-3, GI-4 open; neither blocks M2).
- ADR-0014 deferred from M1 to M2 (owner milestone M2).

## Files changed
- None for M2.

## Files pending approval
- M1 files are uncommitted; **the user commits M1 personally** (instruction 2026-10-06).

## Next milestone
- M3 — User App Foundation (spec drafted during M2; locked until M2 is COMPLETED and approved).

## Do NOT start
- M2 work before `START MILESTONE M2`
- Any User App feature work (M3+)
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M1 Global Architecture: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-06 |
| Completed / approved | 2026-10-06 — `APPROVE MILESTONE M1` issued by the user |
| Spec | `milestones/M1-global-architecture.md` (CONFIRMED) |

Acceptance criteria at approval: AC-1 … AC-9, AC-11, AC-12 done. AC-10: ADR-0003, 0004, 0006–0013, 0015 Accepted; ADR-0014 (money storage type) explicitly deferred to owner milestone M2, as AC-10 permits.

Key decisions (all user-ratified): NestJS 11; monorepo; TypeORM + migration scripts; ImageKit.io media; Firebase (Google, phone) for users/vendors and username + password for admins, no 2FA at launch; two separate Flutter codebases; hosting deferred (localhost + local PostgreSQL 18); Node 24 + npm; staging + prod environments; cursor pagination (offset for admin tables); backend foundation in M3; event payments record-only (platform collects no user-to-vendor money).

Reviews: security (security-manager, PASS WITH FINDINGS, 16 findings addressed), performance, notification and documentation — done.

Files changed in M1 (all under `.claude/project/`): `architecture.md`, `architecture/` (backend, identity-access, flutter, admin-cms, media-and-deep-links, environments, quality, threat-model), `api-contracts.md`, `database-schema.md`, `notification-matrix.md`, `payment-architecture.md`, `decisions.md`, `decisions/ADR-0006` … `ADR-0015`, `milestones.md`, `milestones/M1-global-architecture.md`, `milestones/M2-global-domain-model.md` (DRAFT), `current-milestone.md`, `progress.md`.
