# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M19** |
| Milestone name | Digital Invitations |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M19-digital-invitations.md` (status: CONFIRMED 2026-10-09) |
| Started date | 2026-10-09 |
| Completed date | — |
| Approval status | **Awaiting `APPROVE MILESTONE M19`** |

## Objective
E-invitation per event (design, details, publish, share as link or image), public guest page with anonymous RSVP (A6), RSVP list and totals, N18 digest.

## Completed work
- Answers applied: backend guest page; picture drawn on the phone; data-driven template catalogue with a starter set of 6 (Classic, Floral, Minimal, Festive, Royal, Pastel; full set planned by the user later, GI-36); A6 form; N18 hourly digest; one invitation per event.
- **Database:** migration `1792500000000-Invitations` (`invitations`, `invitation_rsvps`; tokens stored only as SHA-256 hashes).
- **Backend:** `invitations` module — template catalogue endpoint; owner get/save/publish/new-link/close-reopen replies/revoke/RSVP list (PLANNING-only writes, rate limited, audited); public guest page `GET /api/v1/i/{token}` + RSVP form post (no account, cookie-based update of one reply, caps, noindex/no-referrer/CSP/no-store, escaped HTML, rate limited); hourly-per-invitation N18 digest job (push group OTHER); `INVITATION_BASE_URL` config; urlencoded body parser (16 kB).
- **User App:** event Overview "Invitation" card (create, preview, publish, share link, share picture, replies summary, menu: edit / close or reopen replies / new link / turn off link, with confirmations; read only when not planning; a phone without the link is offered a new one), editor with design chips and live preview, invitation card renderer, share-as-picture screen (PNG drawn on the phone), Replies screen with totals. Link kept in secure storage on this phone.

## In-progress work
- None.

## Blocked work
- None. (Guest links reach only phones on the same Wi-Fi until the backend is hosted / `INVITATION_BASE_URL` is set.)

## Tests completed
- Backend: unit 74/74; e2e 137/137 (8 new invitation tests: catalogue, owner flow with hash-only token, guest page headers + RSVP create/update via cookie, invalid replies, close/new link/revoke, cancelled-event and unknown links look the same, owner-only, N18 hourly digest); lint and typecheck clean.
- User App: `flutter analyze` clean; `flutter test` 291/291 (12 new: JSON parsing, controller link/revoke/conflict/failure, create → publish → share link, share picture, replies list and totals, close replies + revoke with confirm/cancel, new link when the phone lacks it, cancelled event read only, editor at 200 % text).
- Android staging debug build OK (then `flutter clean`).
- Not verified: opening a real link from another phone, and a real N18 push on a device.

## Reviews
| Review | Status |
|---|---|
| Security review | DONE — 256-bit random tokens, only hashes stored; link shown once and kept in the phone's secure storage; guest page escapes all text, no scripts (CSP), noindex/no-referrer/no-store, neutral page for unknown/revoked links (no existence leak); guest writes rate limited (10/min/IP), 20-guest and 1000-reply caps; responder cookie httpOnly/SameSite=Lax/Secure on HTTPS, path-scoped, only hashed; audit logs carry ids only. Residual: links are bearer secrets (anyone with the link can view and reply) — by design (A6). |
| Performance review | DONE — one row per event; RSVP list capped at 1000 and indexed by invitation/updated time; totals by one grouped query; digest job locks with SKIP LOCKED every 5 min; templates cached per session in the app; picture rendered once on tap at 3× (~1080 px wide). |
| Notification review | DONE — N18 digest: one in-app row + push per invitation per hour at most, push group OTHER, payload ids only; no notifications to guests (no contact details collected). Other state changes (publish, revoke, close) are owner actions → no notification. |
| Documentation | DONE — api-contracts, database-schema, notification-matrix, architecture/flutter.md §6l, media-and-deep-links §5, spec ACs, progress. |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-36.
- Business rules on hold: R6 (before M28/M29), R10 (before M26). R11 final policy by M21. A6 confirmed.

## Files changed
- Database: `database/migrations/1792500000000-Invitations.ts`.
- Backend: `src/modules/invitations/*` (new: templates, guest-page, entity, DTOs, service, controller, rsvp-digest job, module), `src/app.module.ts`, `src/app.setup.ts`, `src/config/env.validation.ts`, `src/config/app-config.service.ts`, `src/modules/notifications/push-policy.ts`, `.env.example`, `test/invitations.e2e-spec.ts` (new), `test/db-harness.ts`, `test/auth.e2e-spec.ts`, `test/events.e2e-spec.ts`.
- User App: `lib/features/invitations/**` (new), `lib/core/platform/external_actions.dart` (`shareImage`), `lib/features/events/presentation/views/event_detail_view.dart`, `lib/features/shell/presentation/bindings/shell_binding.dart`; tests `test/features/invitations/invitations_test.dart`, `test/helpers/fake_invitations.dart` (new), `test/helpers/fake_media.dart`, `test/helpers/fake_event_vendors.dart`.
- Docs: listed under Documentation above, plus `current-milestone.md`, `milestones.md`, `known-issues.md`.

## Files pending approval
- All M19 files above (uncommitted; the user commits). M17/M18 files too unless already committed.

## Next milestone
- M20 — Reviews (spec drafted at the M19 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M18 Notification Center + FCM: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M18` issued by the user |
| Spec | `milestones/M18-notification-center-fcm.md` (CONFIRMED) |

Evidence at approval: Notification Center (bell, list, read/read-all, routing), FCM pushes (notifications-as-outbox worker, devices, preferences, retries, invalid-token clean-up), in-context permission, Settings → Notifications, Android channels; backend 74 unit + 129 e2e, Flutter 279 tests; Android debug build OK; reviews done. Not verified: a real push on a device (user's step); iOS pending GI-35. Dev DB migration `1792400000000-NotificationDelivery` to be run by the user.

## Previous milestone — M17 Reminders: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M17` issued by the user |
| Spec | `milestones/M17-reminders.md` (CONFIRMED) |

Evidence at approval: reminders (create/reschedule/cancel, task link, auto-cancel), due job (N17), checklist due/overdue at 09:00 (N16), Overview card, "Remind me" on tasks, Menu → Schedule, Home due banner; backend 74 unit + 120 e2e, Flutter 268 tests; reviews done. Not verified: signed-in device run; live firing on a running server. Dev DB migration `1792300000000-Reminders` to be run by the user.

## Previous milestone — M16 Event Payments: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M16` issued by the user |
| Spec | `milestones/M16-event-payments.md` (CONFIRMED) |

Evidence at approval: private payment notes per booking (add/edit/delete, exact paid/balance/overpaid), budget Paid/Spent/Outstanding/paid-to-cancelled, GI-32 hint, no notifications (A2); backend 74 unit + 113 e2e, Flutter 258 tests; reviews done. Not verified: signed-in device run. Dev DB migration `1792200000000-EventPaymentNotes` to be run by the user.

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
