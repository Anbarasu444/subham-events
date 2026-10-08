/**
 * Auth flow against the real local test database (`event_planner_test`).
 * Uses backend/.env (or TEST_DATABASE_URL / TEST_DATABASE_MIGRATION_URL) and
 * swaps the dev database name for the test one. Skipped when not configured.
 */
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseEnv } from 'node:util';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import type { App } from 'supertest/types';
import { DataSource } from 'typeorm';
import { TokenVerifier } from '../src/modules/auth/token-verifier';
import {
  InMemoryRateLimitStore,
  RateLimitStore,
} from '../src/modules/rate-limit/rate-limit.store';
import { FakeTokenVerifier } from './fakes';

function testUrls(): { app: string; migrator: string } | null {
  const envFile = join(__dirname, '..', '.env');
  const env: Record<string, string | undefined> = existsSync(envFile)
    ? parseEnv(readFileSync(envFile, 'utf8'))
    : {};
  const toTest = (url?: string) =>
    url?.replace(/\/event_planner_dev(\?|$)/, '/event_planner_test$1');
  const app = process.env.TEST_DATABASE_URL ?? toTest(env.DATABASE_URL);
  const migrator =
    process.env.TEST_DATABASE_MIGRATION_URL ??
    toTest(env.DATABASE_MIGRATION_URL);
  if (!app || !migrator || !app.includes('event_planner_test')) return null;
  return { app, migrator };
}

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

