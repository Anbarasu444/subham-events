# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M7** |
| Milestone name | Home Dashboard |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M7-home-dashboard.md` (status: CONFIRMED 2026-10-07) |
| Started date | 2026-10-07 |
| Completed date | — |
| Approval status | **Awaiting `APPROVE MILESTONE M7`** |

## Objective
Home tab dashboard. Option A (user decision): dashboard framework with four sections and empty states now; sections filled by M8–M12.

## Completed work
- Home tab dashboard (`features/home`): greeting (time of day, first name when signed in, refreshed on reload/app resume), "Create your first event" call to action (guest → sign-in returning to My Events; signed in → My Events tab), four section cards with honest empty states; Explore card action → Explore tab.
- Section framework: `DashboardSectionSource` contract, `HomeController` with independent per-section loading, generation counter (older results dropped), sign-in-only sections not loaded for guests, refresh keeps shown state (no skeleton flash), crashes reported to `CrashReporter` and shown as inline error with "Try again", reload only on sign-in/sign-out change, pull-to-refresh.
- `DashboardSectionCard`: heading title, skeleton / empty (+ action) / error-retry / content, debug assert for content without a builder; per-card `Obx` rebuild scope.

## In-progress work
- None.

## Blocked work
- None.

## Tests completed
- `flutter analyze`: no issues; `dart format`: clean; `flutter test`: **112 passed** (16 new M7 tests: greeting, independent sections, sign-in/out reload (no reload on profile update), guest skip-load, out-of-order loads, refresh without skeleton flash, crash reported; screen: four sections, guest copy, headings + signed-in copy, guest CTA → sign-in with returnTo, signed-in CTA → My Events, pull-to-refresh, Explore action, failing section retry, 200 % text on 320×568 scrolled to the end).
- iOS simulator (iPhone 16, staging, guest): dashboard light + dark, Explore card fully visible above the bar, card action → Explore tab (Home scroll kept), CTA → sign-in.

## Acceptance criteria evidence
| AC | Evidence |
|---|---|
| AC-1 | Screen tests + simulator screenshots |
| AC-2 | Controller + widget tests (failing section shows retry, others render) |
| AC-3 | Pull-to-refresh widget test; sign-in/sign-out controller test |
| AC-4 | CTA / Explore action widget tests; simulator |
| AC-5 | 200 % test, heading semantics test, dark-mode simulator screenshot |
| AC-6 | analyze clean, 112 tests pass; only `user_app/` and `.claude/project/` changed |
| AC-7 | Reviews below; docs updated |

## Reviews
| Review | Status |
|---|---|
| Code review | PASS WITH FINDINGS — fixed: stale-load race, refresh flashing, swallowed exceptions, unused `requiresSignIn`, rebuild scope, session reload noise, unique ids, missing tests |
| UI/UX review | PASS WITH FINDINGS — fixed: error text style, skeleton flash, stale greeting, content assert, signed-in empty copy no longer promises event creation |
| Performance review | Done (in reviews): per-card `Obx`, static skeleton, fixed small list (no builder needed), `AnimatedSize` only on state change |
| Security review | N/A beyond guest gating — guests make no calls for sign-in-only sections; no backend change |
| Notification review | N/A (no state changes) |
| Documentation | Done — `architecture/flutter.md` §6a, spec, progress |

## Known issues
- "Create your first event" (user-requested label) leads signed-in users to My Events, which says event creation is coming soon until M8. M8 makes it real and should switch to "Create event" once the user has events.
- Simulator taps occasionally drop the first tap after idle (tool behaviour, seen on M6 bar too; not reproducible in widget tests).
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-26.
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21. Assumptions A1–A12, O1, O2 per `domain-model.md` §9.

## Files changed
- New: `user_app/lib/features/home/domain/dashboard_section.dart`, `user_app/lib/features/home/data/empty_section_source.dart`, `user_app/lib/features/home/presentation/controllers/home_controller.dart`, `user_app/lib/features/home/presentation/widgets/dashboard_section_card.dart`, `user_app/test/features/home/home_dashboard_test.dart`
- Modified: `user_app/lib/features/home/presentation/views/home_tab_view.dart`, `user_app/lib/features/shell/presentation/bindings/shell_binding.dart`, `user_app/test/features/shell/shell_test.dart`
- Docs: `.claude/project/{current-milestone,progress,milestones}.md`, `.claude/project/milestones/M7-home-dashboard.md`, `.claude/project/architecture/flutter.md`
- No backend, database, Firebase, vendor_app or admin_cms changes.

## Files pending approval
- All M7 files are uncommitted; the user commits personally.

## Next milestone
- M8 — Event Management (spec drafted at the M7 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M6 Main Navigation: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M6` issued by the user |
| Spec | `milestones/M6-main-navigation.md` (CONFIRMED) |

Evidence at approval: shell with Home, Explore, My Events, Menu; nested per-tab navigation, lazy tabs, guest gating with sign-in return, Menu sections with Coming-soon pages, forced sign-out reason shown, tabs reset on sign-out; 96 Flutter tests; iOS simulator checks; UI + code reviews PASS WITH FINDINGS (fixed). Android back-button device check optional (not run).

## Earlier milestones
- M5 Authentication: COMPLETED 2026-10-07 (uncommitted).
- M4 Splash & App Bootstrap: COMPLETED 2026-10-06 (committed `d7565c3`).
- M3 User App Foundation: COMPLETED 2026-10-06 (committed `e78060f`).
- M2 Global Domain Model: COMPLETED 2026-10-06 (committed `658d59d`).
- M1 Global Architecture: COMPLETED 2026-10-06 (committed `1c21c35`).
