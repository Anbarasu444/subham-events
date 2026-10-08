# API Contracts

> Part A (conventions) is the M1 deliverable for spec item 3 / AC-3 and applies to every endpoint.
> Part B (endpoint catalogue) is filled in by the milestone that implements each endpoint. No client may rely on undocumented behaviour.

# Part A — Conventions

## 1. Base path and versioning

- Base: `https://<api-host>/api/v1`.
- Major version in the path. Within `v1`, only additive, backward-compatible changes (new endpoints, new optional request fields, new response fields). Clients must ignore unknown response fields.
- Breaking changes require `/api/v2` for the affected routes, a deprecation window (≥ 2 mobile release cycles), and a `Deprecation` / `Sunset` header on old routes.
- Audience route groups: shared/user routes at `/api/v1/...`, vendor routes at `/api/v1/vendor/...`, admin routes at `/api/v1/admin/...`, public routes are marked `Auth: Public`.
- Clients send `X-Client: <app>/<semver>+<build>`; the API may answer `426 CLIENT_UPGRADE_REQUIRED` for unsupported versions.

## 2. JSON conventions

- `camelCase` property names; `UPPER_SNAKE_CASE` enum values.
- IDs are UUID strings (`"id": "0192b0b6-6c1e-7a6b-9d3a-3f1f5c2a9e10"`).
- Optional values are omitted or `null` consistently per field (documented per endpoint); empty lists are `[]`, never `null`.
- Booleans are named `isX` / `hasX`.
- Request bodies are whitelisted: unknown properties → `422 VALIDATION_FAILED`.

## 3. Success envelope

Single resource:
```json
{
  "data": { "id": "0192b0b6-…", "name": "Asha & Ravi Wedding", "status": "PLANNING" },
  "meta": { "requestId": "c0a8012e-…" }
}
```

Collection:
```json
{
  "data": [ { "id": "…" }, { "id": "…" } ],
  "meta": {
    "requestId": "c0a8012e-…",
    "page": { "type": "cursor", "limit": 20, "nextCursor": "eyJjIjoiMjAyNi0xMC0wNlQwOTo1NDoxMVoiLCJpIjoiMDE5MiJ9", "hasMore": true }
  }
}
```

`204 No Content` is used for deletes and actions with no body.

