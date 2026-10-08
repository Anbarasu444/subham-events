/**
 * Shared set-up for e2e tests against the local test database
 * (`event_planner_test`). Uses backend/.env (or TEST_DATABASE_URL /
 * TEST_DATABASE_MIGRATION_URL) with the dev database name swapped for the
 * test one; suites are skipped when it is not configured.
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
import { FcmSender } from '../src/modules/notifications/fcm-sender';
import {
  InMemoryRateLimitStore,
  RateLimitStore,
} from '../src/modules/rate-limit/rate-limit.store';
import { FakeFcmSender, FakeTokenVerifier } from './fakes';

export function testUrls(): { app: string; migrator: string } | null {
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

export interface DbTestApp {
  app: INestApplication<App>;
  migrator: DataSource;
  verifier: FakeTokenVerifier;
  /** Records pushes instead of calling Firebase (M18). */
  fcm: FakeFcmSender;
  /** Empties every table and the rate-limit store. */
  reset(): Promise<void>;
  close(): Promise<void>;
  http(): ReturnType<typeof request>;
}

/** Runs migrations, then boots the app with fake token verification. */
export async function startDbTestApp(
  urls: { app: string; migrator: string },
  /** Provider overrides, e.g. a fake ImageKit client. */
  overrides: { provide: unknown; useValue: unknown }[] = [],
): Promise<DbTestApp> {
  const migrator = new DataSource({
    type: 'postgres',
    url: urls.migrator,
    migrationsTableName: 'typeorm_migrations',
    migrations: [join(__dirname, '..', '..', 'database', 'migrations', '*.ts')],
  });
  await migrator.initialize();
  await migrator.runMigrations();

  process.env.DATABASE_URL = urls.app;
  const { AppModule } = await import('../src/app.module');
  const { configureApp } = await import('../src/app.setup');
  const verifier = new FakeTokenVerifier();
  const fcm = new FakeFcmSender();
  const rateLimits = new InMemoryRateLimitStore();
  let builder = Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(TokenVerifier)
    .useValue(verifier)
    .overrideProvider(FcmSender)
    .useValue(fcm)
    .overrideProvider(RateLimitStore)
    .useValue(rateLimits);
  for (const override of overrides) {
    builder = builder
      .overrideProvider(override.provide)
      .useValue(override.useValue);
  }
  const moduleRef = await builder.compile();
  const app = moduleRef.createNestApplication<INestApplication<App>>();
  configureApp(app);
  await app.init();
  // Wait for the background connection (manualInitialization).
  const ds = app.get(DataSource);
  for (let i = 0; i < 50 && !ds.isInitialized; i++) {
    await new Promise((r) => setTimeout(r, 100));
  }

  return {
    app,
    migrator,
    verifier,
    fcm,
    http: () => request(app.getHttpServer()),
    async reset() {
      rateLimits.clear();
      // audit_logs is append-only (triggers); the table owner disables them
      // only around the test clean-up.
      await migrator.query(`ALTER TABLE audit_logs DISABLE TRIGGER USER`);
      await migrator.query(
        'TRUNCATE notification_devices, notification_preferences, checklist_alerts, reminders, event_payment_notes, bookings, quotations, enquiries, event_vendors, wishlist_items, vendor_listings, vendors, event_expenses, budget_allocations, checklist_items, idempotency_keys, events, media, notifications, audit_logs, user_roles, users, rate_limit_counters',
      );
      await migrator.query(`ALTER TABLE audit_logs ENABLE TRIGGER USER`);
    },
    async close() {
      await app.close();
      await migrator.destroy();
    },
  };
}
