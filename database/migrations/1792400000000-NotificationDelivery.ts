import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M18: push delivery. Device registry and per-group push preferences
 * (notification-matrix.md Part A §2), and push-outbox columns on
 * `notifications`: a row with delivery_status PENDING is waiting to be
 * pushed; the worker leases it (push_next_at), sends, and records the
 * result. Record and push intent are written in one transaction.
 */
export class NotificationDelivery1792400000000 implements MigrationInterface {
  name = 'NotificationDelivery1792400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE notification_devices (
        id uuid PRIMARY KEY,
        user_id uuid NOT NULL,
        audience text NOT NULL,
        fcm_token text NOT NULL,
        platform text NOT NULL,
        app_version text,
        is_active boolean NOT NULL DEFAULT true,
        last_seen_at timestamptz NOT NULL DEFAULT now(),
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT fk_notification_devices_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT uq_notification_devices_fcm_token UNIQUE (fcm_token),
        CONSTRAINT ck_notification_devices_audience CHECK (audience IN ('USER','VENDOR')),
        CONSTRAINT ck_notification_devices_platform CHECK (platform IN ('ANDROID','IOS')),
        CONSTRAINT ck_notification_devices_fcm_token CHECK (char_length(fcm_token) BETWEEN 20 AND 4096),
        CONSTRAINT ck_notification_devices_app_version CHECK (app_version IS NULL OR char_length(app_version) <= 40)
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_notification_devices_user_id_is_active ON notification_devices (user_id, audience) WHERE is_active`,
    );

    await queryRunner.query(`
      CREATE TABLE notification_preferences (
        user_id uuid NOT NULL,
        push_group text NOT NULL,
        push_enabled boolean NOT NULL,
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT pk_notification_preferences PRIMARY KEY (user_id, push_group),
        CONSTRAINT fk_notification_preferences_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT ck_notification_preferences_push_group CHECK (push_group IN ('BOOKINGS','REMINDERS','OTHER'))
      )`);

    await queryRunner.query(`
      ALTER TABLE notifications
        ADD COLUMN push_attempts integer NOT NULL DEFAULT 0,
        ADD COLUMN push_next_at timestamptz,
        ADD COLUMN push_error text,
        ADD COLUMN pushed_at timestamptz,
        ADD CONSTRAINT ck_notifications_push_attempts CHECK (push_attempts BETWEEN 0 AND 10)`);
    // The push worker: pending rows by next attempt.
    await queryRunner.query(
      `CREATE INDEX ix_notifications_push_pending ON notifications (push_next_at) WHERE delivery_status = 'PENDING'`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX ix_notifications_push_pending`);
    await queryRunner.query(`
      ALTER TABLE notifications
        DROP CONSTRAINT ck_notifications_push_attempts,
        DROP COLUMN pushed_at,
        DROP COLUMN push_error,
        DROP COLUMN push_next_at,
        DROP COLUMN push_attempts`);
    await queryRunner.query(`DROP TABLE notification_preferences`);
    await queryRunner.query(`DROP TABLE notification_devices`);
  }
}
