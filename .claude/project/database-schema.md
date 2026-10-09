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

## 5. Money (ADR-0014)

- `numeric(12,2)` in **rupees** + `currency char(3) not null default 'INR'`. Column naming: `<name>_amount` + `<name>_currency` where several amounts share a row (e.g. `starting_price_amount`), or `amount` + `currency`.
- `ck_*_amount_non_negative` (or positive where required) on every money column. Never `real`, `double precision` or the PostgreSQL `money` type.
- TypeORM maps `numeric` to string; repositories convert to an exact decimal type — never JS `number` arithmetic.
- Percentages (e.g. fee rates) stored as integer basis points (`fee_bps integer`).
- Listing **starting price** and event-vendor **agreed budget** are different columns on different tables (CLAUDE.md §8).

## 6. Status values

- Statuses are `text` columns with a `CHECK (status IN (...))` constraint (easier to evolve with expand/contract than PostgreSQL enum types) and mirrored as TypeScript union types.
- Each stateful table records `status_changed_at`; full transition history lives in the audit log. **M2 decision:** no separate `<entity>_status_history` tables — `audit_logs` (with entity index and before/after summary) is the transition history for all entities, including platform fees and bookings.

## 7. Soft delete (R11 — nothing is hard-deleted)

- User decision (R11, 2026-10-06) — **interim, for development:** keep everything in the database and media storage; only mark records as deleted. The final deletion policy will be discussed later (owner M21, release-blocking at M72); the schema keeps `deleted_at`/status flags so either anonymisation or erasure can be added without redesign. Application code never issues `DELETE` on business tables.
- User-deletable records carry `deleted_at timestamptz null` (users and vendors additionally use `status = DELETED`). Repositories filter `deleted_at is null` by default; partial unique indexes use `where deleted_at is null`.
- Money, booking, review, audit and provider records are never deleted or soft-deleted; they change state (e.g. `CANCELLED`).
- Only technical tables are purged by system jobs (notifications after 1 year, completed jobs after 30 days, expired idempotency keys) — see `domain-model.md` §8.
- ⚠ Compliance risk (DPDP Act 2023 / store account-deletion policies) recorded in `domain-model.md` §8 and `architecture/threat-model.md`; review before release (M72).

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

