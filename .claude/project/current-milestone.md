# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M21** |
| Milestone name | User Profile / Menu |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M21-user-profile-menu.md` (status: CONFIRMED 2026-10-09) |
| Started date | 2026-10-09 |
| Completed date | — |
| Approval status | **Awaiting `APPROVE MILESTONE M21`** |

## Objective
Profile view/edit (name, photo), My reviews, Help, safe account deletion (R11 interim, A8 as changed), Menu without dead ends.

## Completed work
- Answers applied: R11 interim kept (1A); deletion effects (2A); profile photo with a config switch (3); placeholder contacts in config (4); terms/privacy coming soon (5); Messages hidden (6); deleted users can sign in again and get the same account back (7A, confirmed).
- **Database:** migration `1792800000000-ProfilePhoto` (media USER/USER_PHOTO; `users.photo_media_id`).
- **Backend:** `PATCH /me` (name), `PUT/DELETE /me/photo` (photo via the existing upload flow, `USER_PHOTO`), `MeDto.photo` (also from `/auth/session`); `POST /me/delete` (typed DELETE; cancels confirmed bookings with N13 to vendors, cancels planning events, closes enquiries, cancels reminders, revokes invitation links, deactivates devices, marks DELETED, revokes tokens; data kept); restore on `/auth/session` (guard lets a DELETED identity reach only that route); reviews of a deleted account show "Deleted user".
- **User App:** My profile (photo with progress, name, read-only phone/email, member since), Delete account screen (effects explained, type DELETE, signs out with a restore message), My reviews, Help (FAQs, contact, version, legal coming soon); Menu: My profile, My reviews, Help real pages, Messages hidden; config keys `SUPPORT_EMAIL`, `SUPPORT_PHONE`, `PROFILE_PHOTO_ENABLED`.

## In-progress work
- None.

## Blocked work
- Android APK build could not be re-run: the Mac's disk filled up during the build (122 MB free; 1.3 GB after `flutter clean`). Dart analysis and all tests pass; no new native plugins were added. Large caches: `~/.gradle/caches` (28 GB) and Xcode DerivedData (9.3 GB) — not deleted without the user's permission.

## Tests completed
- Backend: unit 74/74; e2e 148/148 (3 new: name edit + validation + audit without the name; photo set/replace/remove + ownership; deletion effects end to end + 403 afterwards + restore on sign-in); lint and typecheck clean.
- User App: analyze clean; 313/313 tests (12 new + shell tests updated): profile parsing, name/photo/delete controller, profile screen, photo switch, photo sheet, delete flow (typed DELETE), Help, My reviews (list/empty), 200 %.
- Not verified: a real device run; the APK build (disk).

## Reviews
| Review | Status |
|---|---|
| Security review | DONE — name only editable (phone/email from verified sign-in; unknown fields 422); photo must be the caller's READY `USER_PHOTO` (ownership enforced at upload and set); deletion requires a revocation-checked token, typed confirmation, rate limit 5/min, runs in one transaction, revokes refresh tokens and deactivates devices; DELETED identities can reach only `/auth/session` (restore, audited); audit logs carry no names. Residual: anyone holding the user's Google/phone sign-in can restore the account — accepted by answer 7A. |
| Performance review | DONE — deletion is set-based SQL per table plus one query per cancelled booking (bounded by the user's bookings); profile reads add one media lookup; avatar uses the cached signed thumbnail. |
| Notification review | DONE — N13 to each vendor whose booking is cancelled by account deletion (in-app; vendor pushes from M36); no notification for profile edits (own actions); devices deactivated so no pushes reach a deleted account. |
| Documentation | DONE — api-contracts (profile, account, media kind), database-schema, notification-matrix, identity-access, domain-model (A8), flutter.md §6n, known-issues GI-38, spec ACs, progress. |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-38.
- R11 final policy to revisit before M72 (GI-38). R6 (before M28/M29), R10 (before M26).

## Files changed
- Database: `database/migrations/1792800000000-ProfilePhoto.ts`.
- Backend: `src/modules/users/{me.controller.ts, me.dto.ts, profile.service.ts (new), users.module.ts, entities/user.entity.ts}`, `src/modules/auth/{account.controller.ts (new), account-deletion.service.ts (new), auth.module.ts, auth.service.ts, auth.guard.ts}`, `src/modules/media/{media.dto.ts, media.entity.ts, media.service.ts}`, `src/modules/reviews/reviews.service.ts`; tests `test/profile.e2e-spec.ts` (new).
- User App: `lib/features/profile/**` (new), `lib/app/config/app_config.dart`, `config/staging.json`, `config/prod.json`, `config/staging.local.json.example`, `lib/core/auth/session.dart`, `lib/core/auth/session_service.dart`, `lib/features/media/{domain/media_repository.dart, data/media_repository_impl.dart, data/media_remote_data_source.dart}`, `lib/features/reviews/{domain/review.dart, data/reviews_repository_impl.dart}`, `lib/features/menu/presentation/views/menu_tab_view.dart`, `lib/features/shell/presentation/bindings/shell_binding.dart`; tests `test/features/profile/profile_test.dart` (new), `test/helpers/fake_profile.dart` (new), `test/helpers/fake_media.dart`, `test/helpers/fake_reviews.dart`, `test/features/shell/shell_test.dart`.
- Docs: listed under Documentation, plus `current-milestone.md`, `milestones.md`.

## Files pending approval
- All M21 files above, and M19/M20 files unless already committed (the user commits).

## Next milestone
- M22 — User App Hardening (spec drafted at the M21 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

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
