# M16 — Event Payments

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M16` on 2026-10-08 (open questions answered the same day) |
| Phase | User App |
| Depends on | M15 COMPLETED and approved (`APPROVE MILESTONE M15`); A2, A3, A11 confirmed (open questions 2–4) |
| Primary owner agent | user-app-manager + backend-manager + database-manager + payment-manager (security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Context (R5 — decided in M2)
The platform **collects no money** between users and vendors. "Event payments" are the user's own **payment notes**: "paid ₹50,000 advance by UPI on 12 Oct" against a booking. These are like checklist entries: the vendor does not confirm them, they have no status, and no money moves. They are completely separate from the vendor **platform fee** (Razorpay, M29).

## Objective
For each booking, the user can record, edit and delete payment notes:
- amount (exact rupees),
- date,
- method (cash, UPI, bank transfer, card, cheque, other),
- kind (advance, instalment, final, other),
- an optional note.

The user sees **paid** and **balance due** (agreed amount − paid, or "overpaid") per booking. The budget's **Paid** and **Spent** figures include the notes (M11 placeholder). The double counting with own expenses (GI-32) is addressed.

## In scope (proposed)
**Database (cross-layer, Rule 7)**
1. `event_payment_notes` (database-schema.md Part C):
   - composite FK `(booking_id, event_id)` → `bookings(id, event_id)`, plus the user,
   - `kind`, `amount numeric(12,2) > 0`, currency, `paid_on date`, `method`, `note` ≤ 1000,
   - soft delete, version,
   - at most 100 per booking.

**Backend (cross-layer, Rule 7)**
2. Owner-only through the event:
   - `GET /events/{id}/bookings/{bookingId}/payments` (notes, newest first, plus totals: agreed, paid, balance or overpaid),
   - `POST` (with an Idempotency-Key),
   - `PATCH` (with version → 412),
   - `DELETE` (soft delete).
   All amounts are exact decimals, and every change is audited **without amounts or note text**.
3. Rules:
   - notes belong to a booking (A3), confirmed, completed, or cancelled (A11);
   - writes are allowed while the event is planning **and after it is completed** (people pay the balance after the event; open question 5);
   - a cancelled event's bookings stay editable for notes;
   - `paid_on` cannot be in the future.
4. Budget (M11): Paid = Σ notes (A11: all bookings, with the part on cancelled bookings reported separately); Spent = Paid + own expenses; per-category Paid; Outstanding = Committed − Paid on active bookings.
5. GI-32: own expenses whose category has an active booking get a hint in the app (open question 6).
6. Notifications: **none** (A2: private notes). Evaluated and documented.

**User App**
7. On the booking panel:
   - "Paid ₹X of ₹Y · Balance ₹Z" (or "Overpaid ₹Z"),
   - **Add payment** (a sheet: amount, date picker defaulting to today, method, kind, note),
   - a payment list with edit and delete (delete asks for confirmation).
8. Budget screen: Paid and Spent show real figures; per-category Paid; a "Paid to cancelled vendors" line when it isn't zero (A11).
9. Optional **Home** budget card: "Paid ₹X" (small change to the M11 card).
10. Tests:
   - Backend unit and e2e: ownership, money exactness, totals and overpaid, A11, rules, idempotency, audit without amounts, budget figures.
   - Flutter: sheet validation, list states, balances, 200 % text.
11. Docs: api-contracts, database-schema, domain-model (A2/A3/A11 answers), payment-architecture (notes ≠ platform fees ≠ money movement), notification-matrix (none), flutter.md, progress.

## Out of scope
- Any real payment through the app (UPI or Razorpay to vendors); receipts and photos; reminders for payment due dates (M17 Reminders); vendor-side payment views (M35); platform fees (M29).

## Acceptance criteria
- [x] AC-1 The user can add, edit and delete payment notes on a booking. Amounts are exact rupees end to end.
- [x] AC-2 Paid, balance and overpaid figures are correct per booking and in the budget (Paid, Spent, Outstanding, per category, cancelled-vendor part per A11), and covered by tests.
- [x] AC-3 Notes are private (owner-only 404 for others), never notified (A2), and audited without amounts or text.
- [x] AC-4 Rules on dates, booking states and event states are enforced by the server.
- [x] AC-5 Screens handle loading, empty, error, retry, offline and read-only states, and render at 200 % text. Checks and tests pass, reviews are done, the docs are updated, and the status is IN_REVIEW.

## Risks
- Users may confuse payment notes with paying through the app. The copy must say "a note for your records; no money is sent".
- Double counting with own expenses (GI-32).

## Open questions (answered 2026-10-08 — see change log)
1. **Name in the app:** call them **"Payments"** with the line "for your records — no money is sent through the app", or **"Payment notes"**? Proposed: "Payments" + that line.
2. **A2 — privacy:** notes are private to you; the vendor never sees them and gets no notification. OK?
3. **A3 — attached to bookings:** you can only add a payment to a booked vendor (money paid to others goes in "My expenses", M11). OK?
4. **A11 — cancelled bookings:** payments made to a vendor whose booking was later cancelled still count in "Paid" (shown separately as "Paid to cancelled vendors"), and you can still add one (e.g. a non-refunded advance). OK?
5. **After the event:** you can keep adding payments after the event is completed (to settle the balance). Proposed: yes, for completed events too; still read-only for deleted events. OK?
6. **Double counting (GI-32):** when you add an own expense in a category where a vendor is booked, show a hint: "Paying a booked vendor? Add it under that booking's payments instead." OK?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-08 | Initial DRAFT created at the M15 approval gate | CLAUDE.md Rule 4 |
| 2026-10-08 | User answers: 1 "recommended" → name **"Payments"** with "for your records — no money is sent through the app"; 3 **A3 OK** (booking only; others go to My expenses); 4 **A11 OK** (cancelled bookings still count, shown as "Paid to cancelled vendors"; can still add); 5 after-event payments **OK** (completed events editable for payments); 6 GI-32 hint **OK**. Question 2 (A2 privacy) — user asked for an explanation; pending | User |
| 2026-10-08 | User answer 2: **A** — payments are private to the user (A2 confirmed): vendors never see them, no notifications | User |
| 2026-10-08 | CONFIRMED by `START MILESTONE M16`. Implementation detail: endpoints are keyed by booking (`/events/{id}/bookings/{bookingId}/payments`) so notes on an earlier, cancelled booking stay reachable (A11) | User / Claude |
