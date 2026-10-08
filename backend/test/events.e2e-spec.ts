/**
 * Events (M8) against the real local test database (`event_planner_test`).
 * Same configuration rules as auth.e2e-spec.ts; skipped when not configured.
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
import { EventAutoCompleteJob } from '../src/modules/events/event-auto-complete.job';
import { localDate } from '../src/modules/events/event-rules';
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

const ids = (data: unknown): string[] =>
  (data as { id: string }[]).map((e) => e.id);

/** Calendar date `days` from today in India. */
function day(days: number): string {
  return localDate('Asia/Kolkata', new Date(Date.now() + days * 86_400_000));
}

describeDb('Events with PostgreSQL (e2e)', () => {
  let app: INestApplication<App>;
  let migrator: DataSource;
  const verifier = new FakeTokenVerifier();
  const rateLimits = new InMemoryRateLimitStore();
  let keySeq = 0;

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
    const ds = app.get(DataSource);
    for (let i = 0; i < 50 && !ds.isInitialized; i++) {
      await new Promise((r) => setTimeout(r, 100));
    }
  });

  beforeEach(async () => {
    rateLimits.clear();
    await migrator.query(`ALTER TABLE audit_logs DISABLE TRIGGER USER`);
    await migrator.query(
      'TRUNCATE checklist_alerts, reminders, event_payment_notes, bookings, quotations, enquiries, event_vendors, wishlist_items, vendor_listings, vendors, event_expenses, budget_allocations, checklist_items, idempotency_keys, events, media, notifications, audit_logs, user_roles, users, rate_limit_counters',
    );
    await migrator.query(`ALTER TABLE audit_logs ENABLE TRIGGER USER`);
    await signIn('uid-a');
    await signIn('uid-b');
  });

  afterAll(async () => {
    await app?.close();
    await migrator?.destroy();
  });

  const http = () => request(app.getHttpServer());
  const signIn = (uid: string) =>
    http()
      .post('/api/v1/auth/session')
      .set('Authorization', `Bearer ${uid}`)
      .expect(200);
  const nextKey = () => `test-key-${++keySeq}-${Date.now()}`;

  const validBody = (overrides: Record<string, unknown> = {}) => ({
    eventType: 'Wedding',
    title: 'Asha & Ravi Wedding',
    eventDate: day(30),
    city: 'Chennai',
    ...overrides,
  });

  const create = (
    body: Record<string, unknown> = validBody(),
    uid = 'uid-a',
    key = nextKey(),
  ) =>
    http()
      .post('/api/v1/events')
      .set('Authorization', `Bearer ${uid}`)
      .set('Idempotency-Key', key)
      .send(body);

  const as = (uid: string) => ({
    get: (path: string) =>
      http().get(`/api/v1${path}`).set('Authorization', `Bearer ${uid}`),
    patch: (path: string, body: object) =>
      http()
        .patch(`/api/v1${path}`)
        .set('Authorization', `Bearer ${uid}`)
        .send(body),
    post: (path: string) =>
      http().post(`/api/v1${path}`).set('Authorization', `Bearer ${uid}`),
    delete: (path: string) =>
      http().delete(`/api/v1${path}`).set('Authorization', `Bearer ${uid}`),
  });

  const auditActions = async (): Promise<string[]> =>
    (
      await migrator.query<{ action: string }[]>(
        `SELECT action FROM audit_logs WHERE entity_type = 'EVENT' ORDER BY occurred_at, id`,
      )
    ).map((r) => r.action);

  it('creates an event with exact money and audits it', async () => {
    const res = await create(
      validBody({
        startTime: '18:30',
        venueName: 'Lotus Hall',
        guestCountEstimate: 250,
        totalBudget: { amount: '400000.50', currency: 'INR' },
      }),
    ).expect(201);
    const event = res.body.data;
    expect(event).toMatchObject({
      eventType: 'Wedding',
      title: 'Asha & Ravi Wedding',
      eventDate: day(30),
      startTime: '18:30',
      timeZone: 'Asia/Kolkata',
      city: 'Chennai',
      venueName: 'Lotus Hall',
      venueAddress: null,
      guestCountEstimate: 250,
      totalBudget: { amount: '400000.50', currency: 'INR' },
      status: 'PLANNING',
      version: 1,
    });
    expect(await auditActions()).toEqual(['EVENT_CREATED']);
  });

  it('requires sign-in and an idempotency key', async () => {
    await http().post('/api/v1/events').send(validBody()).expect(401);
    const res = await http()
      .post('/api/v1/events')
      .set('Authorization', 'Bearer uid-a')
      .send(validBody())
      .expect(428);
    expect(res.body.error.code).toBe('IDEMPOTENCY_KEY_REQUIRED');
  });

  it('replays a retried create and rejects a reused key', async () => {
    const key = nextKey();
    const first = await create(validBody(), 'uid-a', key).expect(201);
    const retry = await create(validBody(), 'uid-a', key).expect(201);
    expect(retry.headers['idempotent-replayed']).toBe('true');
    expect(retry.body.data.id).toBe(first.body.data.id);
    const [{ count }] = await migrator.query(
      `SELECT count(*)::int AS count FROM events`,
    );
    expect(count).toBe(1);

    const reused = await create(validBody({ city: 'Madurai' }), 'uid-a', key);
    expect(reused.status).toBe(409);
    expect(reused.body.error.code).toBe('IDEMPOTENCY_KEY_REUSED');
  });

  it('validates fields, money and dates', async () => {
    const missing = await create({ title: 'x' }).expect(422);
    const fields = (missing.body.error.details as { field: string }[]).map(
      (d) => d.field,
    );
    expect(fields).toEqual(
      expect.arrayContaining(['eventType', 'eventDate', 'city']),
    );

    const money = await create(
      validBody({ totalBudget: { amount: '10.1', currency: 'INR' } }),
    ).expect(422);
    expect(money.body.error.details[0].field).toBe('totalBudget.amount');

    const past = await create(validBody({ eventDate: day(-1) })).expect(422);
    expect(past.body.error.details[0].code).toBe('MUST_NOT_BE_PAST');

    await create(validBody({ eventDate: '2026-02-30' })).expect(422);
    await create(validBody({ startTime: '25:00' })).expect(422);
    await create(validBody({ timeZone: 'Mars/Base' })).expect(422);
    await create(validBody({ timeZone: '+05:30' })).expect(422);
    await create(validBody({ timeZone: 'Etc/GMT+5' })).expect(422);
    const zone = await create(
      validBody({ timeZone: 'America/New_York', eventDate: day(40) }),
    ).expect(201);
    expect(zone.body.data.timeZone).toBe('America/New_York');
    await create(validBody({ ownerUserId: 'x' })).expect(422);
    await create(validBody({ title: '   ' })).expect(422);
  });

  it('never exposes or changes another user’s event', async () => {
    const id = (await create().expect(201)).body.data.id as string;
    await as('uid-b').get(`/events/${id}`).expect(404);
    await as('uid-b')
      .patch(`/events/${id}`, { title: 'Mine', version: 1 })
      .expect(404);
    await as('uid-b').post(`/events/${id}/cancel`).expect(404);
    await as('uid-b').delete(`/events/${id}`).expect(404);
    await as('uid-a').get('/events/not-a-uuid').expect(404);
    const list = await as('uid-b').get('/events').expect(200);
    expect(list.body.data).toEqual([]);
  });

  it('lists upcoming and past events with cursor pagination', async () => {
    const later = (
      await create(validBody({ title: 'Later', eventDate: day(60) }))
    ).body.data.id;
    const soon = (
      await create(validBody({ title: 'Soon', eventDate: day(10) }))
    ).body.data.id;
    const cancelled = (
      await create(validBody({ title: 'Off', eventDate: day(20) }))
    ).body.data.id;
    const old = (await create(validBody({ title: 'Old', eventDate: day(5) })))
      .body.data.id;
    await as('uid-a').post(`/events/${cancelled}/cancel`).expect(200);
    await migrator.query(`UPDATE events SET event_date = $1 WHERE id = $2`, [
      day(-3),
      old,
    ]);

    const page1 = await as('uid-a')
      .get('/events?scope=upcoming&limit=1')
      .expect(200);
    expect(ids(page1.body.data)).toEqual([soon]);
    expect(page1.body.meta.page).toMatchObject({
      type: 'cursor',
      limit: 1,
      hasMore: true,
    });
    const page2 = await as('uid-a')
      .get(
        `/events?scope=upcoming&limit=1&cursor=${page1.body.meta.page.nextCursor}`,
      )
      .expect(200);
    expect(ids(page2.body.data)).toEqual([later]);
    expect(page2.body.meta.page).toMatchObject({
      hasMore: false,
      nextCursor: null,
    });

    const past = await as('uid-a').get('/events?scope=past').expect(200);
    expect(ids(past.body.data)).toEqual([cancelled, old]);

    const cancelledOnly = await as('uid-a')
      .get('/events?status=CANCELLED')
      .expect(200);
    expect(cancelledOnly.body.data).toHaveLength(1);

    await as('uid-a').get('/events?cursor=garbage').expect(422);
    const forged = Buffer.from(
      JSON.stringify({ d: 'not-a-date', i: 'x' }),
    ).toString('base64url');
    await as('uid-a').get(`/events?cursor=${forged}`).expect(422);
    // A cursor from the upcoming list cannot be replayed on the past list.
    await as('uid-a')
      .get(`/events?scope=past&cursor=${page1.body.meta.page.nextCursor}`)
      .expect(422);
    await as('uid-a').get('/events?limit=500').expect(422);
  });

  it('updates with optimistic concurrency and records changed fields', async () => {
    const id = (await create(validBody({ venueName: 'Hall' }))).body.data.id;
    const ok = await as('uid-a')
      .patch(`/events/${id}`, {
        title: 'New title',
        venueName: null,
        eventDate: day(-2), // existing events may move to a past date
        totalBudget: { amount: '1000.00', currency: 'INR' },
        version: 1,
      })
      .expect(200);
    expect(ok.body.data).toMatchObject({
      title: 'New title',
      venueName: null,
      eventDate: day(-2),
      totalBudget: { amount: '1000.00', currency: 'INR' },
      version: 2,
    });

    const stale = await as('uid-a')
      .patch(`/events/${id}`, { title: 'Again', version: 1 })
      .expect(412);
    expect(stale.body.error.code).toBe('PRECONDITION_FAILED');
    await as('uid-a')
      .patch(`/events/${id}`, { title: null, version: 2 })
      .expect(422);
    await as('uid-a').patch(`/events/${id}`, { title: 'x' }).expect(422);

    const unchanged = await as('uid-a')
      .patch(`/events/${id}`, { title: 'New title', version: 2 })
      .expect(200);
    expect(unchanged.body.data.version).toBe(2);

    const [{ summary }] = await migrator.query(
      `SELECT summary FROM audit_logs WHERE action = 'EVENT_UPDATED'`,
    );
    expect(summary.fields).toEqual([
      'title',
      'eventDate',
      'venueName',
      'totalBudget',
    ]);
  });

  it('follows the event state machine', async () => {
    const id = (await create()).body.data.id;
    const cancelled = await as('uid-a')
      .post(`/events/${id}/cancel`)
      .expect(200);
    expect(cancelled.body.data.status).toBe('CANCELLED');
    const again = await as('uid-a').post(`/events/${id}/cancel`).expect(409);
    expect(again.body.error.code).toBe('INVALID_STATE_TRANSITION');
    await as('uid-a').post(`/events/${id}/reopen`).expect(200);
    const done = await as('uid-a').post(`/events/${id}/complete`).expect(200);
    expect(done.body.data.status).toBe('COMPLETED');

    await migrator.query(`UPDATE events SET event_date = $1 WHERE id = $2`, [
      day(-1),
      id,
    ]);
    await as('uid-a').post(`/events/${id}/reopen`).expect(409);
    expect(await auditActions()).toEqual([
      'EVENT_CREATED',
      'EVENT_CANCELLED',
      'EVENT_REOPENED',
      'EVENT_COMPLETED',
    ]);
  });

  it('soft-deletes and hides the event', async () => {
    const id = (await create()).body.data.id;
    await as('uid-a').delete(`/events/${id}`).expect(204);
    await as('uid-a').get(`/events/${id}`).expect(404);
    await as('uid-a').delete(`/events/${id}`).expect(404);
    const [row] = await migrator.query(
      `SELECT deleted_at FROM events WHERE id = $1`,
      [id],
    );
    expect(row.deleted_at).not.toBeNull();
    expect((await as('uid-a').get('/events').expect(200)).body.data).toEqual(
      [],
    );
  });

  it('auto-completes planning events after their date', async () => {
    const past = (await create(validBody({ title: 'Past' }))).body.data.id;
    const future = (await create(validBody({ title: 'Future' }))).body.data.id;
    await migrator.query(`UPDATE events SET event_date = $1 WHERE id = $2`, [
      day(-1),
      past,
    ]);

    const completed = await app.get(EventAutoCompleteJob).run();
    expect(completed).toBe(1);
    expect((await as('uid-a').get(`/events/${past}`)).body.data.status).toBe(
      'COMPLETED',
    );
    expect((await as('uid-a').get(`/events/${future}`)).body.data.status).toBe(
      'PLANNING',
    );
    expect(await auditActions()).toContain('EVENT_AUTO_COMPLETED');
    expect(await app.get(EventAutoCompleteJob).run()).toBe(0);
  });
});
