# Notification Matrix

> Part A is the notification architecture (M1, spec item 8 / AC-7). Part B is the matrix; each row is implemented and tested by the milestone that builds the triggering feature.

# Part A — Architecture

## 1. Flow

```mermaid
sequenceDiagram
  autonumber
  participant S as Domain service (in transaction)
  participant DB as PostgreSQL
  participant W as Worker
  participant FCM as FCM
  participant App as App / Admin CMS
  S->>DB: business change + notifications row(s) + jobs row (notification.push) — one transaction
  DB-->>S: commit
  W->>DB: claim job (FOR UPDATE SKIP LOCKED)
  W->>DB: load recipient's active devices + preferences
  alt push not wanted (preference off / in-app only type / no devices)
    W->>DB: mark job done (delivery_status = SKIPPED)
  else
    W->>FCM: send per device (data + notification payload)
    alt token unregistered / invalid
      W->>DB: deactivate device
    else transient error (5xx, quota)
      W->>DB: reschedule with exponential backoff (max 5 attempts, then FAILED)
    end
    W->>DB: delivery_status = SENT (per device result recorded)
  end
  App->>DB: (via API) GET /notifications, PATCH read state
```

- **PostgreSQL `notifications` is the source of truth** for the in-app center. Push is best-effort delivery; failure never rolls back the business change.
- Exactly-once creation (same transaction as the change); at-least-once push (clients de-duplicate by `notificationId`).

## 2. Notification record

| Field | Notes |
|---|---|
| `id` | UUIDv7; also sent in push `data.notificationId` |
| `recipient_user_id` | Recipient platform user |
| `recipient_audience` | `USER`, `VENDOR`, `ADMIN` — which app/center shows it |
| `category` | `AUTH`, `CATEGORY`, `VENDOR`, `EVENT`, `BOOKING`, `PAYMENT`, `CHECKLIST`, `INVITATION`, `REVIEW`, `SYSTEM` |
| `type` | Stable code, e.g. `QUOTATION_RECEIVED` |
| `entity_type`, `entity_id` | Target entity |
| `title`, `body` | Rendered server-side at creation (English at launch); no sensitive data in push body |
| `deep_link` | Path form, e.g. `/u/quotations/{id}` (see `architecture/media-and-deep-links.md` §5) |
| `data jsonb` | Small extra metadata for the client |
| `read_at` | null = unread |
| `push_policy` | `ALWAYS`, `IF_ENABLED`, `NEVER` |
| `created_at` | |

Device registry `notification_devices`: `user_id`, `audience`, `fcm_token` (unique), `platform`, `app_version`, `last_seen_at`, `is_active`. Registered on sign-in/app start (M18/M36), removed on sign-out, deactivated on FCM `UNREGISTERED`.

Preferences: per user per category (push on/off); in-app records are always created. Transactional categories (`PAYMENT`, `BOOKING`, `AUTH` security events) cannot be fully disabled for in-app.

## 3. Push payload

```json
{
  "notification": { "title": "New quotation", "body": "Lens & Light sent a quotation for your wedding." },
  "data": { "notificationId": "…", "type": "QUOTATION_RECEIVED", "entityType": "QUOTATION", "entityId": "…", "deepLink": "/u/quotations/…" },
  "android": { "priority": "high", "notification": { "channelId": "bookings" } },
  "apns": { "payload": { "aps": { "thread-id": "bookings" } } }
}
```

Android channels per category group (`bookings`, `payments`, `reminders`, `marketplace`, `general`).

## 4. Admin recipients

Admin notifications are in-app (CMS) by default, addressed to all active admins holding the relevant sub-role at creation time (e.g. `MARKETPLACE_ADMIN` for listing submissions). Admin web push is not planned for launch.

## 5. Noise rules

- No push for internal/technical events (job retries, cache refresh, webhook receipt before verification).
- Collapse repeated pushes for the same entity within 2 minutes (e.g. multiple quotation edits) via FCM `collapse_key` = `type:entityId`.
- Quiet hours for non-urgent categories (reminders/marketing-like) evaluated in M17/M18.

