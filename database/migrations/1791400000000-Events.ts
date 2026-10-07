import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M8: user events and idempotency keys (database-schema.md Part C).
 * Event type is free text (O1, user decision 2026-10-07); no cover image yet.
 * Money is numeric(12,2) rupees (ADR-0014). FKs RESTRICT (R11: soft delete only).
 */
export class Events1791400000000 implements MigrationInterface {
  name = 'Events1791400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE events (
        id uuid PRIMARY KEY,
        owner_user_id uuid NOT NULL,
        event_type text NOT NULL,
        title text NOT NULL,
        event_date date NOT NULL,
        start_time time,
        time_zone text NOT NULL DEFAULT 'Asia/Kolkata',
        city text NOT NULL,
        venue_name text,
        venue_address text,
        guest_count_estimate integer,
        total_budget_amount numeric(12,2),
        currency text NOT NULL DEFAULT 'INR',
        status text NOT NULL DEFAULT 'PLANNING',
        status_changed_at timestamptz NOT NULL DEFAULT now(),
        deleted_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_events_owner_user_id FOREIGN KEY (owner_user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT ck_events_event_type CHECK (char_length(event_type) BETWEEN 1 AND 60),
        CONSTRAINT ck_events_title CHECK (char_length(title) BETWEEN 1 AND 100),
        CONSTRAINT ck_events_city CHECK (char_length(city) BETWEEN 1 AND 80),
        CONSTRAINT ck_events_venue_name CHECK (venue_name IS NULL OR char_length(venue_name) BETWEEN 1 AND 120),
        CONSTRAINT ck_events_venue_address CHECK (venue_address IS NULL OR char_length(venue_address) BETWEEN 1 AND 300),
        CONSTRAINT ck_events_guest_count_estimate CHECK (guest_count_estimate IS NULL OR guest_count_estimate BETWEEN 0 AND 100000),
        CONSTRAINT ck_events_total_budget_amount CHECK (total_budget_amount IS NULL OR total_budget_amount >= 0),
        CONSTRAINT ck_events_currency CHECK (currency IN ('INR')),
        CONSTRAINT ck_events_status CHECK (status IN ('PLANNING', 'COMPLETED', 'CANCELLED'))
      )`);
    // My Events list and Home "upcoming event" (owner, date, id keyset).
    await queryRunner.query(
      `CREATE INDEX ix_events_owner_user_id_event_date_id ON events (owner_user_id, event_date, id) WHERE deleted_at IS NULL`,
    );
    // Auto-complete job: planning events whose date has passed.
    await queryRunner.query(
      `CREATE INDEX ix_events_planning_event_date ON events (event_date) WHERE status = 'PLANNING' AND deleted_at IS NULL`,
    );

    await queryRunner.query(`
      CREATE TABLE idempotency_keys (
        principal_type text NOT NULL,
        principal_id uuid NOT NULL,
        key text NOT NULL,
        route text NOT NULL,
        request_hash text NOT NULL,
        status text NOT NULL,
        response_status integer,
        response_body jsonb,
        created_at timestamptz NOT NULL DEFAULT now(),
        expires_at timestamptz NOT NULL,
        CONSTRAINT pk_idempotency_keys PRIMARY KEY (principal_type, principal_id, key),
        CONSTRAINT ck_idempotency_keys_principal_type CHECK (principal_type IN ('USER', 'ADMIN')),
        CONSTRAINT ck_idempotency_keys_key CHECK (char_length(key) BETWEEN 8 AND 128),
        CONSTRAINT ck_idempotency_keys_status CHECK (status IN ('IN_PROGRESS', 'COMPLETED'))
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_idempotency_keys_expires_at ON idempotency_keys (expires_at)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE idempotency_keys`);
    await queryRunner.query(`DROP TABLE events`);
  }
}
