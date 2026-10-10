# M23 — USER APP FREEZE

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M23` on 2026-10-09; milestone COMPLETED 2026-10-10 |
| Phase | User App (last User App milestone) |
| Depends on | M22 COMPLETED and approved (`APPROVE MILESTONE M22`) |
| Primary owner agent | qa-manager + user-app-manager (security-manager, performance-manager, ui-manager, notification-manager, code-reviewer reviewers) |

## Context
- M23 closes the User App phase. After `APPROVE MILESTONE M23` the Vendor App (M24–M39) unlocks, and the User App is **frozen**: only bug fixes and integration changes (M55+), no new features.
- The broader hardening was moved here from M22 (answer 6): performance profiling, offline behaviour on every screen, and release-readiness checks.
- Open items from earlier milestones that affect the User App:
  - GI-5: package id `com.example.user_app`.
  - GI-11: release signing.
  - GI-14: FreeRASP off.
  - GI-16: cold-start time not measured.
  - GI-22: Crashlytics symbols.
  - GI-35: iOS pushes.
  - GI-38: support contacts and legal links.
  - GI-39: illustrations.
  - GI-40: disk space for builds.
  - A real-device push test (M18).
  - The APK build, which has not been re-run since M20.

## Objective (proposed)
The User App is verified end to end on a real Android phone, robust offline and on low-end devices, consistent across screens, documented, and tagged as frozen. Release blockers that need the user are listed with owners and dates.

## In scope (proposed)
**A. Verification on devices**
1. Android release-mode build of the staging flavor, installed on the user's phone. Smoke test of every flow (checklist below) against the local backend.
2. A real FCM push received on the phone (reminder, quote, booking) and tap-through routing.
3. iOS simulator run, if the user wants it (question 2).

**B. Hardening (moved from M22)**

4. Offline / slow-network pass on every screen: airplane mode and server stopped. Each screen shows its stale banner or retry, never a blank screen.
5. Performance:
   - cold start and Home load times measured (closes GI-16);
   - scrolling jank check on Home, Checklist and Budget;
   - image memory check with the illustrations.
6. Accessibility pass:
   - TalkBack on key flows;
   - contrast of all festive colours (AA);
   - 200 % text on every screen.
7. Consistency pass: empty, error and loading states, snackbars and confirmations; any leftover old-style screens.
8. Security pass:
   - no secrets in the app;
   - ProGuard/R8 rules;
   - logs without personal data;
   - FreeRASP state (GI-14).

**C. Freeze**

9. Full regression run (backend unit + e2e, Flutter tests including screenshots).
10. User App freeze record:
    - the version (e.g. `1.0.0+1`);
    - the git tag suggestion `M23-user-app-freeze` (the user tags and commits);
    - a frozen-scope note in docs;
    - the change policy after freeze.
11. A user-facing **User App feature summary**: what the app does, with screenshots.
12. A release-blockers list with owners: package id, signing, APNs, legal links, real illustrations, support contacts, Sign in with Apple (GI-17), and so on.

## Out of scope
- New features (anything not already built).
- The Vendor App (M24+), the Admin CMS, and store publishing (M72).

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app | Bug fixes found in A/B only | 1–8 |
| backend | Bug fixes only, if the device tests find any | 1–2 |
| database | None expected | — |
| Firebase | None, unless the user completes APNs (GI-35) | 3 |

## Acceptance criteria
- [~] AC-1 The app is built and run on a real Android phone; every smoke-test flow passes (evidence: the user's confirmation and screenshots). — **Partial, deferred by the user (2026-10-10):** Google and phone sign-in verified on the user's Redmi M2101K7AI (server: `POST /auth/session` 200, events/reminders/notifications load, FCM device registered). Remaining smoke-test flows → **M64 Full QA** (GI-41).
- [~] AC-2 A real push is received and routes correctly. — **Deferred to M64** (GI-41): device registered for push (`PUT /me/devices` 204); a real push receipt and tap-through not yet observed.
- [x] AC-3 Offline, performance, accessibility and security passes are done, with findings fixed or logged. — Evidence: contrast fix + test (AA-safe brand gradients); security pass (no secrets, Android backup off, cleartext debug-only); offline states checked on iOS simulator and in tests; performance: cold start not measured on device (stays GI-16, M64).
- [x] AC-4 Full regression is green; the freeze record, feature summary and blockers list are written. — Evidence: backend 74 unit + 148 e2e, Flutter 328 incl. screenshot tests; `user-app-freeze.md` (freeze record, policy, feature summary, 14 release blockers).
- [x] AC-5 Reviews are done, the docs are updated, and the status is IN_REVIEW. — Evidence: reviews and docs in `current-milestone.md`; approved by the user without a separate IN_REVIEW step (see change log).

## Smoke-test checklist (draft)
Sign in (Google / phone) · create, edit, cancel and reopen an event · cover photo · checklist (add, done, month tabs, reorder, remind me) · budget (total, plan, expense, category details) · explore (search, filters, vendor details) · save vendor · add to event · enquiry · accept a (sample) quote · payments · complete booking · review · reminder push · invitation (create, publish, share link and picture, guest RSVP on another phone, replies) · notifications centre · profile (name, photo) · help · delete account and restore by signing in · sign out.

## Risks
- Device tests need the user's time, a phone, and a running backend on the same Wi-Fi.
- Disk space (GI-40) must be freed before builds.

## Open questions (please answer before `START MILESTONE M23`)
1. **Device test:** will you run the smoke test on your Android phone (I'll give you the steps and a checklist to tick), with me building the APK and checking logs?
2. **iOS:** include an iOS simulator check in M23, or leave iOS for later?
3. **Release blockers:** do you want to fix any now (e.g. the real package id / app name, GI-5), or only list them for M72?
4. **Version number** for the frozen User App: `1.0.0+1` OK?
5. **Freeze policy:** after M23, User App changes only for bugs and integration (M55+). OK?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-09 | Initial DRAFT created at the M22 approval gate | CLAUDE.md Rule 4 |
| 2026-10-09 | User answers: 1 **yes** — the user runs the Android smoke test on their phone (Claude builds the APK, gives steps, reads logs); 2 **quick iOS simulator check now**; a real iPhone stays blocked until the real app id is set (GI-5); 3 **list release blockers now, fix in M72** — no confirmed real app id/name exists yet (still `com.example.user_app`, GI-5), so nothing is changed; 4 version **1.0.0+1**; 5 freeze policy **OK** (after M23 only bug fixes and integration changes) | User |
| 2026-10-09 | CONFIRMED by `START MILESTONE M23` | User |
| 2026-10-10 | **Scope change (user):** after sign-in passed on the device, the user issued `APPROVE MILESTONE M23` in reply to the choice "1 = finish the device test now / 2 = sign-in is enough, move the rest to M64" — recorded as option 2: remaining Android smoke-test flows and the real-push check moved to M64 Full QA (GI-41). | User |
| 2026-10-10 | **COMPLETED** — `APPROVE MILESTONE M23` (issued while IN_PROGRESS; the user's explicit approval overrides the IN_REVIEW step) | User |
