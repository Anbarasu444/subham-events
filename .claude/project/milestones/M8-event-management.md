# M8 — Event Management

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M8` on 2026-10-07; milestone COMPLETED 2026-10-07 |
| Phase | User App |
| Depends on | M7 COMPLETED and approved (`APPROVE MILESTONE M7`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager (security-manager, performance-manager, ui-manager, code-reviewer reviewers) |

## Objective
A signed-in user can create, view, edit, cancel, reopen and delete (soft) their events, unlimited and concurrently (R2). The My Events tab lists them, the Home dashboard's **Upcoming event** section shows the next event, and the "Create your first event" button really creates one. The backend stores events in PostgreSQL with server-side ownership checks, validation and audit, following the Event state machine (`domain-model.md` §4.6).

## In scope
**Database (cross-layer, Rule 7)**
1. Migration: `events` table per `database-schema.md` Part C (`owner_user_id`, `event_type` (free text entered by the user, 1–60 chars — answer 1), `title`, `event_date`, `start_time`, `time_zone` default `Asia/Kolkata`, `city`, `venue_name`, `venue_address`, `guest_count_estimate ≥ 0`, `total_budget_amount numeric(12,2) ≥ 0 null`, `currency`, `status` (PLANNING, COMPLETED, CANCELLED), `deleted_at`, `version`, timestamps), FKs, checks and the index `ix_events_owner_user_id_event_date_id` (partial, not deleted). No `event_types` table and no `cover_media_id` in M8 (answers 1–2).

**Backend (cross-layer, Rule 7)**
2. `events` module (controller → service → repository): 
   - `POST /api/v1/events`, `GET /api/v1/events` (own events, cursor pagination per ADR-0013, filter `status`, `upcoming`/`past`, sorted by date), `GET /api/v1/events/{id}`, `PATCH /api/v1/events/{id}` (optimistic concurrency via `version`), `POST /api/v1/events/{id}/cancel`, `POST /api/v1/events/{id}/reopen`, `POST /api/v1/events/{id}/complete`, `DELETE /api/v1/events/{id}` (soft delete).
   - Ownership on every route (404 for other users' events, never 403-leak), DTO validation, money as decimal-rupee strings (ADR-0014), state-transition rules from §4.6, audit log entries for create/update/state change/delete.
3. Auto-complete job: PLANNING events become COMPLETED the day after `event_date` in the event's time zone (jobs foundation from M5).
4. Rate limits for write routes; idempotency for `POST /events` (`Idempotency-Key`, `api-contracts.md` §9) — the `idempotency_keys` table is added here if needed by this endpoint.

**User App**
5. Events feature (`features/events`): repository + Dio data source + models; My Events tab: list (upcoming first, then past/cancelled), pull-to-refresh, pagination, loading/empty/error/retry/offline states.
6. Create / edit event form: event type (free text; the form may offer common types such as Wedding or Birthday as quick-fill suggestions, but any text is accepted), title, date (not in the past for new events; existing events may be edited to a past date), optional start time, city, venue name/address (optional), guest estimate, optional total budget (decimal rupees, Indian formatting); validation messages; unsaved-changes guard.
7. Event summary page inside the My Events tab (basic info + status + actions: edit, cancel, reopen, mark completed, delete with confirmation). Rich event details (checklist, budget, vendors tabs) belong to M10.
8. Home dashboard: replace the Upcoming event placeholder source with a real source (next PLANNING event) and content card; "Create your first event" opens the create form for signed-in users and becomes "Create event" once the user has events (M7 note).
9. Tests: backend unit + e2e (ownership, validation, transitions, pagination, idempotency, auto-complete job, migrations on empty DB); Flutter controller/repository/widget tests (form validation, list states, actions, dashboard section).
10. Docs: `api-contracts.md` Part B (events, event types), `database-schema.md` Part B, `architecture/flutter.md`, notification evaluation, current-milestone, progress.

## Out of scope
- Checklist (M9), event details screen with tabs (M10), budget allocations/overview (M11), vendors/enquiries (M12–M15), reminders (M17), invitations (M19)
- Event notifications to vendors (no vendors yet) and push/FCM (M18)
- Admin event views (M40+), vendor_app / admin_cms (phase-locked)
- Event cover image upload / ImageKit (answer 2: no media in M8; where an image is needed later the user supplies a temporary image URL)

## Deliverables
`events` migration, `events` backend module and endpoints, auto-complete job, User App events feature (list, form, summary, actions), real Home Upcoming-event section, tests, docs.

## Cross-layer impact (CLAUDE.md Rule 7)
| Layer | Expected change | Justification (in-scope item #) |
|---|---|---|
| user_app | Events feature, My Events tab, dashboard section | 5–8 |
| backend | `events` module, job, rate limits, idempotency | 2–4 |
| database | `events` (+ `idempotency_keys` if needed) | 1, 4 |
| Firebase | None | — |
| API contracts | Events endpoints | 10 |
| Notifications | Evaluated: creating/editing/cancelling one's own event notifies nobody else → no notification in M8 (vendor-facing event notifications arrive with M14+) | 10 |

## Acceptance criteria
- [x] AC-1 A signed-in user can create an event (all fields validated client- and server-side) and sees it in My Events and on the Home dashboard; guests are asked to sign in.
- [x] AC-2 Edit works with optimistic concurrency (stale `version` → 412 `PRECONDITION_FAILED` with a clear message in the app).
- [x] AC-3 Cancel, reopen, complete and soft delete follow `domain-model.md` §4.6; invalid transitions return 409/422; delete asks for confirmation and hides the event (row kept, R11).
- [x] AC-4 A user can never read or change another user's event (e2e: 404); every write is audited.
- [x] AC-5 List is cursor-paginated, sorted (upcoming first), with loading/empty/error/retry/offline states.
- [x] AC-6 Money is exact decimal rupees end-to-end (`numeric(12,2)`, `"10.10"` in the API, no floating point in the app).
- [x] AC-7 Auto-complete job moves past PLANNING events to COMPLETED (test).
- [x] AC-8 Migrations apply on an empty database.
- [x] AC-9 Backend lint/typecheck/tests/build and Flutter analyze/format/tests pass; security, performance, UI, notification and code reviews done; docs updated; IN_REVIEW.

## Required reviews
- Security: ownership checks, input validation, rate limits, audit, no data leakage in errors.
- Performance: list query + index, pagination, app list rendering.
- UI/UX: form usability (date/time pickers, rupee input), empty states, destructive-action confirmation, 200 % text.
- Notification: evaluation recorded (expected: none).
- Code review: full diff.

## Risks and assumptions
- Time zone: dates are stored as local `date` + IANA zone (default `Asia/Kolkata`); "upcoming" is computed in the event's zone.
- Free-text event types (answer 1) cannot be grouped or filtered reliably by admins/vendors later; a reference list could be added in a later milestone if needed.
- Completing an event automatically may surprise users if the date was wrong; reopen is allowed while the date is in the future.

## Open questions (answered 2026-10-07)
1. ~~Event types~~ — **user can enter any event type** (free text; no fixed list, no `event_types` table).
2. ~~Cover image~~ — **not in M8**; proceed without media. The user will provide a temporary image URL when an image is needed.
3. ~~Required fields~~ — **yes**: event type, title, date, city required; start time, venue, guest estimate, total budget optional.
4. ~~Past dates~~ — **yes**: new events not in the past; existing events may be edited to a past date.

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-07 | Initial DRAFT created at the M7 approval gate | CLAUDE.md Rule 4 |
| 2026-10-07 | Open questions answered: free-text event type (no `event_types` table), no cover image/media in M8, required fields and past-date rule confirmed (items 1, 2, 6; AC-8 updated) | User |
| 2026-10-07 | CONFIRMED by `START MILESTONE M8` | User |
| 2026-10-07 | Implementation decisions after reviews (recorded, low risk — CLAUDE.md §31): stale-version error is 412 `PRECONDITION_FAILED` with `version` in the PATCH body (api-contracts §4 catalogue; AC-2 wording updated from 409); reopen allowed when the date is today or later (domain-model §4.6 clarified); time zones restricted to Region/City IANA names (or UTC) that PostgreSQL also knows; cursors bound to their list scope; idempotency keys stuck "in progress" are reclaimed after 60 s; a new create key when the form input changes | Claude |
| 2026-10-07 | Set IN_REVIEW (signed-in simulator check not run — user asked to continue; covered by e2e + widget tests) | Claude |
| 2026-10-07 | `APPROVE MILESTONE M8` → COMPLETED | User |