describeDb('Auth with PostgreSQL (e2e)', () => {
  let app: INestApplication<App>;
  let migrator: DataSource;
  const verifier = new FakeTokenVerifier();
  const rateLimits = new InMemoryRateLimitStore();

  beforeAll(async () => {
    migrator = new DataSource({
      type: 'postgres',
      url: urls!.migrator,
      migrationsTableName: 'typeorm_migrations',
      migrations: [
        join(__dirname, '..', '..', 'database', 'migrations', '*.ts'),
      ],
    });
    await migrator.initialize();
    await migrator.runMigrations();

    process.env.DATABASE_URL = urls!.app;
    const { AppModule } = await import('../src/app.module');
    const { configureApp } = await import('../src/app.setup');
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(TokenVerifier)
      .useValue(verifier)
      .overrideProvider(RateLimitStore)
      .useValue(rateLimits)
      .compile();
    app = moduleRef.createNestApplication();
    configureApp(app);
    await app.init();
    // Wait for the background connection (manualInitialization).
    const ds = app.get(DataSource);
    for (let i = 0; i < 50 && !ds.isInitialized; i++) {
      await new Promise((r) => setTimeout(r, 100));
    }
  });

  beforeEach(async () => {
    rateLimits.clear();
    // audit_logs is append-only (triggers); the table owner disables them
    // only around the test clean-up.
    await migrator.query(`ALTER TABLE audit_logs DISABLE TRIGGER USER`);
    await migrator.query(
      'TRUNCATE checklist_items, idempotency_keys, events, media, notifications, audit_logs, user_roles, users, rate_limit_counters',
    );
    await migrator.query(`ALTER TABLE audit_logs ENABLE TRIGGER USER`);
  });

  afterAll(async () => {
    await app?.close();
    await migrator?.destroy();
  });

  const session = (token: string) =>
    request(app.getHttpServer())
      .post('/api/v1/auth/session')
      .set('Authorization', `Bearer ${token}`);

  it('creates the user once, grants USER, welcomes and audits', async () => {
    const first = await session('uid-new').expect(200);
    expect(first.body.data.isNewUser).toBe(true);
    expect(first.body.data.user.roles).toEqual(['USER']);
    expect(first.body.data.user.phone).toBe('+919800000001');

    const second = await session('uid-new').expect(200);
    expect(second.body.data.isNewUser).toBe(false);
    expect(second.body.data.user.id).toBe(first.body.data.user.id);

    const [{ count: users }] = await migrator.query(
      `SELECT count(*)::int AS count FROM users`,
    );
    expect(users).toBe(1);
    const notifications = await migrator.query(
      `SELECT type, push_policy FROM notifications WHERE recipient_user_id = $1`,
      [first.body.data.user.id],
    );
    expect(notifications).toEqual([{ type: 'WELCOME', push_policy: 'NEVER' }]);
    const audit: { action: string }[] = await migrator.query(
      `SELECT action FROM audit_logs ORDER BY occurred_at, id`,
    );
    expect(audit.map((a) => a.action)).toEqual([
      'AUTH_SIGN_UP',
      'AUTH_SIGN_IN',
    ]);
    expect(verifier.checkRevokedCalls.at(-1)).toBe(true);
  });

  it('stores email only when verified', async () => {
    verifier.identities.set('uid-mail', {
      email: 'x@example.com',
      emailVerified: false,
    });
    const res = await session('uid-mail').expect(200);
    expect(res.body.data.user.email).toBeNull();
    verifier.identities.set('uid-mail', {
      email: 'x@example.com',
      emailVerified: true,
    });
    const again = await session('uid-mail').expect(200);
    expect(again.body.data.user.email).toBe('x@example.com');
  });

  it('concurrent first sign-ins create one user', async () => {
    await Promise.all([
      session('uid-race'),
      session('uid-race'),
      session('uid-race'),
    ]);
    const [{ count }] = await migrator.query(
      `SELECT count(*)::int AS count FROM users WHERE firebase_uid = 'uid-race'`,
    );
    expect(count).toBe(1);
  });

  it('GET /me returns the profile; unregistered identities get AUTH_REQUIRED', async () => {
    await session('uid-me').expect(200);
    const me = await request(app.getHttpServer())
      .get('/api/v1/me')
      .set('Authorization', 'Bearer uid-me')
      .expect(200);
    expect(me.body.data.roles).toEqual(['USER']);
    const unknown = await request(app.getHttpServer())
      .get('/api/v1/me')
      .set('Authorization', 'Bearer uid-unknown')
      .expect(401);
    expect(unknown.body.error.code).toBe('AUTH_REQUIRED');
  });

  it('suspended accounts are refused at session creation', async () => {
    await session('uid-sus').expect(200);
    await migrator.query(
      `UPDATE users SET status = 'SUSPENDED' WHERE firebase_uid = 'uid-sus'`,
    );
    const res = await session('uid-sus').expect(403);
    expect(res.body.error.code).toBe('ACCOUNT_SUSPENDED');
  });

  it('sign-out revokes refresh tokens and is audited', async () => {
    await session('uid-out').expect(200);
    await request(app.getHttpServer())
      .post('/api/v1/auth/sign-out')
      .set('Authorization', 'Bearer uid-out')
      .expect(204);
    expect(verifier.revoked).toContain('uid-out');
    const rows = await migrator.query(
      `SELECT 1 FROM audit_logs WHERE action = 'AUTH_SIGN_OUT'`,
    );
    expect(rows).toHaveLength(1);
  });

  it('rate-limits session creation before token checks', async () => {
    for (let i = 0; i < 60; i++) await session('uid-rl');
    const res = await session('uid-rl').expect(429);
    expect(res.body.error.code).toBe('RATE_LIMITED');
    expect(res.headers['retry-after']).toBeDefined();
  });

  // Separate app/migrator roles → "permission denied"; a single local role
  // (owner) is still stopped by the append-only trigger.
  it('the app role cannot change or delete audit history', async () => {
    await session('uid-audit').expect(200);
    const appDs = app.get(DataSource);
    await expect(
      appDs.query(`UPDATE audit_logs SET action = 'X'`),
    ).rejects.toThrow(/permission denied|append-only/);
    await expect(appDs.query(`DELETE FROM audit_logs`)).rejects.toThrow(
      /permission denied|append-only/,
    );
    // Even the owner role cannot rewrite history (trigger).
    await expect(
      migrator.query(`UPDATE audit_logs SET action = 'X'`),
    ).rejects.toThrow(/append-only/);
  });
});
