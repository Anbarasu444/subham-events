# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M6** |
| Milestone name | Main Navigation |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M6-main-navigation.md` (status: CONFIRMED 2026-10-07) |
| Started date | 2026-10-07 |
| Completed date | — |
| Approval status | Awaiting `APPROVE MILESTONE M6` (optional: Android back-button check on a device/emulator) |

## Objective
Permanent bottom-navigation shell (Home, Explore, My Events, Menu) with per-tab navigation, state preservation and guest gating; replaces the temporary home placeholder.

## Completed work (acceptance-criteria evidence)
| AC | Evidence | Status |
|---|---|---|
| AC-1 | App starts on the shell (Home tab) — iOS simulator screenshot; home placeholder and old account screen removed | Done |
| AC-2 | Widget tests: lazy tab build, state kept when switching, re-select returns to root | Done |
| AC-3 | Widget tests: pages inside a tab keep the bar; system back (`handlePopRoute`) pops inside the tab, then goes Home, then exits; verified on iOS simulator (Settings page inside Menu keeps the bar). **Android device/emulator back check: not run by Claude (no emulator available)** | Done (Android manual check optional) |
| AC-4 | Guest My Events prompt (simulator + test); sign-in return reopens the shell on the requested tab (`offAllNamed('/?tab=events')` test); returnTo allow-list tests | Done |
| AC-5 | Menu: signed-in header, sections Planning (Schedule, Checklist, Budget, Messages) and Account (My profile, Settings, Help), Sign out; guests see Settings/Help + Sign in; pending-profile state keeps signed-in menu with Try again + Sign out; Diagnostics staging only (tests); entries open "Coming soon" inside the tab | Done |
| AC-6 | 200 % text on 320×568 without overflow (test); section/empty-state titles marked as headings; tab labels without duplicate tooltips; light theme verified on simulator | Done |
| AC-7 | `flutter analyze` clean; 96 tests pass; only `user_app/` and `.claude/project/` changed | Done |
| AC-8 | UI and code reviews done; performance: lazy tabs, tickers off for hidden tabs; docs updated | Done |

## Reviews
| Review | Status | Notes |
|---|---|---|
| Code review | Done — PASS WITH FINDINGS | Fixed: forced sign-out reason shown again (Menu + My Events), pending-profile state in Menu, sign-in return test, system-back test, tab stacks reset on sign-out, tickers off for hidden tabs, guard middleware documented as kept for later. Tracked: move Menu sign-out logic into a controller in M21 |
| UI/UX review | Done — PASS WITH FINDINGS | Fixed: Menu grouped into Planning / Account, consistent chevrons, Menu icon, no duplicate tab tooltip, heading semantics, Home heading "Welcome" |
| Performance review | Done | Tabs built lazily and kept alive; hidden tabs' tickers disabled; Obx scope limited to shell/tab state |
| Security review | Done (inline) | Guest gating is UX only; no protected data fetched for guests; returnTo restricted to known shell routes |
| Notification review | N/A | — |
| Documentation | Done | flutter.md §6 (shell), spec change log, progress |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-25.
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21. Assumptions A1–A12, O1, O2 per `domain-model.md` §9.

## Files changed
- `user_app/lib/features/shell/**` (new), `features/{home,explore,events,menu}/presentation/views/*` (new tab screens, menu, coming soon), `core/widgets/{empty_state_view,session_message}.dart` (new), `app/routes/{app_routes,app_pages}.dart`, `app/startup/startup_router.dart`, `app/middlewares/auth_guard_middleware.dart` (doc), `features/auth/presentation/bindings/auth_bindings.dart`; removed `features/home/.../home_placeholder_view.dart`, `features/auth/.../account_view.dart`
- Tests: `test/features/shell/shell_test.dart` (new), `test/features/auth/otp_controller_test.dart`
- Also since M5 approval (M5 follow-ups found in the real sign-in check, already in M5 records): iOS `Info.plist` (deep linking off, bundle name), Android manifest (deep linking off), auth error-code debug logging
- `.claude/project/`: `architecture/flutter.md`, M6 spec, milestones, current-milestone, progress

## Files pending approval
- M5 and M6 files are uncommitted (last commit `d7565c3` = M4); the user commits personally.

## Next milestone
- M7 — Home Dashboard (spec drafted at the M6 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M5 Authentication: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-06 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M5` issued by the user |
| Spec | `milestones/M5-authentication.md` (CONFIRMED) |

Evidence at approval: backend 46 unit + 19 e2e (incl. 8 PostgreSQL) tests; Flutter 78 tests; iOS + Android staging/prod builds; real phone sign-in → My account → sign-out verified on the iOS simulator against the real backend, database and Firebase; code, security, UI reviews PASS WITH FINDINGS (fixed / recorded GI-18…GI-25). Google sign-in sheet verified; completing a Google login left optional.

## Earlier milestones
- M4 Splash & App Bootstrap: COMPLETED 2026-10-06 (committed `d7565c3`).
- M3 User App Foundation: COMPLETED 2026-10-06 (committed `e78060f`).
- M2 Global Domain Model: COMPLETED 2026-10-06 (committed `658d59d`).
- M1 Global Architecture: COMPLETED 2026-10-06 (committed `1c21c35`).
