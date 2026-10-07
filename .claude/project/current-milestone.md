# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M9** |
| Milestone name | Checklist |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M9-checklist.md` (status: CONFIRMED 2026-10-07) |
| Started date | 2026-10-07 |
| Completed date | — |
| Approval status | **Awaiting `APPROVE MILESTONE M9`** |

## Objective
Per-event checklist the user writes themselves (R8): add, edit, tick, reorder, delete, due dates and overdue highlighting; progress on the event, cards and Home. Backend `checklist` module + `checklist_items` migration (Rule 7).

## Completed work
- Database: migration `1791500000000-ChecklistItems` (applied by the user to the dev database 2026-10-07).
- Backend: `checklist` module:
  - list with summary
  - idempotent add (max 200 tasks)
  - edit with version check
  - complete/reopen
  - reorder (full set, versions untouched)
  - soft delete
  - access always through the user's own, non-deleted event
  - read only unless the event is PLANNING
  - overdue computed in the event's time zone
  - audit for every change
  - write rate limit

  `EventDto` gains a `checklist` summary `{ total, done, overdue }`: one aggregate query per list page, read inside write transactions. New error code `LIMIT_REACHED`.
- User App: checklist screen:
  - progress header and read-only banner
  - To do / Done sections
  - tick with Undo
  - drag to reorder, with Move up/down menu and screen-reader actions
  - add/edit bottom sheet
  - delete with confirmation
  - overdue styling
  - instant updates with per-task rollback

  It is reached from the event page's checklist card, from task counts on event cards, from Home "Checklist progress" (next event's progress plus up to three urgent tasks) and from Menu → Checklist (picker; opens directly when there is only one event). Checklist changes refresh event screens once per burst.

## In-progress work
- None.

## Not verified
- Signed-in checklist flows on the iOS simulator against the real backend were **not** run: the simulator is signed out and signing in is the user's step (Firebase). Covered by 20 backend e2e checklist/event tests on PostgreSQL and the Flutter controller/widget tests. Live backend: migration applied, checklist route returns 401 without a token.

## Tests completed
- Backend: lint, typecheck, build, Prettier clean; 57 unit tests; 43 e2e tests on PostgreSQL. The 14 checklist tests cover:
  - order, overdue and summary on events
  - complete/reopen
  - edit with version check
  - validation
  - reorder
  - soft delete
  - read-only events
  - another user / wrong event → 404
  - 200 limit
  - audit
  - idempotent replay and reused key
  - overdue by event time zone (Pago Pago vs Kiritimati)
  - blank notes
- Flutter: analyze and format clean, 167 tests. These cover the checklist model, the controller (optimistic tick, per-task rollback with overlapping ticks, reorder guard, delete rollback, errors), the form controller, the Home source, and the screens (add + tick + undo, overdue + move + delete, read only, Menu picker with 1 or several events and with none, Home card, 200 % text).

## Reviews
| Review | Status |
|---|---|
| Code review | PASS WITH FINDINGS — fixed: summary read inside the write transaction; per-task rollback; refresh bursts coalesced and stale event-page loads ignored; picker opens once; reorder 422 reloads; added e2e (replay, ownership on every write, wrong event, time-zone overdue); blank notes → null |
| Security review | PASS WITH FINDINGS — fixed: summary in transaction; logged: per-user limits and soft-delete growth (GI-27), idempotency response bodies keep text 24 h (GI-29) |
| UI/UX + performance review | PASS WITH FINDINGS — fixed: 200 % app bar, 48 dp drag handle + screen-reader move actions, dragged-row surface, keyboard Done saves, "task" wording, Undo failure feedback, no overlapping reorder, picker semantics; accepted: rebuild scope at ≤ 200 tasks |
| Notification review | Done — no notification for owner changes; N16 deferred to M17/M18 (user decision) |
| Documentation | Done — api-contracts Part B (checklist), database-schema Part B, flutter.md §6c, notification-matrix, known-issues GI-27/GI-29, spec change log |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-29.
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21.

## Files changed
- Database: `database/migrations/1791500000000-ChecklistItems.ts`
- Backend: `src/modules/checklist/*` (entity, dto + spec, summary service, service, controller, module), `src/modules/events/{events.dto.ts,events.service.ts,events.module.ts}`, `src/common/errors/error-codes.ts`, `test/db-harness.ts`, `test/checklist.e2e-spec.ts`, `test/auth.e2e-spec.ts`, `test/events.e2e-spec.ts`
- User App: `lib/features/checklist/**`, `lib/features/events/{domain,data,presentation}/**` (summary, `notifyChanged` with debounce, status filter, checklist card, card counts, detail reload), `lib/features/home/{data/checklist_progress_source.dart,data/empty_section_source.dart,presentation/views/home_tab_view.dart}`, `lib/features/menu/presentation/views/menu_tab_view.dart`, `lib/features/shell/presentation/bindings/shell_binding.dart`, `lib/core/network/api_client.dart` (PUT); tests under `test/features/checklist`, `test/features/events`, `test/features/shell`, `test/helpers`
- Docs: `.claude/project/{current-milestone,progress,milestones,api-contracts,database-schema,notification-matrix,known-issues}.md`, `architecture/flutter.md`, `milestones/M9-checklist.md`
- No vendor_app or admin_cms changes.

## Files pending approval
- M8 and M9 files are uncommitted; the user commits personally.

## Next milestone
- M10 — Event Details (spec drafted at the M9 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M8 Event Management: COMPLETED

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
