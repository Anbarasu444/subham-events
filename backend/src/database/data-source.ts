import 'reflect-metadata';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { DataSource } from 'typeorm';

/**
 * DataSource for the TypeORM CLI only (`npm run migration:*`).
 * Uses the migrator role (DATABASE_MIGRATION_URL); migrations live in
 * the repository's database/migrations folder (ADR-0006).
 * Reads backend/.env when the variables are not already exported.
 */
const envFile = join(__dirname, '..', '..', '.env');
if (!process.env.DATABASE_MIGRATION_URL && existsSync(envFile)) {
  process.loadEnvFile(envFile);
}

const url = process.env.DATABASE_MIGRATION_URL;
if (!url) {
  // Never fall back to DATABASE_URL: the app role has no DDL rights.
  throw new Error(
    'Set DATABASE_MIGRATION_URL (migrator role) to run migrations',
  );
}

export default new DataSource({
  type: 'postgres',
  url,
  synchronize: false,
  migrationsRun: false,
  migrationsTableName: 'typeorm_migrations',
  entities: [join(__dirname, '..', 'modules', '**', '*.entity.{ts,js}')],
  migrations: [
    join(__dirname, '..', '..', '..', 'database', 'migrations', '*.ts'),
  ],
});
