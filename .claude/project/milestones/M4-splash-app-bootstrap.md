# M4 — Splash & App Bootstrap

| Field | Value |
|---|---|
| Spec status | **DRAFT** — becomes CONFIRMED when the user issues `START MILESTONE M4` |
| Phase | User App |
| Depends on | M3 COMPLETED and approved (`APPROVE MILESTONE M3`) |
| Primary owner agent | user-app-manager (ui-manager, security-manager, performance-manager reviewers) |

## Objective
The User App starts quickly and predictably: a branded native splash, an ordered bootstrap that initialises app services before the first screen, global error capture, runtime-protection (FreeRASP) in observe mode, real app version reporting, and a measured cold-start baseline. No sign-in (M5) and no navigation shell (M6).

## In scope
1. **Native splash** with `flutter_native_splash` (light/dark, Android 12+ splash API, iOS launch screen), preserved until bootstrap completes, then removed — no blank frame between native splash and first screen.
2. **Bootstrap sequence** (`app/bootstrap.dart`, architecture/flutter.md §9): ordered, timed steps with a single `BootstrapResult`; failures in non-critical steps are logged and do not block start-up; a fatal failure shows a branded "Couldn't start" screen with retry (no blank screen).
3. **App version** (GI-7): real version/build via `package_info_plus` (new dependency — approval at START) feeding `X-Client` and the diagnostics screen.
4. **Global error capture**: `FlutterError.onError`, `PlatformDispatcher.onError`, zone errors → a `CrashReporter` interface with a console implementation (Crashlytics implementation added in M5 when Firebase exists).
5. **FreeRASP** (`freerasp`) initialised in bootstrap in **observe/log-only mode** for staging and prod (reactions decided in M22); per-flavor config (package name, signing cert hash placeholder, iOS team ID placeholder) — no secrets.
6. **Initial route decision** hook: bootstrap decides the first route (today: home placeholder; M5 adds auth state; M6 the shell) — implemented as a small `StartupRouter` so later milestones extend rather than rewrite.
7. **Cold-start baseline**: measure time from process start to first frame (debug-off profile build) on the iOS simulator and an Android emulator/device; record in `progress.md` against the ≤ 2.5 s budget (architecture/quality.md §4).
8. **Tests**: bootstrap order and failure handling (unit), "Couldn't start" screen and splash removal (widget), StartupRouter (unit).
9. **Brand colour**: change the theme seed to **`#FF7E7E`** (user, 2026-10-06; replaces the M3 placeholder `#8E3B5F`), check light/dark contrast (text on primary ≥ 4.5:1, adjust tones if needed), and use it for the splash background. Logo: **text/icon placeholder** until branding exists (later change expected).

## Out of scope
- Firebase, Crashlytics, authentication, FCM (M5, M18)
- Navigation shell / bottom navigation (M6), onboarding screens
- FreeRASP blocking reactions (M22)
- ObjectBox (first milestone that caches structured data)
- Final package ID / release signing (GI-5, GI-11)

## Deliverables
Native splash assets/config, bootstrap pipeline, CrashReporter interface, FreeRASP observe-mode setup, version reporting, startup-failure screen, tests, cold-start baseline record.

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification (in-scope item #) |
|---|---|---|
| user_app | Splash, bootstrap, error capture, FreeRASP, version | 1–8 |
| backend | None (unless a client-version header check is required — not planned) | — |
| database | None | — |
| Firebase | None | — (M5) |
| API contracts | None | — |
| Notifications | None | — |

## Acceptance criteria
- [ ] AC-1 Cold start shows the native splash and goes straight to the first screen without a blank/white frame (light and dark mode), on iOS simulator and Android.
- [ ] AC-2 Bootstrap steps run in the documented order; a failing non-critical step is logged and start-up continues; a fatal failure shows the "Couldn't start" screen with a working retry (tests).
- [ ] AC-3 `X-Client` and diagnostics show the real version/build (no `0.0.0`); GI-7 resolved.
- [ ] AC-4 Uncaught Flutter, platform and zone errors reach `CrashReporter` (tests).
- [ ] AC-5 FreeRASP initialises in staging and prod without blocking start-up; threat callbacks are logged only.
- [ ] AC-6 Cold-start baseline measured and recorded; meets ≤ 2.5 s p90 on the reference setup or a remediation is documented.
- [ ] AC-7 `flutter analyze` clean, `dart format` clean, all tests pass; only `user_app/` and `.claude/project/` changed.
- [ ] AC-8 UI/UX, security and performance reviews done; docs updated; milestone set to IN_REVIEW.

## Required reviews
- UI/UX: splash visuals, start-failure screen, accessibility (text scaling, contrast).
- Security: FreeRASP configuration contains no secrets; error reports contain no PII.
- Performance: cold-start measurement, bootstrap step timings.
- Notification: N/A.

## Risks and assumptions
- Splash artwork: placeholder mark until a logo exists; brand colour `#FF7E7E`. Light coral backgrounds need care for white-text contrast.
- FreeRASP requires release signing hashes / Apple team ID for meaningful results; placeholders until GI-5/GI-11 are resolved.
- Android builds work on the user's Mac (GI-6 resolved); Claude's own Gradle downloads time out, so Android acceptance checks may need the user to run them.

## Open questions
1. ~~Artwork~~ — answered: no logo yet; use a placeholder; theme colour `#FF7E7E` for now (may change later).
2. ~~New packages~~ — answered: approved (`flutter_native_splash`, `package_info_plus`, `freerasp`).
3. ~~GI-6 / M3 AC-6~~ — answered: Android build and DB setup/migrations work on the user's Mac.

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-06 | Initial DRAFT created at the M3 approval gate | CLAUDE.md Rule 4 |
| 2026-10-06 | Open questions answered before START: placeholder logo, theme colour `#FF7E7E` (added as in-scope item 9), packages approved, Android build + DB setup confirmed working | User |
