# M19 — Digital Invitations

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M19` on 2026-10-09 (open questions answered 2026-10-08) |
| Phase | User App |
| Depends on | M18 COMPLETED and approved (`APPROVE MILESTONE M18`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager + notification-manager (security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Context (R9, A6 — decided in M2)
Each event can have an **e-invitation**:
- the user picks a design, writes the details and shares it as a **link** or an **image**;
- **guests can RSVP** without an account: name, attending / not attending / maybe, number of guests and an optional message (A6);
- the owner sees the RSVPs and gets an "RSVP received" notification (N18, digested, at most one push per invitation per hour).

Guests don't have the app, so the link needs a **public web page**. There is no web domain or hosting decided yet (ADR-0010), so open question 1 decides how guests see the invitation.

## Objective (proposed)
For a planning event, the owner can:
- create an invitation from a built-in design,
- preview it and publish it,
- share it as a link (WhatsApp, SMS…) and/or as an image,
- close RSVPs or revoke the link,
- see responses with totals (attending, maybe, not attending, total guests).

Guests open the link in any browser, see the invitation and send or update their RSVP.

## In scope (proposed)
**Database (cross-layer, Rule 7)**
1. `invitations` (Part C):
   - one per event (open question 6),
   - design code, title, message, host names, a snapshot of date, time and venue,
   - status DRAFT/PUBLISHED/REVOKED, `rsvp_open`, a share token **stored only as a SHA-256 hash**, published and revoked times.
2. `invitation_rsvps` (A6):
   - responder token hash (one RSVP per browser; re-submitting updates it),
   - name 1–80, response, guest count 1–20, message ≤ 500.

**Backend (cross-layer, Rule 7)**
3. Owner endpoints (owner-only through the event):
   - get, create and update the invitation,
   - publish (issues the token once and returns the share URL; re-publishing after edits keeps the same link),
   - close or reopen RSVPs, revoke,
   - list RSVPs with totals.
   Writes need a PLANNING event, except revoke and closing RSVPs.
4. Public guest pages (no login), at `GET /i/{token}`:
   - a small server-rendered **HTML page** with the invitation and an RSVP form (`POST /i/{token}/rsvp`),
   - the response is remembered with a cookie so a guest can update it,
   - `noindex`, `Referrer-Policy: no-referrer`, a CSP and per-IP rate limits,
   - unknown or revoked token → a neutral "This invitation is no longer available" page,
   - RSVPs close the day after the event or when the owner closes them.
5. N18 "RSVP received" as a **digest** (domain-model §4.15): at most one notification per invitation per hour ("3 new RSVPs"), in-app and pushed in the OTHER group. Cap of 1,000 RSVPs per invitation.

**User App**
6. A new **Invitation** section on the event's Overview (or its own screen):
   - pick a design from a **template catalogue** (answer 3: many predefined templates, planned by the user later; M19 builds the data-driven catalogue with a small starter set), fill in the title, message and host names (prefilled from the event),
   - a live preview, Publish, Share link (share sheet),
   - Share image (the phone draws the invitation as a picture and shares it with the link in the text; open question 2),
   - Close or reopen RSVPs, Revoke (with confirmation).
7. An RSVP screen: totals and a list (name, response, guest count, message, time), refresh, empty and error states.
8. Tests:
   - Backend unit and e2e: token hashing, never returning the raw token after publish, the public page and RSVP (create/update, validation, closed and revoked states, rate limit, cookie), owner-only, the N18 digest.
   - Flutter: editor validation, preview, publish and share flows with fakes, RSVP list states, 200 % text.
9. Docs: api-contracts, database-schema, domain-model (A6 answer), notification-matrix N18, media-and-deep-links (invitation URL until the link domain exists), threat model (public pages), flutter.md, progress.

## Out of scope
- A custom domain or a separate web app for invitations (later, with hosting; ADR-0010). Photos uploaded into invitations. Multiple languages. Guest lists, sending invitations by SMS or email from the server, seating. Printing/PDF.

## Acceptance criteria
- [x] AC-1 The owner can create, preview, publish and share an invitation (link and image), and revoke it or close RSVPs. — Evidence: Overview card + editor + share link/picture + menu; widget tests "creates, publishes and shares…", "shares the invitation as a picture…", "closes replies and turns the link off…".
- [x] AC-2 Guests open the link in a browser without an account, see the invitation and send or update one RSVP (A6). Closed and revoked states are shown clearly. — Evidence: guest page and RSVP form e2e (create, update via cookie, closed, revoked, unknown).
- [x] AC-3 The share token is stored only as a hash. The public page is noindex/no-referrer, CSP-protected and rate limited, and holds no other personal data. — Evidence: `share_token_hash` bytea only; noindex/no-referrer header e2e assertions; neutral page for cancelled/unknown links (e2e); escaped HTML; rate limits via the shared `RateLimit` guard (its 429 behaviour is covered by earlier milestones' tests).
- [x] AC-4 The owner sees RSVPs with correct totals. N18 is a digest: at most one notification per invitation per hour. — Evidence: totals e2e + Replies screen test; digest job e2e (second run within the hour sends nothing).
- [x] AC-5 All screens handle every state and render at 200 % text. Checks and tests pass, reviews are done, the docs are updated, and the status is IN_REVIEW. — Evidence: 200 % editor test; backend 74 + 137, Flutter 291; reviews in current-milestone.md; status IN_REVIEW.

## Risks
- Until there is a proper web domain, the link points at the API server's address. In development that is your Mac, so **guests on other phones can only open it on the same Wi-Fi** (or once the backend is hosted).
- Public pages attract spam: rate limits and a 20-guest cap per RSVP limit the damage.

## Open questions (answered 2026-10-08 — see change log)
1. **Guest page:** the backend serves a simple invitation web page with the RSVP form (works in any browser, no app needed). The link uses the server's address until a web domain exists. OK?
2. **Image format:** the app draws the invitation as a picture on the phone and shares it, with the RSVP link added in the message text. No image is stored on a server. OK?
3. **Designs:** proposed 4 built-in designs (Classic, Floral, Minimal, Festive) with colour themes; no uploaded photos in M19. OK, or other styles?
4. **RSVP form (A6):** guest name (required), Attending / Not attending / Maybe, number of guests (1–20, default 1), optional message (up to 500 characters). No phone or email asked. One RSVP per browser, and sending again updates it. OK?
5. **RSVP notifications (N18):** grouped, at most one notification per invitation per hour ("3 new RSVPs"), in the Notification Center and as a phone push under "Other" in settings. The RSVP list always shows every response. OK?
6. **How many invitations:** one per event (you can edit it; the link stays the same), proposed. OK, or several (e.g. separate ones for different functions)?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-08 | Initial DRAFT created at the M18 approval gate | CLAUDE.md Rule 4 |
| 2026-10-08 | User answers: 1 guest page served by the backend (server address until a domain exists) — OK; 2 picture drawn on the phone and shared with the link — OK; 3 **the user will plan the designs later and wants many predefined templates** → M19 builds a data-driven template catalogue (code, name, colours, fonts, layout) so templates can be added without code changes to the screens, with a small starter set; the full template set is follow-up work (GI-36); 4 A6 form — OK; 5 N18 digest hourly, push under Other — OK; 6 "A" → **one invitation per event** (edit keeps the same link) | User |
| 2026-10-09 | CONFIRMED by `START MILESTONE M19` | User |
| 2026-10-09 | Implemented; starter catalogue of 6 designs (Classic, Floral, Minimal, Festive, Royal, Pastel); set IN_REVIEW | Claude |
| 2026-10-09 | **COMPLETED** — `APPROVE MILESTONE M19` | User |
