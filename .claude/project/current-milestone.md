# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M11** |
| Milestone name | Budget Management |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M11-budget-management.md` (status: CONFIRMED 2026-10-08) |
| Started date | 2026-10-08 |
| Completed date | — |
| Approval status | Awaiting `APPROVE MILESTONE M11` (set IN_REVIEW 2026-10-08) |

## Objective
Per-event budget planning in exact rupees: total, planned amount per vendor category, unplanned remainder, over-plan warning; committed/paid columns ready for M15/M16 (Option A, confirmed by the user); plus the user's own expenses (answer 5, design A confirmed). Notes/diary deferred (B2).

## Completed work / In-progress work / Blocked work
- **Done (Option A core):**
  - Migration `1791700000000-VendorCategoriesAndBudget` (applied by the user): `vendor_categories` + 12-category idempotent seed; `budget_allocations` (numeric(12,2), partial unique index, soft delete).
  - Backend: public `GET /vendor-categories` (rate limited, cached 5 min); `budget` module GET/PUT/DELETE, owner-only, PLANNING-only writes, currency check, audited without amounts, archived-category plan lines.
  - User App: event Budget tab, standalone budget page, Menu → Budget picker, Home Budget overview; money sheet with exact rupee input; total editable from the budget screen.
  - Review fixes: confirmation before clearing a plan or removing the total; archived lines (remove only); stale banner and retry gating on the Budget tab; newest-request-wins guard; reload after a conflict on the total; semantics labels; clearer copy.
- **Own expenses (answer 5, design A confirmed "yes, B2 later"):**
  - Migration `1791800000000-EventExpenses` — **not yet applied to the dev DB: the user runs `npm run migration:run`** (the test DB is migrated by the e2e harness).
  - Backend: `GET/POST /events/{id}/expenses`, `PATCH/DELETE /events/{id}/expenses/{expenseId}` (owner-only, PLANNING-only writes, Idempotency-Key, version → 412, 500/event, audited without amounts/text); budget gains `expenses`, `spent`, per-category `expenses`; `remaining` = total − committed − expenses (negative when over).
  - App: "My expenses" section (add/edit sheet with exact amount, date, optional category, note; delete with confirmation; own loading/empty/error/stale states), "My expenses" and "Left to spend" / over-total warning in the summary, per-category "My expenses", Home "Spent so far".
- Notes/diary: deferred by the user (B2) — GI-31.

## Tests completed
- Backend: unit 69/69, e2e 68/68 (budget/expenses 14 e2e: sums, archived, seed idempotency, money validation, ownership, read-only, expenses add/list/sum, edit/version/soft delete/audit without amounts, negative remaining, input validation incl. null PATCH fields, idempotent replay, owner-only/read-only); lint, typecheck and build clean.
- User App: `flutter analyze` clean; `flutter test` 202/202 (budget/expense model incl. negative remaining, expense form idempotency-key reuse; screens: plan, over-plan, invalid input, clear confirmation, archived line, stale banner, add expense with validation and category, edit + delete with confirmation, over-total warning, expense load retry, read-only, Menu, Home incl. spent, 200 % text with a long expense).
- Not verified: signed-in run on the simulator (Firebase sign-in is the user's step).

## Reviews
| Review | Status |
|---|---|
| Security review | Done (ownership 404 incl. expenses, PLANNING-only writes, rate limits, Idempotency-Key, audit without amounts or user text) |
| Payment/money review | Done (exact decimals both ends; budget ≠ payments) |
| Performance review | Done (one budget query set per event; categories cached). Note for M42: add an index on `budget_allocations(category_id)` before admin archives categories at scale |
| UI review | Done (fixes applied) |
| Code review | Done (fixes applied). Deviation recorded: Home "Open budget" opens the standalone budget page rather than switching to the event's tab |
| Notification review | Done — owner's own changes (plans, expenses), no notification |
| Documentation | Done (spec change log, api-contracts, database-schema, domain-model A1 superseded, payment-architecture, notification-matrix, flutter.md, known-issues GI-31/GI-32) |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-30.
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21. A1 superseded (own expenses). New: GI-31 (notes/diary deferred), GI-32 (avoid double-counting with M16 payment notes).

## Files changed
- database: `database/migrations/1791700000000-VendorCategoriesAndBudget.ts`, `database/migrations/1791800000000-EventExpenses.ts`
- backend: `src/modules/categories/*`, `src/modules/budget/*` (incl. `event-expense.entity.ts`, `expenses.{dto,service,controller}.ts`), `src/app.module.ts`, `test/budget.e2e-spec.ts`, `test/db-harness.ts`, `test/auth.e2e-spec.ts`, `test/events.e2e-spec.ts`
- user_app: `lib/features/budget/**`, `lib/features/events/presentation/{controllers/planning_event_picker_controller.dart,views/planning_event_picker_view.dart,views/event_detail_view.dart}`, `lib/features/home/{data/budget_overview_source.dart,data/empty_section_source.dart,presentation/views/home_tab_view.dart}`, `lib/features/menu/presentation/views/menu_tab_view.dart`, `lib/features/shell/presentation/bindings/shell_binding.dart`, `lib/features/checklist/presentation/views/checklist_view.dart` (picker moved out; copy), `lib/core/widgets/async_state_view.dart` (StaleBanner made public); removed `checklist_picker_{controller,view}.dart` (replaced by the generic picker); tests under `test/features/{budget,checklist,events,shell}` and `test/helpers/fake_budget_repository.dart`
- docs: api-contracts, database-schema, domain-model, notification-matrix, payment-architecture, known-issues, architecture/flutter.md, milestones.md, M11 spec, current-milestone, progress

## Files pending approval
- M10 files are uncommitted; the user commits personally.

## Next milestone
- M12 — Vendor Discovery (spec drafted at the M11 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M10 Event Details: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M10` issued by the user |
| Spec | `milestones/M10-event-details.md` (CONFIRMED) |

Evidence at approval: media module with ImageKit upload API v2 (single-use signed settings) and server-side verification; event cover set/remove with signed, resized, metadata-free URLs; tabbed event screen (Overview/Checklist/Budget/Vendors) with cover photo flow, Open in Maps, Share; backend 63 unit + 54 e2e, Flutter 178 tests; ImageKit verified live; security, UI and code reviews PASS WITH FINDINGS (fixed; GI-30 logged). Not verified: real in-app cover upload (simulator signed out).

## Earlier milestone — M9 Checklist: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-07 |
| Completed / approved | 2026-10-07 — `APPROVE MILESTONE M9` issued by the user |
| Spec | `milestones/M9-checklist.md` (CONFIRMED) |

Evidence at approval: `checklist_items` migration (applied by the user); backend checklist module + checklist summary on events; User App checklist screen (tick with undo, reorder with accessible alternative, add/edit sheet, read-only for non-planning events), event page/card progress, Home Checklist progress, Menu → Checklist picker; backend 57 unit + 43 e2e, Flutter 167 tests; code, security and UI reviews PASS WITH FINDINGS (fixed; GI-27, GI-29 logged). Not verified: signed-in flows on the simulator (simulator signed out).

## Earlier milestone — M8 Event Management: COMPLETED

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
