# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M4** |
| Milestone name | Splash & App Bootstrap |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M4-splash-app-bootstrap.md` (status: CONFIRMED 2026-10-06) |
| Started date | 2026-10-06 |
| Completed date | — |
| Approval status | Awaiting cold-start measurement on Android (AC-6) and `APPROVE MILESTONE M4` |

## Objective
Branded native splash, ordered bootstrap with failure handling, global error capture, FreeRASP in observe mode, real app version, and a cold-start baseline.

## Completed work (acceptance-criteria evidence)
| AC | Evidence | Status |
|---|---|---|
| AC-1 | iOS simulator (iPhone 16): native splash `#FF7E7E` (light) and `#3A1F1F` (dark, verified after reinstall — iOS caches launch screens) → home screen, no blank frame; first screen fades in 250 ms. Android splash resources generated (incl. Android 12 `values-v31`); Android run by user | iOS verified; Android by user |
| AC-2 | `bootstrapper_test.dart`: ordered steps, non-critical failure continues, critical failure stops; `startup_failure_app_test.dart`: message + retry; text-scaling test (200 %, 320×568) | Done |
| AC-3 | Home screen shows "Foundation build 1.0.0 (staging)"; `X-Client` uses the same values; `app_config_test` | Done (GI-7 resolved) |
| AC-4 | `error_handlers_test.dart`: framework errors and uncaught platform errors reach `CrashReporter` | Done |
| AC-5 | FreeRASP 8.2.4 integrated in observe mode, never blocks start-up, started once per process; **disabled until the user provides `TALSEC_WATCHER_MAIL` + signing identities** (logged; reported as error in prod); tests cover disabled/missing-config paths | Done — activation pending user (GI-14) |
| AC-6 | Bootstrap step timings logged on every start. Profile-mode cold-start cannot be measured on the iOS simulator (debug only) and Claude's Android Gradle downloads time out — **measurement requested from the user** (command in report) | Pending user |
| AC-7 | `flutter analyze`: no issues; `dart format`: clean; `flutter test`: 44/44; only `user_app/` and `.claude/project/` changed | Done |
| AC-8 | UI review and security review done (see below); docs updated | Done |

## Reviews
| Review | Status | Notes |
|---|---|---|
| UI/UX review | Done — ui-manager PASS WITH FINDINGS | Fixed: 200 % text scaling (scrollable centred layouts + test), splash→home fade-in, busy button announced to screen readers, retry screen survives a throwing retry, hero-icon token, brand-colour contrast note, stale comment |
| Security review | Done — security-manager PASS WITH FINDINGS | Fixed: prod build without FreeRASP config reports an error, FreeRASP started once per process, missing package info reported. Recorded: GI-14 (Talsec data sharing → ADR + privacy disclosure before distribution; role mailbox), GI-15 (crash-report redaction with Crashlytics in M5) |
| Performance review | Partial | Bootstrap does only 3 light steps (config, package info, FreeRASP); no network on start-up; step timings logged. Cold-start number pending user measurement (AC-6) |
| Notification review | N/A | No notification impact |
| Documentation | Done | flutter.md §9–§11, known issues (GI-7 resolved, GI-14, GI-15), spec change log |

## Known issues
- See `known-issues.md`: GI-4, GI-5 (package ID), GI-7 (version — M4 scope), GI-8…GI-12. GI-6 and GI-13 resolved (user confirmed).
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21. Assumptions A1–A12, O1, O2 per `domain-model.md` §9.

## Files changed
- `user_app/`: `pubspec.yaml`, `pubspec.lock` (flutter_native_splash, package_info_plus, freerasp); `lib/app/bootstrap.dart`, `lib/app/app.dart`, `lib/app/config/app_config.dart`, `lib/app/startup/*` (bootstrapper, startup router, start-failure screen); `lib/core/crash/*`, `lib/core/security/runtime_protection.dart`, `lib/core/theme/tokens.dart`, `lib/core/widgets/{app_button,centered_scrollable,fade_in_on_start}.dart`, `lib/features/home/...home_placeholder_view.dart`; tests under `test/app/`, `test/core/crash/`, `test/core/security/`, `test/helpers/recording_reporter.dart`; generated native splash files (Android `res/drawable*`, `values*`, iOS `LaunchScreen.storyboard`, `LaunchBackground`/`LaunchImage` assets, `Info.plist`)
- `.claude/project/`: `architecture/flutter.md`, `known-issues.md`, `milestones/M4-splash-app-bootstrap.md`, `milestones.md`, `current-milestone.md`, `progress.md`

## Files pending approval
- M3 committed by the user (`e78060f`). M4 files are uncommitted; the user commits personally.

## Next milestone
- M5 — Authentication (spec drafted at the M4 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M3 User App Foundation: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-06 |
| Completed / approved | 2026-10-06 — `APPROVE MILESTONE M3` issued by the user |
| Spec | `milestones/M3-user-app-foundation.md` (CONFIRMED) |

Evidence at approval: backend lint/typecheck/format clean, 33 unit + 9 e2e tests, build OK, prod deps 0 vulnerabilities; Flutter analyze clean, 32 tests, iOS simulator build + launch OK; code and security reviews PASS WITH FINDINGS (fixed or recorded GI-9…GI-12). Not confirmed at approval: Android build (GI-6) and DB migration run against the local databases (GI-13). Deviations (a)–(f) in the M3 spec change log accepted with the approval.

## Earlier milestones
- M2 Global Domain Model: COMPLETED 2026-10-06 (committed `658d59d`).
- M1 Global Architecture: COMPLETED 2026-10-06 (committed `1c21c35`).
