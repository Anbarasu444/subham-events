import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M20 change (user, 2026-10-09): one "rate the vendor" reminder 3 days
 * after a booking is completed, if it has not been reviewed.
 */
export class ReviewReminders1792700000000 implements MigrationInterface {
  name = 'ReviewReminders1792700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE bookings ADD COLUMN review_reminded_at timestamptz`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_bookings_review_reminder_due ON bookings (completed_at) WHERE status = 'COMPLETED' AND review_reminded_at IS NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX ix_bookings_review_reminder_due`);
    await queryRunner.query(
      `ALTER TABLE bookings DROP COLUMN review_reminded_at`,
    );
  }
}
