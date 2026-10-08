# Current Milestone

> Authoritative milestone status file (CLAUDE.md §26). There is no M0; M1 is the first milestone.

| Field | Value |
|---|---|
| Milestone ID | **M10** |
| Milestone name | Event Details |
| Phase | User App (M3–M23) |
| Status | **IN_REVIEW** |
| Spec | `.claude/project/milestones/M10-event-details.md` (status: CONFIRMED 2026-10-07) |
| Started date | 2026-10-07 |
| Completed date | — |
| Approval status | **Awaiting `APPROVE MILESTONE M10`** |

## Objective
The event page becomes the event's home screen: header (cover, title, date, countdown, status) and sections Overview, Checklist, Budget (placeholder until M11) and Vendors (placeholder until M12–M15); event actions move into it.

## Completed work
- Database: migration `1791600000000-MediaAndEventCover` (`media`, `events.cover_media_id`), applied by the user 2026-10-07.
- Backend `media` module (ImageKit, ADR-0007):
  - Single-use **upload API v2** tokens sign folder, name, privacy and no-overwrite.
  - Server-side verification checks path, privacy, MIME type and 1 B–5 MB.
  - Rejected and abandoned files are deleted.
  - At most 3 unfinished uploads per event; 10 upload requests per minute.
  - Race-safe completion.
  - Cover set/remove on events, with signed, resized, metadata-free URLs on `EventDto.cover`.
  - Audit entries `MEDIA_UPLOADED`, `MEDIA_REJECTED`, `EVENT_COVER_SET`, `EVENT_COVER_REMOVED`.
  - Optional ImageKit settings, validated without echoing values.
- Live checks against the user's ImageKit account:
  - private upload works,
  - unsigned URLs are blocked (403) and signed URLs load, including `md-false`,
  - v2 rejects changed fields and reused tokens.

  All test files were deleted afterwards.
- User App event screen:
  - Cover photo, or an event-type gradient band, with add/change/remove (pick from photos or camera, 5 MB, progress, remove asks to confirm).
  - Header with title, type, date/time, countdown and status.
  - Pinned tabs:
    - **Overview**: quick actions Add task / Open in Maps / Share, details, checklist summary, and "Mark as completed" once the date has passed.
    - **Checklist**: the M9 checklist.
    - **Budget** and **Vendors**: honest placeholders.
  - Actions menu: cover, complete, reopen, cancel, delete.
  - Packages `image_picker`, `url_launcher`, `share_plus` (approved); iOS/Android permission entries.

## In-progress work
- None.

## Not verified
- A real cover upload from the app on the simulator was **not** done: the simulator is signed out (Firebase sign-in is the user's step). The ImageKit side was verified live with the same token and upload format the app sends, and the app's upload chain is covered by widget, controller and repository tests with fakes.

## Tests completed
- Backend: lint, typecheck, build, Prettier clean; **63 unit** tests (v2 token signing, signed URLs, config validation); **54 e2e** on PostgreSQL, 10 of them for media/covers:
  - signed fixed settings
  - pending cap
  - validation and ownership
  - verify → set cover with signed URLs
  - too large / empty / wrong type / public → deleted and audited
  - wrong path not deleted
  - another user blocked
  - replace and remove with audit
  - cover on a cancelled event
  - late rejection doesn't undo success
  - abandoned uploads removed
- Flutter: analyze and format clean, **178** tests, including the upload chain, the cover controller flows, share/Maps text, and the event screen (header, tabs, placeholders, Maps/Share hand-off, add cover, remove cover with confirmation, "Mark as completed" for past events, 200 % text).

## Reviews
| Review | Status |
|---|---|
| Security review | PASS WITH FINDINGS. Fixed: v1 signatures → v2 single-use signed uploads (F1); delete abandoned/rejected files (F2); pending cap + lower rate (F3); race-safe completion (F4); `md-false` (F5); rejection audit, empty-file message (F6). Logged: GI-30 (orphans when search lags; R11 keeps replaced covers) |
| UI/UX + performance review | PASS WITH FINDINGS. Fixed: rebuild scope, decode size, busy indicator, remove confirmation and labels, tab scrolling, completion prompt, menu icons/divider/red delete, summary card semantics and empty state, Maps placement and errors, iPad share origin, icon-only cover button at large text |
| Code review | PASS WITH FINDINGS. Fixed: rejection race, atomic pending cap, spec endpoint text. Decided (recorded): cover editable in any status like other event details. Accepted: one extra reload after a cover change, `thumbnailUrl` reserved for lists |
| Notification review | Done: no notifications (owner's own changes) |
| Documentation | Done: api-contracts (media + cover), database-schema, media-and-deep-links (v2, metadata, clean-up), threat model, flutter.md §6d, notification matrix, known-issues GI-30, spec change log |

## Known issues
- See `known-issues.md`: GI-4, GI-5, GI-8, GI-10, GI-11, GI-12, GI-14, GI-16…GI-30.
- Business rules on hold: R3 (before M15), R6 (before M28/M29), R10 (before M26). R11 final policy by M21.

## Files changed
- Database: `database/migrations/1791600000000-MediaAndEventCover.ts`
- Backend: `src/modules/media/*` (ImageKit client + spec, entity, dto, service, cover URLs, controller, clean-up job, module), `src/modules/events/{event.entity,events.dto,events.service,events.controller,events.module}.ts`, `src/config/{env.validation,app-config.service}.ts` (+ spec), `.env.example`, `test/{media.e2e-spec,fakes,db-harness,auth.e2e-spec,events.e2e-spec}.ts`
- User App: `lib/features/media/**`, `lib/core/platform/{photo_picker,external_actions}.dart`, `lib/features/events/**` (cover model, repository, event screen, controller), `lib/features/checklist/presentation/views/checklist_view.dart` (shared slivers), `lib/features/shell/presentation/bindings/shell_binding.dart`, `pubspec.yaml`/`pubspec.lock`, `ios/Runner/Info.plist`, `ios/Podfile.lock`, `android/app/src/main/AndroidManifest.xml`, generated plugin registrants (linux/macos); tests under `test/features/{media,events,checklist}`, `test/helpers`
- Docs: `.claude/project/{current-milestone,progress,milestones,api-contracts,database-schema,notification-matrix,known-issues}.md`, `architecture/{media-and-deep-links,threat-model,flutter}.md`, `milestones/M10-event-details.md`
- No vendor_app or admin_cms changes.

## Files pending approval
- M10 files are uncommitted; the user commits personally.

## Next milestone
- M11 — Budget Management (spec drafted at the M10 gate).

## Do NOT start
- Vendor App work (locked until M23 approved)
- Admin CMS work (locked until M39 approved)

---

## Previous milestone — M9 Checklist: COMPLETED

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
