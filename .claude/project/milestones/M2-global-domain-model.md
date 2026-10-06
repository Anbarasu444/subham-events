# M2 — Global Domain Model

| Field | Value |
|---|---|
| Spec status | **DRAFT** — becomes CONFIRMED when the user issues `START MILESTONE M2` |
| Phase | Architecture |
| Depends on | M1 COMPLETED and approved (`APPROVE MILESTONE M1`) |
| Primary owner agent | architecture-manager (database-manager, payment-manager, notification-manager, security-manager as reviewers) |

## Objective
Define the platform's complete domain model — entities, relationships, invariants, state machines and the logical PostgreSQL schema — so every later milestone implements tables and endpoints from an agreed model rather than inventing them. **Documentation only. No migrations, no application code.**

## In scope
1. **Entity catalogue** — refine every entity in CLAUDE.md §8 (User, Vendor, Admin, VendorCategory, VendorListing, Event, EventVendor, ChecklistItem, Booking, Quotation, PaymentTransaction (event payments), PlatformFeeTransaction, Reminder, Invitation, Wishlist, Review, Notification, NotificationDevice, AuditLog) plus infrastructure entities from M1 (jobs, idempotency_keys, provider_events, media, admin_users, user_roles, fee schedule, enquiries). Each: purpose, owner module, attributes with types, required/optional, ownership/visibility rules.
2. **Relationships & ERD** — Mermaid ER diagram(s); cardinalities; FK delete behaviour (RESTRICT/CASCADE) per relation.
3. **Invariants** — business rules the backend enforces (e.g. listing starting price ≠ agreed budget; one open platform-fee order per submission; review only after a completed booking; quotation belongs to one enquiry and one event-vendor).
4. **State machines** — states, transitions, actor allowed per transition, side effects (audit, notification row from `notification-matrix.md`) for: vendor listing / submission, platform-fee transaction, enquiry, quotation, booking, event payment record, checklist item, reminder, invitation, review, user account, vendor account.
5. **Logical schema** — table list with columns, types, constraints and indexes following `database-schema.md` Part A conventions (planning document, not migrations); mapping of each table to the milestone that creates it.
6. **Budget model** — how event budget, category allocations, agreed budgets and recorded payments relate; computed values and where they are computed.
7. **Data lifecycle** — retention, soft-delete vs hard-delete per entity, account-deletion anonymisation rules, audit coverage list.
8. **Open business questions** — list and resolve with the user (see below), recording answers in the spec change log or ADRs.
9. **Milestone planning hand-off** — draft spec for M3 (User App Foundation) including the backend/database foundation per ADR-0015 if Accepted.

## Out of scope
- Writing migrations, ORM schema files, DTOs or any code (M3+)
- API endpoint catalogue (each implementing milestone adds its endpoints to `api-contracts.md` Part B)
- UI flows and screen design
- Changing M1 Accepted ADRs (a new superseding ADR would be needed, with user approval)

## Deliverables
- `domain-model.md` (rewritten: entity catalogue, invariants, state machines, ERD)
- `database-schema.md` Part A additions if conventions need refinement; a "Logical schema (planned)" section
- `notification-matrix.md` Part B refined with state-machine references
- `payment-architecture.md` §1.3/§2 state tables finalised
- New ADRs for any significant modelling decision
- `milestones/M3-user-app-foundation.md` (DRAFT)

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app / vendor_app / admin_cms | None | Documentation-only milestone |
| backend / database | None (design only) | Items 1–5 |
| Firebase | None | — |
| API contracts | None (conventions already in M1) | — |
| `.claude/project/*` | Documentation + ADRs | All items |

## Acceptance criteria
- [ ] AC-1 Every entity listed in CLAUDE.md §8 and the M1 infrastructure entities has a catalogue entry with attributes, types, owner module and visibility rules.
- [ ] AC-2 An ERD covers all entities with cardinalities and FK delete behaviour.
- [ ] AC-3 State machines exist for every stateful entity listed in item 4, each with allowed actors and side effects, and no transition left undefined (forbidden transitions explicit).
- [ ] AC-4 Platform-fee and event-payment models are fully separate (no shared table/enum); ADR-0014 is resolved (Accepted) and all money fields follow it.
- [ ] AC-5 Listing starting price vs event-vendor agreed budget is modelled explicitly with the budget computation rules.
- [ ] AC-6 Every notification matrix row maps to a state transition (or a scheduled trigger).
- [ ] AC-7 Logical schema lists tables, key columns, constraints and indexes per conventions, each mapped to its creating milestone.
- [ ] AC-8 Data lifecycle (retention, deletion, anonymisation) is defined per entity.
- [ ] AC-9 All open business questions are answered by the user or explicitly deferred with an owner milestone.
- [ ] AC-10 M3 spec drafted; no file outside `.claude/` modified; `current-milestone.md` and `progress.md` updated; milestone set to IN_REVIEW.

## Required reviews
- Security: ownership/visibility rules per entity; PII inventory.
- Performance: indexes for known list queries; growth estimates for high-volume tables (notifications, audit_logs, jobs).
- Notification: matrix ↔ state machine consistency.
- Payment: payment-manager review of both money domains.
- Documentation: cross-links, ADR index.

## Risks and assumptions
- Over-modelling later features (e.g. content, reports) — keep them at catalogue level with a named owner milestone.
- Business rules not stated in CLAUDE.md must be asked, not invented (§31).

## Open questions (to be resolved in M2)
1. Can one event have multiple vendors in the same category (e.g. two photographers)?
2. Can a user have multiple events at once? (CLAUDE.md implies yes — confirm limits, if any.)
3. Quotation rules: validity period, revisions, can a vendor send several quotations per enquiry, who can cancel?
4. Booking: does a booking require an accepted quotation, or can a user record a booking with a vendor found outside the platform?
5. Event payments: **record-only confirmed by the user (2026-10-06)** — the platform collects no user-to-vendor money. Still open: who records a payment, does the counter-party confirm?
6. Platform fee: per category, per listing submission, one-off or periodic (renewal)? Is a fee charged again on resubmission after rejection?
7. Reviews: one per booking? Editable? Vendor replies?
8. Checklist: template-based by event type? Who creates templates (admin content)?
9. Invitations: RSVP tracking in scope or share-only?
10. Vendor: can one vendor account have multiple listings in multiple categories (CLAUDE.md implies yes)? Team members per vendor?
11. Account deletion: data retention requirements (legal/tax) for financial records.
12. **Money storage type (ADR-0014, deferred from M1 — mandatory):** rupees with 2 decimals as exact `numeric(12,2)` + decimal string in the API (Option A, recommended) or floating-point double (Option B, requires amending CLAUDE.md §21).

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-06 | Initial DRAFT created during M1 (spec item 12) | M1 scope |
