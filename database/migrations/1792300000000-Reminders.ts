import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M17: user reminders (domain-model.md §4.13; N17) and a record of the
 * checklist due/overdue alerts already sent (N16, once per task per state).
 * Times are instants (timestamptz); the app shows them in local time.
 */
export class Reminders1792300000000 implements MigrationInterface {
  name = 'Reminders1792300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Target for the composite FK below (invariant 13).
    await queryRunner.query(
      `ALTER TABLE checklist_items ADD CONSTRAINT uq_checklist_items_id_event_id UNIQUE (id, event_id)`,
    );
    await queryRunner.query(`
      CREATE TABLE reminders (
        id uuid PRIMARY KEY,
        user_id uuid NOT NULL,
        event_id uuid NOT NULL,
        checklist_item_id uuid,
        title text NOT NULL,
        remind_at timestamptz NOT NULL,
        status text NOT NULL DEFAULT 'SCHEDULED',
        sent_at timestamptz,
        seen_at timestamptz,
        cancelled_at timestamptz,
        cancel_reason text,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_reminders_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
        CONSTRAINT fk_reminders_event_id FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE RESTRICT,
        CONSTRAINT fk_reminders_checklist_item FOREIGN KEY (checklist_item_id, event_id)
          REFERENCES checklist_items (id, event_id) ON DELETE RESTRICT,
        CONSTRAINT ck_reminders_title CHECK (char_length(title) BETWEEN 1 AND 120),
        CONSTRAINT ck_reminders_status CHECK (status IN ('SCHEDULED','SENT','CANCELLED')),
        CONSTRAINT ck_reminders_sent CHECK ((status = 'SENT') = (sent_at IS NOT NULL)),
        CONSTRAINT ck_reminders_cancelled CHECK ((status = 'CANCELLED') = (cancelled_at IS NOT NULL AND cancel_reason IS NOT NULL)),
        CONSTRAINT ck_reminders_cancel_reason CHECK (cancel_reason IS NULL OR cancel_reason IN
          ('USER','TASK_DONE','TASK_DELETED','EVENT_CANCELLED','EVENT_DELETED'))
      )`);
    // The due job: scheduled reminders by time.
    await queryRunner.query(
      `CREATE INDEX ix_reminders_remind_at_scheduled ON reminders (remind_at) WHERE status = 'SCHEDULED'`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_reminders_event_id_remind_at ON reminders (event_id, remind_at)`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_reminders_user_id_status_remind_at ON reminders (user_id, status, remind_at)`,
    );
    await queryRunner.query(
      `CREATE INDEX ix_reminders_checklist_item_id ON reminders (checklist_item_id) WHERE checklist_item_id IS NOT NULL`,
    );

    await queryRunner.query(`
      CREATE TABLE checklist_alerts (
        checklist_item_id uuid NOT NULL,
        kind text NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT pk_checklist_alerts PRIMARY KEY (checklist_item_id, kind),
        CONSTRAINT fk_checklist_alerts_checklist_item_id FOREIGN KEY (checklist_item_id)
          REFERENCES checklist_items (id) ON DELETE RESTRICT,
        CONSTRAINT ck_checklist_alerts_kind CHECK (kind IN ('DUE_TODAY','OVERDUE'))
      )`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE checklist_alerts`);
    await queryRunner.query(`DROP TABLE reminders`);
    await queryRunner.query(
      `ALTER TABLE checklist_items DROP CONSTRAINT uq_checklist_items_id_event_id`,
    );
  }
}
