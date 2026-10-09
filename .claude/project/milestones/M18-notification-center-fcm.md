# M18 — Notification Center + FCM

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M18` on 2026-10-08 (open questions answered the same day) |
| Phase | User App |
| Depends on | M17 COMPLETED and approved (`APPROVE MILESTONE M17`); the user's Firebase/Apple steps (open question 2) for real pushes |
| Primary owner agent | notification-manager + user-app-manager + backend-manager + database-manager (security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Context
Since M5, every feature has written **in-app notification records** (quotes, bookings, reminders, checklist alerts…) with `push_policy NEVER`. M18 does two things:
- makes them visible in an **in-app Notification Center** (bell, list, read/unread),
- delivers **phone push notifications** through Firebase Cloud Messaging (FCM), following notification-matrix.md Part A: an outbox job, a device registry, retries, and token clean-up.

## Objective
Signed-in users:
- see their notifications in a Notification Center (newest first, unread badge, mark read or all read, tap opens the related screen),
- receive phone pushes for user-facing types (N10–N14, N16, N17, and others in the matrix) on Android and iOS, respecting per-category push preferences.

Tapping a push opens the right screen. Device tokens are registered on sign-in and app start, removed on sign-out, and dropped when FCM reports them invalid.

## In scope (proposed)
**Database (cross-layer, Rule 7)**
1. `notification_devices` (Part C): user, audience, `fcm_token` unique (re-assigned on registration), platform, app version, active, last seen.
2. `notification_preferences` (user × category, push on/off).
3. Use of the existing `jobs` outbox for `notification.push`.
4. Switch user-facing types from `push_policy NEVER` to `ALWAYS`/`IF_ENABLED` per the matrix. Vendor-audience records stay in-app until the Vendor App (M36).

**Backend (cross-layer, Rule 7)**
5. Endpoints:
   - `GET /me/notifications` (cursor, newest first, unread count),
   - `POST /me/notifications/{id}/read`,
   - `POST /me/notifications/read-all`,
   - `GET /me/notifications/unread-count`.
6. Devices: `PUT /me/devices` (register or refresh a token) and `DELETE /me/devices/{token}` (sign-out).
7. Preferences: `GET` and `PUT /me/notification-preferences`. Transactional categories (BOOKING, PAYMENT) can't fully turn off the in-app records (only the push).
8. A push worker:
   - claims `notification.push` jobs (`SKIP LOCKED`), loads active devices and preferences,
   - sends through Firebase Admin with the payload of matrix §3 (no sensitive data in the body), using Android channels and APNs thread ids,
   - deactivates the token on UNREGISTERED, backs off on transient errors (max 5 attempts),
   - records `delivery_status`,
   - follows the collapse/noise rules (§5).
9. Notification creation enqueues the push job in the same transaction (exactly-once record, at-least-once push).

**User App**
10. A **bell** in the app bar (Home) with an unread badge, and a **Notification Center** screen:
    - list, read/unread styling, mark all read, pull to refresh, paging,
    - empty, error and offline states,
    - tap opens the target (event, vendors tab with the booking, reminders, checklist).
11. **FCM**:
    - the `firebase_messaging` package (**new dependency — needs your approval**, open question 1) and Android notification channels;
    - permission request at a sensible moment (open question 4);
    - token registration on sign-in and app start, token refresh, unregister on sign-out;
    - foreground messages shown as an in-app banner, background and terminated taps routed to the screen;
    - de-duplication by `notificationId`.
12. Menu → Settings → **Notifications**: push on/off per category group.
13. Tests:
    - Backend unit and e2e: list/read/count, device registration/re-assignment/removal, preferences, the worker with a fake FCM client (success, invalid token, retry/backoff, preference off, no devices), payload privacy.
    - Flutter: center list and states, badge, routing from a notification, the permission flow with fakes, 200 % text.
14. Docs: api-contracts, database-schema, notification-matrix (policies and channels per type), flutter.md, threat model (tokens), progress.

## Out of scope
- Vendor and admin pushes (M36, admin later), email or SMS, marketing or broadcast messages, rich pushes with images, quiet-hours scheduling (M17 answer 5: none).
- Deep links from outside the app (web links), which need the link domain.

## Acceptance criteria
- [x] AC-1 The Notification Center lists the user's notifications with unread count, mark read and mark all read, and opens the related screen.
- [~] AC-2 (Android path built and tested with a fake sender; the real-device check is the user's step; iOS pending GI-35) Pushes are delivered for user-facing types on Android and iOS (verified on at least one real device by the user), respecting preferences. Invalid tokens are deactivated. Transient failures retry with backoff.
- [x] AC-3 Devices are registered and re-assigned correctly, and removed on sign-out. No push is sent to a signed-out device.
- [x] AC-4 Push content holds no sensitive data. Every payload has `notificationId`, and the app de-duplicates.
- [x] AC-5 Screens handle all states and render at 200 % text. Checks and tests pass, reviews are done, the docs are updated, and the status is IN_REVIEW.

## Your steps (needed for real pushes; I can't do them)
- **Android:** nothing extra beyond the Firebase project you already set up (FCM is enabled by default). Test on a real phone or an emulator with Google Play.
- **iOS:**
  - an Apple Developer **APNs Authentication Key (.p8)** uploaded in Firebase Console → Project settings → Cloud Messaging,
  - the **Push Notifications** and **Background Modes → Remote notifications** capabilities enabled (I can add these in Xcode project files; the key upload is yours),
  - a real bundle id (GI-5), because iOS pushes need a provisioned app.
- The backend already has the Firebase service-account path configured (used for auth). FCM uses the same credentials. No new secret goes into the app.

## Risks
- iOS push needs the APNs key and a real bundle id (GI-5). Without them, iOS pushes can't be verified; Android can.
- Permission prompts asked too early get denied. Ask in context (open question 4).

## Open questions (answered 2026-10-08 — see change log)
1. **Approve adding `firebase_messaging`** (the official Firebase plugin for push) to the User App? Without it there are no phone pushes; only the in-app center works.
2. **Platforms for M18:** Android pushes now, with iOS pushes once you've uploaded the APNs key and chosen the real bundle id (recommended)? Or wait until iOS is ready too?
3. **Which notifications push** (the rest stay in-app only). Proposed:
   - push: quote received (N10), booking confirmed/cancelled/completed (N12–N14), reminders (N17), checklist due/overdue (N16);
   - in-app only: low-value or own-action records.
   OK?
4. **When to ask for notification permission:** proposed: the first time you create a reminder or send an enquiry ("Get notified when the vendor replies?"), and from Settings. Not at app start. OK?
5. **Settings:** proposed: one switch per group — Bookings & quotes, Reminders & checklist, Other. Booking and payment notifications always appear in the in-app center even when the push is off. OK?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-08 | Initial DRAFT created at the M17 approval gate | CLAUDE.md Rule 4 |
| 2026-10-08 | User answers: 1 **`firebase_messaging` approved**; 2 "A" → the first (recommended) option: **Android pushes now, iOS pushes once the user uploads the APNs key and picks the real bundle id** (GI-5); 3 push types OK (N10, N12–N14, N16, N17; others in-app only); 4 permission asked in context (first reminder / enquiry, and Settings), not at launch — OK; 5 three switches (Bookings & quotes, Reminders & checklist, Other), booking/payment always in-app — OK | User |
| 2026-10-08 | CONFIRMED by `START MILESTONE M18`. Implementation decision: the `notifications` rows themselves are the push outbox (`delivery_status = PENDING` + attempt/next-attempt columns, claimed with a lease and `SKIP LOCKED`) instead of a separate `jobs` table, which does not exist yet; same guarantees (record and push intent in one transaction, at-least-once push) | User / Claude |
| 2026-10-08 | APPROVED by `APPROVE MILESTONE M18` with AC-2 partially verified (real-device push is the user's step; iOS tracked as GI-35) | User |
