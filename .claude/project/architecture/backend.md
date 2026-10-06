# Backend Architecture (NestJS)

> M1 deliverable for spec item 2 / AC-2. Design only — no code is written in M1. NestJS 11 (ADR-0003); data access with TypeORM per ADR-0006 (Accepted).

## 1. Process model

One NestJS codebase in `backend/`, two entry points:

| Entry | Command (planned) | Runs |
|---|---|---|
| `main.ts` | `node dist/main` | HTTP API (`/api/v1`) |
| `worker.ts` | `node dist/worker` | Job runner: outbox/jobs polling, scheduled tasks (reminders, reconciliation, cleanup) |

Both share modules; the worker simply does not mount HTTP controllers.

## 2. Layering inside every module

```text
Controller (HTTP only: routing, DTO validation, auth decorators, response mapping)
   ↓
Application service (use cases, transactions, authorization policies, orchestration, emits notifications/audit)
   ↓
Domain (entities/value objects/state machines — pure TypeScript, no NestJS/DB imports)
   ↓
Repository (data access only via TypeORM entities/repositories; returns domain objects; the only layer that imports TypeORM)
   ↓
PostgreSQL
```

Rules:
- Controllers contain no business logic and never touch repositories directly.
- Services are the transaction boundary. A use case that changes state opens one DB transaction covering: domain write(s), `audit_logs` row, `notifications` row(s), `jobs` outbox row(s).
- State transitions are implemented as explicit state-machine functions in the domain layer (`canTransition(from, to, actor)`), unit-tested exhaustively.
- Cross-module calls go through the other module's exported **service interface**, never its repository.
- Integrations (Firebase, Razorpay, ImageKit) are wrapped in adapter providers behind interfaces so services are testable with fakes.

Folder layout per module:

```text
backend/src/modules/<module>/
  <module>.module.ts
  controllers/        # one per audience if needed: <x>.controller.ts, <x>.vendor.controller.ts, <x>.admin.controller.ts
  dto/                # request/response DTOs (class-validator / class-transformer)
  services/
  domain/             # entities, value objects, state machines, domain errors
  repositories/
  <module>.constants.ts
backend/src/common/        # cross-cutting (see §4)
backend/src/integrations/  # firebase/, razorpay/, imagekit/ adapters
backend/src/config/        # typed config schema + loader
backend/src/database/      # TypeORM DataSource (shared by app + migration CLI), transaction helper
```

## 3. Module map (through M73)

Audience column: **U** = user routes, **V** = vendor routes (`/vendor/...`), **A** = admin routes (`/admin/...`), **P** = public/guest, **—** = internal only.

| # | Module | Responsibility | Audience | May depend on | First milestone |
|---|---|---|---|---|---|
| 1 | `health` | Liveness/readiness, build info | P | `database` | M3 |
| 2 | `auth` | Firebase token / session-cookie verification guard, `/auth/session`, sign-out, account linking | U V A | `users`, `integrations/firebase`, `audit` | M5 |
| 3 | `users` | User profile, preferences, account status, deletion requests | U A | `media`, `audit` | M5 |
| 4 | `rbac` | Role & permission definitions, policy helpers, admin sub-roles | — | — (leaf) | M5 |
| 4a | `admin-auth` | Admin accounts (username + argon2id password), login, lockout, sessions, password change/reset by SUPER_ADMIN, bootstrap CLI | A | `rbac`, `audit` | M40 |
| 5 | `notifications` | Notification records, device registry, read state, FCM fan-out jobs, preferences | U V A | `users`, `integrations/firebase`, `jobs` | M5 (devices: M18) |
| 6 | `audit` | Append-only audit log of privileged & state-changing actions | A | — (leaf) | M5 |
| 7 | `media` | Upload intents (ImageKit auth params), upload verification, signed delivery URLs, ownership, variants | U V A | `integrations/imagekit`, `audit`, `jobs` | M8 |
| 8 | `categories` | Admin-defined vendor categories, platform-fee config reference | P V A | `media`, `audit` | M12 |
| 9 | `vendors` | Vendor profile, verification status | P V A | `users`, `media`, `audit`, `notifications` | M12 (read), M26 (write) |
| 10 | `listings` | Vendor category listings, starting price, portfolio, approval lifecycle, marketplace visibility | P V A | `vendors`, `categories`, `media`, `platform-fees` (read-only check), `notifications`, `audit` | M12 (read), M28 (write) |
| 11 | `events` | User events (central planning entity), event overview | U A | `users`, `media`, `audit` | M8 |
| 12 | `checklist` | Checklist items, progress, due/overdue | U | `events`, `notifications` | M9 |
| 13 | `budget` | Event budget, allocations, planned vs agreed vs paid | U | `events`, `event-vendors`, `event-payments` | M11 |
| 14 | `event-vendors` | Event ↔ vendor relationship: agreed budget, relationship status | U V A | `events`, `listings` | M11/M14 |
| 15 | `wishlist` | Saved vendors/listings | U | `listings` | M14 |
| 16 | `enquiries` | User → vendor enquiries | U V A | `event-vendors`, `notifications`, `audit` | M14 |
| 17 | `quotations` | Vendor quotations, revisions, accept/reject | U V A | `enquiries`, `event-vendors`, `notifications`, `audit` | M15 |
| 18 | `bookings` | Booking lifecycle (confirmed/cancelled/completed) | U V A | `quotations`, `event-vendors`, `notifications`, `audit` | M15 |
| 19 | `event-payments` | Event/vendor payment records against bookings (not platform fees) | U V A | `bookings`, `notifications`, `audit` | M16 |
| 20 | `reminders` | User reminders, scheduling via jobs | U | `events`, `checklist`, `notifications`, `jobs` | M17 |
| 21 | `invitations` | Templates, generation, share tokens, public invitation page data | U P | `events`, `media` | M19 |
| 22 | `reviews` | Ratings/reviews, eligibility (completed booking), moderation | U V A P | `bookings`, `vendors`, `notifications`, `audit` | M20 |
| 23 | `platform-fees` | Fee schedule, Razorpay orders, verification, webhooks, `platform_fee_transactions` | V A | `integrations/razorpay`, `notifications`, `audit`, `jobs` | M29 |
| 24 | `content` | CMS-managed content (banners, FAQs, terms) | P A | `media`, `audit` | M51 |
| 25 | `reports` | Read-only aggregates for admin reporting | A | read-only access to other modules' query services | M52 |
| 26 | `jobs` | Outbox/job table, worker loop, scheduler, retry/backoff | — | `database` | M5 (first async need) |