| Migration | Milestone | Change |
|---|---|---|
| `1791279600000-Baseline` | M3 | No schema change; proves the TypeORM migration pipeline and creates the `typeorm_migrations` bookkeeping table |
| `1791300000000-AuthFoundation` | M5 | `users`, `user_roles`, `audit_logs` (UPDATE/DELETE revoked from `app_rw`), `notifications`, `rate_limit_counters` per Part C |
| `1791300000001-AuditLogsImmutable` | M5 | Triggers make `audit_logs` append-only for every role (UPDATE/DELETE/TRUNCATE raise) |
| `1791400000000-Events` | M8 | `events` (free-text `event_type` per O1, no `cover_media_id` yet; length/range/status checks; `total_budget_amount numeric(12,2) ≥ 0`; soft delete) with indexes `ix_events_owner_user_id_event_date_id` (partial, not deleted) and `ix_events_planning_event_date` (auto-complete job); `idempotency_keys` (PK principal + key, 24 h `expires_at`, purged hourly) |
| `1791500000000-ChecklistItems` | M9 | `checklist_items` (`event_id → events` RESTRICT, title 1–120, notes ≤ 1000, `due_date`, status PENDING/DONE with `completed_at` consistency check, `sort_order ≥ 0`, soft delete, `version`) with `ix_checklist_items_event_id_status_due_date` (partial, not deleted). Overdue is derived, not stored; the 200-items limit is enforced by the API under an event row lock |
| `1791600000000-MediaAndEventCover` | M10 | `media` (owner/kind limited to EVENT / EVENT_COVER for now, status PENDING_UPLOAD/READY/REJECTED, reserved `folder` + `file_name`, unique `imagekit_file_id`, size ≤ 30 MB check, READY-requires-file-details check, soft delete) with `ix_media_owner_type_owner_id` and `ix_media_status_created_at` (pending clean-up); `events.cover_media_id → media` (RESTRICT) |
| `1791700000000-VendorCategoriesAndBudget` | M11 | `vendor_categories` (name 1–80, unique slug pattern, status DRAFT/PUBLISHED/ARCHIVED, sort order; `icon_media_id` deferred to M42) seeded idempotently by slug with 12 PUBLISHED starter categories; `budget_allocations` (`event_id → events`, `category_id → vendor_categories`, `planned_amount numeric(12,2) ≥ 0`, INR, soft delete, version) with partial unique `(event_id, category_id) WHERE deleted_at IS NULL` |
| `1792600000000-Reviews` | M20 | `reviews` (booking/user/vendor/listing FKs, one per booking, rating 1–5 with ACTIVE/REMOVED + reason consistency, comment ≤ 1000 with comment-presence ⇔ status check, moderation fields with moderated-time check) and its five indexes; listing aggregates stay in `vendor_listings.rating_sum/count` (atomic increments) |
| `1792500000000-Invitations` | M19 | `invitations` (event and user FKs, unique per event, template code pattern, title 1–120, message ≤ 1000, host names ≤ 200, event date/time/venue snapshot, status DRAFT/PUBLISHED/REVOKED with published-requires-hash and revoked-time consistency checks, `rsvp_open`, unique `share_token_hash` (SHA-256, nullable after revoke), `last_rsvp_notified_at` for the N18 digest, version); `invitation_rsvps` (invitation FK, unique per responder token hash, name 1–80, response, guest count 1–20, message ≤ 500) with `ix_invitation_rsvps_invitation_id_updated_at` |
| `1792400000000-NotificationDelivery` | M18 | `notification_devices` (user FK, audience USER/VENDOR, unique `fcm_token` 20–4096, platform ANDROID/IOS, app version, active, last seen; partial index by user/audience where active); `notification_preferences` (PK user + push group BOOKINGS/REMINDERS/OTHER, push on/off); `notifications` gains the push-outbox columns `push_attempts` (0–10), `push_next_at` (lease / next attempt), `push_error`, `pushed_at`, with the partial index `ix_notifications_push_pending (push_next_at) WHERE delivery_status = 'PENDING'` (decision: the notifications rows are the outbox; no separate jobs table) |
| `1792300000000-Reminders` | M17 | `checklist_items` gains `uq(id, event_id)`; `reminders` (user and event FKs, composite FK `(checklist_item_id, event_id)` → checklist items, title 1–120, `remind_at timestamptz`, status SCHEDULED/SENT/CANCELLED with sent and cancelled consistency checks, cancel reason, `seen_at`, version) with indexes for the due job (partial SCHEDULED by time), event, user/status and task; `checklist_alerts` (PK task + kind DUE_TODAY/OVERDUE: N16 once per task per state) |
| `1792200000000-EventPaymentNotes` | M16 | `event_payment_notes` (composite FK `(booking_id, event_id)` → `bookings(id, event_id)`, user FK, kind ADVANCE/INSTALMENT/FINAL/OTHER, `amount numeric(12,2) > 0`, INR, `paid_on`, method CASH/UPI/BANK_TRANSFER/CARD/CHEQUE/OTHER, note 1–1000, soft delete, version) with partial indexes by booking (newest paid first) and by event (budget) |
| `1792100000000-QuotationsAndBookings` | M15 | `quotations` (enquiry FK + composite FK to event vendors, `amount numeric(12,2) > 0`, INR, description ≤ 2000, `valid_until`, `revision_no ≥ 1`, status SENT/ACCEPTED/REJECTED/SUPERSEDED/WITHDRAWN, answered ⇔ `responded_at`; partial unique one SENT per enquiry); `bookings` (composite FK to event vendors, `quotation_id` unique, user FK, `agreed_amount > 0` (not updatable in the ORM), `service_date`, status CONFIRMED/CANCELLED/COMPLETED with cancellation and completion consistency checks, reason 3–500, `uq(id, event_id)` for M16 payment notes; partial unique one active booking per event vendor; indexes for vendor, user, event and the completion job) |
| `1792000000000-WishlistEventVendorsEnquiries` | M14 | `wishlist_items` (PK user + listing, soft delete, index by user/newest); `event_vendors` (event/listing/vendor/category FKs, status check, private notes ≤ 1000, version, partial unique `(event_id, listing_id) WHERE status <> 'REMOVED'`, unique `(id, event_id, vendor_id)` as composite FK target, indexes by event and vendor/status); `enquiries` (composite FK `(event_vendor_id, event_id, vendor_id)`, user FK, message 10–1000, preferred date, status OPEN/QUOTED/DECLINED/CLOSED, `closed_by_type`, closed ⇔ `closed_at` check, partial unique one live enquiry per event vendor, indexes for vendor inbox, user and event) |
| `1791900000000-VendorsAndListings` | M12 | `vendors` (`user_id → users` unique ⏸R10, business name 1–120, description ≤ 2000, phone/email, city 1–80, `service_areas text[]` ≤ 30 (O2), `logo_media_id → media`, status ACTIVE/SUSPENDED/DELETED with `deleted_at` consistency) with `ix_vendors_city (lower(city))` partial ACTIVE; `vendor_listings` (`vendor_id → vendors`, `category_id → vendor_categories`, unique `(vendor_id, category_id)` ⏸R10, title 1–120, description ≤ 4000, `starting_price_amount numeric(12,2) ≥ 0`, INR, city, service areas, status DRAFT…ARCHIVED, APPROVED-requires-`approved_at`, `rating_count`/`rating_sum` range check, `pending_revision jsonb`, version) with partial (`status = 'APPROVED'`) indexes `(category_id, lower(city))`, `(approved_at DESC, id DESC)`, `(starting_price_amount, id)` and `ix_vendor_listings_vendor_id` |
| `1791800000000-EventExpenses` | M11 | `event_expenses` (`event_id → events` RESTRICT, title 1–120, `amount numeric(12,2) > 0`, INR, `spent_on date`, optional `category_id → vendor_categories` RESTRICT, note 1–1000 or null, soft delete, `version`) with `ix_event_expenses_event_id_spent_on` (partial, not deleted). The 500-per-event limit is enforced by the API under an event row lock |

