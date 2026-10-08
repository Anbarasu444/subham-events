# M13 — Vendor Details

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M13` on 2026-10-08 (open questions answered the same day) |
| Phase | User App |
| Depends on | M12 COMPLETED and approved (`APPROVE MILESTONE M12`) |
| Primary owner agent | user-app-manager + backend-manager (security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Dependency note
The details page shows one approved listing and its vendor. Some of what it will eventually show comes later:
- listing photos and portfolio (M28),
- ratings and reviews (M20),
- saving, contacting and enquiring (M14).

M13 builds the page with honest placeholders for these, as M7/M11/M12 did, and is tried with the M12 sample vendors.

## Objective
Tapping a vendor card (Explore or Home) opens a details page that shows:
- the listing (title, category, description, "Starting from" price, city and service areas),
- the vendor (business name, about, city, and contact details per A10, open question 1),
- more listings from the same vendor and similar vendors (same category and city).

The page also loads, fails, refreshes and fits large text well. The "Vendor details are coming soon" note from M12 goes away.

## In scope
**Backend (cross-layer, Rule 7)**
1. `GET /api/v1/listings/{id}`:
   - Public; guests allowed. Rate limited.
   - Returns only a **visible** listing (APPROVED, ACTIVE vendor, PUBLISHED category). Anything else, or a malformed id → 404.
   - Response: the card fields plus `description`, `rating` summary (0 until M20), `photos: []` (until M28), and `vendor { id, businessName, description, city, serviceAreas, contact }`. `contact` follows open question 1. Never the owner user id, unapproved changes or other private fields.
2. `GET /api/v1/listings/{id}/related`: up to 6 other visible listings of the same vendor, and up to 6 similar visible listings (same category, matching city or service area, newest first). Public.
3. Read-only. No schema change is expected (uses M12 tables). If contact details need a column change, that is a migration listed here.

**User App**
4. **Listing details page** (pushed from Explore, Home and related cards):
   - A header with the category icon (photo placeholder until M28).
   - Title, category, "Starting from ₹X", city and service areas, description.
   - A "About the vendor" section.
   - Contact details or actions per open questions 1–2.
   - "More from this vendor" and "Similar vendors" horizontal lists.
   - Share (open question 3).
   - Skeleton, error/retry, offline/stale and not-available (404, e.g. a listing withdrawn since the list loaded) states.
   - Works for guests.
5. Replace the M12 "coming soon" tap everywhere with opening the page (pushed within the current tab).
6. Tests:
   - Backend unit and e2e: visibility (404 for draft, rejected, suspended vendor, archived category, unknown id), no private fields, related lists (limits, exclusions, city match), rate limit and validation.
   - Flutter: repository, controller and widgets, including states, guest view, navigation from Explore/Home, related taps and 200 % text.
7. Docs: api-contracts, domain-model (A10 answer), flutter.md, current-milestone, progress.

## Out of scope
- Wishlist, enquiry, adding a vendor to an event, in-app messages (M14; GI-26).
- Listing photos and portfolio upload/display (M28), ratings and reviews (M20), quotations (M15).
- Vendor-side editing (M26–M28); admin moderation (M40+).
- Deep links that open the app at a listing from a shared link (needs the link domain; later milestone).
- vendor_app / admin_cms (phase-locked).

## Deliverables
Two public endpoints; the listing details page with related lists; tests; docs.

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app | Listing details page; navigation from cards | 4–5 |
| backend | Listing details and related endpoints (read only) | 1–2 |
| database | None expected (contact columns exist on `vendors`) | 3 |
| Firebase | None | — |
| API contracts | Two endpoints | 7 |
| Notifications | Evaluated: viewing changes no state, so no notification | 7 |

## Acceptance criteria
- [x] AC-1 Tapping any vendor card opens its details page; guests can view it.
- [x] AC-2 Only visible listings open. Anything else returns 404, and the app shows a clear "no longer available" state.
- [x] AC-3 The page shows the listing and vendor information. Contact details follow the answer to open question 1. No private vendor fields are returned (tested).
- [x] AC-4 "More from this vendor" and "Similar vendors" show the right listings (same vendor; same category and city), never the listing itself or hidden ones.
- [x] AC-5 Loading, error/retry, offline and not-found states, plus 200 % text on a small phone, work.
- [x] AC-6 Backend and Flutter checks and tests pass. Security, privacy (A10), performance, UI and code reviews are done, the docs are updated, and the status is IN_REVIEW.

## Required reviews
- Security/privacy: public data only; A10 contact exposure; scraping risk of phone numbers (rate limit; signed-in only if chosen).
- Performance: one query for details plus one for related; cached categories; no image loading before M28.
- UI: page hierarchy, states, guest flow.
- Notification: none.
- Code review.

## Risks and assumptions
- Showing phone numbers to guests makes them easy to scrape. Showing them only to signed-in users reduces this (open question 1).
- Sample vendors have fake contact details (`@example.invalid`, no phone) in development.

## Open questions (answered 2026-10-08 — see change log)
1. **Contact details (A10):** A10 proposed that vendor phone and email are **public** on approved listings. Show them to everyone, or **only to signed-in users** (guests see "Sign in to see contact details")? Proposed: signed-in users only (less scraping).
2. **Contact actions:** proposed: tap-to-call and tap-to-email buttons on the page (they open the phone's dialer or mail app, no in-app messaging). OK, or keep contact for M14?
3. **Share:** proposed: a Share button that shares the listing's name, vendor, city and starting price as text (no app link until deep links exist). OK?
4. **Related lists:** proposed: "More from this vendor" and "Similar vendors" (same category, same city or service area), up to 6 each. OK?
5. **Photos:** a large category-icon header until listing photos arrive in M28 (as in M12), or will you supply temporary image URLs?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-08 | Initial DRAFT created at the M12 approval gate | CLAUDE.md Rule 4 |
| 2026-10-08 | User answers: 1 "recommended" → vendor phone/email returned **only to signed-in users** (guests get `contact: null` and see "Sign in to see contact details"); 2 "now" → **tap-to-call and tap-to-email** buttons in M13 (open the dialer / mail app; no in-app messaging); 3 Share as text (name, vendor, city, starting price) OK; 4 "More from this vendor" + "Similar vendors", up to 6 each, OK; 5 "recommended" → category-icon header until M28 photos. A10 refined accordingly | User |
| 2026-10-08 | CONFIRMED by `START MILESTONE M13` | User |
