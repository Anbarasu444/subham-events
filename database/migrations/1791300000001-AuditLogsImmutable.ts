import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Makes audit_logs append-only for every role (not only app_rw), so the
 * guarantee does not depend on role grants (M5 security review).
 */
export class AuditLogsImmutable1791300000001 implements MigrationInterface {
  name = 'AuditLogsImmutable1791300000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE FUNCTION audit_logs_block_changes() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'audit_logs is append-only';
      END $$;
    `);
    await queryRunner.query(`
      CREATE TRIGGER trg_audit_logs_append_only
      BEFORE UPDATE OR DELETE ON audit_logs
      FOR EACH ROW EXECUTE FUNCTION audit_logs_block_changes()
    `);
    await queryRunner.query(`
      CREATE TRIGGER trg_audit_logs_no_truncate
      BEFORE TRUNCATE ON audit_logs
      FOR EACH STATEMENT EXECUTE FUNCTION audit_logs_block_changes()
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP TRIGGER trg_audit_logs_no_truncate ON audit_logs`,
    );
    await queryRunner.query(
      `DROP TRIGGER trg_audit_logs_append_only ON audit_logs`,
    );
    await queryRunner.query(`DROP FUNCTION audit_logs_block_changes()`);
  }
}