**Sample quotes (M15):** `database/seeds/dev-sample-quotes.sql` (`npm run seed:dev-quotes`) plays the vendor until M33: for each open enquiry to a sample listing it sends a quote (starting price + 20 %, valid 14 days) or, if one is waiting, a revision (5 % lower; the previous becomes SUPERSEDED), with an N10 record. Guarded to `*_dev` / `*_test` databases like the vendor seed.

**Sample data (M12):** `database/seeds/dev-sample-vendors.sql` (run with `npm run seed:dev-samples` in `backend/`) loads 20 fake vendors/listings (18 visible; one draft, one suspended vendor) into `*_dev` / `*_test` databases only — the script aborts on any other database name. Rows are marked (`sample-vendor-N` Firebase uids, `@example.invalid` emails, `[Sample]` descriptions, ids starting `5a`/`5b`/`5c`). Never run in production.

Local databases `event_planner_dev` / `event_planner_test` and roles `migrator` / `app_rw` are created by `database/scripts/setup-local.sql` (run by the user). First domain tables (`users`, `user_roles`, `audit_logs`, `jobs`, `notifications`) expected in M5.

# Part C — Logical schema (planned, M2)

> Planning document, **not migrations**. Each table is created by the milestone in the last column, through a TypeORM migration that follows Part A. ⏸ = depends on a held business rule (R3/R6/R10, see `domain-model.md`); ❓ = depends on a working assumption awaiting confirmation. Every table also has `created_at`, `updated_at` (Part A §4); `id uuid` PK unless stated. Money = `numeric(12,2)` + `currency char(3) default 'INR'` (ADR-0014).

## C.1 Identity and administration

| Table | Key columns and constraints | Indexes | Milestone |
|---|---|---|---|
| `users` | `firebase_uid text uq not null`, `display_name text`, `phone text` (column-level encryption evaluated in M5 — R11 mitigation), `email text`, `email_verified bool`, `photo_media_id → media`, `status text ck (ACTIVE,SUSPENDED,DELETED)`, `status_changed_at`, `deleted_at`, `last_sign_in_at` | `uq_users_firebase_uid`; `ix_users_phone`; `ix_users_status` (partial `where status <> 'ACTIVE'`) | M5 |
| `user_roles` | PK `(user_id → users, role)`, `role ck (USER,VENDOR)`, `granted_at` | PK | M5 |
| `admin_users` | `username citext uq`, `password_hash text`, `display_name`, `role ck (SUPER_ADMIN,MARKETPLACE_ADMIN,FINANCE_ADMIN,SUPPORT_ADMIN,CONTENT_ADMIN)`, `status ck (ACTIVE,DISABLED)`, `failed_login_count int ≥0`, `locked_until`, `must_change_password bool`, `password_changed_at`, `last_login_at`, `created_by_admin_id → admin_users` | `uq_admin_users_username` | M40 |
| `admin_sessions` | `admin_user_id → admin_users`, `token_hash bytea uq`, `expires_at`, `last_seen_at`, `last_password_confirmed_at`, `revoked_at`, `ip inet`, `user_agent text` | `uq_admin_sessions_token_hash`; `ix_admin_sessions_admin_user_id` | M40 |

