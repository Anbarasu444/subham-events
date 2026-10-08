import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M16 (R5, A2, A3, A11): the user's private payment notes against a booking.
 * Records only — no money moves through the platform, nothing is verified,
 * nobody is notified. Money is numeric(12,2) (ADR-0014).
 */
export class EventPaymentNotes1792200000000 implements MigrationInterface {
  name = 'EventPaymentNotes1792200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE event_payment_notes (
        id uuid PRIMARY KEY,
        booking_id uuid NOT NULL,
        event_id uuid NOT NULL,
        user_id uuid NOT NULL,
        kind text NOT NULL,
        amount numeric(12,2) NOT NULL,
        currency text NOT NULL DEFAULT 'INR',
        paid_on date NOT NULL,
        method text NOT NULL,
        note text,
        deleted_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_event_payment_notes_booking FOREIGN KEY (booking_id, event_id)
          REFERENCES bookings (id, event_id) ON DELETE RESTRICT,
        CONSTRAINT fk_event_payment_notes_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT ck_event_payment_notes_kind CHECK (kind IN ('ADVANCE','INSTALMENT','FINAL','OTHER')),
        CONSTRAINT ck_event_payment_notes_amount CHECK (amount > 0),
        CONSTRAINT ck_event_payment_notes_currency CHECK (currency IN ('INR')),
        CONSTRAINT ck_event_payment_notes_method CHECK (method IN ('CASH','UPI','BANK_TRANSFER','CARD','CHEQUE','OTHER')),
        CONSTRAINT ck_event_payment_notes_note CHECK (note IS NULL OR char_length(note) BETWEEN 1 AND 1000)
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_event_payment_notes_booking_id ON event_payment_notes (booking_id, paid_on DESC) WHERE deleted_at IS NULL`,
    );
    // Budget: all notes of an event.
    await queryRunner.query(
      `CREATE INDEX ix_event_payment_notes_event_id ON event_payment_notes (event_id) WHERE deleted_at IS NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE event_payment_notes`);
  }
}
