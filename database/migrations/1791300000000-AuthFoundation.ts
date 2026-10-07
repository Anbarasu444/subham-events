import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M5: users, roles, audit log, notifications and rate-limit counters
 * (database-schema.md Part C.1/C.4). Money-free. All FKs RESTRICT (R11).
 */
export class AuthFoundation1791300000000 implements MigrationInterface {
  name = 'AuthFoundation1791300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE users (
        id uuid PRIMARY KEY,
        firebase_uid text NOT NULL,
        display_name text,
        phone text,
        email text,
        email_verified boolean NOT NULL DEFAULT false,
        status text NOT NULL DEFAULT 'ACTIVE',
        status_changed_at timestamptz NOT NULL DEFAULT now(),
        deleted_at timestamptz,
        last_sign_in_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT uq_users_firebase_uid UNIQUE (firebase_uid),
        CONSTRAINT ck_users_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED')),
        CONSTRAINT ck_users_deleted_at CHECK ((status = 'DELETED') = (deleted_at IS NOT NULL))
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_users_phone ON users (phone) WHERE phone IS NOT NULL`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_users_status ON users (status) WHERE status <> 'ACTIVE'`,
    );

    await queryRunner.query(`
      CREATE TABLE user_roles (
        user_id uuid NOT NULL,
        role text NOT NULL,
        granted_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role),
        CONSTRAINT fk_user_roles_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT ck_user_roles_role CHECK (role IN ('USER', 'VENDOR'))
      )`);

    await queryRunner.query(`
      CREATE TABLE audit_logs (
        id uuid PRIMARY KEY,
        occurred_at timestamptz NOT NULL DEFAULT now(),
        actor_type text NOT NULL,
        actor_id uuid,
        actor_role text,
        action text NOT NULL,
        entity_type text NOT NULL,
        entity_id uuid,
        request_id text,
        ip inet,
        summary jsonb NOT NULL DEFAULT '{}'::jsonb,
        reason text,
        CONSTRAINT ck_audit_logs_actor_type CHECK
          (actor_type IN ('USER', 'VENDOR', 'ADMIN', 'SYSTEM', 'PROVIDER', 'GUEST'))
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_audit_logs_entity_type_entity_id_occurred_at ON audit_logs (entity_type, entity_id, occurred_at)`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_audit_logs_actor_type_actor_id_occurred_at ON audit_logs (actor_type, actor_id, occurred_at)`,
    );

    await queryRunner.query(`
      CREATE TABLE notifications (
        id uuid PRIMARY KEY,
        recipient_type text NOT NULL,
        recipient_user_id uuid,
        recipient_admin_id uuid,
        audience text NOT NULL,
        category text NOT NULL,
        type text NOT NULL,
        entity_type text,
        entity_id uuid,
        title text NOT NULL,
        body text NOT NULL,
        deep_link text,
        data jsonb NOT NULL DEFAULT '{}'::jsonb,
        push_policy text NOT NULL,
        delivery_status text NOT NULL DEFAULT 'NOT_REQUIRED',
        read_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT fk_notifications_recipient_user_id FOREIGN KEY (recipient_user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT ck_notifications_recipient CHECK (
          (recipient_type = 'USER' AND recipient_user_id IS NOT NULL AND recipient_admin_id IS NULL) OR
          (recipient_type = 'ADMIN' AND recipient_admin_id IS NOT NULL AND recipient_user_id IS NULL)),
        CONSTRAINT ck_notifications_audience CHECK (audience IN ('USER', 'VENDOR', 'ADMIN')),
        CONSTRAINT ck_notifications_category CHECK (category IN
          ('AUTH','CATEGORY','VENDOR','EVENT','BOOKING','PAYMENT','CHECKLIST','INVITATION','REVIEW','SYSTEM')),
        CONSTRAINT ck_notifications_push_policy CHECK (push_policy IN ('ALWAYS', 'IF_ENABLED', 'NEVER')),
        CONSTRAINT ck_notifications_delivery_status CHECK
          (delivery_status IN ('NOT_REQUIRED', 'PENDING', 'SENT', 'SKIPPED', 'FAILED'))
      )`);
    await queryRunner.query(
      `CREATE INDEX ix_notifications_recipient_user_id_audience_created_at ON notifications (recipient_user_id, audience, created_at DESC, id DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_notifications_unread ON notifications (recipient_user_id, audience) WHERE read_at IS NULL`,
    );

    await queryRunner.query(`
      CREATE TABLE rate_limit_counters (
        bucket_key text NOT NULL,
        window_start timestamptz NOT NULL,
        hits integer NOT NULL,
        CONSTRAINT pk_rate_limit_counters PRIMARY KEY (bucket_key, window_start),
        CONSTRAINT ck_rate_limit_counters_hits CHECK (hits > 0)
      )`);

    // Audit log is append-only for the runtime role (environments.md §3).
    await queryRunner.query(`
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_rw') THEN
          REVOKE UPDATE, DELETE, TRUNCATE ON audit_logs FROM app_rw;
        END IF;
      END $$;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE rate_limit_counters`);
    await queryRunner.query(`DROP TABLE notifications`);
    await queryRunner.query(`DROP TABLE audit_logs`);
    await queryRunner.query(`DROP TABLE user_roles`);
    await queryRunner.query(`DROP TABLE users`);
  }
}