## C.2 Marketplace

| Table | Key columns and constraints | Indexes | Milestone |
|---|---|---|---|
| `vendor_categories` | `name`, `slug uq`, `description`, `icon_media_id → media`, `status ck (DRAFT,PUBLISHED,ARCHIVED)`, `sort_order`, `created_by_admin_id` | `uq_vendor_categories_slug`; `ix_vendor_categories_status_sort_order` | M12 (read + seed), M42 (admin) |
| `platform_fee_schedules` ⏸R6 | `category_id → vendor_categories`, `amount ck >= 1.00` (Razorpay minimum), `currency`, `effective_from`, `effective_to` null, `created_by_admin_id`; exclusion: one open schedule per category | `ix_platform_fee_schedules_category_id_effective_from` | M29/M43 |
| `vendors` ⏸R10 | `user_id → users uq` (⏸ one vendor per user), `business_name`, `description`, `phone`, `email`, `city`, `service_areas text[]` (❓O2), `logo_media_id`, `status ck (ACTIVE,SUSPENDED,DELETED)`, `deleted_at` | `uq_vendors_user_id`; `ix_vendors_city` | M12 (read), M26 |
| `vendor_listings` | `vendor_id → vendors`, `category_id → vendor_categories`, `title`, `description`, `starting_price_amount ck ≥0`, `currency`, `city`, `service_areas text[]`, `status ck (DRAFT,IN_REVIEW,APPROVED,REJECTED,SUSPENDED,ARCHIVED)`, `rejection_reason`, `approved_at`, `approved_by_admin_id`, `version int`, `pending_revision jsonb null` (unapproved edits of an approved listing, reviewed via a submission), `rating_count int`, `rating_sum int` (denormalised, atomic increments) | `uq(vendor_id, category_id)` ⏸R10; `ix_vendor_listings_category_id_status_city` (partial `where status='APPROVED'`); `ix_vendor_listings_vendor_id` | M12 (read), M28 |
| `listing_media` | PK `(listing_id, media_id)`, `sort_order`, `is_cover bool`; one cover per listing (partial unique) | PK; `uq_listing_media_cover` | M28 |
| `listing_submissions` ⏸R6 | `listing_id → vendor_listings`, `submission_no int`, `status ck (AWAITING_FEE,PENDING_REVIEW,APPROVED,REJECTED,WITHDRAWN)`, `fee_required bool` ⏸, `submitted_at`, `reviewed_by_admin_id`, `reviewed_at`, `decision_reason`; one open submission per listing (partial unique on `listing_id where status in (AWAITING_FEE,PENDING_REVIEW)`) | `ix_listing_submissions_status_submitted_at` (admin queue) | M30 |
| `platform_fee_transactions` | `vendor_id`, `listing_submission_id`, `fee_schedule_id`, `amount ck > 0`, `currency`, `razorpay_order_id uq`, `razorpay_payment_id`, `status ck (CREATED,PENDING,SUCCESS,EXPIRED,FAILED,REVIEW_REQUIRED,REFUNDED)`, `paid_at`, `expires_at`, `resolution_reason`, `resolved_by_admin_id`; ck `status <> 'SUCCESS' or (razorpay_payment_id is not null and paid_at is not null)`; one open order per submission (partial unique `where status in (CREATED,PENDING,REVIEW_REQUIRED)`); **at most one paid** (partial unique `listing_submission_id where status = 'SUCCESS'`) | `ix_platform_fee_transactions_status_created_at`; `ix_…_vendor_id` | M29 |
| `platform_fee_payment_attempts` | `transaction_id → platform_fee_transactions`, `razorpay_payment_id uq`, `status ck (ATTEMPTED,CAPTURED,FAILED)`, `amount numeric(12,2) ck > 0` (converted from provider paise), `currency`, `error_code`, `error_description` | `ix_…_transaction_id` | M29 |
| `provider_events` | `provider text`, `provider_event_id uq per provider`, `type`, `payload jsonb`, `received_at`, `processed_at`, `attempts int`, `processing_error text`; app role: INSERT/SELECT/UPDATE(processed_at) only | `uq(provider, provider_event_id)` | M29 |

## C.3 Event planning

