# M9 — Checklist

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M9` on 2026-10-07; milestone COMPLETED 2026-10-07 |
| Phase | User App |
| Depends on | M8 COMPLETED and approved (`APPROVE MILESTONE M8`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager (security-manager, performance-manager, ui-manager, notification-manager, code-reviewer reviewers) |

## Objective
For each of their events, a signed-in user keeps a checklist of tasks they write themselves (R8, no templates): add, edit, reorder, tick off, untick and delete items, with optional due dates and notes. Overdue items stand out, progress is visible on the event and on the Home dashboard's **Checklist progress** section, and the Menu's Checklist entry stops being "Coming soon". The backend stores items in PostgreSQL with owner-only access and audit, following `domain-model.md` §4.12.

## In scope
**Database (cross-layer, Rule 7)**
1. Migration: `checklist_items` per `database-schema.md` Part C: `event_id → events` (owner checked through the event), `title` (1–120), `notes` (optional, ≤ 1000), `due_date date null`, `status` (PENDING, DONE), `completed_at`, `sort_order`, `deleted_at`, `version`, timestamps; index `ix_checklist_items_event_id_status_due_date` (partial, not deleted). At most 200 items per event (answer 3).

**Backend (cross-layer, Rule 7)**
2. `checklist` module:
   - `GET /api/v1/events/{eventId}/checklist` (items in sort order, with counts: total, done, overdue)
   - `POST /api/v1/events/{eventId}/checklist` (idempotent create)
   - `PATCH /api/v1/events/{eventId}/checklist/{itemId}` (title, notes, due date; `version` check)
   - `POST …/{itemId}/complete` and `…/{itemId}/reopen` (PENDING ↔ DONE, sets/clears `completed_at`)
   - `PUT /api/v1/events/{eventId}/checklist/order` (reorder)
   - `DELETE …/{itemId}` (soft delete)
   - `GET /api/v1/events/{eventId}` and the events list gain a small `checklist` summary `{ total, done, overdue }` for cards and Home.
   - The owner check goes through the event (another user's event or item → 404). Overdue is derived in the event's time zone. Rules for items of a cancelled, completed or deleted event: open question 2. Audit every change; rate-limit writes.

**User App**
3. Checklist screen inside the event (from the event page and from Menu → Checklist, which lets you pick an event):
   - Pending / Done sections, overdue highlighted, progress bar.
   - Add and edit sheets: title, optional due date and notes.
   - Tick off with undo, drag to reorder, swipe or menu to delete with confirmation.
   - Loading, empty, error, retry and offline states.
4. Event page: a checklist progress row that opens the checklist. Event cards show `done/total`.
5. Home dashboard: replace the Checklist progress placeholder with a real section showing the next event's progress and its overdue or next-due items.
6. Tests: backend unit and e2e tests covering:
   - ownership through the event
   - validation
   - complete/reopen
   - reorder
   - soft delete
   - overdue computed in the event's time zone
   - idempotency
   - migration

   Flutter controller, repository and widget tests covering:
   - add, edit, tick and untick, reorder, delete
   - all loading/empty/error states
   - the Home section
   - 200 % text
7. Docs: `api-contracts.md` Part B, `database-schema.md` Part B, `architecture/flutter.md`, notification evaluation, current-milestone, progress.

## Out of scope
- Reminders and scheduled due/overdue notifications (M17 Reminders; push via FCM in M18). See open question 1.
- Checklist templates or suggestions (R8: users add every item themselves).
- Assigning items to vendors or other people; sharing checklists.
- Rich event details screen with tabs (M10), budget (M11).
- vendor_app / admin_cms (phase-locked).

## Deliverables
`checklist_items` migration, `checklist` backend module and endpoints, event checklist summary, User App checklist screen + event/Home integration + Menu entry, tests, docs.

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification (in-scope item #) |
|---|---|---|
| user_app | Checklist feature, event page row, card counts, Home section, Menu entry | 3–5 |
| backend | `checklist` module; events responses gain a checklist summary | 2 |
| database | `checklist_items` | 1 |
| Firebase | None | — |
| API contracts | Checklist endpoints; `checklist` summary on `EventDto` | 7 |
| Notifications | Evaluated: changes by the owner notify nobody; due/overdue reminders N16 follow open question 1 | 7 |

## Acceptance criteria
- [x] AC-1 A signed-in user can add, edit, tick, untick, reorder and delete checklist items for their own event. Validation runs on both client and server.
- [x] AC-2 Overdue (pending, due date before today in the event's time zone) is computed server-side and highlighted in the app. Done items show when they were completed.
- [x] AC-3 Another user's event or item is never readable or changeable: e2e tests show 404. Every write is audited.
- [x] AC-4 Progress (done/total, overdue count) is shown consistently on the checklist screen, the event page, event cards and the Home dashboard.
- [x] AC-5 Loading, empty, error, retry and offline states are handled. Ticking an item feels instant, and the change is undone if the server rejects it.
- [x] AC-6 Rules for items of cancelled, completed or deleted events follow the answer to open question 2 (tests).
- [x] AC-7 Migrations apply on an empty database. Backend lint, typecheck, tests and build pass. Flutter analyze, format and tests pass.
- [x] AC-8 Security, performance, UI, notification and code reviews are done, the docs are updated, and the status is IN_REVIEW.

## Required reviews
- Security: ownership through the parent event, input limits, rate limits, audit.
- Performance: checklist query and index, summary computation on event lists (no N+1), list rendering and reorder.
- UI/UX: quick add, tick feedback and undo, reorder accessibility (non-drag alternative), overdue styling, 200 % text.
- Notification: N16 decision recorded.
- Code review: full diff.

## Risks and assumptions
- Optimistic ticking needs careful rollback on errors and concurrency with other devices (`version`).
- Adding counts to event lists must stay one query (aggregate join), not one query per event.
- Drag-to-reorder needs an accessible alternative (move up/down actions).

## Open questions (all answered 2026-10-07)
1. ~~Due-date notifications (N16)~~ — **answered: yes.** M9 shows due/overdue in the app only (highlighting, Home section); scheduled in-app/push N16 notifications are built with Reminders in M17 (push via FCM in M18).
2. ~~Cancelled / completed / deleted events~~ — **answered: read only.** The checklist of a COMPLETED or CANCELLED event is visible but cannot be changed (writes → 409 `INVALID_STATE_TRANSITION`); it is editable only while the event is PLANNING (reopening the event makes it editable again). Items of a deleted event are hidden with it.
3. ~~Limits~~ — **answered: yes.** At most 200 (non-deleted) items per event, title 1–120 characters, notes up to 1000 characters.
4. ~~Menu → Checklist~~ — **answered: yes.** Several events → pick one of the user's PLANNING events first; exactly one → open its checklist directly.

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-07 | Initial DRAFT created at the M8 approval gate | CLAUDE.md Rule 4 |
| 2026-10-07 | Open questions 1–2 answered: due/overdue in-app highlighting only (N16 notifications → M17/M18); checklist read-only for completed/cancelled events (AC-6). Questions 3–4 open | User |
| 2026-10-07 | Open questions 3–4 answered: limits 200 items / 120-char title / 1000-char notes; Menu → Checklist picks an event when there are several | User |
| 2026-10-07 | CONFIRMED by `START MILESTONE M9` | User |
| 2026-10-07 | Implementation decisions after reviews (recorded, low risk): blank notes are stored as no notes; a reorder never overlaps other changes; checklist changes refresh event screens once per burst (400 ms); the event title moved from the checklist app bar into the page (200 % text) | Claude |
| 2026-10-07 | Set IN_REVIEW (signed-in simulator check not run — simulator signed out; covered by e2e + widget tests) | Claude |
| 2026-10-07 | `APPROVE MILESTONE M9` → COMPLETED | User |
