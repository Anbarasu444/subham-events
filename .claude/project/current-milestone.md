# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M16** |
| Milestone name | Event Payments |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M16-event-payments.md` (status: CONFIRMED 2026-10-08) |
| Started date | 2026-10-08 |
| Completed date | — |
| Approval status | Awaiting `APPROVE MILESTONE M16` (set IN_REVIEW 2026-10-08) |

## Objective
Private payment notes per booking (R5: no money moves): add/edit/delete, paid and balance per booking, budget Paid/Spent/Outstanding, GI-32 hint.

## Completed work / In-progress work / Blocked work
- **Database:** migration `1792200000000-EventPaymentNotes` — **the user runs `npm run migration:run`**.
- **Backend:** payments module under event vendors (list with exact paid/balance/overpaid, create with Idempotency-Key, edit with version, soft delete; booking-keyed so cancelled bookings stay reachable, A11; allowed after the event; paid date not in the future; 100 per booking; audit without amounts or notes; no notifications, A2); `BookingDto.paid`; budget Paid / paidToCancelled / Outstanding / per-category Paid / Spent.
- **User App:** "Paid ₹X of ₹Y · balance" and a Payments button on every booking (also cancelled); Payments page (totals, list, add/edit sheet, delete confirmation, "for your records — no money is sent" copy); budget lines "of which to cancelled vendors" and "Still to pay vendors"; GI-32 hint in the own-expense sheet.
- Nothing blocked.

## Tests completed
- Backend: unit 74/74 (incl. paid/cancelled/outstanding figures), e2e 113/113 (incl. 7 M16 tests: exact totals and budget, overpaid, edit/412/soft delete with audit free of amounts and notes, privacy (no notifications, 404 for others), validation incl. future date and 428, A11 cancelled bookings, after completion / deleted event); lint, typecheck and build clean.
- User App: `flutter analyze` clean; `flutter test` 258/258 (payments JSON, budget fields, form key reuse and zero amount; Payments page add/edit/overpaid/delete, retry, 200 % text; GI-32 hint; booking panel paid line).
- Not verified: signed-in device run.

## Reviews
| Review | Status |
|---|---|
| Security / privacy review | Done — owner-only, composite FK to the booking/event, no notifications, audit without amounts or notes, Idempotency-Key on create |
| Payment / money review | Done — exact decimals, no money movement, separate from platform fees (payment-architecture §2.3), A11 figures tested |
| Performance review | Done — paid sums per booking in one grouped query; budget in one query with indexed sub-sums |
| UI review | Done — clear "no money is sent" copy, balance/overpaid, confirmations, 200 % text |
| Code review | Done (self-review) |
| Notification review | Done — none by design (A2) |
| Documentation | Done (api-contracts, database-schema, notification-matrix, payment-architecture §2.3, flutter.md §6i, known-issues GI-32 mitigated, spec, progress) |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-34 (GI-32 mitigated).
- Business rules on hold: R6 (before M28/M29), R10 (before M26). R11 final policy by M21. A2, A3, A11 confirmed.

## Files changed
- database: `database/migrations/1792200000000-EventPaymentNotes.ts`
- backend: `src/modules/event-vendors/{payment-note.entity.ts,payments.dto.ts,payments.service.ts,payments.controller.ts,event-vendors.module.ts,event-vendors.service.ts,event-vendors.dto.ts}`, `src/modules/budget/{budget.service.ts,budget.dto.ts,budget.service.spec.ts}`, `test/payments.e2e-spec.ts`, TRUNCATE lists in `test/{db-harness,auth.e2e-spec,events.e2e-spec}.ts`
- user_app: `lib/features/event_vendors/{domain/payment.dart,domain/event_vendor.dart,data/payments_repository_impl.dart,data/event_vendors_repository_impl.dart,presentation/controllers/payments_controller.dart,presentation/controllers/payment_form_controller.dart,presentation/widgets/payment_sheet.dart,presentation/views/payments_view.dart,presentation/widgets/event_vendor_slivers.dart}`, `lib/features/budget/{domain/budget.dart,data/budget_model.dart,presentation/widgets/budget_slivers.dart,presentation/widgets/expense_sheet.dart}`, `lib/features/shell/presentation/bindings/shell_binding.dart`; tests `test/features/payments/payments_test.dart`, `test/helpers/{fake_payments.dart,fake_event_vendors.dart}`, `test/features/engagement/engagement_test.dart`
- docs: api-contracts, database-schema, notification-matrix, payment-architecture, known-issues, architecture/flutter.md, M16 spec, milestones.md, current-milestone, progress

## Files pending approval
- M14–M16 files are uncommitted unless the user has committed them.

## Next milestone
- M17 — Reminders (spec drafted at the M16 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M15 Quotations & Booking: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M15` issued by the user |
| Spec | `milestones/M15-quotations-booking.md` (CONFIRMED; R3 resolved, A7 confirmed) |

Evidence at approval: quotations (one live, revisions supersede, derived expiry), accept → booking with server-copied agreed amount (idempotent, row-locked), reject, cancel with reason, complete + hourly job, N10–N14 in-app, budget Committed; dev/test-only sample quote script; backend 73 unit + 106 e2e, Flutter 250 tests; reviews done. Not verified: signed-in device run; real vendor quotes (M33). Dev DB migration `1792100000000-QuotationsAndBookings` to be run by the user.

## Previous milestone — M14 Wishlist / Contact / Enquiry: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M14` issued by the user |
| Spec | `milestones/M14-wishlist-contact-enquiry.md` (CONFIRMED) |