| Table | Key columns and constraints | Indexes | Milestone |
|---|---|---|---|
| `events` | `owner_user_id → users`, `event_type text` (free text 1–60, O1), `title`, `event_date date`, `start_time time`, `time_zone text default 'Asia/Kolkata'`, `city`, `venue_name`, `venue_address`, `guest_count_estimate int ≥0`, `total_budget_amount ck ≥0 null`, `currency`, `cover_media_id`, `status ck (PLANNING,COMPLETED,CANCELLED)`, `deleted_at`, `version` | `ix_events_owner_user_id_event_date_id` (partial `where deleted_at is null`) | M8 |
| `checklist_items` | `event_id → events`, `title`, `notes`, `due_date date null`, `status ck (PENDING,DONE)`, `completed_at`, `sort_order`, `deleted_at` | `ix_checklist_items_event_id_status_due_date` | M9 |
| `budget_allocations` | `event_id`, `category_id`, `planned_amount ck ≥0`, `currency`; `uq(event_id, category_id)` | uq | M11 |
| `event_expenses` | `event_id`, `title`, `amount ck >0`, `currency`, `spent_on`, `category_id` (nullable), `note` | `(event_id, spent_on desc)` partial | M11 |
| `event_vendors` | `event_id`, `listing_id`, `vendor_id`, `category_id`, `status ck (ADDED,ENQUIRED,QUOTED,BOOKED,COMPLETED,CANCELLED,REMOVED)`, `notes` (user-private); `uq(event_id, listing_id)`; `uq(id, event_id, vendor_id)` (target of composite FKs) | `ix_event_vendors_event_id`; `ix_event_vendors_vendor_id_status` | M11/M14 |
| `wishlist_items` | PK `(user_id, listing_id)` | `ix_wishlist_items_user_id_created_at` | M14 |
| `enquiries` | `(event_vendor_id, event_id, vendor_id) → event_vendors(id, event_id, vendor_id)` composite FK, `user_id`, `message text`, `preferred_date`, `status ck (OPEN,QUOTED,DECLINED,CLOSED)`, `decline_reason`, `closed_at`; one open enquiry per event vendor (partial unique) | `ix_enquiries_vendor_id_status_created_at` (vendor inbox); `ix_enquiries_user_id_created_at` | M14 |
| `quotations` ⏸R3 | `enquiry_id`, `event_vendor_id`, `vendor_id`, `amount ck > 0`, `currency`, `description`, `valid_until` ⏸, `revision_no` ⏸, `status ck (SENT,ACCEPTED,REJECTED,…⏸)`, `responded_at` | `ix_quotations_enquiry_id` | M15 |
| `bookings` | `(event_vendor_id, event_id, vendor_id) → event_vendors(id, event_id, vendor_id)` composite FK, `quotation_id uq`, `user_id`, `agreed_amount ck > 0`, `currency`, `service_date`, `status ck (CONFIRMED,CANCELLED,COMPLETED)`, `cancelled_by_type ck (USER,VENDOR,ADMIN)`, `cancel_reason`, `completed_at`; partial unique `event_vendor_id where status in (CONFIRMED,COMPLETED)` | `ix_bookings_vendor_id_service_date`; `ix_bookings_user_id_service_date`; `ix_bookings_status_service_date` (completion job) | M15 |
| `event_payment_notes` ❓A2/A3 | `(booking_id, event_id) → bookings(id, event_id)` composite FK (bookings gets `uq(id, event_id)`), `user_id`, `kind ck (ADVANCE,INSTALMENT,FINAL,OTHER)`, `amount ck > 0`, `currency`, `paid_on date`, `method ck (CASH,UPI,BANK_TRANSFER,CARD,CHEQUE,OTHER)`, `note`, `deleted_at` | `ix_event_payment_notes_booking_id` | M16 |
| `reminders` | `user_id`, `event_id`, `(checklist_item_id, event_id) → checklist_items(id, event_id)` composite FK (nullable), `title`, `remind_at timestamptz`, `status ck (SCHEDULED,SENT,CANCELLED)`, `sent_at` | `ix_reminders_status_remind_at` (partial `where status='SCHEDULED'`) | M17 |
| `invitations` | `event_id uq` (one per event), `user_id`, `template_code` (catalogue code; no `format`/`image_media_id`: pictures are drawn on the phone, M19 answer 2), `title`, `message`, `host_names`, `event_date`, `start_time`, `venue_name`, `venue_address` (snapshot at save), `share_token_hash bytea uq`, `status ck (DRAFT,PUBLISHED,REVOKED)`, `rsvp_open bool`, `published_at`, `revoked_at`, `last_rsvp_notified_at`, `version` | unique indexes only | M19 |
| `invitation_rsvps` (A6) | `invitation_id`, `responder_token_hash bytea`, `guest_name 1–80`, `response ck (ATTENDING,NOT_ATTENDING,MAYBE)`, `guest_count int ck 1..20`, `message ≤ 500`, `created_at`, `updated_at`; `uq(invitation_id, responder_token_hash)` | `ix_invitation_rsvps_invitation_id_updated_at` | M19 |
| `reviews` | `booking_id uq`, `user_id`, `vendor_id`, `listing_id`, `rating smallint ck 1..5`, `rating_status ck (ACTIVE,REMOVED)` + `rating_removed_reason`, `comment ≤ 1000` (null ⇔ `NONE`), `comment_status ck (NONE,PENDING_MODERATION,APPROVED,REJECTED,HIDDEN)`, `moderated_by_admin_id` (no FK until admin accounts, M40+), `moderated_at`, `moderation_reason ≤ 500`, `version` | `ix_reviews_listing_id_created_at` (partial APPROVED + ACTIVE, public list); `ix_reviews_listing_id_rating` (partial ACTIVE, breakdown); `ix_reviews_comment_status_created_at` (partial PENDING_MODERATION, admin queue); `ix_reviews_user_id_created_at`; `ix_reviews_vendor_id` | M20 |

