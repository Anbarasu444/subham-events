# M5 — Authentication

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M5` on 2026-10-06 |
| Phase | User App |
| Depends on | M4 COMPLETED and approved (`APPROVE MILESTONE M4`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager (security-manager, notification-manager, code-reviewer reviewers) |

## Objective
Users can browse as guests and sign in to the User App with **Google** or **phone number (OTP)** through Firebase Authentication (ADR-0008). The NestJS backend verifies Firebase ID tokens, creates/maps the PostgreSQL user, resolves roles server-side and protects routes by default. Sign-out, token refresh, suspended/deleted accounts and every failure path behave as documented in `architecture/identity-access.md` §3–§6, §8.

## In scope
**Firebase (user-created, Claude configures the app)**
1. Firebase project `<app>-staging` (created by the user) with Google and Phone providers; iOS + Android app registrations for the staging flavor; `flutterfire`/manual config per flavor; App Check decision recorded (enforcement may follow later).
2. **iOS native flavors** (staging/prod schemes & configurations) with per-flavor `GoogleService-Info.plist` and Google URL scheme; moves `NSAllowsLocalNetworking` to Debug/staging only (GI-9).
3. Firebase client-config commit policy decided (ADR-0012 open point) and `.gitignore` updated accordingly.

**User App**
4. `firebase_core`, `firebase_auth`, `google_sign_in` (+ `firebase_crashlytics` for item 12) — added with approval at START.
5. Auth feature (`features/auth`): sign-in screen (Google button, phone entry), OTP screen (resend timer, auto-retrieval on Android), loading/error/retry states, cancel handling; `AuthService` (Firebase), `AuthRepository` (calls `/auth/session`), `SessionController`.
6. `AuthInterceptor`: attaches the ID token; single-flight forced refresh + one replay on `401 AUTH_TOKEN_EXPIRED`; sign-out on invalid/revoked/suspended/deleted (identity-access.md §5, §8).
7. `AuthGuardMiddleware` + `returnTo`: protected routes redirect guests to sign-in and resume after sign-in; `StartupRouter` uses the cached auth state.
8. Sign-out (clears session data, secure store keys, private image cache) and a minimal "signed in as" area on the home placeholder (full profile is M21).
9. Secure-storage review (GI-12): confirm how `encrypted_shared_preferences` stores its key; if not hardware-backed, propose `flutter_secure_storage` via ADR (user approval) before storing session data.

**Backend (cross-layer, Rule 7)**
10. `firebase-admin` integration (credentials from a service-account file **outside the repo**, path via env; nothing committed); `auth` module: global guard (Bearer ID token; `@Public()` opt-out), `RequestUser`, `POST /api/v1/auth/session`, `POST /api/v1/auth/sign-out` (revokes refresh tokens), revocation check on sensitive routes, user-status cache ≤ 60 s.
11. `users`, `rbac` (USER/VENDOR roles), `audit` and `jobs` foundations as needed by sign-in: migrations for `users`, `user_roles`, `audit_logs` (append-only grants), `notifications` (N1 welcome, in-app only), following `database-schema.md` Part A/C; email persisted only when `email_verified` (identity-access.md §6).
12. Crash reporting: Crashlytics implementation of `CrashReporter` **with redaction** (GI-15) — tokens, Authorization headers, phone numbers, emails removed; tests.
13. Rate limits for auth endpoints (shared store per architecture/backend.md §4 — PostgreSQL-backed) and `trust proxy` decision noted (GI-10).

**Docs & tests**
14. `api-contracts.md` Part B for `/auth/*` and `GET /api/v1/me`; `database-schema.md` Part B for new migrations; notification matrix N1 implemented; tests: backend unit + e2e (fake Firebase verifier: valid, expired, revoked, suspended, deleted, missing token, public route), migration run on empty DB, Flutter unit/widget tests for auth flows and interceptor refresh.

## Out of scope
- Vendor sign-in / vendor role grant (M25), Admin CMS username+password auth (M40)
- Profile editing, account deletion (M21); FCM device registration (M18)
- Sign in with Apple — deferred by the user until before the iOS release (must be added before App Store submission if Google sign-in is offered — guideline 4.8)
- Hosting/deployment

## Deliverables
Working Google + phone sign-in on the staging flavor (iOS and Android), verified sessions on the backend, users/roles/audit/notifications tables, Crashlytics with redaction, iOS flavors, tests and docs.

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification (in-scope item #) |
|---|---|---|
| user_app | Auth feature, interceptor, guard, flavors, Crashlytics | 2, 4–9, 12 |
| backend | Firebase Admin, auth module, guard, users/rbac/audit/notifications basics, rate limiting | 10, 11, 13 |
| database | Migrations: users, user_roles, audit_logs, notifications (+ jobs if needed) | 11 |
| Firebase | Staging project config, providers, app registrations (user creates project) | 1–3 |
| API contracts | `/auth/session`, `/auth/sign-out`, `/me` | 14 |
| Notifications | N1 welcome (in-app only) | 11 |

## Acceptance criteria
- [ ] AC-1 Guest can open the app and use public screens without signing in; a protected route sends the guest to sign-in and returns to it afterwards.
- [ ] AC-2 Google sign-in and phone OTP sign-in work on the staging flavor (iOS and Android), including cancel, wrong OTP, expired OTP, network failure and retry states.
- [ ] AC-3 `POST /auth/session` verifies the token server-side, creates the user once (idempotent), grants `USER`, returns user + roles; email stored only if verified; audited.
- [ ] AC-4 All non-public routes reject missing/invalid/expired/revoked tokens with the documented error codes; suspended/deleted users get 403 and are signed out by the app (e2e + Flutter tests).
- [ ] AC-5 Expired token → one forced refresh + replay; concurrent requests share one refresh (unit tests).
- [ ] AC-6 Sign-out revokes refresh tokens, clears local session data and returns to guest state.
- [ ] AC-7 Migrations apply on an empty database; `audit_logs` is append-only for `app_rw`; N1 notification row created on first sign-in (no push).
- [ ] AC-8 Crashlytics receives errors with tokens/phone numbers/emails redacted (tests); no secrets or service-account files committed.
- [ ] AC-9 iOS staging/prod flavors work; `NSAllowsLocalNetworking` not present in prod builds (GI-9).
- [ ] AC-10 Backend lint/typecheck/tests/build and Flutter analyze/format/tests pass; security, notification, UI, performance reviews and code review done; docs updated; IN_REVIEW.

## Required reviews
- Security: token verification, guard defaults, role resolution, rate limiting, secure storage, redaction, no committed credentials.
- Notification: N1 behaviour (in-app only).
- UI/UX: sign-in and OTP screens, error states, accessibility.
- Performance: sign-in latency, start-up impact of Firebase init.
- Code review: full diff.

## Risks and assumptions
- Firebase project, provider setup and service-account key are created by the user (Claude never creates cloud resources or handles the key's content).
- Phone auth on iOS needs APNs/reCAPTCHA setup; Firebase test phone numbers are used for automated/dev testing.
- Package ID is still `com.example.user_app` (GI-5): Firebase app registrations made now must be redone after the rename — consider renaming first.
- **App Store guideline 4.8:** apps offering Google sign-in generally must also offer Sign in with Apple (or an equivalent privacy-focused option) — affects iOS release (open question 2).

## Open questions
1. Firebase — **partly answered (2026-10-06):** the user created Firebase project `subam-events` and placed config files at `user_app/android/google-services.json` and `user_app/ios/GoogleService-Info.plist` (also in `vendor_app/`, which stays untouched until M24). Findings to resolve before/at START:
   - the apps are registered as `com.example.user_app` / `com.example.userApp` (no `.stg` suffix) while the staging flavor uses `.stg`;
   - the files contain no OAuth client (`oauth_client` empty, no `REVERSED_CLIENT_ID`) → Google sign-in is not yet enabled / Android SHA-1 not yet added;
   - one project only: is `subam-events` the **staging** project (ADR-0012 expects staging + prod)?
   - backend service-account JSON location not yet given.
2. ~~Sign in with Apple~~ — answered: **defer until before the iOS release** (App Store guideline 4.8 risk recorded).
3. ~~Config files~~ — answered: **commit to git** (root `.gitignore` rule changed in M5).
4. ~~Packages~~ — answered: approved (`firebase_core`, `firebase_auth`, `google_sign_in`, `firebase_crashlytics`, `firebase-admin`).
5. ~~Package ID~~ — answered: **no change for now** (GI-5 stays open).

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-06 | Initial DRAFT created at the M4 approval gate | CLAUDE.md Rule 4 |
| 2026-10-06 | Open questions 2–5 answered (Apple sign-in deferred to pre-release, commit config files, packages approved, package ID unchanged); question 1 partly answered — Firebase project `subam-events`, config files placed; follow-ups listed | User |
| 2026-10-06 | CONFIRMED by `START MILESTONE M5` while open question 1 follow-ups (app IDs, Google provider/SHA-1, staging project, service-account path) were still open — Firebase-dependent verification is blocked on them; independent work proceeds | User |
| 2026-10-07 | User decisions: keep vendor_app Firebase files (GI-20); separate prod Firebase project before release (GI-18); sign-out signs out all devices | User |
