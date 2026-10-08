# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M18** |
| Milestone name | Notification Center + FCM |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M18-notification-center-fcm.md` (status: CONFIRMED 2026-10-08) |
| Started date | 2026-10-08 |
| Completed date | — |
| Approval status | Awaiting `APPROVE MILESTONE M18` (set IN_REVIEW 2026-10-08) |

## Objective
In-app Notification Center (list, unread badge, read/read-all, routing) and FCM phone pushes (outbox worker, device registry, preferences, retries, token clean-up) for user-facing types.

## Completed work / In-progress work / Blocked work
- **Database:** migration `1792400000000-NotificationDelivery` — **the user runs `npm run migration:run`**.
- **Backend:** user push types queued in the creating transaction (notifications rows as the outbox); `PushWorker` (lease + SKIP LOCKED, preferences, devices, FCM send via Firebase Admin, invalid-token deactivation, backoff, FAILED after 5); endpoints for the center, devices and preferences; `FcmSender` abstraction (fake in tests).
- **User App:** `firebase_messaging` added (approved); bell with unread badge on Home; Notification Center (paged, read, mark all read, tap opens the event); push registration after permission, token refresh, unregister before sign-out; in-context permission prompt (first reminder / enquiry) and Settings → Notifications (three groups, allow button); foreground banner with de-duplication; Android channels + POST_NOTIFICATIONS. Android debug build verified.
- **Blocked on the user (iOS only):** APNs key + real bundle id (GI-35).

## Tests completed
- Backend: unit 74/74, e2e 129/129 (incl. 9 M18 tests: list/count/read/read-all and ownership, paging, push with ids-only payload, skip on no device / group off with the in-app record kept, invalid token deactivation and retry with backoff then success, give up after 5, token moved to the new user and removed on sign-out, input validation and auth, vendor records never queued); lint, typecheck and build clean.
- User App: `flutter analyze` clean; `flutter test` 279/279 (JSON; PushService: register only when granted, token refresh, unregister, guests, open marks read; in-context prompt once; center: badge, open marks read, mark all, empty/error, 200 % text; settings toggles and allow); `flutter build apk --debug --flavor staging` succeeded.
- Not verified: a real push on a device (needs the user's phone with the backend running and Firebase credentials); iOS pushes (GI-35).

## Reviews
| Review | Status |
|---|---|
| Security / privacy review | Done — payload carries ids only, tokens owned per user and moved on re-registration, removed before sign-out, invalid tokens deactivated, preferences per user, no secrets in the app |
| Performance review | Done — partial index for pending pushes, batched leases with SKIP LOCKED, one device + preference lookup per notification, unread count via index |
| UI review | Done — badge, unread dot, mark all read as an icon (200 % text), honest permission explanations |
| Code review | Done (self-review) |
| Notification review | Done — push types/groups/channels per answers; at-least-once with client de-duplication |
| Documentation | Done (api-contracts, database-schema, notification-matrix, flutter.md §6k, known-issues GI-35, spec, progress) |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-35.
- Business rules on hold: R6 (before M28/M29), R10 (before M26). R11 final policy by M21.

## Files changed
- database: `database/migrations/1792400000000-NotificationDelivery.ts`
- backend: `src/modules/notifications/{notification.entity.ts,notifications.service.ts,notifications.module.ts,push-policy.ts,fcm-sender.ts,push.worker.ts,me-notifications.ts}`, `test/{notifications.e2e-spec.ts,fakes.ts,db-harness.ts,auth.e2e-spec.ts,events.e2e-spec.ts}`
- user_app: `pubspec.yaml`/`pubspec.lock` (`firebase_messaging`), `lib/features/notifications/**`, `lib/core/auth/session_service.dart` (before-sign-out hooks), `lib/features/events/presentation/events_navigation.dart` (`openEventById`), `lib/features/home/presentation/views/home_tab_view.dart` (bell), `lib/features/menu/presentation/views/{menu_tab_view.dart,settings_view.dart}`, `lib/features/reminders/presentation/widgets/reminders_section.dart`, `lib/features/checklist/presentation/views/checklist_view.dart`, `lib/features/event_vendors/presentation/widgets/event_vendor_slivers.dart` (permission prompts), `lib/features/shell/presentation/bindings/shell_binding.dart`, `android/app/src/main/{AndroidManifest.xml,kotlin/com/example/user_app/MainActivity.kt}`; tests `test/features/notifications/notifications_test.dart`, `test/helpers/fake_notifications.dart`, `test/features/shell/shell_test.dart`
- docs: api-contracts, database-schema, notification-matrix, known-issues, architecture/flutter.md, M18 spec, milestones.md, current-milestone, progress

## Files pending approval
- M17 and M18 files are uncommitted unless the user has committed them.

## Next milestone
- M19 — Digital Invitations (spec drafted at the M18 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

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