# Part B — Matrix

In-app = row created in `notifications`. Push = FCM to recipient devices (subject to preferences).

| # | Trigger (state change) | Category | Recipient | In-App | Push | Milestone(s) |
|---|---|---|---|---|---|---|
| N1 | First sign-in (welcome) | AUTH | User | Yes | No | M5 |
| N2 | Account suspended / reinstated by admin | AUTH | User/Vendor | Yes | Yes | M46 |
| N3 | New category published | CATEGORY | Vendors | Yes | No | M42 |
| N4 | Platform fee changed for a category ⏸R6 | CATEGORY | Vendors with drafts in that category | Yes | No | M43 |
| N5 | Vendor listing submitted for review | VENDOR | Admins (MARKETPLACE_ADMIN) | Yes | No (CMS in-app) | M30/M44 |
| N6 | Platform fee payment succeeded | PAYMENT | Vendor; Admins (FINANCE_ADMIN) | Yes | Vendor: Yes; Admin: in-app | M29 |
| N7 | Platform fee payment failed | PAYMENT | Vendor | Yes | Yes | M29 |
| N8 | Vendor listing approved / rejected (with reason) | VENDOR | Vendor | Yes | Yes | M31/M45 |
| N9 | New enquiry | BOOKING | Vendor | Yes | Yes | M14/M32 |
| N10 | Quotation received / revised | BOOKING | User | Yes | Yes | M15/M33 |
| N11 | Quotation accepted / rejected by user ⏸R3 (withdraw/expiry rows added when R3 resolved) | BOOKING | Vendor | Yes | Yes | M15/M33 |
| N12 | Booking confirmed | BOOKING | User and Vendor | Yes | Yes | M15/M34 |
| N13 | Booking cancelled (by either party/admin) | BOOKING | Other party (and both if admin) | Yes | Yes | M15/M34/M48 |
|  | ↳ M21: deleting an account cancels its confirmed bookings (reason "Account deleted") and sends N13 to each vendor (in-app; vendor push from M36). No other notification on profile changes (the user's own actions) | | | | | M21 |
| N14 | Booking completed | BOOKING | User (review prompt: "How did it go? Rate the vendor." — M20) | Yes | Yes | M15/M20 |
| N15 | ~~Event payment recorded~~ — **removed (M2):** payment notes are the user's private notes (R5, ❓A2); no notification | — | — | — | — | — |
| N16 | Checklist item due today / overdue (only items with a due date) | CHECKLIST | User | Yes | Yes (once per item per state, 09:00 event time zone) | M9/M17 |
| N17 | User reminder fires | CHECKLIST | User | Yes | Yes | M17 |
| N18 | RSVP received on an invitation (R9) | INVITATION | Invitation owner | Yes, digested (M19): one row per invitation per hour ("3 new RSVPs"); the RSVP list always shows every reply | Yes, same row; push group OTHER | M19 |
| N19 | Review received — rating immediately (A4); comment when approved | REVIEW | Vendor | Yes — M20: `REVIEW_RECEIVED` in-app (vendor audience) with name "Asha K." and stars, never the comment | Yes from M36 (vendor devices) | M20/M37 |
| N20 | Approved review comment later hidden by admin | REVIEW | Review author | Yes | No | M51 |
| N23 | Review comment submitted for moderation (R7) | REVIEW | Admins (MARKETPLACE_ADMIN, CONTENT_ADMIN) | Yes (CMS) — **deferred to M51**: no admin accounts exist yet (M40+); until then the queue is `ix_reviews_comment_status_created_at` | No | M51 |
| N24 | Review comment approved / rejected (R7) | REVIEW | Review author | Yes | No | M20/M51 |
| N25 | Enquiry declined by vendor | BOOKING | User | Yes | Yes | M14/M32 |
| N26 | Event's booked vendor account deleted/suspended | VENDOR | Event owner | Yes | Yes | M46 |
| N21 | System announcement by admin | SYSTEM | Targeted audience | Yes | Optional per announcement | M50 |
| N22 | App update required / maintenance | SYSTEM | All users of an app | Yes | Yes | M50 |
| N27 | Rate-the-vendor reminder: 3 days after a booking is completed, once, only if not yet reviewed and completed within the last 30 days (M20 change, user 2026-10-09) | REVIEW | User | Yes (`REVIEW_REMINDER`) | Yes, group OTHER | M20 |

Rows are confirmed (and amended through the spec change log) by the milestone that implements them; each milestone's notification review checks every row it touches.

### Evaluated with no notification
| Milestone | State change | Decision |
|---|---|---|
| M8 | Event created / edited / cancelled / reopened / completed / deleted by its owner; event auto-completed the day after its date | No notification: the owner made the change (or a date-driven housekeeping change with no action needed), and no other party is attached to an event before vendors exist (M14+). Vendor-facing event changes are evaluated again in M14/M15. |
| M9 | Checklist item added / edited / ticked / unticked / reordered / deleted by the event owner | No notification: the owner made the change. Due today / overdue reminders (N16) are deferred to M17 (scheduled) and M18 (push) — user decision 2026-10-07; M9 only highlights overdue tasks in the app. |
| M10 | Event cover photo added / changed / removed; event screen | No notification: the owner's own change; no other party involved. |
| M11 | Budget plan set/changed/cleared by the event owner | No notification: the owner's own planning change; no other party involved. |
| M18 | Push delivery for user types (N10, N12–N14 to the user, N16, N17) | `push_policy IF_ENABLED`, queued as `delivery_status PENDING` in the creating transaction; groups BOOKINGS (BOOKING/PAYMENT), REMINDERS (CHECKLIST), OTHER; Android channels `bookings`, `reminders`, `general` (created by the app); the push body never includes personal data beyond the in-app title/body; the app de-duplicates by `notificationId` and shows foreground pushes as a banner. iOS delivery needs the user's APNs key and a real bundle id (GI-35). |
| M17 | Reminder due (N17); checklist task due today / overdue (N16) | In-app records (`REMINDER_DUE`, `CHECKLIST_DUE_TODAY`, `CHECKLIST_OVERDUE`), `push_policy NEVER` until M18 adds FCM. N17 fires at the user's chosen time (no quiet hours, answer 5); N16 once per task per state from 09:00 event-local, pending tasks of planning events only. Home shows due, unseen reminders until dismissed. Creating/editing/cancelling a reminder: no notification. |
| M16 | Payment note added/edited/deleted | **No notification** (A2: private records; the vendor never sees them). |
| M15 | Quote received (N10), accepted/declined (N11), booking confirmed (N12), cancelled by the user (N13), auto-completed (N14) | In-app records, `push_policy NEVER` until pushes exist (M18 users, M36 vendors). N10 comes from the dev sample script until vendors send quotes (M33). Vendor-facing records carry A9 fields only (plus amount and, for N13, the user's reason). A user marking their own booking completed creates no notification. |
| M14 | Enquiry sent (N9) | In-app record for the vendor's user (audience VENDOR, category BOOKING, type `ENQUIRY_RECEIVED`), A9 fields only; `push_policy NEVER` until vendor devices exist (M36). Saving vendors, adding/removing event vendors, notes and closing enquiries: no notification (the user's own actions; the vendor sees closed enquiries in their inbox, M32). |
| M13 | Viewing a listing, calling or emailing a vendor (hand-off to the phone's apps) | No notification: no platform state changes; contact happens outside the app. |
| M12 | Browsing / searching vendor listings | No notification: read-only, no state change. |
| M11 | Own expense added/edited/deleted by the event owner | No notification: the owner's own note; no other party involved. Over-budget is shown in the budget screen, not pushed. |
