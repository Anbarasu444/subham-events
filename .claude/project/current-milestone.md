# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M13** |
| Milestone name | Vendor Details |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M13-vendor-details.md` (status: CONFIRMED 2026-10-08) |
| Started date | 2026-10-08 |
| Completed date | — |
| Approval status | Awaiting `APPROVE MILESTONE M13` (set IN_REVIEW 2026-10-08) |

## Objective
Tapping a vendor card opens a details page: listing, vendor (contact for signed-in users, A10), more from the vendor and similar vendors; guests allowed.

## Completed work / In-progress work / Blocked work
- **Backend:** `@OptionalAuth()` guard mode (guest without a token; signed-in user identified; unregistered token → guest; bad token → 401); `GET /listings/{id}` (visible only, else 404; vendor profile; contact only for signed-in users; no private fields) and `GET /listings/{id}/related` (same vendor / similar by category + city or service area, 6 each). No schema change.
- **User App:** listing details page (category-icon header, title, vendor, "Starting from" with "final price is agreed with the vendor" note, place and service areas, description, About the vendor, tap-to-call / tap-to-email for signed-in users, "Sign in to see contact details" for guests, Share as text, More from this vendor, Similar vendors, refresh, stale/error/retry and "no longer listed" states); every vendor card (Explore, Home, related lists) opens it; the M12 "coming soon" note is gone. `ExternalActions` gains `call`/`email`; Android `tel`/`mailto` queries.
- Nothing blocked.

## Tests completed
- Backend: unit 72/72 (incl. `@OptionalAuth` guard cases), e2e 82/82 (incl. 4 details tests: guest vs signed-in vs unregistered vs expired-token contact, no private fields, 404 for draft/suspended/unknown/malformed/archived-category, related same-vendor and similar by city/service area); lint and typecheck clean.
- User App: `flutter analyze` clean; `flutter test` 228/228 (detail JSON with/without contact, share text; screens: signed-in call/email hand-off, guest sign-in prompt → sign-in route, related lists open details, share, no-longer-listed, failed load keeps preview + retry, 200 % text; Explore card tap opens details).
- Not verified: real dialer/mail app on a device (only fakes in tests); signed-in run on the simulator/device.

## Reviews
| Review | Status |
|---|---|
| Security / privacy review | Done — contact only with a verified registered user; invalid tokens rejected (no silent downgrade); same visibility rule as discovery; malformed ids 404; private vendor fields never selected; rate limited. Residual: signed-in users can still collect numbers (rate limit only) |
| Performance review | Done — one query for details, one per related list (6 rows, partial indexes); the tapped card renders immediately; no images before M28 |
| UI review | Done — clear hierarchy, honest price note, guest prompt, external-app failure message, states, 200 % text |
| Code review | Done (self-review; fixes applied during testing) |
| Notification review | Done — no notification (no state change) |
| Documentation | Done (api-contracts incl. optional auth, domain-model A10, notification-matrix, flutter.md, spec, progress) |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-33.
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21. A10 answered (signed-in users only).

## Files changed
- backend: `src/modules/auth/{auth.decorators.ts,auth.guard.ts,auth.guard.spec.ts}`, `src/modules/listings/{listings.dto.ts,listings.repository.ts,listings.service.ts,listings.controller.ts}`, `test/listings.e2e-spec.ts`
- user_app: `lib/features/explore/{domain/listing.dart,data/discovery_repository_impl.dart,presentation/controllers/listing_detail_controller.dart,presentation/views/listing_detail_view.dart,presentation/widgets/listing_card_tile.dart}`, `lib/core/platform/external_actions.dart`, `android/app/src/main/AndroidManifest.xml`; tests `test/features/explore/{listing_detail_test.dart,explore_test.dart}`, `test/helpers/{fake_discovery_repository.dart,fake_media.dart}`
- docs: api-contracts, domain-model, notification-matrix, architecture/flutter.md, M13 spec, milestones.md, current-milestone, progress

## Files pending approval
- M11, M12 and M13 files are uncommitted; the user commits personally.

## Next milestone
- M14 — Wishlist / Contact / Enquiry (spec drafted at the M13 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M12 Vendor Discovery: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M12` issued by the user |
| Spec | `milestones/M12-vendor-discovery.md` (CONFIRMED) |

Evidence at approval: `vendors` / `vendor_listings` schema (O2 city + service areas), dev/test-only sample seed, public `GET /listings` (visibility rule, filters, sorts, bound cursors) and `GET /listings/cities`; Explore tab and Home "Explore vendors"; backend 71 unit + 78 e2e, Flutter 219 tests; reviews done. Not verified: signed-in simulator/device run; query plans at real catalogue size (GI-33). Dev DB migration `1791900000000-VendorsAndListings` (and optional sample seed) to be run by the user.

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
