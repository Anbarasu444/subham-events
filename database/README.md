# database/

PostgreSQL schema for the Event Planning Platform.

| Path | Purpose |
|---|---|
| `migrations/` | TypeORM migration classes (ADR-0006). The only way the schema changes. |
| `scripts/setup-local.sql` | One-time local setup: roles `migrator` / `app_rw`, databases `event_planner_dev` / `event_planner_test` |
| `scripts/grants.sql` | Per-database grants (included by the setup script) |
| `seeds/dev-sample-vendors.sql` | **Dev/test only** fake vendors for trying discovery (M12): `cd backend && npm run seed:dev-samples`. Refuses databases not named `*_dev` / `*_test`. |

Conventions: `.claude/project/database-schema.md`. Planned tables: Part C of the same file.

## Local setup (PostgreSQL 18, Homebrew)

1. Make sure PostgreSQL is running: `brew services start postgresql@18`
2. Run the setup script **yourself** from the repository root; it prompts for the two passwords
   (hidden input, never committed):

   ```sh
   psql -d postgres -f database/scripts/setup-local.sql
   ```

3. Create `backend/.env` from `backend/.env.example` and put the same passwords in
   `DATABASE_URL` (role `app_rw`) and `DATABASE_MIGRATION_URL` (role `migrator`).
4. Apply migrations from `backend/` (the CLI reads `backend/.env` and uses `DATABASE_MIGRATION_URL`):

   ```sh
   cd backend
   npm run migration:show
   npm run migration:run
   ```

   For the test database, export `DATABASE_MIGRATION_URL` pointing at `event_planner_test` and run the same commands.

## Rules

- `synchronize` is always `false`; migrations never run automatically at app start.
- Never edit a migration that has been applied in a shared environment — add a new one.
- Generate with `npm run migration:generate -- ../database/migrations/<Name>` and **review** the SQL;
  hand-write constraints TypeORM cannot express (checks, partial indexes) with `queryRunner.query`.
- The app connects as `app_rw` (no DDL); migrations run as `migrator`.
