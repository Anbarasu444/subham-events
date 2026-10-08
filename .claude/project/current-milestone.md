# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M12** |
| Milestone name | Vendor Discovery |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M12-vendor-discovery.md` (status: CONFIRMED 2026-10-08) |
| Started date | 2026-10-08 |
| Completed date | — |
| Approval status | Awaiting `APPROVE MILESTONE M12` (set IN_REVIEW 2026-10-08) |

## Objective
Users (including guests) browse approved vendor listings by category, city, price and search text; Explore tab and Home "Explore vendors" section (Option A, answered by the user).

## Completed work / In-progress work / Blocked work
- **Database:** migration `1791900000000-VendorsAndListings` (`vendors`, `vendor_listings` per Part C with O2 city + service areas, status checks, partial APPROVED indexes) — **the user runs `npm run migration:run` on the dev DB**; dev/test-only sample data `database/seeds/dev-sample-vendors.sql` (20 fake vendors, 18 visible) via `npm run seed:dev-samples`, guarded to `*_dev` / `*_test` databases.
- **Backend:** public `GET /listings` (visibility: APPROVED + ACTIVE vendor + PUBLISHED category; filters category, city/service area, exact price range, text; sorts relevance/newest/price; cursor bound to the search; 120/min) and `GET /listings/cities` (cached 5 min).
- **User App:** Explore tab (search with debounce, category chips, filter sheet with city/exact prices/sort, removable filter chips, infinite scroll, pull to refresh, skeleton/empty/error/stale states, guest browsing, "details coming soon" on tap), Home "Explore vendors" section (categories + listings near the next event's city, fallback to all; "See all vendors" opens Explore with the city).
- Nothing blocked.

## Tests completed
- Backend: unit 71/71 (incl. listing card mapping), e2e 78/78 (incl. 10 discovery tests: visibility, archived category, category/city/service-area filters ignoring case, exact price range and validation, search ranking and wildcard escaping, sorts, paging without repeats for every sort, cursor binding and input validation, cities, seed idempotency and the dev/test guard); lint, typecheck and build clean.
- User App: `flutter analyze` clean; `flutter test` 219/219 (explore model, controller: default city, guest, paging, debounce, stale refresh, load-more retry, Home preset; Home source fallback; screens: guest browse + coming-soon tap, category + search, filter sheet with price validation/city/sort and chip removal, empty → clear filters, error → retry, infinite scroll, Home → Explore with city, 200 % text on a small phone).
- Not verified: the signed-in app on the simulator (Firebase sign-in is the user's step); query plans at real catalogue size (only sample data exists).

## Reviews
| Review | Status |
|---|---|
| Security review | Done — public endpoints return no private vendor fields; inputs bounded (lengths, money pattern, limit ≤ 50, UUIDs), unknown params rejected, LIKE wildcards escaped, parameterised SQL, cursors validated and bound to the search, rate limited; sample data guarded to dev/test databases and unusable for sign-in |
| Performance review | Done — partial indexes for category/city, newest and price; page size 20 (max 50); categories/cities cached in memory 5 min and `max-age=300`; static skeletons; lazy slivers. GI-33: `ILIKE` search and service-area matching not index-backed (M66) |
| UI review | Done — loading/empty/error/stale/load-more states, removable filter chips, exact price input with validation, semantics merged per card, 200 % text checked |
| Code review | Done (self-review; fixes applied during testing) |
| Notification review | Done — read-only browsing, no notification |
| Documentation | Done (api-contracts, database-schema incl. seed, database README, domain-model visibility rule, notification-matrix, flutter.md §6f, known-issues GI-33, spec, progress) |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-33.
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21. O2 answered (city + service areas).
- Decision recorded: archiving a category hides its listings from discovery.

## Files changed
- database: `database/migrations/1791900000000-VendorsAndListings.ts`, `database/seeds/dev-sample-vendors.sql`, `database/README.md`
- backend: `src/modules/listings/*` (dto, repository, service + spec, controller, module), `src/database/seed-dev-samples.ts`, `package.json` (`seed:dev-samples` script), `src/app.module.ts`, `test/listings.e2e-spec.ts`, TRUNCATE lists in `test/db-harness.ts`, `test/auth.e2e-spec.ts`, `test/events.e2e-spec.ts`
- user_app: `lib/features/explore/**` (domain, data, controller, widgets, view), `lib/features/home/data/{explore_section_source.dart,empty_section_source.dart}`, `lib/features/home/presentation/views/home_tab_view.dart`, `lib/features/shell/presentation/bindings/shell_binding.dart`; tests `test/features/explore/explore_test.dart`, `test/helpers/fake_discovery_repository.dart`, wiring in budget/checklist/events/home/shell screen tests
- docs: api-contracts, database-schema, domain-model, notification-matrix, known-issues, architecture/flutter.md, M12 spec, milestones.md, current-milestone, progress

## Files pending approval
- M11 and M12 files are uncommitted; the user commits personally.

## Next milestone
- M13 — Vendor Details (spec drafted at the M12 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M11 Budget Management: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M11` issued by the user |
| Spec | `milestones/M11-budget-management.md` (CONFIRMED; scope extended with own expenses) |

Evidence at approval: vendor categories (12 seeded, public list); per-event budget (plan per category, total editable on the budget screen, unplanned and over-plan warning, committed/paid ready for M15/M16, archived-category lines); own expenses (add/edit/delete, counted as spent; remaining = total − committed − expenses); event Budget tab, standalone page, Menu → Budget, Home overview; backend 69 unit + 68 e2e, Flutter 202 tests; reviews done with fixes. Not verified: signed-in simulator run. Dev DB migration `1791800000000-EventExpenses` to be run by the user (confirm). Notes/diary deferred (GI-31); GI-32 for M16.

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
