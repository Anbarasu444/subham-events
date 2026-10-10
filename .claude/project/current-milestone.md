# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M24** |
| Milestone name | Vendor Foundation |
| Phase | Vendor App (M24–M39) — first Vendor App milestone |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M24-vendor-foundation.md` (status: CONFIRMED 2026-10-10) |
| Started date | 2026-10-10 |
| Completed date | — |
| Approval status | **Awaiting `APPROVE MILESTONE M24`** |

## Objective
Turn the stock `vendor_app` template into the reference architecture (flavors, core layer, one style file, one illustrations file, splash, bootstrap, placeholder home).

## Completed work
- `vendor_app` turned into the reference architecture by **copying the User App core** (answer 3; `user_app/` untouched): `app/` (bootstrap, bootstrapper + start-failure screen, config, routes, initial binding), `core/` (network/Dio client + interceptors, error/Result, ViewState + state views, crash reporting + redaction, secure store, cache manager, FreeRASP wrapper, theme, festive widgets, utils), `features/diagnostics` (staging).
- Removed for now (arrive later): auth/session, auth interceptor, auth middleware, money, media/picker.
- **Subam Vendor** branding (answer 1): app name "Subam Vendor" / "Subam Vendor STG", `X-Client: vendor_app/…`.
- **One style file** `lib/core/theme/app_style.dart` (answer 2): Kalam font, the user's gradient **#11998E → #38EF7D** for decoration, AA-safe deeper teal/green (#0B6E66 → #1B7F4B) for white-text fills, mint background; native splash deep teal.
- **One illustrations file** `lib/core/assets/app_illustrations.dart` with the 26 vendor pictures (answer 4; icon fallbacks until supplied, GI-43).
- Flavors: Android `staging` (`.stg`) / `prod` (copied Gradle setup, `google-services.json` moved to `android/app/`); iOS `staging`/`prod` schemes, `config/<flavor>/flavor.xcconfig`, staging `GoogleService-Info.plist` moved to `ios/config/staging/` with matching Google/Firebase ids. iOS prod Firebase app missing (GI-42).
- Placeholder **vendor home**: welcome card, live server-connection card (check again, offline message), coming-soon grid, staging Diagnostics link.
- Android backup off; cleartext HTTP only in the debug manifest; unused iOS photo/camera prompts removed.

## In-progress work
- None.

## Blocked work
- None.

## Tests completed
- `flutter analyze` clean; `flutter test` **55/55** (copied core tests: config, bootstrapper/start-failure, error handlers, redaction, API client, runtime protection, dates, state views, diagnostics; new: `vendor_style_test.dart` 6, `vendor_home_test.dart` 3 incl. offline + retry and 200 % text).
- Device runs: iOS simulator (iPhone 16) and the user's Android phone (USB `adb reverse`): splash → home → "Connected" (backend `GET /health/ready` 200).
- User App: no changes (git status), so its 328 tests are unaffected.
- Screenshots: `vendor_app/build/subam_vendor_ios_home.png`, `vendor_app/build/subam_vendor_android_home.png`.

## Reviews
| Review | Status |
|---|---|
| Security review | DONE — no secrets in the app (Firebase client configs are public identifiers); release builds HTTPS-only (cleartext debug-only, prod config requires https); Android backup off; logging interceptor redacts and is off in prod; FreeRASP wired but off until GI-14; no auth yet (M25). |
| Performance review | DONE — same start-up path as the User App (non-blocking Crashlytics, splash removed on first frame); home makes one health request on open; illustrations decoded at display size; no timers or continuous animations. |
| Notification review | DONE — no notifications in M24 (FCM arrives in M36). |
| Documentation | DONE — spec ACs + change log, `milestones.md`, `progress.md`, `known-issues.md` GI-42/GI-43, `vendor_app/config/README.md`. |

## Known issues
- See `known-issues.md`: GI-4…GI-43 (new: GI-42 vendor ids/prod Firebase/signing, GI-43 vendor illustrations).

## Files changed
- `vendor_app/`: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.gitignore`; `lib/` (new: `main_staging.dart`, `main_prod.dart`, `app/**`, `core/**`, `features/diagnostics/**`, `features/home/**`; removed template `main.dart`); `test/` (new suite; removed template `widget_test.dart`); `config/` (README, staging/prod json, local example); `assets/fonts/kalam/*`, `assets/illustrations/.gitkeep`; Android: `settings.gradle.kts`, `app/build.gradle.kts`, `app/google-services.json` (moved), debug/main manifests, splash resources; iOS: `Runner.xcodeproj/project.pbxproj`, `xcschemes/{staging,prod}`, `Runner/Info.plist`, `Podfile`, `Flutter/*.xcconfig`, `config/{staging,prod}/flavor.xcconfig`, `config/staging/GoogleService-Info.plist` (moved), splash assets; generated plugin registrants (linux/macos/windows).
- Docs: `.claude/project/{current-milestone.md, milestones.md, progress.md, known-issues.md, milestones/M24-vendor-foundation.md}`.
- No backend, database or `user_app/` changes.

