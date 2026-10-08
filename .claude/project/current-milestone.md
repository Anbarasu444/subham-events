# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M15** |
| Milestone name | Quotations & Booking |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M15-quotations-booking.md` (status: CONFIRMED 2026-10-08) |
| Started date | 2026-10-08 |
| Completed date | — |
| Approval status | Awaiting `APPROVE MILESTONE M15` (set IN_REVIEW 2026-10-08) |

## Objective
Users view, accept and reject vendor quotations; accepting creates a confirmed booking whose agreed amount comes from the quote; bookings can be cancelled or completed; the budget's Committed figure counts them.

## Completed work / In-progress work / Blocked work
- **Database:** migration `1792100000000-QuotationsAndBookings` — **the user runs `npm run migration:run`**; dev/test-only `database/seeds/dev-sample-quotes.sql` (`npm run seed:dev-quotes`) plays the vendor until M33.
- **Backend:** accept (Idempotency-Key, row locks, one transaction: quote ACCEPTED → booking CONFIRMED with the server-copied amount → event vendor BOOKED → enquiry CLOSED), reject (enquiry reopens), cancel with reason (planning or cancelled events), complete (from the service date), hourly `BookingAutoCompleteJob` (day after the service date), derived EXPIRED, R3 supersede rule (one SENT per enquiry, enforced by index), N10–N14 in-app records, audit without reasons; budget Committed/Remaining from bookings.
- **User App:** quote panel (Accept & book with exact-amount confirmation, Decline, expired state, revisions), booking panel (agreed amount, service date, Mark completed, Cancel booking with reason), budget Committed shows real amounts.
- Nothing blocked.

## Tests completed
- Backend: unit 73/73 (incl. Committed/Remaining), e2e 106/106 (incl. 11 M15 tests: sample quote + N10, revision supersedes and stale accept refused, accept once with replay/new-key refusal/428 and N11/N12 without user contact or budget, budget committed, reject reopens and new quote, expired and withdrawn refused, cancel with reason (validation, N13, audit without reason, re-enquire), completion before/after date and job idempotency with N14, user completes on the date, owner-only and planning-only accept, script guard); lint, typecheck and build clean.
- User App: `flutter analyze` clean; `flutter test` 250/250 (quote/booking JSON, accept key reuse on retry; screens: accept → booked with exact amount, decline, expired, cancel needs a reason, mark completed, 200 % text).
- Not verified: signed-in device run; real vendor quotes (M33).

## Reviews
| Review | Status |
|---|---|
| Security / privacy review | Done — owner-only, row locks against double accept, Idempotency-Key, server-copied amount, A9-only vendor notification data (tested), reasons not audited |
| Payment / money review | Done — exact decimals, agreed amount immutable (ORM `update: false` + no update path), Committed separate from payments (payment-architecture §2.2) |
| Performance review | Done — quotes/bookings fetched per event-vendor list in two indexed queries; job batched with SKIP LOCKED |
| UI review | Done — confirmation with the exact amount, honest expiry, reason dialog, states, 200 % text |
| Code review | Done (self-review) |
| Notification review | Done — N10–N14 in-app; pushes at M18/M36 |
| Documentation | Done (api-contracts, database-schema incl. sample quotes, domain-model R3/A7, notification-matrix, payment-architecture §2.2, flutter.md §6h, spec, progress) |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-34 (GI-34: vendors cannot send real quotes until M33).
- Business rules on hold: R6 (before M28/M29), R10 (before M26). R11 final policy by M21. R3 resolved, A7 confirmed.

## Files changed
- database: `database/migrations/1792100000000-QuotationsAndBookings.ts`, `database/seeds/dev-sample-quotes.sql`
- backend: `src/modules/event-vendors/{quotation.entity.ts,booking.entity.ts,booking-auto-complete.job.ts,event-vendors.service.ts,event-vendors.controller.ts,event-vendors.dto.ts,event-vendors.module.ts}`, `src/modules/budget/{budget.service.ts,budget.service.spec.ts}`, `src/database/seed-dev-samples.ts`, `package.json` (`seed:dev-quotes`), `test/quotations-bookings.e2e-spec.ts`, TRUNCATE lists in `test/{db-harness,auth.e2e-spec,events.e2e-spec}.ts`
- user_app: `lib/features/event_vendors/{domain/event_vendor.dart,data/event_vendors_repository_impl.dart,presentation/controllers/event_vendors_controller.dart,presentation/widgets/event_vendor_slivers.dart}`; tests `test/features/engagement/engagement_test.dart`, `test/helpers/fake_event_vendors.dart`
- docs: api-contracts, database-schema, domain-model, notification-matrix, payment-architecture, architecture/flutter.md, M15 spec, milestones.md, current-milestone, progress

## Files pending approval
- M14 and M15 files are uncommitted unless the user has committed them.

## Next milestone
- M16 — Event Payments (spec drafted at the M15 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

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