## 4. Error format and catalogue

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Some fields are invalid.",
    "details": [
      { "field": "eventDate", "code": "MUST_BE_FUTURE", "message": "Event date must be in the future." }
    ],
    "requestId": "c0a8012e-…"
  }
}
```

- `code` is stable and machine-readable; `message` is a safe, generic English message (clients localise by `code`).
- No stack traces, SQL, provider payloads or internal IDs in errors.

Initial catalogue (extend per milestone; never reuse a code with a different meaning):

| HTTP | code | Meaning |
|---|---|---|
| 400 | `BAD_REQUEST` | Malformed JSON / unparseable request |
| 401 | `AUTH_REQUIRED` | No credentials on a protected route |
| 401 | `AUTH_TOKEN_EXPIRED` | Firebase ID token / session expired — refresh and retry once |
| 401 | `AUTH_TOKEN_INVALID` | Bad signature / audience / malformed |
| 401 | `AUTH_TOKEN_REVOKED` | Token revoked — sign out |
| 403 | `ACCOUNT_SUSPENDED` | User suspended |
| 403 | `ACCOUNT_DELETED` | User deleted / deletion in progress |
| 403 | `FORBIDDEN_ROLE` | Caller lacks the required role (e.g. VENDOR) |
| 403 | `FORBIDDEN_PERMISSION` | Admin sub-role lacks permission |
| 401 | `ADMIN_LOGIN_FAILED` | Wrong username/password or disabled account (one generic code) |
| 401 | `ADMIN_SESSION_EXPIRED` | Admin session expired, idle-timed-out or revoked |
| 403 | `ADMIN_PASSWORD_CHANGE_REQUIRED` | Admin must change the temporary password first |
| 423 | `ADMIN_ACCOUNT_LOCKED` | Too many failed logins; retry after `Retry-After` |
| 404 | `NOT_FOUND` | Resource does not exist **or** caller may not see it |
| 409 | `CONFLICT` | Generic conflict |
| 409 | `INVALID_STATE_TRANSITION` | e.g. accepting an expired quotation |
| 409 | `IDEMPOTENCY_KEY_REUSED` | Same key, different request body |
| 409 | `DUPLICATE` | Unique constraint (e.g. already wishlisted) |
| 409 | `LIMIT_REACHED` | A per-owner limit is reached (e.g. 200 checklist items per event, M9) |
| 412 | `PRECONDITION_FAILED` | `If-Match` version mismatch (optimistic concurrency) |
| 413 | `PAYLOAD_TOO_LARGE` | Body too large |
| 422 | `VALIDATION_FAILED` | Field validation errors in `details` |
| 422 | `MEDIA_INVALID` | Uploaded object failed type/size/content checks |
| 426 | `CLIENT_UPGRADE_REQUIRED` | App version no longer supported |
| 428 | `IDEMPOTENCY_KEY_REQUIRED` | Missing key on an endpoint that requires it |
| 429 | `RATE_LIMITED` | Too many requests; see `Retry-After` |
| 500 | `INTERNAL_ERROR` | Unexpected error (logged with requestId) |
| 502 | `PAYMENT_PROVIDER_ERROR` | Razorpay call failed |
| 503 | `AUTH_PROVIDER_UNAVAILABLE` | Firebase verification unavailable |
| 503 | `SERVICE_UNAVAILABLE` | Maintenance / dependency down; retryable |

## 5. Pagination (ADR-0013)

Cursor (default for mobile feeds and any list that grows or changes):
```http
GET /api/v1/events?limit=20&cursor=eyJjIjoi…
```
- `limit` default 20, max 100. Cursor is opaque (base64url of the sort key + id); clients never construct it.
- Response `meta.page`: `{ "type": "cursor", "limit": 20, "nextCursor": "…" | null, "hasMore": true }`.

Offset (admin tables needing page numbers / totals):
```http
GET /api/v1/admin/vendors/applications?page=2&pageSize=50
```
- `pageSize` default 25, max 100. Response `meta.page`: `{ "type": "offset", "page": 2, "pageSize": 50, "totalItems": 312, "totalPages": 7 }`.

## 6. Filtering and sorting

```http
GET /api/v1/listings?categoryId=…&city=chennai&minStartingPrice=25000.00&sort=-startingPrice,createdAt
```
- Filters are explicit, documented query parameters per endpoint (no generic query language). Unknown filter → `422`.
- `sort` = comma-separated whitelisted fields, `-` prefix = descending. Every sort ends with `id` as a tiebreaker server-side for stable pagination.
- Text search uses `q` where supported.

## 7. Date and time

- Instants: ISO-8601 UTC with `Z`, millisecond precision — `"createdAt": "2026-10-06T09:54:11.000Z"`.
- Calendar dates without time (e.g. event date): `"eventDate": "2026-12-14"` plus the event's IANA zone `"timeZone": "Asia/Kolkata"` when time-of-day matters.
- Clients display in device local time; the server never formats dates for display.

## 8. Money (ADR-0014)

```json
"agreedBudget": { "amount": "40000.00", "currency": "INR" }
```
- `amount`: **rupees as a decimal string with exactly 2 decimals** (`"10.10"`, `"40000.00"`). Never a JSON number, never floating point.
- `currency`: ISO-4217 code; launch supports `INR` only — other codes → `422`.
- Requests use the same shape; invalid format (not 2 decimals, exponent, negative where not allowed) → `422 VALIDATION_FAILED`.
- Totals, fees and balances are computed server-side with exact decimals; clients only format for display.
- Razorpay calls convert rupees to integer paise inside the backend only; paise never appear in the API.

## 9. Idempotency

Required (`428 IDEMPOTENCY_KEY_REQUIRED` if missing) on: platform-fee order creation, payment verification, recording event payments, booking confirmation/cancellation and any other endpoint marked `Idempotent: required`.

```http
POST /api/v1/vendor/platform-fees/orders
Idempotency-Key: 4f1c2a7e-9b3d-4d61-8a0f-0c6c5b2e7d11
```
- Key: client-generated UUID per user intent (reused on retries of the same intent).
- Server stores key + caller + route + request-body hash for 24 h; repeat with the same body → the original response replayed with header `Idempotent-Replayed: true`; same key with a different body → `409 IDEMPOTENCY_KEY_REUSED`; repeat while the first is still in progress → `409 CONFLICT` (retry later).

## 10. Authentication headers

| Client | Header |
|---|---|
| User App / Vendor App | `Authorization: Bearer <Firebase ID token>` |
| Admin CMS (server-side only) | `Authorization: AdminSession <opaque admin session token>` (username/password login, ADR-0008) — Bearer Firebase tokens are rejected on `/admin/*` |
| Public routes | none (token ignored if present, except to personalise e.g. `isWishlisted`) |
| Razorpay webhooks | `X-Razorpay-Signature` (no auth header) |

## 11. Other headers

| Header | Direction | Purpose |
|---|---|---|
| `X-Request-Id` | both | Correlation; server generates if absent and always echoes |
| `X-Client` | request | App/version for support and upgrade gating |
| `Accept-Language` | request | Future localisation of server-generated notification text |
| `ETag` / `If-Match` | both | Optimistic concurrency on editable resources (event, listing, quotation) where documented |
| `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` | response | Current rate-limit bucket state (IETF draft fields) |
| `Retry-After` | response | On 429 / 503 |

## 12. Endpoint documentation template

Each endpoint added in Part B uses:

```markdown
### POST /api/v1/<path>
- Milestone: Mxx · Auth: Bearer (USER) | Public | Session (ADMIN: <permission>) · Idempotent: required | n/a
- Request: { … }            - Response 2xx: { data: … }
- Errors: codes …           - Pagination/filter/sort: …
- Authorization rule: …     - Notification side effects: matrix row …
- Audit: action name …
```

# Part B — Endpoint catalogue

### GET /api/v1/health/live
- Milestone: M3 · Auth: Public · Idempotent: n/a
- Response 200: `{ "data": { "status": "ok" }, "meta": { "requestId": "…" } }`
- Errors: none expected (process liveness only; no dependency checks).
- Authorization: none. Notification side effects: none. Audit: none.

### GET /api/v1/health/ready
- Milestone: M3 · Auth: Public · Idempotent: n/a
- Response 200: `{ "data": { "status": "ok", "checks": { "database": "up" } }, "meta": { "requestId": "…" } }`
- Errors: `503 SERVICE_UNAVAILABLE` when PostgreSQL does not answer `SELECT 1` within 2 s (the API keeps running and reconnects in the background).
- Authorization: none. Notification side effects: none. Audit: none.

All responses carry `X-Request-Id` (incoming value echoed if it matches `[A-Za-z0-9-]{8,128}`, otherwise a new UUID).

### POST /api/v1/auth/session
- Milestone: M5 · Auth: Bearer Firebase ID token (revocation checked); the platform user may not exist yet · Idempotent: naturally (repeat calls return the same user)
- Request: no body. Identity comes only from the verified token.
- Response 200: `{ "data": { "user": { "id", "displayName", "phone", "email", "status", "roles": ["USER"], "createdAt" }, "isNewUser": true } }`
- Errors: 401 `AUTH_REQUIRED` / `AUTH_TOKEN_EXPIRED` / `AUTH_TOKEN_INVALID` / `AUTH_TOKEN_REVOKED`; 403 `ACCOUNT_SUSPENDED` / `ACCOUNT_DELETED`; 429 `RATE_LIMITED` (60/min per IP, checked before token verification); 503 `AUTH_PROVIDER_UNAVAILABLE`.
- Rules: first call creates the user (role `USER`); email stored only when `email_verified`; phone refreshed from the token.
- Side effects: audit `AUTH_SIGN_UP` (first) or `AUTH_SIGN_IN`; notification N1 `WELCOME` (in-app only, first call).

### POST /api/v1/auth/sign-out
- Milestone: M5 · Auth: Bearer (registered user) · Response: 204
- Revokes the user's Firebase refresh tokens (all devices); routes without revocation checks accept the current ID token until it expires (≤ 1 h).
- Errors: 401/403 as above; 429 `RATE_LIMITED`; 503 `AUTH_PROVIDER_UNAVAILABLE`. Audit: `AUTH_SIGN_OUT`.

### GET /api/v1/me
- Milestone: M5 · Auth: Bearer (registered user)
- Response 200: `{ "data": { "id", "displayName", "phone", "email", "status", "roles", "createdAt" } }`
- Errors: 401 `AUTH_REQUIRED` (no token, or the identity has no platform user yet — the app then calls `/auth/session`), other auth errors as above.

All non-public routes are protected by default (global guard); only `/health/*` is public.

### Events (M8)
Shared rules for every `/events` route:
- Auth: Bearer (registered user). Only the caller's own, non-deleted events are visible. Another user's event, a deleted event or a malformed id → `404 NOT_FOUND` (never 403).
- `EventDto`: `{ id, eventType, title, eventDate: "YYYY-MM-DD", startTime: "HH:mm" | null, timeZone (IANA), city, venueName | null, venueAddress | null, guestCountEstimate | null, totalBudget: { amount: "400000.50", currency: "INR" } | null, status: PLANNING | COMPLETED | CANCELLED, version, createdAt, updatedAt }`.
- Field rules: `eventType` free text 1–60 (O1), `title` 1–100, `city` 1–80, `venueName` 1–120, `venueAddress` 1–300 (strings trimmed), `guestCountEstimate` 0–100000, `startTime` 24-hour `HH:mm`, `timeZone` IANA Region/City name or `UTC` that PostgreSQL also knows (default `Asia/Kolkata`; offsets such as `+05:30`, POSIX rules and `Etc/*` → 422 `UNKNOWN_TIME_ZONE`/validation error), `eventDate` real date 2000–2100. Unknown properties → 422.
- Writes are rate limited (120/min per IP, bucket `events-write`) and audited. Notifications: none (the owner's own action; evaluated in M8).

### POST /api/v1/events
- Milestone: M8 · Idempotent: **required** (`Idempotency-Key`, 8–128 letters/digits/dashes; replay returns the original `201` with `Idempotent-Replayed: true`; same key + different body → `409 IDEMPOTENCY_KEY_REUSED`; same key still running → `409 CONFLICT` (a key stuck in progress for over 60 s, e.g. after a crash, is reclaimed); missing → `428 IDEMPOTENCY_KEY_REQUIRED`).
- Request: `{ eventType, title, eventDate, city, startTime?, timeZone?, venueName?, venueAddress?, guestCountEstimate?, totalBudget? }`.
- Response 201: `{ data: EventDto }`. Errors: 422 `VALIDATION_FAILED` (field `eventDate` code `MUST_NOT_BE_PAST` when before today in the event's zone).
- Audit: `EVENT_CREATED`.

### GET /api/v1/events
- Milestone: M8 · Query: `scope` = `all` (default) | `upcoming` (PLANNING and dated today or later in the event's zone) | `past` (everything else); `status`; `limit` 1–100 (default 20); `cursor`.
- Sort: `upcoming` and `all` by `eventDate` ascending (so `all` lists the oldest first — it is not "upcoming first"), `past` descending; `id` tiebreaker. Cursor pagination (`meta.page`, ADR-0013). A cursor only continues the scope it came from; an invalid or foreign cursor → 422 `INVALID_CURSOR`.

### GET /api/v1/events/{id}
- Milestone: M8 · Response 200: `{ data: EventDto }` · Errors: 404.

### PATCH /api/v1/events/{id}
- Milestone: M8 · Optimistic concurrency via body `version` (the version last read) — chosen over `If-Match` to keep the mobile client simple; mismatch → `412 PRECONDITION_FAILED`.
- Request: any subset of the create fields plus required `version`; `null` clears an optional field; required fields cannot be null. Moving an existing event to a past date is allowed (M8 answer 4).
- Response 200: `{ data: EventDto }` (version + 1 when something changed). Audit: `EVENT_UPDATED` with the changed field names.

### POST /api/v1/events/{id}/cancel · /reopen · /complete
- Milestone: M8 · Response 200: `{ data: EventDto }`. State machine (domain-model.md §4.6): cancel and complete only from PLANNING; reopen from COMPLETED/CANCELLED only while `eventDate` is today or later in the event's zone. Otherwise `409 INVALID_STATE_TRANSITION`.
- Audit: `EVENT_CANCELLED`, `EVENT_REOPENED`, `EVENT_COMPLETED`.

### DELETE /api/v1/events/{id}
- Milestone: M8 · Response 204. Soft delete (`deleted_at`, R11): the row is kept and hidden from every route. Audit: `EVENT_DELETED`.

### Checklist (M9)
Shared rules for `/events/{eventId}/checklist…`:
- Auth: Bearer (registered user). The parent event must be the caller's own and not deleted; otherwise (or a malformed id, or an item of another event) → `404 NOT_FOUND`.
- Writes need the event to be PLANNING (M9 answer 2: completed/cancelled → read only) → otherwise `409 INVALID_STATE_TRANSITION`. Writes are rate limited (300/min per IP, bucket `checklist-write`) and audited (`CHECKLIST_ITEM_CREATED|UPDATED|COMPLETED|REOPENED|DELETED`, `CHECKLIST_REORDERED`; summaries hold ids/field names only, never titles or notes).
- `ChecklistItemDto`: `{ id, title (1–120), notes (≤ 1000) | null, dueDate "YYYY-MM-DD" | null, status: PENDING | DONE, isOverdue, completedAt | null, sortOrder, version, createdAt, updatedAt }`. `isOverdue` = PENDING with a due date before today in the event's time zone (derived, §4.12). Past due dates are accepted.
- `ChecklistDto`: `{ eventId, isEditable, summary: { total, done, overdue }, items: ChecklistItemDto[] }` (items in the user's order).
- `EventDto` (all event routes) gains `checklist: { total, done, overdue }` (one aggregate query per list page) and, from M10, `cover` (see Media uploads).
- Notifications: none for owner changes; due/overdue notifications (N16) are built with Reminders in M17 (push M18).

### GET /api/v1/events/{eventId}/checklist
- Milestone: M9 · Response 200: `{ data: ChecklistDto }`. Readable for any non-deleted own event (also completed/cancelled).

### POST /api/v1/events/{eventId}/checklist
- Milestone: M9 · Idempotent: **required** (as `POST /events`). Request `{ title, notes?, dueDate? }`. Response 201 `{ data: ChecklistItemDto }` (appended at the end). At most 200 non-deleted items per event → `409 LIMIT_REACHED`.

### PATCH /api/v1/events/{eventId}/checklist/{itemId}
- Milestone: M9 · Request: any of `title`, `notes`, `dueDate` (`null` clears notes/due date; title cannot be null) plus required `version` → `412 PRECONDITION_FAILED` when stale. Response 200 `{ data: ChecklistItemDto }`.

### POST …/checklist/{itemId}/complete · …/{itemId}/reopen
- Milestone: M9 · PENDING → DONE sets `completedAt`; DONE → PENDING clears it. Same state again → `409 INVALID_STATE_TRANSITION`. Response 200 `{ data: ChecklistItemDto }`.

### PUT /api/v1/events/{eventId}/checklist/order
- Milestone: M9 · Request `{ itemIds: uuid[] }` = every non-deleted item exactly once, in the new order (else `422 ITEMS_MISMATCH`). Response 200 `{ data: ChecklistDto }`. Order is presentation only: item `version`s do not change.

### DELETE /api/v1/events/{eventId}/checklist/{itemId}
- Milestone: M9 · Response 204. Soft delete (R11).

### Media uploads and event cover (M10)
Flow (media-and-deep-links.md §3): `POST /media/uploads` → app uploads the file **directly to ImageKit** with the returned parameters → `POST /media/uploads/{mediaId}/complete` → `PUT /events/{id}/cover`. All routes: Bearer (registered user); 10 requests/min per IP (`media-upload`); without ImageKit settings → `503 SERVICE_UNAVAILABLE`.

### POST /api/v1/media/uploads
- Milestone: M10 · Request `{ kind: "EVENT_COVER", ownerId: <eventId>, contentType: image/jpeg|png|webp|heic|heif, sizeBytes ≤ 5242880 }`. The event must be the caller's and not deleted (else 404).
- Response 201 `{ data: { mediaId, uploadUrl, token, fields, expire, maxBytes } }` — ImageKit **upload API v2**: `token` is a single-use JWT (HS256, private key, 10-minute expiry) that signs every entry of `fields` (`fileName`, `folder` = `/{root}/event-cover/event/{eventId}`, `isPrivateFile: "true"`, `useUniqueFileName: "false"`, `overwriteFile: "false"`, `checks`). The app posts `file` + `token` + `fields` unchanged; ImageKit rejects changed fields or a reused token. At most 3 unfinished uploads per event (`409 LIMIT_REACHED`).

### POST /api/v1/media/uploads/{mediaId}/complete
- Milestone: M10 · Request `{ fileId }` (ImageKit file id). Only the uploader; else 404. The server fetches the file from ImageKit and requires the exact reserved path, a private file, an allowed MIME type and ≤ 5 MB; otherwise the file is deleted (if at the reserved path), the media row becomes REJECTED and `422 MEDIA_INVALID` is returned with `details[0].code` = `NOT_FOUND | WRONG_PATH | NOT_PRIVATE | TYPE_NOT_ALLOWED | EMPTY | TOO_LARGE` (audited as `MEDIA_REJECTED`). Repeating a successful completion is harmless; two concurrent completions cannot both succeed.
- Response 200 `{ data: { mediaId, status: "READY" } }`. Audit `MEDIA_UPLOADED`.

### PUT /api/v1/events/{id}/cover · DELETE /api/v1/events/{id}/cover
- Milestone: M10 · PUT `{ mediaId }` (a READY EVENT_COVER of this event uploaded by the caller, else `422 MEDIA_INVALID`/`MEDIA_NOT_READY`) → 200 `{ data: EventDto }`. The previous cover is soft-deleted. DELETE removes the cover → 200 `{ data: EventDto }`. Audit `EVENT_COVER_SET` / `EVENT_COVER_REMOVED`.
- `EventDto.cover`: `{ mediaId, url, thumbnailUrl, expiresAt } | null` — signed ImageKit URLs of resized variants (`w-1200` / `w-480`, `f-auto`, `md-false` = no EXIF/GPS metadata), valid 15 minutes; clients cache images by `mediaId` + variant, not by URL. Originals are never served.

### GET /api/v1/vendor-categories
- Milestone: M11 · Auth: **Public** · Response 200 `{ data: [{ id, name, slug, sortOrder }] }` — PUBLISHED categories in display order (seeded starter list; admin management M42; reused by vendor discovery M12). Rate limited 120/min per IP (`categories-read`); `Cache-Control: public, max-age=300`.

### Event budget (M11)
Owner-only through the event (another user's/deleted event, malformed or unpublished category → 404). Writes need a PLANNING event (else `409 INVALID_STATE_TRANSITION`), are rate limited (120/min per IP, `budget-write`) and audited (`BUDGET_ALLOCATION_SET` with `{ categoryId, created }`, `BUDGET_ALLOCATION_CLEARED` — amounts are not copied into the audit log). All figures are computed server-side with exact decimals (ADR-0014); listing starting prices never appear. No notifications.
- `BudgetDto`: `{ eventId, isEditable, totalBudget: Money | null, planned: Money, unplanned: Money | null, isOverPlanned, committed: Money, paid: Money, expenses: Money, spent: Money, remaining: Money | null, categories: [{ categoryId, name, isArchived, planned: Money | null, committed: Money, paid: Money, expenses: Money }] }`. Lines are the PUBLISHED categories plus any no-longer-published category the event still has a plan for (`isArchived: true`, listed last; it can be cleared but not set). `unplanned` = total − planned (null without a total; **negative**, e.g. `"-100000.00"`, when over-planned; `unplanned` and `remaining` are the only Money fields that can be negative). `committed`/`paid` are `"0.00"` until bookings (M15) and payment notes (M16); `expenses` = the user's own expenses; `spent` = paid + expenses; `remaining` = total − committed − expenses (null without a total; **negative** when over). A no-longer-offered category is also listed when it has own expenses.

### GET /api/v1/events/{eventId}/budget
- Milestone: M11 · Response 200 `{ data: BudgetDto }` (also for completed/cancelled events, `isEditable: false`).

### PUT /api/v1/events/{eventId}/budget/allocations/{categoryId} · DELETE …
- Milestone: M11 · PUT `{ planned: { amount: "40000.00", currency: "INR" } }` (≥ 0, exact two decimals, currency must be the event's currency else `422 VALIDATION_FAILED`) → 200 `{ data: BudgetDto }`; repeating the same amount changes nothing (naturally idempotent). DELETE clears the plan (soft delete) → 200 `{ data: BudgetDto }`; clearing a category with no plan (including an archived one) is a no-op that still returns the budget. The total budget stays on the event (`PATCH /events/{id}` `totalBudget`).

### Vendor discovery (M12)
Public (guests allowed), read only, rate limited 120/min per IP (`listings-read`). A listing is visible only when it is `APPROVED`, its vendor is `ACTIVE` and its category is `PUBLISHED`. No private vendor fields (owner user id, phone, email, unapproved changes) are returned; contact details come with the details page (M13). No notifications.
- `ListingCardDto`: `{ id, title, category: { id, name, slug }, vendor: { id, businessName }, city, serviceAreas: string[], startingPrice: Money, rating: { average: "4.5" | null, count }, coverImageUrl: null (until M28), publishedAt }`. `startingPrice` is marketplace information only — never a budget or agreed amount.

### GET /api/v1/listings
- Query (all optional; unknown parameters → 422): `categoryId` (uuid), `city` (1–80, trimmed; case-insensitive match on the listing city **or** any service area — O2), `q` (1–100, trimmed; listing title, vendor name or category name; `%`/`_` are plain text), `minStartingPrice` / `maxStartingPrice` (exact `"25000.00"` strings; max < min → 422 `RANGE_INVERTED`), `sort` (`-publishedAt` newest, `startingPrice`, `-startingPrice`; omitted = relevance: title starts with `q`, then title contains, vendor name, category name; then newest), `limit` (1–50, default 20), `cursor`.
- Response 200 `{ data: ListingCardDto[], meta: { page: { type: "cursor", limit, nextCursor, hasMore } } }`. Every sort ends with `id`; a cursor only continues the exact search (filters + sort) it came from (else 422 `INVALID_CURSOR`).

### GET /api/v1/listings/{id} (M13)
- Auth: **optional** (`@OptionalAuth`): no token → guest; a valid token of a registered user → signed in; a token of a not-yet-registered Firebase user → guest; an invalid/expired token → 401 (the app refreshes it). Rate limited (`listings-read`).
- Response 200 `{ data: ListingDetailDto }` = `ListingCardDto` + `{ description: string | null, photos: [] (until M28), vendor: { id, businessName, description, city, serviceAreas, contact: { phone, email } | null } }`. `contact` is **null for guests** (A10, M13 answer 1); either field may be null when the vendor has not added it.
- 404 when the listing is not visible (draft, in review, rejected, suspended/archived, vendor not ACTIVE, category not PUBLISHED), unknown or malformed.

### GET /api/v1/listings/{id}/related (M13)
- Public, rate limited. Response 200 `{ data: { sameVendor: ListingCardDto[], similar: ListingCardDto[] } }`: up to 6 other visible listings of the same vendor, and up to 6 visible listings of **other** vendors in the same category whose city or service areas include the listing's city; both newest first. 404 as above.

### Saved vendors (M14)
Signed-in only; private to the user; rate limited (`wishlist-write`, 120/min) on writes.
- `GET /api/v1/me/wishlist?limit&cursor` → `{ data: [{ listing: ListingCardDto, isAvailable, savedAt }], meta.page }`, newest first. `isAvailable: false` when the listing was hidden after saving.
- `GET /api/v1/me/wishlist/ids` → `{ data: string[] }` (all saved listing ids, ≤ 500; heart state).
- `PUT /api/v1/me/wishlist/{listingId}` → 204, idempotent; only visible listings (else 404); at most 500 (409 `LIMIT_REACHED`). `DELETE …` → 204 (soft delete; no-op if not saved).
- `GET /api/v1/listings?saved=true` (optional auth): only the caller's saved listings; guests → 401 `AUTH_REQUIRED`.

### Event vendors (M14)
Owner-only through the event (another user's/deleted event → 404); writes need a PLANNING event (409 `INVALID_STATE_TRANSITION`), rate limited (`event-vendors-write` 120/min) and audited (`EVENT_VENDOR_ADDED/UPDATED/REMOVED`, ids and field names only). No amounts here (agreed amounts are bookings, M15).
- `EventVendorDto`: `{ id, status: ADDED|ENQUIRED|QUOTED|BOOKED|COMPLETED|CANCELLED, notes (private), listing: ListingCardDto, isAvailable, enquiries: EnquiryDto[] (newest first), canEnquire, version, createdAt }`; `EnquiryDto`: `{ id, status: OPEN|QUOTED|DECLINED|CLOSED, message, preferredDate, closedBy: USER|VENDOR|SYSTEM|null, closedAt, createdAt }`.
- `GET /api/v1/events/{id}/vendors` → `{ data: { eventId, isEditable, vendors: EventVendorDto[] } }` (REMOVED ones excluded).
- `POST /api/v1/events/{id}/vendors` `{ listingId }` → 201 (added) or **200 with the existing vendor** (already on the event; naturally idempotent). Visible listings only (404); your own listing → 403 `FORBIDDEN_PERMISSION` (A12); at most 100 per event.
- `PATCH /api/v1/events/{id}/vendors/{eventVendorId}` `{ notes?, version }` → 200; stale version → 412.
- `DELETE …/{eventVendorId}` → 204: REMOVED (from ADDED/ENQUIRED/QUOTED; else 409); its live enquiry is closed (USER). A removed listing can be added again (new row).

### Enquiries (M14)
- `POST /api/v1/events/{id}/vendors/{eventVendorId}/enquiries` — **Idempotency-Key required** (428 without) — `{ message (10–1000, trimmed), preferredDate? (YYYY-MM-DD, today or later in the event's zone) }` → 201 `{ data: EventVendorDto }` (status → ENQUIRED). One live (OPEN/QUOTED) enquiry per event vendor (409 `DUPLICATE`); listing must still be visible (404); own listing 403; booked vendor 409. Rate limited `enquiries-write` 20/min. Creates **N9** (in-app, audience VENDOR) for the vendor's user with A9 fields only (`customerName, eventType, eventDate, city, guestCountEstimate, listingId`); push later (M36). Audited `ENQUIRY_SENT` (ids only).
- `POST …/enquiries/{enquiryId}/close` → 200 `{ data: EventVendorDto }`: CLOSED (USER); the event vendor returns to ADDED so a new enquiry can be sent. Already closed → 409.
- Cancelling or deleting an event closes its live enquiries (SYSTEM).

### Notification Center, devices and preferences (M18)
Signed-in only; rate limited (`notifications-write` 120/min) on writes. Only the caller's USER-audience notifications are visible.
- `NotificationDto`: `{ id, category, type, title, body, entityType, entityId, deepLink, data, readAt, createdAt }` (`data.eventId` routes the app to the event).
- `GET /api/v1/me/notifications?limit&cursor` (≤ 50, newest first, cursor bound to created time + id) → `{ data: NotificationDto[], meta.page }`.
- `GET /api/v1/me/notifications/unread-count` → `{ data: { count } }`. `POST /api/v1/me/notifications/{id}/read` → 204 (404 for others' ids). `POST /api/v1/me/notifications/read-all` → `{ data: { updated } }`.
- `PUT /api/v1/me/devices` `{ token (20–4096), platform: ANDROID|IOS, appVersion? }` → 204: registers this phone; a token already registered to someone else moves to the caller (shared phone). `DELETE /api/v1/me/devices/{token}` → 204 (sign-out; no-op if not the caller's).
- `GET /api/v1/me/notification-preferences` → `{ data: [{ group: BOOKINGS|REMINDERS|OTHER, pushEnabled }] }` (all on by default); `PUT` `{ preferences: [{ group, pushEnabled }] }` → the full list. Turning a group off stops pushes only; in-app records are always created.
- Push delivery: user records of types QUOTATION_RECEIVED, BOOKING_CONFIRMED/CANCELLED/COMPLETED, REMINDER_DUE, CHECKLIST_DUE_TODAY/OVERDUE are queued (`delivery_status PENDING`) in the same transaction and sent by the push worker every 10 s; payload `data` carries only `notificationId`, `type`, `entityType`, `entityId`, `deepLink`, `eventId` (no personal data). Invalid tokens are deactivated; transient failures retry after 2/4/8/16 minutes, FAILED after 5 attempts. Vendor-audience records stay in-app until M36.

### Reminders (M17, §4.13)
Owner-only through the event (404 otherwise); writes need a PLANNING event (409), rate limited (`reminders-write` 120/min), audited (`REMINDER_CREATED/UPDATED/CANCELLED`, ids and field names only — no titles).
- `ReminderDto`: `{ id, eventId, eventTitle, title, remindAt (ISO instant, UTC), status: SCHEDULED|SENT|CANCELLED, checklistItemId, checklistItemTitle, sentAt, seenAt, cancelReason: USER|TASK_DONE|TASK_DELETED|EVENT_CANCELLED|EVENT_DELETED|null, version }`.
- `GET /api/v1/events/{id}/reminders` → `{ data: { eventId, isEditable, upcoming: ReminderDto[] (soonest first), past: ReminderDto[] (newest first, ≤ 50) } }`.
- `POST /api/v1/events/{id}/reminders` — **Idempotency-Key required** — `{ title (1–120, trimmed), remindAt (ISO-8601 with offset, in the future), checklistItemId? (a live task of this event) }` → 201; at most 200 scheduled per event (409 `LIMIT_REACHED`).
- `PATCH …/reminders/{reminderId}` (`title?`, `remindAt?`, `checklistItemId?`, `version`) → 200; only SCHEDULED (409); stale version → 412.
- `POST …/reminders/{reminderId}/cancel` → 200 (SCHEDULED → CANCELLED, reason USER). `POST …/reminders/{reminderId}/seen` → 204 (dismisses the in-app "due" banner; any event status).
- `GET /api/v1/me/reminders?scope=upcoming|due&limit` (≤ 50) → `{ data: ReminderDto[] }`: scheduled across the user's events (soonest first), or sent and not yet seen.
- Server jobs: due reminders → SENT + N17 (every minute); checklist N16 "due today"/"overdue" once per task per state from 09:00 event-local (every 15 minutes). Auto-cancel: task done or deleted, event cancelled or deleted.

### Payments (M16; R5, A2, A3, A11)
The user's **private payment notes** per booking — records only, no money moves, nothing is verified, no notifications (A2). Owner-only through the event (another user's/deleted event or unknown booking → 404). Allowed for CONFIRMED, COMPLETED and CANCELLED bookings (A11) while the event is PLANNING, COMPLETED or CANCELLED. Rate limited (`payments-write`, 120/min); audited (`PAYMENT_NOTE_CREATED/UPDATED/DELETED`, ids and field names only — no amounts or notes).
- `PaymentDto`: `{ id, amount: Money, paidOn: "YYYY-MM-DD", method: CASH|UPI|BANK_TRANSFER|CARD|CHEQUE|OTHER, kind: ADVANCE|INSTALMENT|FINAL|OTHER, note, version, createdAt }`.
- `GET /api/v1/events/{id}/bookings/{bookingId}/payments` → `{ data: { bookingId, bookingStatus, agreedAmount, paid, balance: Money | null, overpaidBy: Money | null, payments: PaymentDto[] } }` (newest first; exact decimals).
- `POST …/payments` — **Idempotency-Key required** — `{ amount (> 0, exact two decimals, booking currency), paidOn (not in the future, event time zone), method, kind, note? (≤ 1000; blank → null) }` → 201 `{ data: PaymentDto }`; at most 100 per booking (409 `LIMIT_REACHED`).
- `PATCH …/payments/{paymentId}` (any create field + `version`; stale → 412) → 200; `DELETE …/payments/{paymentId}` → 204 (soft delete).
- `BookingDto` gains `paid: Money`. Budget gains `paid` (all notes, A11), `paidToCancelled`, `outstanding` (Σ positive balances of active bookings), per-category `paid`; `spent` = paid + own expenses.

### Quotations and bookings (M15, R3 + A7)
Event vendors (`EventVendorDto`) also carry `quotations: QuotationDto[]` (newest first, all revisions) and `booking: BookingDto | null` (the active booking, else the latest cancelled one).
- `QuotationDto`: `{ id, enquiryId, status: SENT|EXPIRED|ACCEPTED|REJECTED|SUPERSEDED|WITHDRAWN, amount: Money, description, validUntil (the event date when the vendor set none), revisionNo, createdAt, respondedAt }`. EXPIRED is derived: a SENT quote whose `validUntil` is before today in the event's time zone.
- `BookingDto`: `{ id, status: CONFIRMED|CANCELLED|COMPLETED, agreedAmount: Money, serviceDate, cancelledBy, cancelReason, completedAt, createdAt, canCancel, canComplete }`.
- `POST /api/v1/events/{id}/vendors/{eventVendorId}/quotations/{quotationId}/accept` — **Idempotency-Key required** (428) → 200 `{ data: EventVendorDto }`. PLANNING event, quote SENT and not expired, listing still visible. One transaction: quote ACCEPTED, booking CONFIRMED with `agreedAmount` **copied server-side from the quote** (never sent by the client), `serviceDate` = the enquiry's preferred date else the event date, event vendor BOOKED, enquiry CLOSED (SYSTEM). N11 to the vendor, N12 to both. Errors: 409 `INVALID_STATE_TRANSITION` (superseded / withdrawn / already answered / expired), 404.
- `POST …/quotations/{quotationId}/reject` → 200: REJECTED; the enquiry reopens (OPEN) and the event vendor returns to ENQUIRED for a new quote. N11.
- `POST /api/v1/events/{id}/vendors/{eventVendorId}/booking/cancel` `{ reason (3–500) }` → 200: CONFIRMED → CANCELLED (USER); allowed while the event is PLANNING or CANCELLED (not COMPLETED); event vendor CANCELLED, a new enquiry is allowed. N13 to the vendor (with the reason); the audit log keeps ids only.
- `POST …/booking/complete` → 200: CONFIRMED → COMPLETED on or after the service date (409 before). An hourly job completes CONFIRMED bookings the day after their service date and creates N14 for the user.
- Budget: `committed` (and per-category `committed`) = Σ `agreedAmount` of CONFIRMED + COMPLETED bookings; `remaining` = total − committed − own expenses.

### GET /api/v1/listings/cities
- Response 200 `{ data: string[] }`: the cities and service areas of visible listings, case-insensitively unique, alphabetical, at most 500. `Cache-Control: public, max-age=300`.

### Own expenses (M11, user answer 5)
Same access rules as the budget: owner-only through the event (another user's/deleted event, unknown expense → 404), writes only while the event is PLANNING (`409 INVALID_STATE_TRANSITION`), rate limited with the budget (`budget-write`, 120/min per IP), audited (`EXPENSE_CREATED`, `EXPENSE_UPDATED` with changed field names, `EXPENSE_DELETED`; ids only — no amounts or text). No notifications. Records only: no money moves (payment-architecture §2.1).
- `ExpenseDto`: `{ id, title, amount: Money, spentOn: "YYYY-MM-DD", categoryId: uuid | null, categoryName: string | null, note: string | null, version, createdAt, updatedAt }`.

### GET /api/v1/events/{eventId}/expenses
- Response 200 `{ data: { eventId, isEditable, total: Money, expenses: ExpenseDto[] } }`, newest first (`spentOn` desc, then creation). At most 500 per event, so no pagination.

### POST /api/v1/events/{eventId}/expenses
- `Idempotency-Key` required (missing → 428). Body `{ title (1–120, trimmed), amount: Money (> 0, exact two decimals, event currency), spentOn: "YYYY-MM-DD", categoryId?: uuid | null (an offered category), note?: string | null (≤ 1000; blank → null) }` → 201 `{ data: ExpenseDto }`. Errors: 422 `VALIDATION_FAILED` (`AMOUNT_NOT_POSITIVE`, `CURRENCY_MISMATCH`, `UNKNOWN_CATEGORY`, field errors), 409 `LIMIT_REACHED` (500).

### PATCH /api/v1/events/{eventId}/expenses/{expenseId} · DELETE …
- PATCH: any of the create fields plus required `version` → 200 `{ data: ExpenseDto }`; stale version → 412 `PRECONDITION_FAILED`. A category that is no longer offered may stay on the expense but cannot be newly chosen. DELETE → 204 (soft delete).

### Background: event auto-complete (no endpoint)
- Hourly in-process job (disabled with `BACKGROUND_JOBS_ENABLED=false`): PLANNING events whose date is before today in their zone become COMPLETED. Audit: `EVENT_AUTO_COMPLETED` (actor `SYSTEM`). No notification.

