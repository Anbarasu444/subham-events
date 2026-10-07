import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M9: user-written checklist items per event (R8, database-schema.md Part C,
 * domain-model.md §4.12). Overdue is derived, not stored. Soft delete only
 * (R11), so the FK to events stays RESTRICT.
 */
export class ChecklistItems1791500000000 implements MigrationInterface {
  name = 'ChecklistItems1791500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE checklist_items (
        id uuid PRIMARY KEY,
        event_id uuid NOT NULL,
        title text NOT NULL,
        notes text,
        due_date date,
        status text NOT NULL DEFAULT 'PENDING',
        completed_at timestamptz,
        sort_order integer NOT NULL,
        deleted_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        version integer NOT NULL DEFAULT 1,
        CONSTRAINT fk_checklist_items_event_id FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE RESTRICT,
        CONSTRAINT ck_checklist_items_title CHECK (char_length(title) BETWEEN 1 AND 120),
        CONSTRAINT ck_checklist_items_notes CHECK (notes IS NULL OR char_length(notes) BETWEEN 1 AND 1000),
        CONSTRAINT ck_checklist_items_status CHECK (status IN ('PENDING', 'DONE')),
        CONSTRAINT ck_checklist_items_completed_at CHECK ((status = 'DONE') = (completed_at IS NOT NULL)),
        CONSTRAINT ck_checklist_items_sort_order CHECK (sort_order >= 0)
      )`);
    // Checklist screen, per-event counts and overdue (status + due date).
    await queryRunner.query(
      `CREATE INDEX ix_checklist_items_event_id_status_due_date ON checklist_items (event_id, status, due_date) WHERE deleted_at IS NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE checklist_items`);
  }
}
