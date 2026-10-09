# M20 — Reviews

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M20` on 2026-10-09 (open questions answered 2026-10-09) |
| Phase | User App |
| Depends on | M19 COMPLETED and approved (`APPROVE MILESTONE M19`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager + notification-manager (security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Context (R7, A4, A5, A12 — decided in M2)
- R7: a review is a **star rating (1–5) + optional comment**; the comment goes to **admin moderation** before it is public.
- A4 (not yet confirmed): the **rating is public immediately**; only the comment waits. A rejected comment leaves the rating public without text.
- A5 (not yet confirmed): reviews only for a **completed booking**, **one per booking**, **no editing** after sending; vendor replies are out of scope.
- A12 (not yet confirmed): a user can't review their own listing; reviews only after the booking's service date.

**Dependency gap:** the Admin CMS (moderation screens) comes in M40–M54, and the Vendor App in M24–M39. Until then, nobody can approve comments in a UI, so they would stay "waiting for approval". Open question 3 decides how to handle this.

## Objective (proposed)
After a booking is completed, the user can rate the vendor and add a comment. Ratings show on listing cards and details straight away. Approved comments show on the listing's details page.

## In scope (proposed)
**Database (cross-layer, Rule 7)**
1. `reviews` (Part C):
   - booking unique (one per booking);
   - user, vendor and listing;
   - rating 1–5 with `rating_status` ACTIVE/REMOVED;
   - comment with `comment_status` NONE/PENDING_MODERATION/APPROVED/REJECTED/HIDDEN and the moderation fields;
   - indexes for the listing's reviews and the admin queue.

**Backend (cross-layer, Rule 7)**
2. User endpoints:
   - write a review for a completed booking (owner only, A5/A12, idempotent);
   - read my review for a booking;
   - list my reviews.
3. Public endpoint: a listing's reviews, paged, showing ratings plus only APPROVED comments, with the reviewer shown as first name + last initial, e.g. "Asha K." (answer 4).
4. Ratings: `rating_sum` / `rating_count` on listings are updated atomically in the same transaction. The listing's average then shows on cards and details (the field already exists, M12/M13).
5. Notifications and audit:
   - N23: an in-app record for admins when a comment needs moderation (readable from M51).
   - N19: a vendor-audience in-app record (pushes for vendors from M36).
   - Review events are audited.

**User App**
6. A "Rate this vendor" prompt on completed bookings (and from the N14 "booking completed" notification), plus the review sheet: stars, optional comment, and a preview of what will be public.
7. After sending: "Your rating is live; your comment is waiting for approval" (read only).
8. Listing details: a rating summary (average, count, star breakdown) and a reviews list (approved comments), with every state handled.

## Out of scope
- Admin moderation screens (M51), and rating removal by admins (M51).
- Vendor viewing of reviews (M37) and vendor replies (A5).
- Review photos; editing or deleting a review (A5); abuse reports (M51).

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app | Review sheet, booking prompt, listing reviews section | 6–8 |
| backend | `reviews` module, rating aggregates, public list | 2–5 |
| database | `reviews` migration | 1 |
| Firebase | None | — |
| API contracts | Review endpoints and DTOs | 2–3 |
| Notifications | N19 (vendor, in-app), N23 (admins, in-app) | 5 |

## Acceptance criteria (proposed)
- [x] AC-1 Only the owner of a completed booking (after its service date) can review it, once. A second attempt or an ineligible attempt is refused (A5, A12). — Evidence: e2e "only a completed booking can be reviewed, once" and "refuses before the service date, own listings and other users"; app test "a completed booking can be rated once".
- [x] AC-2 The rating counts toward the listing average immediately and atomically (A4). Comments are public only when APPROVED. — Evidence: e2e "counts the rating at once; the comment waits for approval" (listing card and summary update; pending comment not public).
- [x] AC-3 Listing details show the rating summary and approved comments with paging and all states. The user sees their own review's status. — Evidence: `ListingReviewsSection` tests (empty, summary + breakdown + paging, retry, 200 %); booking panel shows "Your rating" and the comment status.
- [x] AC-4 N19 and N23 records are created per the matrix. Review events are audited. No personal data beyond the shown name ("Asha K.") is exposed. — Evidence: e2e "tells the vendor (N19, in-app) and audits without the comment"; public list shows only "Asha K.". **N23 deferred to M51** (no admin accounts yet; GI-37).
- [x] AC-5 All screens render at 200 % text. Checks and tests pass, reviews are done, the docs are updated, and the status is IN_REVIEW. — Evidence: 200 % tests; backend 74 + 144, Flutter 301; reviews in current-milestone.md; status IN_REVIEW.

## Required reviews
- Security: eligibility checks, self-review ban, public data minimisation, rate limits.
- Performance: atomic aggregates, indexed paging.
- Notification: N19 and N23 only; no noisy pushes.
- Documentation: api-contracts, database-schema, notification-matrix, flutter.md.

## Risks and assumptions
- Until M51 there is no moderation UI, so comments would wait indefinitely (question 3).
- Bookings are completed only by real or sample vendors (dev seeds, M15) and the auto-complete job, so testing uses the dev sample data.

## Open questions (please answer before `START MILESTONE M20`)
1. **A4:** is the rating public immediately, with only the comment waiting for approval? (Recommended: yes.)
2. **A5:** one review per completed booking, no editing after sending, no vendor replies for now? (Recommended: yes.)
3. **Comments before the Admin CMS exists:** pick one.
   - A: comments wait (show "waiting for approval") until M51; ratings work now. *(recommended)*
   - B: add a dev/test-only script to approve or reject comments, so you can try the whole flow now.
   - C: publish comments without moderation until M51 (this changes R7).
4. **Reviewer name shown publicly:** first name only (e.g. "Asha"), or "Asha K.", or anonymous ("Verified customer")?
5. **When to ask:** show "Rate this vendor" on the completed booking and in the "booking completed" notification. OK? Any reminder later (e.g. after 3 days), or none?
6. **A12:** reviews only after the booking's service date, and never for your own listing. OK?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-09 | Initial DRAFT created at the M19 approval gate | CLAUDE.md Rule 4 |
| 2026-10-09 | User answers: 1 yes — **A4 confirmed** (rating public immediately; only the comment waits); 2 ok — **A5 confirmed** (one review per completed booking, no editing, no vendor replies); 3 **A** — comments show "waiting for approval" until M51, ratings work now; 4 **B** — public name shown as first name + last initial ("Asha K."); 5 yes — ask on the completed booking and in the N14 notification; the later reminder was not answered → assumed none; **then answered: one reminder after 3 days if not rated** (see later entry); 6 ok — **A12 confirmed** (only after the service date; never your own listing) | User |
| 2026-10-09 | CONFIRMED by `START MILESTONE M20` | User |
| 2026-10-09 | **Scope change (user, during review):** answer 5 extended — one "rate the vendor" reminder 3 days after completion if not rated (N27, push group OTHER; migration `1792700000000-ReviewReminders`, hourly job). Bookings completed more than 30 days ago are not reminded (assumption: avoids a burst for old bookings) | User |
| 2026-10-09 | Implementation note: N23 (admins) is not created — there are no admin accounts until M40+; the pending-comment index is the moderation queue and N23 ships with M51 (GI-37). Set IN_REVIEW | Claude |
| 2026-10-09 | **COMPLETED** — `APPROVE MILESTONE M20` | User |
