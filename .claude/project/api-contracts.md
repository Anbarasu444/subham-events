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

## 8. Money (ADR-0014 — deferred to M2)

User direction: amounts are expressed in **rupees with 2 decimals** (e.g. `10.10`), currency `INR` only at launch. The exact wire/storage type is decided in M2:

- Option A (recommended, exact): `"agreedBudget": { "amount": "40000.00", "currency": "INR" }` — decimal string, `numeric(12,2)` in PostgreSQL.
- Option B (floating point): `"agreedBudget": { "amount": 40000.0, "currency": "INR" }` — requires amending CLAUDE.md §21.

Rules that hold either way: totals and fees are computed server-side; clients only format for display; Razorpay calls convert rupees to integer paise at the backend boundary; non-INR currencies → `422`.

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

_None yet. First endpoints expected in M3 (`/health/*`) and M5 (`/auth/*`)._
