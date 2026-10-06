# Database Schema

> Part A (data architecture conventions) is the M1 deliverable for spec item 5. Entity/table-level design is M2. Part B (implemented schema) is updated by every milestone that adds a migration.
> Tooling: ADR-0006 (Accepted) — TypeORM (data-mapper) with TypeORM migration scripts committed in `database/migrations/`; `synchronize: false` everywhere.

# Part A — Conventions

## 1. Engine and tooling

- PostgreSQL **18** — locally installed (Homebrew, 18.4 observed on 2026-10-06); hosted version chosen with the hosting ADR (ADR-0010) and must match the major version.
- Migrations are TypeORM migration classes in `database/migrations/<timestamp>-<PascalCaseName>.ts` (`up`/`down`), created with `migration:generate` (from entity changes) or `migration:create` (hand-written), then **reviewed and hand-edited** where needed (check constraints, partial indexes, triggers, data migrations via `queryRunner.query`). Forward-only once applied in a shared environment; never edit an applied migration — a fix is a new migration. `synchronize` is always `false`.
- Migrations are run explicitly (`npm run migration:run`) with the `migrator` role — never automatically at app start; CI (when introduced) applies all migrations to an empty database on every change.
- Destructive changes (drop/rename column, type narrowing) use expand → migrate data → contract across at least two deployments.

## 2. Naming

| Object | Convention | Example |
|---|---|---|
| Tables | `snake_case`, plural | `event_vendors`, `platform_fee_transactions` |
| Columns | `snake_case` | `agreed_budget_minor` |
| Primary key | `id` | |
| Foreign key column | `<singular_table>_id` | `event_id` |
| FK constraint | `fk_<table>_<column>` | `fk_bookings_event_vendor_id` |
| Unique | `uq_<table>_<cols>` | `uq_users_firebase_uid` |
| Index | `ix_<table>_<cols>` | `ix_listings_category_id_status` |
| Check | `ck_<table>_<rule>` | `ck_quotations_amount_positive` |
| Enum type | `<name>_enum` or text + check (see §6) | |

## 3. Primary keys

- `uuid` primary keys, generated **by the application as UUIDv7** (TypeORM `@PrimaryColumn("uuid")` set by the repository) (time-ordered → good index locality, non-enumerable externally). Default `gen_random_uuid()` exists only as a fallback for seed scripts.
- Reference/lookup tables may use stable text codes as keys when the code is part of the domain (e.g. `currency char(3)`).

## 4. Timestamps and time zones

- Every table: `created_at timestamptz not null default now()`, `updated_at timestamptz not null default now()` (maintained by the repository layer; a trigger is acceptable).
- All instants are `timestamptz` stored in UTC. Calendar dates are `date`; an event's local zone is stored as IANA text (`time_zone`), never as an offset.
- Server and DB session time zone: UTC.

## 5. Money

- Amounts in **rupees with 2 decimals** (user direction); currency column `char(3)` default `INR`.
- Column type decided in M2 (ADR-0014): recommended `numeric(12,2)` (exact); `double precision` only if the user amends CLAUDE.md §21.
- `ck_*_amount_non_negative` (or positive where required) on every money column. Never the PostgreSQL `money` type.
- Percentages (e.g. fee rates) stored as integer basis points (`fee_bps integer`).
- Listing **starting price** and event-vendor **agreed budget** are different columns on different tables (CLAUDE.md §8).

## 6. Status values

- Statuses are `text` columns with a `CHECK (status IN (...))` constraint (easier to evolve with expand/contract than PostgreSQL enum types) and mirrored as TypeScript union types.
- Each stateful table records `status_changed_at`; full transition history lives in the audit log (and, for money/booking entities, a dedicated `<entity>_status_history` table decided in M2).

## 7. Soft delete

- Default: **no soft delete**; rows are deleted when the domain allows deletion and nothing references them.
- Soft delete (`deleted_at timestamptz null`) only where the domain needs recoverability or must preserve references: users (account deletion workflow), vendors, listings, events, media. Queries filter `deleted_at is null` in repositories; partial unique indexes use `where deleted_at is null`.
- Money and audit records are **never** deleted or soft-deleted; they change state (e.g. `CANCELLED`, `REFUNDED`).
- Personal-data erasure on account deletion anonymises PII columns while keeping financial/audit integrity (detailed in M21/M72).

## 8. Integrity and concurrency

- Foreign keys on every reference, `ON DELETE RESTRICT` by default; `CASCADE` only for pure children (e.g. checklist items of a deleted event) and stated in the migration.
- Unique constraints express business uniqueness (e.g. one active wishlist entry per user+listing).
- Optimistic concurrency: `version integer not null default 1` on user-editable aggregates exposed with `ETag`/`If-Match`.
- State transitions: `SELECT … FOR UPDATE` on the aggregate row inside the transaction.

## 9. Indexes

- Every foreign key column is indexed unless covered by a composite index.
- List queries get composite indexes matching `WHERE` + `ORDER BY` (+ `id` tiebreaker) for cursor pagination.
- Partial indexes for hot subsets (e.g. `where status = 'PENDING_REVIEW'`).
- Each index is justified by a query in the migration comment; unused indexes reviewed in M67.

## 10. Audit log

- Table `audit_logs`: `id`, `occurred_at`, `actor_type` (`USER`/`VENDOR`/`ADMIN`/`SYSTEM`/`PROVIDER`), `actor_id`, `actor_role`, `action` (e.g. `LISTING_APPROVED`), `entity_type`, `entity_id`, `request_id`, `ip`, `summary jsonb` (small before/after diff of business fields, no secrets/PII beyond IDs), `reason text`.
- Append-only: app DB role has `INSERT, SELECT` only on `audit_logs`.
- Written in the same transaction as the change it records.
- Partitioning by month considered at M67.

## 11. Async infrastructure tables (shape fixed in M2/M5)

- `jobs` (transactional outbox/job queue): `id`, `type`, `payload jsonb`, `run_at`, `status`, `attempts`, `last_error`, `locked_at`, `locked_by`; consumed with `FOR UPDATE SKIP LOCKED`.
- `idempotency_keys`: key, user, route, request hash, response snapshot, `expires_at`.
- JSON (`jsonb`) is allowed only for genuinely schemaless payloads (job payloads, provider webhook raw bodies, audit diffs, notification deep-link metadata) — never instead of relational columns.

## 12. Seed vs reference data

- Reference data required for the app to function (e.g. supported currencies, notification type catalogue, initial admin bootstrap) is created by migrations or an idempotent `database/seeds/reference/` script run in every environment.
- Demo/test data lives in `database/seeds/dev/` and never runs in staging/prod.
- Initial SUPER_ADMIN is created by a one-off, audited bootstrap command with an email supplied at runtime (never committed).

## 13. Local development

- Local PostgreSQL 18 (Homebrew service) with databases `event_planner_dev` and `event_planner_test` and roles `app_rw` / `migrator`, created by a documented setup script in `database/` (M3); `.env.example` documents `DATABASE_URL`. No Docker required.
- Integration tests use a fresh database per test run (migrations applied from empty).

# Part B — Implemented schema

_No tables yet. First migration expected in M3 (foundation: `jobs`, `idempotency_keys` if needed, `audit_logs`) / M5 (`users`, roles)._