## C.4 Platform services

| Table | Key columns and constraints | Indexes | Milestone |
|---|---|---|---|
| `media` | `owner_type`, `owner_id`, `kind`, `imagekit_file_id uq`, `file_path`, `content_type`, `size_bytes ck ≤ limit`, `width`, `height`, `duration_seconds`, `status ck (PENDING_UPLOAD,READY,REJECTED)`, `deleted_at`, `uploaded_by_type`, `uploaded_by_id` | `ix_media_owner_type_owner_id`; `ix_media_status_created_at` (cleanup) | M8 |
| `notifications` | `recipient_type ck (USER,ADMIN)`, `recipient_user_id null`, `recipient_admin_id null` (exactly one set), `audience ck (USER,VENDOR,ADMIN)`, `category`, `type`, `entity_type`, `entity_id`, `title`, `body`, `deep_link`, `data jsonb`, `push_policy`, `delivery_status`, `read_at` | `ix_notifications_recipient_user_id_audience_created_at`; partial unread index | M5 |
| `notification_devices` | `user_id`, `audience`, `fcm_token text uq` (re-assigned to the new user on registration; removed on sign-out), `platform`, `app_version`, `is_active`, `last_seen_at` | `ix_notification_devices_user_id_is_active` | M18 |
| `notification_preferences` | PK `(user_id, audience, category)`, `push_enabled bool` | PK | M18 |
| `content_items` | `type ck (BANNER,FAQ,PAGE)`, `slug`, `title`, `body`, `media_id`, `status ck (DRAFT,PUBLISHED,ARCHIVED)`, `published_at`, `sort_order` | `ix_content_items_type_status_sort_order` | M51 |
| `audit_logs` | See Part A §10 (`actor_type` adds `GUEST` for RSVP writes); admin reads of private data also logged; app role INSERT/SELECT only | `ix_audit_logs_entity_type_entity_id_occurred_at`; `ix_audit_logs_actor_type_actor_id_occurred_at` | M5 |
| `jobs` | `type`, `payload jsonb`, `run_at`, `status ck (PENDING,RUNNING,DONE,FAILED)`, `attempts`, `max_attempts`, `last_error`, `locked_at`, `locked_by`, `dedupe_key uq null` | `ix_jobs_status_run_at` (partial `where status='PENDING'`) | M5 |
| `idempotency_keys` | PK `(principal_type, principal_id, key)`, `route`, `request_hash`, `status`, `response_status`, `response_body jsonb`, `expires_at` | `ix_idempotency_keys_expires_at` | M15 |

## C.5 Growth estimates (performance review input)

| Table | Expected volume (first 12 months, assumption) | Note |
|---|---|---|
| `notifications` | Highest volume (~10–50 per active user/month) | Retention 1 year; partition by month if > 50 M rows (M67) |
| `audit_logs` | Every state change | Partition by month considered at M67 |
| `jobs` | Every notification + reminder + cleanup | Done jobs purged after 30 days |
| `invitation_rsvps` | Up to hundreds per invitation | Indexed by invitation |
| Others | Proportional to users/events/vendors | Standard indexes above |