## Files pending approval
- All M24 files above (the user commits).

## Next milestone
- M24 (this one), then M25 — Vendor Authentication.

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M23 USER APP FREEZE: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** — **User App frozen** (version 1.0.0+1) |
| Started | 2026-10-09 |
| Completed / approved | 2026-10-10 — `APPROVE MILESTONE M23` issued by the user (while IN_PROGRESS; recorded as option 2: rest of the device test moved to M64, GI-41) |
| Spec | `milestones/M23-user-app-freeze.md` (CONFIRMED) |

Evidence at approval: regression green (backend 74 unit + 148 e2e, Flutter 328); iOS simulator check; Android Google + phone sign-in verified on the user's phone; contrast (AA-safe brand gradients), security (backup off) and offline passes; freeze record, policy, feature summary and 14 release blockers in `user-app-freeze.md`. Local setup fixes: pending M21 migration applied; `adb reverse` for device testing. Not verified on device: remaining flows and real push (GI-41).

## Previous milestone — M22 User App Hardening + festive refresh: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-09 |
| Completed / approved | 2026-10-09 — `APPROVE MILESTONE M22` issued by the user |
| Spec | `milestones/M22-user-app-hardening.md` (CONFIRMED) |

Evidence at approval: one style file (`app_style.dart`, Kalam, festive gradient), one illustrations file (`app_illustrations.dart`), festive components, redesigned Home (countdown, quick actions, donut charts), Checklist (month tabs), Budget (+ category details), Menu; user illustrations wired; Flutter 327 tests incl. screenshot tests. Not verified: APK build (disk, GI-40). Broader hardening moved to M23.

## Previous milestone — M21 User Profile / Menu: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-09 |
| Completed / approved | 2026-10-09 — `APPROVE MILESTONE M21` issued by the user |
| Spec | `milestones/M21-user-profile-menu.md` (CONFIRMED) |

Evidence at approval: My profile (name, photo with config switch), My reviews, Help (FAQs, placeholder contacts, version, legal coming soon), account deletion (R11 interim, data kept; bookings/events/reminders/invitations/devices handled; N13 to vendors) with restore on sign-in (7A); Messages hidden; backend 74 unit + 148 e2e, Flutter 313 tests; reviews done. APK build not re-run (disk full). Dev DB migration `1792800000000-ProfilePhoto` to be run by the user.

## Previous milestone — M20 Reviews: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-09 |
| Completed / approved | 2026-10-09 — `APPROVE MILESTONE M20` issued by the user |
| Spec | `milestones/M20-reviews.md` (CONFIRMED) |

Evidence at approval: reviews for completed bookings (stars + optional comment, once, idempotent, A4/A5/A12), atomic listing ratings, public rating summary and approved comments ("Asha K."), booking prompt and status, N19 vendor in-app, N14 invites a rating, N27 reminder 3 days after completion if not rated; backend 74 unit + 145 e2e, Flutter 301 tests; Android debug build OK; reviews done. N23 deferred to M51 (GI-37). Dev DB migrations `1792600000000-Reviews` and `1792700000000-ReviewReminders` to be run by the user.

## Previous milestone — M19 Digital Invitations: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-09 |
| Completed / approved | 2026-10-09 — `APPROVE MILESTONE M19` issued by the user |
| Spec | `milestones/M19-digital-invitations.md` (CONFIRMED) |

Evidence at approval: invitation per event (template catalogue of 6, editor with live preview, publish, share link or phone-drawn picture, close/reopen replies, new link, revoke), public guest page with anonymous RSVP (A6, hash-only tokens, noindex/no-referrer/CSP), replies list with totals, N18 hourly digest; backend 74 unit + 137 e2e, Flutter 291 tests; Android debug build OK; reviews done. Not verified: opening a link from another phone; a real N18 push. Dev DB migration `1792500000000-Invitations` to be run by the user.

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
