# M10 — Event Details

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M10` on 2026-10-07 |
| Phase | User App |
| Depends on | M9 COMPLETED and approved (`APPROVE MILESTONE M9`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager (security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Objective
The M8 event page becomes the event's **home screen**: a header with the event's cover, title, date, countdown and status, and sections for Overview, Checklist and the features coming next (Budget M11, Vendors M12–M15). It is the place the user plans one event from. Existing actions (edit, complete, cancel, reopen, delete) move into this screen without changing their rules.

## In scope (answers 2026-10-07: tabs; ImageKit cover photo; Open in Maps; Share as text; 5 MB photos)
1. **Event details screen** (replaces the M8 event page, same route from My Events, Home and notifications later):
   - Header: **cover photo** (the event's own photo, or a coloured band with an event-type icon when there is none), title, event type, date and start time, a countdown ("In 12 days" / "Today" / "Completed"), status chip.
   - **Tabs** under the header (answer 1): **Overview · Checklist · Budget · Vendors** (swipe between them).
2. **Overview**:
   - Date and time, city, venue and address, guest estimate, total budget.
   - Checklist progress summary.
   - The next 3 open tasks.
   - Quick actions: Edit, Add task, **Share details as text** through the phone's share sheet (`share_plus`, answer 3).
   - **Open in Maps** for the venue/address (`url_launcher`, answer 2).
3. **Checklist section**: the M9 checklist embedded in the screen. No new checklist features.
4. **Budget / Vendors sections**: honest placeholders ("Budget arrives in the next update"), each linking to what exists today (total budget, Explore). Real content comes in M11 and M12–M15.
5. **Event actions menu**: edit, mark completed, cancel, reopen and delete with the M8 confirmations, moved into an overflow menu. Read-only states are shown consistently across sections.
6. **Cover photo** (answer: own photo per event via ImageKit, max **5 MB**):
   - App: pick from the gallery or camera (`image_picker`). Downscale on the device, then show upload progress, with change and remove options.
   - Backend `media` module:
     - `POST /media/uploads`: the backend authorises an upload for one event and returns a single-use ImageKit v2 upload token that fixes folder, file name and privacy.
     - The app uploads straight to ImageKit.
     - `POST /media/uploads/{mediaId}/complete {fileId}`: the backend fetches the file's details from ImageKit and checks path, privacy, type (JPEG/PNG/WebP/HEIC) and size (≤ 5 MB).
     - `PUT /events/{id}/cover {mediaId}` sets the cover (`events.cover_media_id`) and `DELETE /events/{id}/cover` removes it.
     - `EventDto` gains `cover: { mediaId, url, thumbnailUrl, expiresAt } | null` with signed, resized ImageKit URLs (originals are never served).
   - Database: migration for a `media` table (database-schema.md Part C) and `events.cover_media_id`. Cover changes are audited.
   - Configuration: `IMAGEKIT_PUBLIC_KEY`, `IMAGEKIT_PRIVATE_KEY` (secret), `IMAGEKIT_URL_ENDPOINT` and `MEDIA_ROOT_FOLDER`. The user adds them to `backend/.env`; they are documented in `.env.example`. The private key never reaches the app.
   - Media is soft-deleted only (R11): the file stays in ImageKit but is no longer served.
7. **States and performance**: loading, error/retry and stale banner. Pull to refresh reloads the event and its checklist. Sections are built lazily, and each section keeps its own scroll position.
8. **Accessibility**: section headers, labelled tabs/segments, 48 dp targets, 200 % text, light and dark mode.
9. **Tests**: backend unit and e2e tests (upload intent ownership, cover verification with a fake ImageKit client: wrong type, too large, other user's file, replaced or removed cover), controller tests and widget tests for:
   - header and countdown
   - sections and actions
   - read-only events
   - error and stale states
   - 200 % text
10. **Docs**: flutter.md (event details), api-contracts (media + cover), database-schema, media-and-deep-links.md (cover flow), threat model (uploads), current-milestone, progress.

## Out of scope
- Budget allocations and overview (M11), vendor discovery, enquiries and bookings (M12–M15), reminders (M17), invitations (M19).
- Other media: profile photos (M21), vendor listing media (M28), invitation images (M19); videos.
- vendor_app / admin_cms (phase-locked).

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification |
|---|---|---|
| user_app | Event details screen, sections, header, actions | 1–8 |
| backend | `media` module (ImageKit signed upload intents, file verification), event cover endpoints, `EventDto.cover` | 6 |
| database | `media` table, `events.cover_media_id` | 6 |
| Firebase | None | — |
| API contracts | Upload intents, cover set/remove, `EventDto.cover` | 6, 10 |
| Notifications | None (no new state changes) | — |

## Acceptance criteria
- [x] AC-1 Opening an event from My Events or Home shows the details screen with the header (cover, title, type, date/time, countdown, status) and the agreed sections.
- [x] AC-2 Overview shows every event field, the checklist progress and up to 3 next tasks. Its quick actions work.
- [x] AC-3 The checklist section behaves exactly like M9: add, tick, reorder, delete and read only.
- [x] AC-4 The Budget and Vendors sections show honest placeholders. They don't show fake data.
- [x] AC-5 Edit, complete, cancel, reopen and delete keep the M8 rules and confirmations. Read-only events show consistently.
- [x] AC-6 The screen has loading, error/retry, stale and offline states, and pull to refresh. It renders at 200 % text in light and dark mode with no overflow.
- [x] AC-7 A user can add, change and remove their event's cover photo (≤ 5 MB, image types only). The backend verifies every upload with ImageKit before using it. Another user's file or event is rejected. The private key never leaves the backend.
- [x] AC-8 "Open in Maps" opens the venue address, and "Share" sends the event details as text.
- [x] AC-9 Backend lint, typecheck, tests and build pass. The migrations apply. Flutter analyze, format and tests pass.
- [x] AC-10 Security, UI, performance and code reviews are done, the docs are updated, and the status is IN_REVIEW.

## Required reviews
Security (upload authorisation, server-side verification, secrets, private media), UI/UX (information hierarchy, tabs, header, photo flow), performance (image sizes, caching, lazy tabs, rebuild scope), notification (none expected), code review.

## Risks and assumptions
- Four sections with two placeholders can feel empty until M11–M15. Honest copy and links reduce this.
- Real cover photos need ImageKit set up (keys server-side, signed uploads, validation), so the effort is noticeably larger.

## Open questions (answered 2026-10-07)
1. ~~Layout~~ — **tabs** (Overview · Checklist · Budget · Vendors).
2. ~~Cover picture~~ — **own photo per event via ImageKit** (user has an ImageKit account; keys go into `backend/.env` by the user). Maximum **5 MB** per cover.
3. ~~Open in Maps~~ — **yes** (`url_launcher` approved).
4. ~~Share details~~ — **yes** (`share_plus` approved).
5. ~~Photo picking~~ — **yes** (`image_picker` approved), max 5 MB.

Interpretation note: the user's reply "1. tabs 2. yes 3. yes 4. maximum 5MB - Yes" was mapped to questions 1, 3, 4 and 5 (cover via ImageKit was confirmed in the previous message). Correct before START if this is wrong.

**Prerequisite (user):** add `IMAGEKIT_PUBLIC_KEY`, `IMAGEKIT_PRIVATE_KEY`, `IMAGEKIT_URL_ENDPOINT`, `MEDIA_ROOT_FOLDER` to `backend/.env` (never in chat). Until then the cover-upload endpoints return `503 SERVICE_UNAVAILABLE` and the app hides "Add cover photo"; everything else works.

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-07 | Initial DRAFT created at the M9 approval gate | CLAUDE.md Rule 4 |
| 2026-10-07 | Answers: tabs; cover photo via ImageKit (max 5 MB); Open in Maps; Share as text; packages `image_picker`, `url_launcher`, `share_plus` approved. Scope extended with backend media (items 6, 9, 10; AC-7…AC-10) | User |
| 2026-10-07 | User added ImageKit keys to `backend/.env`; CONFIRMED by `START MILESTONE M10` | User |
| 2026-10-07 | Implementation decisions (recorded, low risk): `MEDIA_ROOT_FOLDER` optional (defaults to `/<APP_ENV>`, it was not in the user's .env); without ImageKit settings the upload endpoints answer 503 and the app shows "Photos are not available right now" (the cover button is shown when uploads are wired in the app); ImageKit REST API used directly (no SDK package); replaced/removed covers kept per R11; orphan-file sweep deferred (GI-30) | Claude |
| 2026-10-08 | Review fixes (recorded): ImageKit upload API v2 (single-use signed upload settings) instead of v1 signatures; abandoned/rejected files deleted; max 3 unfinished uploads per event and 10 upload requests/min; `md-false` on delivered images; cover removal asks to confirm; status actions in a menu with an Overview "Mark as completed" prompt after the date | Claude |
| 2026-10-08 | Item 6 endpoint names aligned with the implemented contract (`/media/uploads`, `…/complete`, `PUT /events/{id}/cover {mediaId}`). Decision (recorded, low risk): the cover follows the M8 rule for event details and can change in any status; the checklist stays read-only for completed/cancelled events (M9). `thumbnailUrl` is returned for later list use | Claude |
| 2026-10-08 | Set IN_REVIEW (real cover upload from the signed-in app not run — simulator signed out; ImageKit verified live, app chain covered by tests) | Claude |
