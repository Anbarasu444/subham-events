# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M2** |
| Milestone name | Global Domain Model |
| Phase | Governance & Architecture (M1–M2) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M2-global-domain-model.md` (status: CONFIRMED 2026-10-06) |
| Started date | 2026-10-06 |
| Completed date | — |
| Approval status | Awaiting user confirmation of assumptions A1–A12 (+ O1, O2) and `APPROVE MILESTONE M2` |

## Objective
Define the complete domain model — entities, relationships, invariants, state machines and the logical PostgreSQL schema — documentation only.

## Completed work (acceptance-criteria evidence)
| AC | Evidence | Status |
|---|---|---|
| AC-1 | `domain-model.md` §2 — 34 entities incl. all CLAUDE.md §8 entities (PaymentTransaction → EventPaymentNote, Admin → AdminUser) and M1 infrastructure entities; owner module, visibility, milestone; §5 key attributes | Done |
| AC-2 | `domain-model.md` §3 ERD + cardinality/FK table (all FKs RESTRICT — R11) | Done |
| AC-3 | `domain-model.md` §4.1–4.16 state machines with actors and side effects; unlisted transitions forbidden. Quotation states partly ⏸ R3 | Done (R3 parts held) |
| AC-4 | Platform fee vs event payment notes fully separate (`payment-architecture.md` §0–2, invariant 9); ADR-0014 Accepted; all money `numeric(12,2)` | Done |
| AC-5 | Starting price vs agreed amount: invariant 1, §4.7 (`bookings.agreed_amount` only authoritative value), budget model §7 | Done |
| AC-6 | `notification-matrix.md` Part B updated (N15 removed, N16/N18/N19 refined, N23–N26 added); each row maps to a transition in §4 | Done |
| AC-7 | `database-schema.md` Part C — all tables with constraints, indexes, creating milestone; growth estimates | Done |
| AC-8 | `domain-model.md` §8 data lifecycle per entity (R11), compliance risk flagged | Done |
| AC-9 | Answered: R1, R2, R4, R5, R7, R8, R9, R11, R12. **Deferred with owner milestone:** R3 → M15, R6 → M28/M29, R10 → M26 (held by user for client confirmation). Assumptions A1–A12 and O1/O2 listed for confirmation | Done with deferrals |
| AC-10 | `milestones/M3-user-app-foundation.md` DRAFT; only `.claude/project/` changed during M2 | Done |

## Tests completed
- Documentation milestone: no executable tests. Cross-checks: every CLAUDE.md §8 entity present; every state transition with a notification maps to a matrix row; money columns all `numeric(12,2)`; no change outside `.claude/project/`.

## Reviews
| Review | Status | Notes |
|---|---|---|
| Security review | Done — security-manager PASS WITH FINDINGS (no Critical) | Fixed: H1 self-dealing ban + review after service date (A12); H2 composite FKs for denormalised owner columns (inv. 13); M1 vendor view of user data (A9); M2 RSVP abuse limits, digest notifications, token rotation; M3 rating removal + atomic counters; M4 FCM token reassignment; M5 audited admin reads + GUEST actor; M6 pending revisions for approved listings; M7 R11 mitigations noted (column encryption evaluated M5); L1–L4 aligned. PII inventory recorded in review |
| Payment review | Done — payment-manager PASS WITH FINDINGS | Fixed: one SUCCESS per submission + block new orders during REVIEW_REQUIRED; REVIEW_REQUIRED resolution defined; CREATED→FAILED + SUCCESS check; single authoritative agreed amount (bookings); "Paid" includes notes on cancelled bookings (A11); attempt amount typed; status history = audit_logs; reconciliation driven by Razorpay captures; ₹1.00 minimum. Refund mechanism ⏸ R6 |
| Performance review | Done | Index per list query (Part C), cursor-friendly composite indexes, admin queues as partial indexes, denormalised rating counters, growth estimates and purge policy for technical tables |
| Notification review | Done | Matrix ↔ state machines consistent; noisy cases digested (RSVP); private notes produce no notifications |
| Documentation | Done | domain-model, database-schema Part C, notification matrix, payment architecture, threat model, M3 spec, ADR index |

## Known issues
- R11 is an **interim development rule** (keep all data, mark deleted); final account-deletion policy to be discussed — owner M21, release-blocking at M72.
- See `known-issues.md` (GI-3, GI-4 open; neither blocks M2).
- ADR-0014 resolved in M2 (Accepted 2026-10-06).

## Files changed
- `domain-model.md` (rewritten), `database-schema.md` (Part A §6–7, Part C), `notification-matrix.md` Part B, `payment-architecture.md` §0–3, `architecture/threat-model.md`, `architecture/identity-access.md` (status values), `milestones/M3-user-app-foundation.md` (new DRAFT), `milestones/M2-global-domain-model.md` (change log)
- `decisions/ADR-0014-money-representation.md` (Accepted), `decisions.md`, `architecture.md`, `api-contracts.md` §8, `database-schema.md` §5, `payment-architecture.md`, `architecture/flutter.md`, `decisions/ADR-0006-orm-and-migrations.md` (money note), `milestones/M2-global-domain-model.md`, `milestones.md`, `current-milestone.md`, `progress.md` — spec open question 12 / AC-4.

## Files pending approval
- M1 was committed by the user (`1c21c35`). M2 files are uncommitted; the user commits personally.

## Next milestone
- M3 — User App Foundation (spec drafted during M2; locked until M2 is COMPLETED and approved).

## Do NOT start
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
