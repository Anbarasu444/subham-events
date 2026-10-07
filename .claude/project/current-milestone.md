# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M8** |
| Milestone name | Event Management |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M8-event-management.md` (status: CONFIRMED 2026-10-07) |
| Started date | 2026-10-07 |
| Completed date | — |
| Approval status | **Awaiting `APPROVE MILESTONE M8`** |

## Objective
Signed-in users create, edit, cancel, reopen, complete and soft-delete events; My Events lists them; Home shows the next event. Backend `events` module + `event_types`/`events` migrations (Rule 7).

## Completed work
- Database: migration `1791400000000-Events` (`events`, `idempotency_keys`), applied by the user to the dev database 2026-10-07.
- Backend: `events` module (create with required idempotency key, cursor-paginated upcoming/past/all lists, get, PATCH with version check, cancel/reopen/complete, soft delete), ownership → 404, validation (free-text type, Region/City time zones known to PostgreSQL, exact money), write rate limits, audit for every change, hourly auto-complete job, idempotency service with replay/reuse/stuck-key handling, cursor helper.
- User App: events feature (repository with change stream, My Events Upcoming/Past with pagination and stale-on-failed-refresh, create/edit form with quick-fill types, pickers, rupee input, server field errors, scroll-to-error, discard guard, event page with complete/cancel/reopen/delete and confirmations); Home "Upcoming event" section shows the next event; button reads "Create your first event" or "Create event".

## In-progress work
- None.

## Not verified
- Signed-in event flows on the iOS simulator against the real backend were **not** run: signing in needs the user (Firebase), and the user asked to continue. Covered instead by 10 backend e2e tests on PostgreSQL and 30+ Flutter controller/widget tests. Simulator (guest): My Events sign-in prompt, Home guest state; live API returns 401 `AUTH_REQUIRED` without a token.

## Blocked work
- None.

## Tests completed
- Backend: lint, typecheck, build, Prettier clean; 55 unit tests; 29 e2e tests on PostgreSQL (10 events tests: create/money/audit, auth + idempotency key required, replay + key reuse, validation incl. time zones, ownership 404s, upcoming/past pagination + forged/foreign cursors, optimistic concurrency + changed-field audit, state machine, soft delete, auto-complete job).
- Live backend on the dev database (migration applied by the user): health ready, event routes mapped, unauthenticated request → 401.
- Flutter: analyze clean, format clean, 145 tests (events model/repository/controllers/screens, date and money input helpers, Home upcoming section, 200 % text).

## Reviews
| Review | Status |
|---|---|
| Code review | PASS WITH FINDINGS — fixed: tampered cursor 500 → 422, cursor bound to scope, stuck idempotency keys reclaimed, new key when form input changes, 412 documented, unit tests for cursor/stableStringify, time zones; accepted/documented: device-clock "today" (GI-28), `all` sort order |
| Security review | PASS WITH FINDINGS — fixed: time-zone validation (offset/POSIX/`Etc` rejected, PostgreSQL check), cursor validation, stuck keys; open: per-user write limit (GI-27), trust proxy (GI-10) |
| UI/UX + performance review | PASS WITH FINDINGS — fixed: failed refresh keeps list, no load-more retry loop, scroll to first error, card/picker semantics, per-action dialog labels, keyboard Done saves, no back during save, FAB hidden on empty list |
| Notification review | Done — no notification for M8 changes (notification-matrix "Evaluated with no notification") |
| Documentation | Done — api-contracts Part B (events), database-schema Part B, flutter.md §6b, domain-model §4.6, notification-matrix, known-issues GI-27/GI-28, spec change log |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-28.
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21.

## Files changed
- Database: `database/migrations/1791400000000-Events.ts`
- Backend: `src/common/pagination/cursor.ts` (+ spec), `src/modules/idempotency/*` (+ spec), `src/modules/events/*` (entity, rules + spec, dto, service, controller, auto-complete job, module), `src/app.module.ts`, `src/config/env.validation.ts`, `src/config/app-config.service.ts`, `.env.example`, `test/events.e2e-spec.ts`, `test/auth.e2e-spec.ts`, `test/jest-e2e.json`, `test/setup-env.ts`
- User App: `lib/core/network/api_client.dart`, `lib/core/money/money.dart`, `lib/core/utils/date_format.dart`, `lib/features/events/**`, `lib/features/home/{data,domain,presentation}/**`, `lib/features/shell/presentation/{bindings/shell_binding.dart,controllers/shell_controller.dart}`, tests under `test/features/events`, `test/core`, `test/helpers`, `test/features/home`, `test/features/shell`
- Docs: `.claude/project/{current-milestone,progress,milestones,api-contracts,database-schema,domain-model,notification-matrix,known-issues}.md`, `architecture/flutter.md`, `milestones/M8-event-management.md`
- No vendor_app or admin_cms changes.

## Files pending approval
- All M8 files are uncommitted; the user commits personally.

## Next milestone
- M9 — Checklist (spec drafted at the M8 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M7 Home Dashboard: COMPLETED

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
