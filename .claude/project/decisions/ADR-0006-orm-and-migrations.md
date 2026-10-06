# ADR-0006 — ORM and migrations: TypeORM with migration scripts on PostgreSQL

| Field | Value |
|---|---|
| Status | **Accepted** — user decision 2026-10-06 ("we use postgres with typeORM with migration script") |
| Date | 2026-10-06 |
| Milestone | M1 |
| Deciders | User (decided) · Claude (documented conventions) |
| Supersedes | — (replaces the earlier Proposed draft recommending Drizzle, which was never accepted) |

## Context
The backend needs data access on PostgreSQL with transactions, row locking, constraints, indexes and exact numeric money, and CLAUDE.md requires migration-driven schema changes. The user chose TypeORM with migration scripts.

## Options considered
1. **TypeORM** (`@nestjs/typeorm`) — first-class NestJS integration, data-mapper repositories, entity decorators, migration CLI (`migration:generate` / `migration:create` / `migration:run` / `migration:revert`), query builder with `setLock('pessimistic_write')` and `setOnLocked('skip_locked')`, `DataSource.transaction()` / `QueryRunner`. **Chosen by the user.**
2. Prisma, Drizzle, Kysely, MikroORM — not chosen.

## Decision
- **TypeORM** on PostgreSQL via `@nestjs/typeorm`, **data-mapper pattern** (entities + repositories), no active-record.
- **`synchronize: false` in every environment**, including local; `migrationsRun: false` — schema changes only through migrations, run explicitly.
- **Migrations** are TypeORM migration classes (TypeScript, `up()`/`down()`), kept in `database/migrations/` and registered in a single TypeORM `DataSource` file used by both the app and the CLI. Generated migrations (`migration:generate`) are always reviewed and hand-edited where TypeORM cannot express the intent (check constraints, partial indexes, triggers, data migrations). Forward-only in shared environments; an applied migration is never edited — a fix is a new migration. `down()` is written for local rollback.
- npm scripts (added in M3): `migration:generate`, `migration:create`, `migration:run`, `migration:revert`, `migration:show`.
- TypeORM entities and repositories are imported only in the repository layer (`architecture/backend.md` §2); services receive domain objects. Entity classes live in each module's `repositories/entities/` folder.
- Money columns are `numeric(12,2)` rupees (ADR-0014). TypeORM returns them as strings — repositories convert with an exact decimal type, never via JS `number` arithmetic.
- Row locking for state transitions via `queryBuilder.setLock('pessimistic_write')`; job claiming via `setLock('pessimistic_write').setOnLocked('skip_locked')`.
- If keeping migrations outside `backend/` causes build/path problems with the TypeORM CLI, M3 may place them at `backend/src/database/migrations/` instead; that choice is recorded in the M3 spec. (CLAUDE.md lists `database/` for migrations; the default is to honour it.)

## Consequences
- Mature NestJS integration and documentation; team familiarity.
- TypeORM's generated migrations need review; relations must not use `eager` loading or cascades implicitly (explicit loading only, to avoid N+1 and accidental writes).
- Money columns need a small TypeORM transformer (exact decimal handling).

## Review trigger
A required PostgreSQL feature unsupported by TypeORM, or TypeORM maintenance concerns; reconsider before M24.
