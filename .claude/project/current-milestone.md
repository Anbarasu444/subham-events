# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M14** |
| Milestone name | Wishlist / Contact / Enquiry |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M14-wishlist-contact-enquiry.md` (status: CONFIRMED 2026-10-08) |
| Started date | 2026-10-08 |
| Completed date | — |
| Approval status | Awaiting `APPROVE MILESTONE M14` (set IN_REVIEW 2026-10-08) |

## Objective
Save listings (wishlist), add vendors to an event (event vendors), send and close enquiries (vendor replies come with the Vendor App); N9 in-app record for vendors (A9 fields only).

## Completed work / In-progress work / Blocked work
- **Database:** migration `1792000000000-WishlistEventVendorsEnquiries` (`wishlist_items`, `event_vendors`, `enquiries` with composite FK and partial unique indexes) — **the user runs `npm run migration:run` on the dev DB**.
- **Backend:** `wishlist` module (list/ids/save/remove, 500 max) and `listings?saved=true`; `event-vendors` module (list/add/notes/remove; enquiries send with Idempotency-Key, close); A12 own-listing block; N9 in-app notification with A9 fields only (`NotificationsService` gained optional `data`); event cancel/delete closes live enquiries; audit without private text.
- **User App:** heart on every vendor card and the details page (guests asked to sign in), Menu → Saved vendors, Explore "Saved" filter chip, "Add to event" on the details page (single event direct, chooser, Undo), event Vendors tab (status, private note, remove, send/close enquiry with honest copy), enquiry sheet (editable starter text, preferred date).
- Nothing blocked.

## Tests completed
- Backend: unit 72/72, e2e 95/95 (incl. 13 M14 tests: wishlist idempotency/order/ownership/paging/hidden/guest, saved filter; event vendors add-once/notes/412/remove/re-add, owner-only/visibility/read-only, A12, audit without notes; enquiries one-live/N9 content with A9 fields only/idempotent replay/428/validation/close and re-enquire/closing on remove and cancel/hidden listing); lint, typecheck and build clean.
- User App: `flutter analyze` clean; `flutter test` 242/242 (wishlist controller guest/optimistic/rollback, enquiry form starter text/validation/key reuse, vendor JSON; screens: heart save, guest prompts (heart, Saved chip, Add to event), Saved filter, Add to event, Vendors tab send/close/note/remove, read-only event, Menu → Saved vendors, 200 % text).
- Not verified: signed-in run on a simulator/device; vendor-side receipt (no Vendor App until M24+).

## Reviews
| Review | Status |
|---|---|
| Security / privacy review | Done — owner-only via the event, composite FKs for denormalised ids, A12 block, A9-only notification data (tested), private notes never audited or sent, enquiry spam limit 20/min + one live per vendor, Idempotency-Key on enquiries, saved filter requires sign-in |
| Performance review | Done — indexed lists (wishlist by user, event vendors by event, enquiries by event vendor); cards fetched in one query per page; heart state from one ids call per session |
| UI review | Done — optimistic hearts with rollback, confirmations for remove/close, honest reply copy (GI-34), privacy note in the enquiry sheet, all states, 200 % text |
| Code review | Done (self-review; a disposed-controller bug in the note dialog and an ids-load race were found by tests and fixed) |
| Notification review | Done — N9 in-app (push at M36); other actions none |
| Documentation | Done (api-contracts, database-schema, domain-model notes, notification-matrix, flutter.md §6g, known-issues GI-34, spec, progress) |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-34.
- Business rules on hold: R3 (**must be resolved before M15**), R6 (before M28/M29), R10 (before M26). R11 final policy by M21. A9 confirmed.

## Files changed
- database: `database/migrations/1792000000000-WishlistEventVendorsEnquiries.ts`
- backend: `src/modules/wishlist/*`, `src/modules/event-vendors/*`, `src/modules/listings/{listings.dto.ts,listings.repository.ts,listings.service.ts,listings.controller.ts,listings.module.ts}`, `src/modules/notifications/notifications.service.ts`, `src/modules/events/events.service.ts` (close enquiries on cancel/delete), `src/app.module.ts`, `test/event-vendors.e2e-spec.ts`, TRUNCATE lists in `test/{db-harness,auth.e2e-spec,events.e2e-spec}.ts`
- user_app: `lib/features/wishlist/**`, `lib/features/event_vendors/**`, `lib/features/explore/{domain/listing.dart,data/discovery_repository_impl.dart,presentation/controllers/explore_controller.dart,presentation/views/explore_tab_view.dart,presentation/views/listing_detail_view.dart,presentation/widgets/listing_card_tile.dart}`, `lib/features/events/presentation/views/event_detail_view.dart`, `lib/features/menu/presentation/views/menu_tab_view.dart`, `lib/features/shell/presentation/bindings/shell_binding.dart`; tests `test/features/engagement/engagement_test.dart`, `test/helpers/fake_event_vendors.dart`, wiring in budget/checklist/events screen tests
- docs: api-contracts, database-schema, domain-model, notification-matrix, known-issues, architecture/flutter.md, M14 spec, milestones.md, current-milestone, progress

## Files pending approval
- M14 files (and the M13-approval doc updates / M14 spec) are uncommitted; the user commits personally.

## Next milestone
- M15 — Quotations & Booking (spec drafted at the M14 gate; R3 must be resolved first).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M13 Vendor Details: COMPLETED

| Field | Value |
|---|---|
| Status | **COMPLETED** |
| Started | 2026-10-08 |
| Completed / approved | 2026-10-08 — `APPROVE MILESTONE M13` issued by the user |
| Spec | `milestones/M13-vendor-details.md` (CONFIRMED) |

Evidence at approval: `@OptionalAuth` guard mode; `GET /listings/{id}` (contact for signed-in users only, A10) and `/related`; listing details page with call/email/share, related lists and all states; backend 72 unit + 82 e2e, Flutter 228 tests; reviews done. Not verified: real dialer/mail hand-off and signed-in device run.

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
