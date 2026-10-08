# M17 — Reminders

| Field | Value |
|---|---|
| Spec status | **CONFIRMED** — ratified by `START MILESTONE M17` on 2026-10-08 (open questions answered the same day) |
| Phase | User App |
| Depends on | M16 COMPLETED and approved (`APPROVE MILESTONE M16`) |
| Primary owner agent | user-app-manager + backend-manager + database-manager + notification-manager (security-manager, ui-manager, performance-manager, code-reviewer reviewers) |

## Dependency note (read first)
A reminder is only useful if it **reaches the user at the right time**. Phone push notifications (FCM) come in **M18** (Notification Center + FCM). M17 comes first, so open question 1 decides how a reminder reaches you in M17:

- **Option A — server reminders now, the in-app list now, phone pushes from M18 (recommended).**
  - The server stores the reminder, and at the time a job marks it sent and creates an in-app notification (N17).
  - The app shows due and upcoming reminders (Home and an event's Reminders list).
  - In M18 the same records start sending phone pushes. No extra package is needed now.
- **Option B — also local phone alerts now.** Add the `flutter_local_notifications` package (a new dependency needs your approval) so the phone itself alerts at the reminder time, even before M18. This needs a notification permission prompt and per-platform setup now, and must stay in step with the server reminders later.

## Objective (Option A)
For each event, the user can:
- create reminders (title, date and time, optional link to a checklist task),
- see upcoming and past reminders,
- edit (reschedule) and cancel them.

At the reminder time the server marks it SENT and creates N17. Checklist tasks with a due date also produce N16 ("due today" and "overdue") once per task per state at 09:00 in the event's time zone. Reminders are cancelled automatically when their task is done or deleted, or when the event is cancelled or deleted (§4.13).

## In scope (Option A)
**Database (cross-layer, Rule 7)**
1. `reminders` (Part C):
   - user, event, optional checklist task (composite FK), `title` 1–120,
   - `remind_at timestamptz`, status SCHEDULED/SENT/CANCELLED, `sent_at`, soft delete, version.
   - Index for the due job.
   - At most 200 scheduled per event.
2. A small table or columns to remember which checklist tasks already got N16 for which state (once per task per state).

**Backend (cross-layer, Rule 7)**
3. Owner-only through the event:
   - `GET /events/{id}/reminders` (upcoming and past),
   - `POST` (Idempotency-Key; `remindAt` in the future),
   - `PATCH` (reschedule/rename, version),
   - `POST …/{id}/cancel`.
   Writes need a PLANNING event. Rate limited, audited without titles.
4. `GET /me/reminders/upcoming` (next few across the user's planning events) for Home.
5. A **due job** (every minute or so): SCHEDULED reminders with `remind_at ≤ now` → SENT + N17 in-app (push from M18). Idempotent, batched, `SKIP LOCKED`.
6. A **checklist due job** (hourly, acting at 09:00 event-local): N16 "due today" and "overdue" once per task per state, for PLANNING events and PENDING tasks with a due date.
7. Auto-cancel hooks: task ticked done or deleted, event cancelled or deleted → CANCELLED.
8. Docs: notification-matrix N16/N17 timing and quiet hours (open question 5).

**User App**
9. An event screen **Reminders** section (Overview tab or its own tab, open question 3): list upcoming and past; add/edit sheet (title, date and time picker, optional "for task…" picker); cancel with confirmation; status chips (Scheduled, Sent, Cancelled).
10. Quick "Remind me" from a checklist task (prefills the title and a time the day before the due date).
11. Home: a "Next reminders" line or card, plus an in-app "due now" banner for SENT reminders not yet seen (until the M18 notification centre).
12. Menu → Schedule (the M6 placeholder) lists reminders across events (open question 4).
13. Tests:
    - Backend unit and e2e: time zones, the due job (idempotent, exact time boundary), auto-cancel hooks, N16 once-per-state, ownership, validation.
    - Flutter: date/time picker validation, lists, states, 200 % text.

## Out of scope
- Phone pushes and the notification centre (M18), unless Option B is chosen.
- Repeating reminders; reminders shared with other people; email or SMS reminders.
- vendor_app / admin_cms.

## Acceptance criteria (Option A)
- [x] AC-1 The user can create, reschedule and cancel reminders for a planning event, optionally linked to a checklist task. The time is stored exactly (UTC) and shown in local time.
- [x] AC-2 At the reminder time the job marks it SENT exactly once and creates N17. Auto-cancel rules (§4.13) work.
- [x] AC-3 N16 "due today" and "overdue" are created once per task per state, at 09:00 in the event's time zone, only for pending tasks of planning events.
- [x] AC-4 Home, the event screen and Menu → Schedule show reminders, with all states, at 200 % text.
- [x] AC-5 Owner-only, validated, rate limited and audited. Checks and tests pass, reviews are done, the docs are updated, and the status is IN_REVIEW.

## Risks
- Without pushes (until M18), users only see reminders when they open the app. The copy must be honest ("You'll get phone alerts once notifications are switched on in a later update").
- Server job timing: a reminder fires within about a minute of its time.

## Open questions (answered 2026-10-08 — see change log)
1. **Approach:** Option A (server reminders + in-app now, phone pushes from M18; recommended), or Option B (also local phone alerts now with the `flutter_local_notifications` package)?
2. **Checklist due alerts (N16):** proposed: one "due today" alert at 09:00 on the due date and one "overdue" alert the next day at 09:00 (event time zone), for pending tasks only. OK?
3. **Where reminders live on the event screen:** proposed: a "Reminders" section inside the **Overview** tab (no fifth tab). OK, or a separate tab?
4. **Menu → Schedule:** proposed: becomes "all my reminders" across events (upcoming first). OK?
5. **Quiet hours:** proposed: reminders fire exactly at the time you chose (you picked it). Checklist alerts (N16) only at 09:00. No other quiet hours. OK?
6. **Default time for "Remind me" from a task:** proposed: 6 PM the day before the task's due date (changeable). OK?

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-10-08 | Initial DRAFT created at the M16 approval gate | CLAUDE.md Rule 4 |
| 2026-10-08 | User answers: 1 **Option A** (server reminders + in-app now; phone pushes from M18; no new package); 2 N16 at 09:00 on the due date and 09:00 the next day if still pending — OK; 3 Reminders section inside the Overview tab — OK; 4 Menu → Schedule = all my reminders, upcoming first — OK; 5 reminders fire at the chosen time, N16 only at 09:00, no other quiet hours — OK; 6 "Remind me" default 6 PM the day before the task's due date — OK | User |
| 2026-10-08 | CONFIRMED by `START MILESTONE M17` | User |
