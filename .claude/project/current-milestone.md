# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M5** |
| Milestone name | Authentication |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M5-authentication.md` (status: CONFIRMED 2026-10-06) |
| Started date | 2026-10-06 |
| Completed date | — |
| Approval status | Awaiting `APPROVE MILESTONE M5` |

## Objective
Guest browsing plus Google and phone sign-in via Firebase; backend token verification, user creation and server-side roles; protected routes, refresh, sign-out and all failure paths.

## Completed work (acceptance-criteria evidence)
| AC | Evidence | Status |
|---|---|---|
| AC-1 | `AuthGuardMiddleware` + `safeReturnTo` (tests); `/account` protected; guests browse public screens | Done |
| AC-2 | **Verified on the iOS simulator (2026-10-07) with the real backend, database and Firebase:** phone sign-in with the Firebase test number → OTP → home shows "My account"; DB: 1 ACTIVE user with role USER, 1 in-app WELCOME notification (push NEVER), audit AUTH_SIGN_UP (provider phone); My account → Sign out (confirm dialog) → `POST /auth/sign-out` 204, audit AUTH_SIGN_OUT, app back to guest. Google: Apple's Google sign-in sheet opens correctly and Cancel returns cleanly; completing a Google login was left to the user (credentials). Android staging/prod build with Firebase. Fixed during the check: Flutter default deep-link handling swallowed the Firebase reCAPTCHA return link (disabled on iOS/Android), duplicate phone line on My account, iOS app name in system prompts; found a Firebase Console setting (SMS region policy allow-list was empty) — user added India | Done (Google login completion by user optional) |
| AC-3 | DB e2e against `event_planner_test`: user created once (incl. 3 concurrent first sign-ins), role USER, email only when verified, audit `AUTH_SIGN_UP`/`AUTH_SIGN_IN` | Done |
| AC-4 | Guard unit tests (all failure codes, roles, status) + API e2e (missing/expired token) + DB e2e (suspended → 403); Flutter interceptor/session tests sign out on revoked/suspended/deleted | Done |
| AC-5 | Interceptor tests: one forced refresh + replay; concurrent requests share one refresh; failed refresh offline keeps the session | Done |
| AC-6 | Sign-out revokes refresh tokens (DB e2e, audited), clears local data and private image cache (session tests); "all devices" confirmed by the user | Done |
| AC-7 | Migrations applied by the user on `event_planner_dev` and by tests on `event_planner_test`; audit log append-only (trigger, e2e); N1 welcome row in-app only (e2e) | Done |
| AC-8 | Crashlytics reporter replaces errors with redacted copies (tests); no service-account key or secret in the repo; backend verified with the real key (fake token → `AUTH_TOKEN_INVALID`, DB ready) | Done |
| AC-9 | iOS flavors (schemes, configs, per-flavor plist, bundle ids); prod build has no `NSAllowsLocalNetworking` (verified) — GI-9 resolved | Done |
| AC-10 | Backend: lint, typecheck, 46 unit + 19 e2e (incl. 8 DB) pass, build OK. Flutter: analyze clean, 78 tests pass. Code, security, UI reviews done and fixed | Done |

## Reviews
| Review | Status | Notes |
|---|---|---|
| Code review | Done — code-reviewer PASS WITH FINDINGS | Fixed: no sign-out on temporary errors (`ProfilePendingSession` + retry), single-flight sign-out keeping the first message, keep Firebase identity on retryable backend failure, Android auto-verification completes sign-in, resend errors shown, rate limit before token verification, OTP/sign-in tests added, DB e2e run |
| Security review | Done — security-manager PASS WITH FINDINGS (no Critical/High) | Fixed: rate limit before auth (per IP, 60/min for carrier NAT), append-only audit trigger, offline refresh keeps session, redaction of OTP codes/verification ids, `returnTo` allow-list. Recorded: GI-18 (separate prod project), GI-19 (App Check/SMS abuse), GI-20 (vendor_app files — kept by user), GI-10 (trust proxy) |
| UI/UX review | Done — ui-manager PASS WITH FINDINGS | Fixed: code field cleared on resend/wrong code, +91 prefix + validation hint, submit from keyboard, autofill hints, "Wrong number? Edit", sign-out error handling, neutral live-region messages, no PII on home, clearer network message |
| Performance review | Done | Fixed a 7 s start-up stall (Crashlytics settings fetch) and added per-step start-up timeouts; first frame ~2.4 s (debug, simulator); token refresh shared; status cache ≤ 60 s |
| Notification review | Done | N1 welcome: in-app only, `push_policy = NEVER`, created once in the sign-up transaction (DB e2e) |
| Documentation | Done | api-contracts Part B (`/auth/session`, `/auth/sign-out`, `/me`), database-schema Part B (2 migrations), identity-access §7a, known issues GI-9/12/15 updated, GI-18…GI-25 added |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8…GI-12, GI-14 (FreeRASP activation), GI-15 (redaction — M5 scope), GI-16 (cold-start measurement — by M22).
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21. Assumptions A1–A12, O1, O2 per `domain-model.md` §9.

## Files changed
- `backend/`: `package.json`/lock (firebase-admin), `.env.example`, `src/app.module.ts`, `src/config/*`, `src/common/errors/error-codes.ts`, `src/common/ids/*`, `src/modules/{auth,users,rbac,audit,notifications,rate-limit}/**`, `src/modules/health/health.controller.ts` (@Public), tests `test/{auth.e2e-spec,app.e2e-spec,fakes,stubs/*}.ts`, `test/jest-e2e.json`
- `database/migrations/`: `1791300000000-AuthFoundation.ts`, `1791300000001-AuditLogsImmutable.ts`
- `user_app/`: `pubspec.*` (firebase_core, firebase_auth, google_sign_in, firebase_crashlytics), `lib/core/auth/**`, `lib/core/crash/{redaction,crashlytics_reporter}.dart`, `lib/core/network/{api_client,interceptors/auth_interceptor}.dart`, `lib/core/widgets/app_text_field.dart`, `lib/features/auth/**`, `lib/features/home/...`, `lib/app/{app,bootstrap,bindings,middlewares,routes,startup/bootstrapper}`, tests; Android `settings.gradle.kts`, `app/build.gradle.kts`, `app/google-services.json`; iOS `config/{staging,prod}/*`, `Flutter/*-{staging,prod}.xcconfig`, `Flutter/{Debug,Release}.xcconfig`, `Runner.xcodeproj` (configs, schemes, build phase), `Runner/Info.plist`, `Podfile(.lock)`
- Root `.gitignore` (Firebase client configs committed — user decision)
- `.claude/project/`: api-contracts, database-schema, identity-access, known-issues, M5 spec, milestones, current-milestone, progress

## Files pending approval
- M4 committed by the user (`d7565c3`). Gate records (this file, progress, known issues, M4 spec, M5 spec draft) are uncommitted.

## Next milestone
- M6 — Main Navigation (spec drafted at the M5 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M4 Splash & App Bootstrap: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-06 |
| Completed / approved | 2026-10-06 — `APPROVE MILESTONE M4` issued by the user (committed `d7565c3`) |
| Spec | `milestones/M4-splash-app-bootstrap.md` (CONFIRMED) |

Evidence at approval: native splash light/dark + fade-in verified on iOS simulator; ordered bootstrap with start-failure screen; CrashReporter + global handlers; real app version (GI-7 resolved); FreeRASP observe mode (off until user config — GI-14); Flutter analyze clean, 44 tests; UI + security reviews PASS WITH FINDINGS (fixed / recorded). Not done at approval: AC-6 cold-start measurement (GI-16, owner M22).

## Earlier milestones
- M3 User App Foundation: COMPLETED 2026-10-06 (committed `e78060f`).
- M2 Global Domain Model: COMPLETED 2026-10-06 (committed `658d59d`).
- M1 Global Architecture: COMPLETED 2026-10-06 (committed `1c21c35`).
