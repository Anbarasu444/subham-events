import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M15: vendor quotations (R3 resolved, domain-model.md §4.9) and bookings
 * (§4.10, A7). The agreed amount is copied from the accepted quotation and
 * never changes (ADR-0014 money). EXPIRED is derived, not stored.
 */
export class QuotationsAndBookings1792100000000 implements MigrationInterface {
  name = 'QuotationsAndBookings1792100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE quotations (
        id uuid PRIMARY KEY,
        enquiry_id uuid NOT NULL,
        event_vendor_id uuid NOT NULL,
        event_id uuid NOT NULL,
        vendor_id uuid NOT NULL,
        amount numeric(12,2) NOT NULL,
        currency text NOT NULL DEFAULT 'INR',
        description text,
        valid_until date,
        revision_no integer NOT NULL DEFAULT 1,
        status text NOT NULL DEFAULT 'SENT',
        responded_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_quotations_enquiry_id FOREIGN KEY (enquiry_id) REFERENCES enquiries (id) ON DELETE RESTRICT,
        CONSTRAINT fk_quotations_event_vendor FOREIGN KEY (event_vendor_id, event_id, vendor_id)
          REFERENCES event_vendors (id, event_id, vendor_id) ON DELETE RESTRICT,
        CONSTRAINT ck_quotations_amount_positive CHECK (amount > 0),
        CONSTRAINT ck_quotations_currency CHECK (currency IN ('INR')),
        CONSTRAINT ck_quotations_description CHECK (description IS NULL OR char_length(description) BETWEEN 1 AND 2000),
        CONSTRAINT ck_quotations_revision_no CHECK (revision_no >= 1),
        CONSTRAINT ck_quotations_status CHECK (status IN ('SENT','ACCEPTED','REJECTED','SUPERSEDED','WITHDRAWN')),
        CONSTRAINT ck_quotations_responded CHECK ((status IN ('ACCEPTED','REJECTED')) = (responded_at IS NOT NULL))
      )`);
    // R3: one live (SENT) quotation per enquiry.
    await queryRunner.query(
      `CREATE UNIQUE INDEX uq_quotations_enquiry_id_sent ON quotations (enquiry_id) WHERE status = 'SENT'`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_quotations_event_vendor_id ON quotations (event_vendor_id, created_at DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_quotations_vendor_id_status ON quotations (vendor_id, status)`,
    );

    await queryRunner.query(`
      CREATE TABLE bookings (
        id uuid PRIMARY KEY,
        event_vendor_id uuid NOT NULL,
        event_id uuid NOT NULL,
        vendor_id uuid NOT NULL,
        quotation_id uuid NOT NULL,
        user_id uuid NOT NULL,
        agreed_amount numeric(12,2) NOT NULL,
        currency text NOT NULL DEFAULT 'INR',
        service_date date NOT NULL,
        status text NOT NULL DEFAULT 'CONFIRMED',
        cancelled_by_type text,
        cancel_reason text,
        cancelled_at timestamptz,
        completed_at timestamptz,
        status_changed_at timestamptz NOT NULL DEFAULT now(),
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_bookings_event_vendor FOREIGN KEY (event_vendor_id, event_id, vendor_id)
          REFERENCES event_vendors (id, event_id, vendor_id) ON DELETE RESTRICT,
        CONSTRAINT fk_bookings_quotation_id FOREIGN KEY (quotation_id) REFERENCES quotations (id) ON DELETE RESTRICT,
        CONSTRAINT fk_bookings_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT uq_bookings_quotation_id UNIQUE (quotation_id),
        CONSTRAINT uq_bookings_id_event_id UNIQUE (id, event_id),
        CONSTRAINT ck_bookings_agreed_amount CHECK (agreed_amount > 0),
        CONSTRAINT ck_bookings_currency CHECK (currency IN ('INR')),
        CONSTRAINT ck_bookings_status CHECK (status IN ('CONFIRMED','CANCELLED','COMPLETED')),
        CONSTRAINT ck_bookings_cancelled_by_type CHECK (cancelled_by_type IS NULL OR cancelled_by_type IN ('USER','VENDOR','ADMIN')),
        CONSTRAINT ck_bookings_cancelled CHECK (
          (status = 'CANCELLED') = (cancelled_at IS NOT NULL AND cancelled_by_type IS NOT NULL AND cancel_reason IS NOT NULL)),
        CONSTRAINT ck_bookings_cancel_reason CHECK (cancel_reason IS NULL OR char_length(cancel_reason) BETWEEN 3 AND 500),
        CONSTRAINT ck_bookings_completed CHECK ((status = 'COMPLETED') = (completed_at IS NOT NULL))
      )`);
    // One active booking per event vendor.
    await queryRunner.query(
      `CREATE UNIQUE INDEX uq_bookings_event_vendor_id_active ON bookings (event_vendor_id) WHERE status IN ('CONFIRMED','COMPLETED')`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_bookings_vendor_id_service_date ON bookings (vendor_id, service_date)`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_bookings_user_id_service_date ON bookings (user_id, service_date)`,
    );
    // Completion job: confirmed bookings by date.
    await queryRunner.query(
      `CREATE INDEX ix_bookings_status_service_date ON bookings (service_date) WHERE status = 'CONFIRMED'`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_bookings_event_id ON bookings (event_id)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE bookings`);
    await queryRunner.query(`DROP TABLE quotations`);
  }
}
