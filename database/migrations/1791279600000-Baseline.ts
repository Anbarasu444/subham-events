import type { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * M3 baseline: proves the migration pipeline against an empty database and
 * makes migration history read-only for the app role. Creates no domain
 * tables (users etc. arrive in M5).
 */
export class Baseline1791279600000 implements MigrationInterface {
  name = 'Baseline1791279600000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // The runtime role must not be able to rewrite migration history.
    await queryRunner.query(`
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_rw') THEN
          REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON typeorm_migrations FROM app_rw;
        END IF;
      END $$;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_rw') THEN
          GRANT INSERT, UPDATE, DELETE ON typeorm_migrations TO app_rw;
        END IF;
      END $$;
    `);
  }
}
