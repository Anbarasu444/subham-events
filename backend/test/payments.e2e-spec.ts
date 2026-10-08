/** Private payment notes per booking (M16; R5, A2, A3, A11). */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { localDate } from '../src/modules/events/event-rules';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

const seed = (file: string) =>
  readFileSync(join(__dirname, '..', '..', 'database', 'seeds', file), 'utf8');
const VENDORS = seed('dev-sample-vendors.sql');
const QUOTES = seed('dev-sample-quotes.sql');
const LOTUS = '5c000000-0000-4000-8000-000000000001';

interface PaymentList {
  agreedAmount: { amount: string };
  paid: { amount: string };
  balance: { amount: string } | null;
  overpaidBy: { amount: string } | null;
  payments: { id: string; amount: { amount: string }; version: number }[];
}

describeDb('Payment notes (e2e)', () => {
  let t: DbTestApp;
  let eventId: string;
  let evId: string;
  let bookingId: string;
  let seq = 0;

  beforeAll(async () => {
    t = await startDbTestApp(urls!);
  });

  afterAll(async () => {
    await t?.close();
  });

  const today = () => localDate('Asia/Kolkata', new Date());
  const inDays = (days: number) =>
    localDate('Asia/Kolkata', new Date(Date.now() + days * 86_400_000));
  const as = (uid: string) => {
    const auth = (r: import('supertest').Test) =>
      r.set('Authorization', `Bearer ${uid}`);
    return {
      get: (p: string) => auth(t.http().get(`/api/v1${p}`)),
      delete: (p: string) => auth(t.http().delete(`/api/v1${p}`)),
      patch: (p: string, body: object) =>
        auth(t.http().patch(`/api/v1${p}`)).send(body),
      post: (p: string, body: object = {}, key = `pay-key-${++seq}`) =>
        auth(t.http().post(`/api/v1${p}`))
          .set('Idempotency-Key', key)
          .send(body),
    };
  };
  const a = () => as('uid-a');
  const path = () => `/events/${eventId}/bookings/${bookingId}/payments`;
  const money = (amount: string) => ({ amount, currency: 'INR' });
  const payment = (over: object = {}) => ({
    amount: money('50000.00'),
    paidOn: today(),
    method: 'UPI',
    kind: 'ADVANCE',
    ...over,
  });
  const list = async () =>
    (await a().get(path()).expect(200)).body.data as PaymentList;

  beforeEach(async () => {
    await t.reset();
    await t.migrator.query(VENDORS);
    for (const uid of ['uid-a', 'uid-b']) {
      await t
        .http()
        .post('/api/v1/auth/session')
        .set('Authorization', `Bearer ${uid}`)
        .expect(200);
    }
    eventId = (
      await a()
        .post('/events', {
          eventType: 'Wedding',
          title: 'Asha & Ravi',
          eventDate: inDays(40),
          city: 'Chennai',
          totalBudget: money('500000.00'),
        })
        .expect(201)
    ).body.data.id as string;
    evId = (
      await a()
        .post(`/events/${eventId}/vendors`, { listingId: LOTUS })
        .expect(201)
    ).body.data.id as string;
    await a()
      .post(`/events/${eventId}/vendors/${evId}/enquiries`, {
        message: 'Please share your best quote for our wedding.',
      })
      .expect(201);
    await t.migrator.query(QUOTES);
    const vendor = (await a().get(`/events/${eventId}/vendors`).expect(200))
      .body.data.vendors[0] as { quotations: { id: string }[] };
    bookingId = (
      await a()
        .post(
          `/events/${eventId}/vendors/${evId}/quotations/${vendor.quotations[0].id}/accept`,
        )
        .expect(200)
    ).body.data.booking.id as string;
  });

  it('records payments and shows exact paid and balance', async () => {
    await a().post(path(), payment()).expect(201);
    await a()
      .post(
        path(),
        payment({ amount: money('0.10'), kind: 'INSTALMENT', note: '  ' }),
      )
      .expect(201);
    const l = await list();
    expect(l).toMatchObject({
      agreedAmount: { amount: '180000.00' },
      paid: { amount: '50000.10' },
      balance: { amount: '129999.90' },
      overpaidBy: null,
    });
    expect(l.payments).toHaveLength(2);

    // The booking and the budget show the same figures.
    const vendor = (await a().get(`/events/${eventId}/vendors`).expect(200))
      .body.data.vendors[0];
    expect(vendor.booking.paid.amount).toBe('50000.10');
    const budget = (await a().get(`/events/${eventId}/budget`).expect(200)).body
      .data;
    expect(budget).toMatchObject({
      paid: money('50000.10'),
      spent: money('50000.10'),
      outstanding: money('129999.90'),
      paidToCancelled: money('0.00'),
    });
  });

  it('reports overpayment', async () => {
    await a()
      .post(path(), payment({ amount: money('180000.01') }))
      .expect(201);
    const l = await list();
    expect(l.balance).toBeNull();
    expect(l.overpaidBy).toEqual(money('0.01'));
  });

  it('edits with a version and deletes softly; audit has no amounts or notes', async () => {
    const created = (
      await a()
        .post(path(), payment({ note: 'Paid by uncle' }))
        .expect(201)
    ).body.data as { id: string; version: number };
    const edited = (
      await a()
        .patch(`${path()}/${created.id}`, {
          amount: money('60000.00'),
          method: 'CASH',
          version: created.version,
        })
        .expect(200)
    ).body.data;
    expect(edited).toMatchObject({ amount: money('60000.00'), method: 'CASH' });
    await a()
      .patch(`${path()}/${created.id}`, {
        kind: 'FINAL',
        version: created.version,
      })
      .expect(412);
    await a().delete(`${path()}/${created.id}`).expect(204);
    await a().delete(`${path()}/${created.id}`).expect(404);
    expect((await list()).payments).toEqual([]);
    const audits = await t.migrator.query<{ action: string }[]>(
      `SELECT action, summary FROM audit_logs WHERE action LIKE 'PAYMENT_NOTE_%' ORDER BY occurred_at, id`,
    );
    expect(audits.map((r) => r.action)).toEqual([
      'PAYMENT_NOTE_CREATED',
      'PAYMENT_NOTE_UPDATED',
      'PAYMENT_NOTE_DELETED',
    ]);
    expect(JSON.stringify(audits)).not.toMatch(/60000|50000|uncle/);
  });

  it('is private: no notifications, other users get 404 (A2)', async () => {
    await a().post(path(), payment()).expect(201);
    const [{ count }] = await t.migrator.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM notifications WHERE type LIKE 'PAYMENT%'`,
    );
    expect(count).toBe(0);
    await as('uid-b').get(path()).expect(404);
    await as('uid-b').post(path(), payment()).expect(404);
  });

  it('validates money, dates and fields', async () => {
    for (const body of [
      payment({ amount: money('0.00') }),
      payment({ amount: money('10.5') }),
      payment({ amount: { amount: '10.00', currency: 'USD' } }),
      payment({ paidOn: inDays(1) }),
      payment({ paidOn: '2026-02-30' }),
      payment({ method: 'BITCOIN' }),
      payment({ kind: 'TIP' }),
      payment({ note: 'x'.repeat(1001) }),
    ]) {
      await a().post(path(), body).expect(422);
    }
    await t
      .http()
      .post(`/api/v1${path()}`)
      .set('Authorization', 'Bearer uid-a')
      .send(payment())
      .expect(428);
  });

  it('keeps counting cancelled bookings and allows notes on them (A11)', async () => {
    await a()
      .post(path(), payment({ amount: money('20000.00') }))
      .expect(201);
    await a()
      .post(`/events/${eventId}/vendors/${evId}/booking/cancel`, {
        reason: 'Venue changed',
      })
      .expect(200);
    await a()
      .post(path(), payment({ amount: money('1.00'), kind: 'OTHER' }))
      .expect(201);
    const budget = (await a().get(`/events/${eventId}/budget`).expect(200)).body
      .data;
    expect(budget).toMatchObject({
      committed: money('0.00'),
      paid: money('20001.00'),
      paidToCancelled: money('20001.00'),
      outstanding: money('0.00'),
    });
  });

  it('allows payments after the event is completed or cancelled', async () => {
    await t.migrator.query(
      `UPDATE events SET status = 'COMPLETED' WHERE id = $1`,
      [eventId],
    );
    await a()
      .post(path(), payment({ kind: 'FINAL' }))
      .expect(201);
    await t.migrator.query(
      `UPDATE events SET deleted_at = now() WHERE id = $1`,
      [eventId],
    );
    await a().post(path(), payment()).expect(404);
  });
});
