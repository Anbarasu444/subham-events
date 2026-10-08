import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M11 (user answer 5, design A): the owner's own expenses for an event —
 * spending outside platform bookings (a relative's help, a non-platform
 * vendor, small purchases). Notes only: no money moves (payment-architecture
 * §"Own expenses"). Money is numeric(12,2) (ADR-0014).
 */
export class EventExpenses1791800000000 implements MigrationInterface {
  name = 'EventExpenses1791800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE event_expenses (
        id uuid PRIMARY KEY,
        event_id uuid NOT NULL,
        title text NOT NULL,
        amount numeric(12,2) NOT NULL,
        currency text NOT NULL DEFAULT 'INR',
        spent_on date NOT NULL,
        category_id uuid,
        note text,
        deleted_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_event_expenses_event_id FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE RESTRICT,
        CONSTRAINT fk_event_expenses_category_id FOREIGN KEY (category_id) REFERENCES vendor_categories (id) ON DELETE RESTRICT,
        CONSTRAINT ck_event_expenses_title CHECK (char_length(title) BETWEEN 1 AND 120),
        CONSTRAINT ck_event_expenses_amount CHECK (amount > 0),
        CONSTRAINT ck_event_expenses_currency CHECK (currency IN ('INR')),
        CONSTRAINT ck_event_expenses_note CHECK (note IS NULL OR char_length(note) BETWEEN 1 AND 1000)
      )`);
    // The budget sums and the list read an event's live expenses, newest first.
    await queryRunner.query(
      `CREATE INDEX ix_event_expenses_event_id_spent_on ON event_expenses (event_id, spent_on DESC) WHERE deleted_at IS NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE event_expenses`);
  }
}
