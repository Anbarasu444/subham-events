# M14 — Wishlist / Contact / Enquiry

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M14` on 2026-10-08 (open questions answered the same day) |
| Phase | User App |
| Depends on | M13 COMPLETED and approved (`APPROVE MILESTONE M13`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager + notification-manager (security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Dependency note (read first)
Enquiries go **to vendors**, but vendors only get an app in M24–M39. Their inbox is M32, and they reply with quotations in M33. So in M14:
- a user can send an enquiry, and it is stored, listed and can be closed,
- the vendor-side notification (N9) is **created in the database** for the vendor's user account (in-app record), and the push is sent once vendor devices exist (M36),
- nobody can answer it until the Vendor App exists. The app says so honestly ("The vendor will reply in the app"). Call/email from M13 remain the way to reach vendors meanwhile.

The same situation came up in M7, M11 and M12. Open question 1 asks whether to build enquiries now or only wishlist + "add to event" now.

"Contact" was largely delivered in M13 (call/email for signed-in users, A10). M14 adds no in-app chat (GI-26 is still open).

## Objective
A signed-in user can:
- **save** vendor listings to a wishlist and see them in one place,
- **add** a listing to one of their events (an event vendor — `event_vendors`, status ADDED), see each event's vendors, add a private note, and remove one,
- **send an enquiry** (message and preferred date) for an event vendor, which moves it to ENQUIRED, and close their own enquiry,
- and see each enquiry's status.

## In scope (proposed — Option A)
**Database (cross-layer, Rule 7)**
1. Migrations (database-schema.md Part C):
   - `wishlist_items` (PK user + listing, soft delete).
   - `event_vendors` (event, listing, vendor and category denormalised server-side; status ADDED/ENQUIRED/QUOTED/BOOKED/COMPLETED/CANCELLED/REMOVED; private `notes`; `uq(event_id, listing_id)`; `uq(id, event_id, vendor_id)` as the composite FK target).
   - `enquiries` (composite FK to `event_vendors`, user, `message`, `preferred_date`, status OPEN/QUOTED/DECLINED/CLOSED, `decline_reason`, `closed_at`; one open enquiry per event vendor).

**Backend (cross-layer, Rule 7)**
2. Wishlist: `GET /me/wishlist` (cursor, newest first, hidden listings flagged), `PUT /me/wishlist/{listingId}` (idempotent save), `DELETE …` (remove).
3. Event vendors (owner-only through the event, PLANNING-only writes like the checklist/budget):
   - `GET /events/{id}/vendors`
   - `POST /events/{id}/vendors` `{ listingId }` (visible listings only; no duplicates)
   - `PATCH …/{eventVendorId}` (notes)
   - `DELETE …` (→ REMOVED, allowed while ADDED/ENQUIRED/QUOTED).
4. Enquiries:
   - `POST /events/{id}/vendors/{eventVendorId}/enquiries` `{ message, preferredDate? }` with an Idempotency-Key → event vendor ENQUIRED.
   - `GET` lists them.
   - `POST …/enquiries/{enquiryId}/close` (user closes).
   - Rules: one OPEN enquiry per event vendor; no enquiry to your own vendor listing (A12); event cancelled → open enquiries closed (§4.6 hook in the events service).
5. Notifications:
   - **N9 "New enquiry"** in-app record for the vendor's user. Push waits for vendor devices (M36).
   - The content follows **A9**: the vendor sees the user's display name, event type, date, city and guest estimate only — never email, budget or notes.
   - Audit every state change.

**User App**
6. A **Save** (heart) button on listing cards and the details page, and a **Saved vendors** screen (Menu). Guests are asked to sign in.
7. **Add to event** on the details page:
   - pick a planning event (one event → direct),
   - "Added to <event>" with an undo/remove option.
8. **Vendors tab** on the event screen (the M10 placeholder): the event's vendors with their status chips, a private note, Remove, and **Send enquiry** (a sheet with the message and an optional preferred date). Enquiry status is shown honestly: "Sent — the vendor will reply in the app".
9. Home/Explore unchanged except for the heart buttons.
10. Tests:
   - Backend unit and e2e: ownership, visibility, duplicates, state rules, one open enquiry, A12, event-cancel closing, N9 record content (A9), idempotency, audit.
   - Flutter: controllers, repositories and widgets, including guest prompts, optimistic save and rollback, add-to-event picker, enquiry sheet validation and 200 % text.
11. Docs: api-contracts, database-schema, domain-model (A9 answer), notification-matrix, flutter.md, current-milestone, progress.

## Out of scope
- Vendor-side inbox, replies, declines and quotations (M32/M33); push to vendors (M36); user notification center (M18).
- Quotations, booking and agreed amounts (M15); in-app chat (GI-26).
- vendor_app / admin_cms (phase-locked).

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app | Save buttons, Saved vendors, Add to event, event Vendors tab, enquiry sheet | 6–9 |
| backend | wishlist, event-vendors, enquiries modules; N9 record; events-cancel hook | 2–5 |
| database | `wishlist_items`, `event_vendors`, `enquiries` | 1 |
| Notifications | N9 in-app record for the vendor (push later, M36) | 5 |
| API contracts | Endpoints above | 11 |

## Acceptance criteria (Option A)
- [x] AC-1 Signed-in users can save and unsave listings and see them in Saved vendors. Guests are asked to sign in. Hidden listings are marked "no longer available".
- [x] AC-2 Users can add a visible listing to a planning event (no duplicates), see the event's vendors, keep a private note and remove a vendor. Other users' events → 404.
- [x] AC-3 Users can send one open enquiry per event vendor (idempotent) and close it. Enquiring with your own vendor listing is blocked (A12). Cancelling an event closes its open enquiries.
- [x] AC-4 Each enquiry creates an N9 in-app notification record for the vendor's user, containing only A9 fields (tested). Every change is audited.
- [x] AC-5 All new screens handle loading, empty, error, retry, offline and read-only (completed/cancelled event) states, and render at 200 % text.
- [x] AC-6 Migrations apply. Backend and Flutter checks and tests pass. Security, privacy, performance, notification, UI and code reviews are done, the docs are updated, and the status is IN_REVIEW.

## Risks and assumptions
- Enquiries cannot be answered until the Vendor App (M32/M33). Without clear copy, users may expect replies.
- R3 (quotation rules) is still on hold and must be resolved before M15, not M14.

## Open questions (answered 2026-10-08 — see change log)
1. **Approach:** Option A (wishlist + add to event + enquiries now, vendor replies later; recommended), or B (wishlist + add to event only; enquiries move to when the Vendor App can answer them)?
2. **A9 (what a vendor sees about the user before booking):** proposed: display name, event type, event date, city and guest estimate only; the phone number and venue only after a booking is confirmed. OK?
3. **Enquiry message:** proposed: required, 10–1000 characters, plus an optional preferred date. A ready-made starter text ("Hi, we're planning a <event type> on <date> in <city>…") that the user can edit. OK?
4. **Saving as a guest:** proposed: guests are asked to sign in (no device-only wishlist). OK?
5. **Where to find saved vendors:** proposed: Menu → Saved vendors, plus a heart filter chip in Explore? Or Menu only?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-08 | Initial DRAFT created at the M13 approval gate | CLAUDE.md Rule 4 |
| 2026-10-08 | User answers: 1 **Option A** (wishlist + add to event + enquiries now; vendor replies with the Vendor App); 2 **A9 OK** (before CONFIRMED the vendor sees display name, event type, event date, city, guest estimate; phone and venue only after CONFIRMED; never email, budget, notes); 3 enquiry message 10–1000 chars + optional preferred date with an editable starter text OK; 5 saved vendors in **both** Menu → Saved vendors and a "Saved" filter chip in Explore. Question 4 (guest saving) — user asked for an explanation; pending | User |
| 2026-10-08 | User answer 4: **A** — guests who tap Save are asked to sign in ("Sign in to save vendors"); the wishlist is server-side only, no device-only wishlist | User |
| 2026-10-08 | CONFIRMED by `START MILESTONE M14` | User |
