# M12 — Vendor Discovery

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M12` on 2026-10-08 (open questions answered the same day) |
| Phase | User App |
| Depends on | M11 COMPLETED and approved (`APPROVE MILESTONE M11`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager (security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Dependency note (read first)
Vendor discovery shows **approved listings of active vendors**. In the roadmap:
- vendors and their listings are created in the Vendor App (M26–M28),
- listing photos are added in M28,
- admins approve listings in the Admin CMS (M40+).

So when M12 runs, no real vendor data can exist yet. This is the same situation as M7 and M11. Options (open question 1):

- **Option A — build discovery now, try it with sample data (recommended).**
  - M12 creates the `vendors` and `vendor_listings` tables (database-schema.md Part C), the public read API and the discovery screens.
  - A **development-only sample data script** (clearly marked, never run in production) fills in a set of fake vendors so the screens can be tried.
  - Real vendors arrive through M26–M30.
- **Option B — screens with empty states only.** No tables yet; Explore says "Vendors are coming soon". Less to build now, but nothing can be tested end to end.
- **Option C — move M12 after the Vendor App.** This needs a roadmap change.

## Objective (Option A)
Users, including guests, can browse the marketplace:
- vendor categories,
- approved vendor listings filtered by category, city, price range and search text, with sorting and smooth paging,
- listing cards showing the vendor name, category, city and **starting price** (marketplace information only, never a budget figure).

The Explore tab and the Home "Explore vendors" section (an M7 placeholder) show it.

## In scope (Option A)
**Database (cross-layer, Rule 7)**
1. Migration for `vendors` (read side: business name, description, city, service areas per O2, status ACTIVE/SUSPENDED/DELETED; `user_id` link per Part C) and `vendor_listings` (category, title, description, `starting_price_amount numeric(12,2) ≥ 0`, city, service areas, status DRAFT…ARCHIVED, approval fields, `rating_count`/`rating_sum` = 0 until M20), with the Part C indexes (including the partial index on APPROVED listings by category and city).
2. `database/seeds/dev-sample-vendors.sql`: **development and test databases only** (the script refuses to run unless the database name ends in `_dev` or `_test`). It holds about 20 fake vendors and listings spread over categories and cities, all marked as samples.

**Backend (cross-layer, Rule 7)**
3. `GET /api/v1/listings`:
   - Public; guests allowed. Rate limited.
   - Returns APPROVED listings of ACTIVE vendors only.
   - Filters: `categoryId`, `city` (matches the listing city or its service areas), `minPrice`/`maxPrice` (exact decimals), `q` (title, vendor name, category name).
   - Sort: `relevance` (default), `newest`, `price_asc`, `price_desc`.
   - Cursor pagination bound to the filters (as in M8). Page size 20, maximum 50.
   - Card DTO: listing id, title, vendor id and business name, category, city, starting price (Money), rating summary (0 until M20), cover image `null` until M28.
4. `GET /api/v1/listings/cities`: public. The distinct cities of approved listings, to fill the city filter.

**User App**
5. **Explore tab**:
   - Category chips or grid.
   - A search field with debounce.
   - A filter sheet: city, price range, sort.
   - A results list with infinite scroll and pull to refresh.
   - Active filters shown as removable chips.
   - Loading skeletons and empty, error, retry and offline states. Works signed out (guest).
6. **Home "Explore vendors"** section: replaces the M7 placeholder with categories and a few listings near the next event's city. "See all" opens Explore.
7. Card tap: listing details are **M13**. In M12 a tap shows a short "Details are coming soon" note (open question 6).
8. Tests:
   - Backend unit and e2e: visibility (only APPROVED + ACTIVE), every filter and sort, exact price bounds, pagination stability, guest access, rate limit, input validation.
   - Flutter: controller, repository and widgets, including search debounce, filters, paging, empty and error states, guest mode and 200 % text.
9. Docs: api-contracts, database-schema, domain-model (O2 answer), flutter.md, current-milestone, progress.

## Out of scope
- Listing details page (M13); wishlist, contact and enquiry (M14); adding a vendor to an event (M14).
- Creating vendors and listings (Vendor App M26–M28), listing photos (M28), platform fees (M29), admin approval (M40+).
- Ratings and reviews (M20). Ranking by rating comes after M20.
- Map view and distance search; full-text or fuzzy search engines (revisit at M66 performance).
- vendor_app / admin_cms (phase-locked).

## Deliverables
Migration; dev-only sample seed script; `vendors` and `listings` read modules with endpoints; Explore tab and Home section; tests; docs.

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app | Explore tab, Home "Explore vendors" section | 5–7 |
| backend | Public listings search and cities endpoints (read only) | 3–4 |
| database | `vendors`, `vendor_listings` tables; dev-only sample seed | 1–2 |
| Firebase | None | — |
| API contracts | Listings search and cities | 9 |
| Notifications | Evaluated: browsing changes no state, so no notification | 9 |

## Acceptance criteria (Option A)
- [x] AC-1 Explore lists only APPROVED listings of ACTIVE vendors. Draft, in-review, rejected, suspended or archived listings never appear, and neither do listings of suspended or deleted vendors (tested).
- [x] AC-2 Category, city, price range and search filters, plus all sorts, work and combine correctly. Prices are exact decimals end to end. Paging never repeats or skips a listing.
- [x] AC-3 Guests can browse without signing in, and signed-in users see the same results.
- [x] AC-4 Starting prices are labelled as "Starting from" and never appear in budget figures.
- [x] AC-5 Explore and the Home section handle loading, empty, error, retry and offline states, and render at 200 % text on a small phone.
- [x] AC-6 Migrations apply. The sample seed runs only on `_dev`/`_test` databases and is idempotent. Backend and Flutter checks and tests pass.
- [x] AC-7 Security, performance (query plans use the indexes; list paging is smooth), UI and code reviews are done, the docs are updated, and the status is IN_REVIEW.

## Required reviews
- Security: public endpoint hardening (rate limit, input bounds, no private vendor fields such as the owner user id or a vendor's unapproved changes).
- Performance: EXPLAIN on the main queries, page size, image placeholders, list rebuilds.
- UI: search, filters and empty states; guest flow.
- Notification: none.
- Code review.

## Risks and assumptions
- Sample data must never reach production: a guarded script, a clear "sample" marker, and documented in the README and database-schema.
- Simple `ILIKE` search is enough for the early catalogue size. A trigram index or a search engine can come later (M66).
- Vendor contact details (A10) are shown on the details page (M13), not on cards.

## Open questions (answered 2026-10-08 — see change log)
1. **Approach:** Option A (build now and try it with dev-only sample data; recommended), B (empty states only), or C (move M12 after the Vendor App)?
2. **O2 vendor location:** proposed: each listing has a **city** plus a list of **service areas** (other cities or localities it serves), and the city filter matches either. OK?
3. **Default city:** proposed: Explore starts filtered to the city of your next planning event (if any), and you can change or clear it. OK?
4. **Search and sort:** proposed: search in listing title, vendor name and category name; sorts are Relevance, Newest, Price low→high and Price high→low (rating sort after M20). OK?
5. **Sample data:** OK to add a dev-only sample script with about 20 fake vendors? Listing images: plain category icons until M28, or will you give temporary image URLs (your M7 answer 2)?
6. **Card tap before M13:** show a "Details are coming soon" note (proposed), or make cards not tappable until M13?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-08 | Initial DRAFT created at the M11 approval gate | CLAUDE.md Rule 4 |
| 2026-10-08 | User answers: 1 **Option A**; 2 O2 = city + service areas (OK); 3 default city = next planning event's city (OK); 4 search title/vendor/category with Relevance/Newest/Price sorts (OK); 5 "recommended" → dev/test-only sample script (~20 fake vendors) with **category icons** as listing images until M28 (recorded as the reading of "recommended"; temporary URLs can still be supplied later); 6 "recommended" → card tap shows "Details are coming soon" until M13 | User |
| 2026-10-08 | CONFIRMED by `START MILESTONE M12` | User |
