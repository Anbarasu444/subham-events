# M15 — Quotations & Booking

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M15` on 2026-10-08 (open questions answered in the same message) |
| Phase | User App |
| Depends on | M14 COMPLETED and approved; **R3 resolved** (open questions 2–5); A7 confirmed (question 6) |
| Primary owner agent | user-app-manager + backend-manager + database-manager + payment-manager (money rules) + notification-manager (security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Dependency note (read first)
Quotations are **sent by vendors**, from the Vendor App (M33). Bookings are confirmed when the user accepts one. So in M15, as with M14, no real vendor can send a quote yet. Open question 1 decides how M15 is tried and used before then:

- **Option A — build the user side now; quotes for testing come from a dev-only script (recommended).**
  - M15 builds quotations and bookings (tables, rules, endpoints, user screens).
  - A **dev/test-only** script (like the M12 sample vendors) creates sample quotes on your enquiries so the screens can be tried.
  - Real quotes start with M33.
- **Option B — also let users record a booking they agreed outside the app.** The user enters the agreed amount and date themselves ("I booked them by phone for ₹40,000"). This is useful straight away, but the amount then comes from the user, not the vendor. The domain model (agreed amount = the vendor's accepted quote) would need a change: for example, a booking marked "recorded by you" that the vendor confirms later.
- **Option C — move M15 after the Vendor App quotation work (M33).** This needs a roadmap change.

## Objective (Option A)
For each event vendor, the user sees the vendor's quotation(s) for their enquiry and can:
- **accept** one, which creates a **confirmed booking** with the quoted amount as the **agreed amount** (exact rupees, immutable),
- **reject** one,
- see the event's bookings,
- cancel a booking with a reason,
- mark a booking completed (or let it complete automatically, A7).

The budget's **Committed** figure (M11) starts counting confirmed and completed bookings.

## In scope (Option A; R3 rules per the answers)
**Database (cross-layer, Rule 7)**
1. `quotations`: enquiry, event vendor and vendor (composite FKs), `amount numeric(12,2) > 0`, currency, description, `valid_until` (R3), `revision_no` (R3), status SENT/ACCEPTED/REJECTED (+ SUPERSEDED/EXPIRED/WITHDRAWN per R3), `responded_at`.
2. `bookings` per Part C: `quotation_id` unique, `agreed_amount > 0` copied from the quote, `service_date`, status CONFIRMED/CANCELLED/COMPLETED, cancelled by + reason, `completed_at`; one active booking per event vendor.
3. A dev/test-only sample-quote script (guarded to `*_dev` / `*_test` like the M12 seed).

**Backend (cross-layer, Rule 7)**
4. User endpoints:
   - list an event vendor's quotations,
   - **accept** (Idempotency-Key; in one transaction: quote ACCEPTED, booking CONFIRMED, event vendor BOOKED, the enquiry CLOSED, other live quotes handled per R3; N11 to the vendor, N12 to both),
   - **reject** (N11),
   - list the event's bookings,
   - **cancel** a booking (reason required; N13 to the vendor; event vendor CANCELLED, enquire again allowed),
   - **mark completed** (on or after the service date; N14).
5. A job that completes confirmed bookings the day after their service date (A7; N14 review prompt in-app).
6. Budget: Committed = Σ agreed amounts of CONFIRMED + COMPLETED bookings, overall and per category. Remaining uses it. Exact decimals.
7. Expired quotes (if R3 adds expiry) are rejected for acceptance by the server, never by the client clock.
8. Notifications: N10 (quote received; created by the sample script now, by M33 later), N11, N12, N13, N14 as in-app records. Pushes come with M18 (user) and M36 (vendor). Every change is audited.

**User App**
9. Vendors tab and vendor rows:
   - "Quote received ₹X" with details (amount, description, valid until),
   - **Accept** (confirmation showing the exact amount and that it becomes the agreed budget) and **Reject**,
   - a booking card (agreed amount, service date, status),
   - **Cancel booking** (reason, confirmation),
   - **Mark completed**.
10. Budget screen: Committed shows real amounts; per-category booked figures.
11. Tests: state machines, money exactness, concurrency (double accept, accept after expiry/withdrawal), ownership, notifications (A9 still applies), the completion job, budget figures, plus Flutter controllers/widgets/200 % text.
12. Docs: api-contracts, database-schema, domain-model (R3, A7), notification-matrix, payment-architecture (agreed amount ≠ payments; payments are M16), flutter.md, progress.

## Out of scope
- Vendor-side quote creation, revision and withdrawal UI (M33), vendor booking screens (M34), pushes (M18/M36).
- Payment notes and Paid figures (M16); reviews (M20); admin cancellation (M48).
- Option B unless chosen.

## Acceptance criteria (Option A)
- [x] AC-1 The user can view, accept and reject quotes. Accepting creates exactly one CONFIRMED booking with the quote amount as the immutable agreed amount, even under double taps and retries (tested).
- [x] AC-2 R3 rules (multiplicity, revisions, expiry, withdrawal) are enforced by the server and tested.
- [x] AC-3 Bookings can be cancelled with a reason, and marked completed on or after the service date. The job completes them the day after (A7).
- [x] AC-4 The budget's Committed and Remaining figures include confirmed and completed bookings exactly. Starting prices never appear.
- [x] AC-5 N10–N14 records are created with A9-safe content. Everything is audited.
- [x] AC-6 All screens handle loading, empty, error, retry, offline and read-only states, and render at 200 % text. Checks and tests pass, reviews are done, the docs are updated, and the status is IN_REVIEW.

## Risks
- Until M33, only sample quotes exist (dev/test). Production users see "waiting for the vendor's quote".
- Money correctness: the agreed amount must be copied server-side from the quote, never sent by the client.

## Open questions (answered 2026-10-08 — see change log)
1. **Approach:** Option A (recommended), B (also let users record bookings agreed outside the app), or C (move M15 after M33)?
2. **R3 — how many quotes at once:** proposed: **one live quote per enquiry**. When the vendor sends a revised quote, the old one becomes SUPERSEDED (the user sees the latest, with "revised" history). OK?
3. **R3 — expiry:** proposed: the vendor may set a **"valid until" date**; after it the quote shows as EXPIRED and can't be accepted (the user can ask for a new one). No date = valid until the event date. OK?
4. **R3 — withdrawal:** proposed: the vendor can **withdraw** a quote until the user accepts it (WITHDRAWN; the user is notified). OK?
5. **R3 — after accepting:** proposed: accepting one vendor's quote does **not** affect other vendors (you can book several in the same category, R1). Rejecting a quote keeps the enquiry open so the vendor can send a new one. OK?
6. **A7 — completion and cancellation:** proposed: a booking completes **automatically the day after its service date**, or the user can mark it completed on or after that date. Either side can cancel a confirmed booking **with a reason**. Money for cancellations is handled outside the app. OK?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-08 | Initial DRAFT created at the M14 approval gate | CLAUDE.md Rule 4 |
| 2026-10-08 | User answers: 1 **Option A** (user side now; dev/test-only sample quotes until M33); **R3 resolved**: 2 one live quote per enquiry, a revision SUPERSEDES the previous; 3 optional `valid_until`, expired quotes cannot be accepted (no date = valid until the event date); 4 vendor may WITHDRAW until accepted (user notified); 5 accepting one vendor does not affect other vendors (R1), rejecting keeps the enquiry open for a new quote; **A7 confirmed**: 6 auto-complete the day after the service date, user may mark completed from the service date, either side cancels a confirmed booking with a reason, cancellation money outside the app. CONFIRMED by `START MILESTONE M15` | User |