Dependency rules:
- Leaf modules (`rbac`, `audit`, `jobs`) depend on nothing domain-specific.
- `platform-fees` and `event-payments` **never** depend on each other.
- `listings` may query `platform-fees` (is the submission's fee paid?) but `platform-fees` never calls `listings`; it emits a domain event (`PlatformFeePaid`) that `listings` consumes.
- No circular dependencies: enforced in CI with `dependency-cruiser` (planned for M3).
- `reports` reads only; nothing depends on it.

Admin is **not** a separate module: each domain module exposes `*.admin.controller.ts` routes guarded by admin sub-role policies, so admin rules live next to the domain rules they govern.

## 4. Cross-cutting concerns

| Concern | Design | Where |
|---|---|---|
| Configuration | `@nestjs/config` with a typed, validated schema (fail fast on missing/invalid vars); secrets only from environment variables (local `.env`; hosted secret store later) | `src/config` |
| Validation | Global `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })`; class-validator DTOs | global |
| Error handling | Global exception filter maps domain errors, validation errors and unknown errors to the error envelope (`api-contracts.md` §4); unknown errors → `INTERNAL_ERROR`, details logged not returned | `src/common/filters` |
| Response shaping | Interceptor wraps success responses in `{ data, meta }` | `src/common/interceptors` |
| Request IDs | Middleware reads `X-Request-Id` or generates a UUID; propagated to logs, error responses and outbound calls | `src/common/middleware` |
| Logging | Structured JSON logs (pino via `nestjs-pino`); redaction of authorization headers, cookies, ID/session tokens, FCM tokens, `Idempotency-Key`, ImageKit upload tokens/signatures and signed-URL query parameters (`ik-s`, `ik-t`), invitation tokens in `/i/{token}` paths, phone numbers, emails, Razorpay signatures | global |
| Authentication | Global guard (opt-out with `@Public()`): non-admin protected routes accept only a Firebase Bearer ID token (`FirebaseAuthGuard`); `/admin/*` accepts only `AdminSession` tokens (`AdminSessionGuard`, backend-managed username/password sessions, ADR-0008); attaches `RequestUser` or `RequestAdmin` | `auth`, `admin-auth` |
| Authorization | `RolesGuard` + resource policies in services (e.g. `assertCanEditEvent(user, event)`); roles from PostgreSQL only | `rbac` |
| Transactions | `TransactionManager.run(async (tx) => …)` over TypeORM `DataSource.transaction` (EntityManager passed to repositories); READ COMMITTED default; `setLock('pessimistic_write')` on rows being transitioned, `setOnLocked('skip_locked')` for job claiming | `src/database` |
| Idempotency | `Idempotency-Key` header on money-creating endpoints; stored in `idempotency_keys` (key, user, route, request hash, response, 24 h expiry) | `src/common/idempotency` |
| Rate limiting | `@nestjs/throttler` with a **shared store** (PostgreSQL-backed at launch, Redis if needed) so limits hold across instances; Express `trust proxy` set to exactly the load-balancer hop so client IPs are correct when deployed behind a proxy (hosting ADR); per IP + per user; stricter buckets for auth, enquiry creation, upload intents, payment order creation (limits per bucket defined in the implementing milestone spec); edge rate limiting decided with the hosting ADR | global + per route |
| Security headers / CORS | `helmet`; CORS disabled (empty allow-list): mobile apps are not browsers and the Admin CMS calls the API server-side only | `main.ts` |
| API docs | OpenAPI generated from DTOs (`@nestjs/swagger`), served only in non-prod; contract snapshot diffed in CI | `main.ts` |
| Time | All timestamps UTC (`timestamptz`); ISO-8601 in API | global |
| Shutdown | `enableShutdownHooks()`; worker finishes its in-flight job before exit | `main.ts`, `worker.ts` |
| Health | `/api/v1/health/live`, `/api/v1/health/ready` (DB check) | `health` |

## 5. Notification & audit emission pattern

Illustrative only:

```ts
await this.tx.run(async (t) => {
  const booking = await this.bookings.lockById(t, id);   // SELECT … FOR UPDATE
  booking.confirm(actor);                                   // domain state machine
  await this.bookings.save(t, booking);
  await this.audit.record(t, { actor, action: 'BOOKING_CONFIRMED', entity: booking });
  await this.notifications.create(t, bookingConfirmed(booking)); // notification rows + outbox jobs
});
```

Nothing is pushed until the transaction commits; the worker delivers from the outbox.

## 6. Testing seams

- Domain: pure unit tests.
- Services: unit tests with in-memory fakes for repositories and adapters.
- Repositories + migrations: integration tests against real PostgreSQL (CI service container).
- Controllers: e2e tests with `supertest` against the Nest app, a test DB and a fake Firebase verifier.

See `quality.md`.