Evidence at approval: wishlist (hearts, Saved vendors, Explore Saved filter), event vendors (add to event, Vendors tab, notes, remove), enquiries (idempotent send, close, closed on event cancel/delete), N9 in-app with A9 fields only; backend 72 unit + 95 e2e, Flutter 242 tests; reviews done. Not verified: signed-in device run; vendor replies (GI-34). Dev DB migration `1792000000000-WishlistEventVendorsEnquiries` to be run by the user.

## Previous milestone — M13 Vendor Details: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M13` issued by the user |
| Spec | `milestones/M13-vendor-details.md` (CONFIRMED) |

Evidence at approval: `@OptionalAuth` guard mode; `GET /listings/{id}` (contact for signed-in users only, A10) and `/related`; listing details page with call/email/share, related lists and all states; backend 72 unit + 82 e2e, Flutter 228 tests; reviews done. Not verified: real dialer/mail hand-off and signed-in device run.

## Previous milestone — M12 Vendor Discovery: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M12` issued by the user |
| Spec | `milestones/M12-vendor-discovery.md` (CONFIRMED) |

Evidence at approval: `vendors` / `vendor_listings` schema (O2 city + service areas), dev/test-only sample seed, public `GET /listings` (visibility rule, filters, sorts, bound cursors) and `GET /listings/cities`; Explore tab and Home "Explore vendors"; backend 71 unit + 78 e2e, Flutter 219 tests; reviews done. Not verified: signed-in simulator/device run; query plans at real catalogue size (GI-33). Dev DB migration `1791900000000-VendorsAndListings` (and optional sample seed) to be run by the user.

## Previous milestone — M11 Budget Management: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M11` issued by the user |
| Spec | `milestones/M11-budget-management.md` (CONFIRMED; scope extended with own expenses) |

Evidence at approval: vendor categories (12 seeded, public list); per-event budget (plan per category, total editable on the budget screen, unplanned and over-plan warning, committed/paid ready for M15/M16, archived-category lines); own expenses (add/edit/delete, counted as spent; remaining = total − committed − expenses); event Budget tab, standalone page, Menu → Budget, Home overview; backend 69 unit + 68 e2e, Flutter 202 tests; reviews done with fixes. Not verified: signed-in simulator run. Dev DB migration `1791800000000-EventExpenses` to be run by the user (confirm). Notes/diary deferred (GI-31); GI-32 for M16.

## Previous milestone — M10 Event Details: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M10` issued by the user |
| Spec | `milestones/M10-event-details.md` (CONFIRMED) |

Evidence at approval: media module with ImageKit upload API v2 (single-use signed settings) and server-side verification; event cover set/remove with signed, resized, metadata-free URLs; tabbed event screen (Overview/Checklist/Budget/Vendors) with cover photo flow, Open in Maps, Share; backend 63 unit + 54 e2e, Flutter 178 tests; ImageKit verified live; security, UI and code reviews PASS WITH FINDINGS (fixed; GI-30 logged). Not verified: real in-app cover upload (simulator signed out).

## Earlier milestone — M9 Checklist: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M9` issued by the user |
| Spec | `milestones/M9-checklist.md` (CONFIRMED) |

Evidence at approval: `checklist_items` migration (applied by the user); backend checklist module + checklist summary on events; User App checklist screen (tick with undo, reorder with accessible alternative, add/edit sheet, read-only for non-planning events), event page/card progress, Home Checklist progress, Menu → Checklist picker; backend 57 unit + 43 e2e, Flutter 167 tests; code, security and UI reviews PASS WITH FINDINGS (fixed; GI-27, GI-29 logged). Not verified: signed-in flows on the simulator (simulator signed out).

## Earlier milestone — M8 Event Management: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M8` issued by the user |
| Spec | `milestones/M8-event-management.md` (CONFIRMED) |

Evidence at approval: `events` + `idempotency_keys` migration (applied by the user); backend events module (create with idempotency, cursor lists, edit with version check, cancel/reopen/complete, soft delete, audit, hourly auto-complete); User App My Events, event form and event page, Home upcoming event; backend 55 unit + 29 e2e, Flutter 145 tests; code, security and UI reviews PASS WITH FINDINGS (fixed; GI-27, GI-28 logged). Not verified: signed-in flows on the simulator (user sign-in needed).

## Earlier milestone — M7 Home Dashboard: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M7` issued by the user |
| Spec | `milestones/M7-home-dashboard.md` (CONFIRMED) |

Evidence at approval: home dashboard framework (greeting, call to action, four independent sections with empty/loading/error-retry, pull-to-refresh, guest vs signed-in); 112 Flutter tests; iOS simulator light/dark checks; code + UI reviews PASS WITH FINDINGS (fixed). Carried to M8: "Create your first event" becomes real and switches to "Create event" once events exist.

## Earlier milestone — M6 Main Navigation: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M6` issued by the user |
| Spec | `milestones/M6-main-navigation.md` (CONFIRMED) |

Evidence at approval: shell with Home, Explore, My Events, Menu; nested per-tab navigation, lazy tabs, guest gating with sign-in return, Menu sections with Coming-soon pages, forced sign-out reason shown, tabs reset on sign-out; 96 Flutter tests; iOS simulator checks; UI + code reviews PASS WITH FINDINGS (fixed). Android back-button device check optional (not run).

## Earlier milestones
- M5 Authentication: COMPLETED 2026-10-07 (committed with M6 `f567e61`).
- M4 Splash & App Bootstrap: COMPLETED 2026-10-06 (committed `d7565c3`).
- M3 User App Foundation: COMPLETED 2026-10-06 (committed `e78060f`).
- M2 Global Domain Model: COMPLETED 2026-10-06 (committed `658d59d`).
- M1 Global Architecture: COMPLETED 2026-10-06 (committed `1c21c35`).
