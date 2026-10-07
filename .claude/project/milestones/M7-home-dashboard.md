# M7 — Home Dashboard

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M7` on 2026-10-07 (Option A) |
| Phase | User App |
| Depends on | M6 COMPLETED and approved (`APPROVE MILESTONE M6`) |
| Primary owner agent | user-app-manager (ui-manager, performance-manager, code-reviewer reviewers) |

## Dependency note (read first)
The roadmap places the Home Dashboard **before** the features it summarises: events (M8), checklist (M9), event details (M10), budget (M11) and vendors (M12). Building real summaries now would mean inventing data and endpoints for later milestones (forbidden by CLAUDE.md Rule 7). This spec therefore proposes **Option A** (open question 1):

- **Option A — dashboard framework now (recommended):** M7 builds the Home tab's layout, sections, loading/empty/error handling and personalised greeting, with each section showing a purposeful empty state and a call to action. Each later milestone (M8, M9, M11, M12, M17) fills its own section using the framework, as part of its own scope.
- **Option B — move M7 after M11:** reorder the roadmap so the dashboard is built when there is data to show. Requires the user to change the roadmap order (CLAUDE.md §10).

## Objective (Option A)
The Home tab becomes a scrollable dashboard: a greeting, a primary "Create your first event" call to action, and section slots (Upcoming event, Checklist progress, Budget overview, Explore vendors) that later milestones plug their data into — with consistent loading, empty, error/retry and offline behaviour, for guests and signed-in users.

## In scope (Option A)
1. **Dashboard layout** in the Home tab: app bar, greeting header (time-of-day greeting + display name when signed in; generic welcome for guests), pull-to-refresh, sections in a lazily built list.
2. **Section framework**: a `DashboardSection` contract (title, optional "See all" action, async state, empty state, error/retry) and a `HomeController` that loads sections independently so one failing section never blanks the page.
3. **Initial sections**, each with an honest empty state and action (no fake data):
   - Upcoming event — "Plan your first event" → My Events tab (guests: sign-in prompt).
   - Checklist progress — "Your checklist will appear once you create an event."
   - Budget overview — same pattern.
   - Explore vendors — "Find vendors for your event" → Explore tab.
4. **Guest vs signed-in** behaviour for every section; reacts to sign-in/sign-out without restarting.
5. **Accessibility & performance**: 200 % text, screen-reader headings per section, lazy building, no animations beyond standard transitions.
6. **Tests**: HomeController (independent section states, refresh), widget tests (guest/signed-in, empty states, section error isolation, pull-to-refresh), text scaling.
7. **Docs**: flutter.md (dashboard section framework), current-milestone, progress.

## Out of scope
- Any real event/checklist/budget/vendor data, endpoints or tables (M8+)
- Notifications/badges (M18), promotional banners/CMS content (M51)
- Backend changes (none expected under Option A)

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app | Home dashboard framework and empty sections | 1–6 |
| backend / database / Firebase / API | None | — |
| Notifications | None | — |

## Acceptance criteria (Option A)
- [x] AC-1 Home shows a greeting (name when signed in), the primary call to action and four sections with purposeful empty states for guests and signed-in users.
- [x] AC-2 Each section loads independently; a failure in one section shows an inline error with retry while the others still render (tests).
- [x] AC-3 Pull-to-refresh reloads all sections; sign-in/sign-out updates the dashboard without restart (tests).
- [x] AC-4 Calls to action open the right tab (My Events / Explore) or the sign-in flow for guests (tests).
- [x] AC-5 200 % text without overflow; section titles are headings; light/dark correct.
- [x] AC-6 `flutter analyze` clean, all tests pass; only `user_app/` and `.claude/project/` changed.
- [x] AC-7 UI/UX, performance and code reviews done; docs updated; IN_REVIEW.

## Required reviews
UI/UX (layout, copy, empty states), performance (lazy sections, rebuild scope), code review. Security/notification: N/A beyond guest gating.

## Risks and assumptions
- Option A produces a dashboard that looks sparse until M8–M12 land; mitigated by clear calls to action.
- Section list may change as features are specified; the framework keeps sections independent.

## Open questions (answer before or at START)
1. ~~Option A or B~~ — **answered: Option A** (framework now; sections filled by M8–M12).
2. Extra sections — not requested; the four sections above are built.

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-07 | Initial DRAFT created at the M6 approval gate | CLAUDE.md Rule 4 |
| 2026-10-07 | User chose Option A; no extra sections | User |
| 2026-10-07 | CONFIRMED by `START MILESTONE M7` | User |
| 2026-10-07 | Implementation decision (low risk, recorded): sign-in-only sections are not loaded for guests; dashboard keeps the "Create your first event" label requested by the user (M8 should switch it to "Create event" once events exist) | Claude (CLAUDE.md §31) |
| 2026-10-07 | Set IN_REVIEW | Claude |
