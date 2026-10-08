/** Quotations and bookings (M15, R3 + A7) against the test database. */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { BookingAutoCompleteJob } from '../src/modules/event-vendors/booking-auto-complete.job';
import { localDate } from '../src/modules/events/event-rules';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

const seed = (file: string) =>
  readFileSync(join(__dirname, '..', '..', 'database', 'seeds', file), 'utf8');
const VENDORS = seed('dev-sample-vendors.sql');
const QUOTES = seed('dev-sample-quotes.sql');
const LOTUS = '5c000000-0000-4000-8000-000000000001'; // venue, ₹1,50,000
const LOTUS_VENDOR_USER = '5a000000-0000-4000-8000-000000000001';
const MESSAGE = 'Hi, please share your best quote for our wedding.';

interface Quote {
  id: string;
  status: string;
  amount: { amount: string };
  validUntil: string;
  revisionNo: number;
}
interface Vendor {
  id: string;
  status: string;
  canEnquire: boolean;
  quotations: Quote[];
  booking: {
    id: string;
    status: string;
    agreedAmount: { amount: string };
    serviceDate: string;
    canCancel: boolean;
    canComplete: boolean;
    cancelReason: string | null;
  } | null;
  enquiries: { status: string; closedBy: string | null }[];
}

describeDb('Quotations and bookings (e2e)', () => {
  let t: DbTestApp;
  let eventId: string;
  let evId: string;
  let seq = 0;

  beforeAll(async () => {
    t = await startDbTestApp(urls!);
  });

  afterAll(async () => {
    await t?.close();
  });

  const inDays = (days: number) =>
    localDate('Asia/Kolkata', new Date(Date.now() + days * 86_400_000));
  const as = (uid: string) => ({
    get: (p: string) =>
      t.http().get(`/api/v1${p}`).set('Authorization', `Bearer ${uid}`),
    post: (p: string, body: object = {}, key = `qb-key-${++seq}`) =>
      t
        .http()
        .post(`/api/v1${p}`)
        .set('Authorization', `Bearer ${uid}`)
        .set('Idempotency-Key', key)
        .send(body),
  });
  const a = () => as('uid-a');
  const base = () => `/events/${eventId}/vendors/${evId}`;
  const vendor = async () =>
    (
      (await a().get(`/events/${eventId}/vendors`).expect(200)).body.data
        .vendors as Vendor[]
    ).find((v) => v.id === evId)!;
  const latestQuote = async () => (await vendor()).quotations[0];
  const accept = (quoteId: string, key?: string) =>
    a().post(`${base()}/quotations/${quoteId}/accept`, {}, key);

  beforeEach(async () => {
    await t.reset();
    await t.migrator.query(VENDORS);
    await t
      .http()
      .post('/api/v1/auth/session')
      .set('Authorization', 'Bearer uid-a')
      .expect(200);
    eventId = (
      await a()
        .post('/events', {
          eventType: 'Wedding',
          title: 'Asha & Ravi',
          eventDate: inDays(40),
          city: 'Chennai',
          totalBudget: { amount: '500000.00', currency: 'INR' },
        })
        .expect(201)
    ).body.data.id as string;
    evId = (
      await a()
        .post(`/events/${eventId}/vendors`, { listingId: LOTUS })
        .expect(201)
    ).body.data.id as string;
    await a()
      .post(`${base()}/enquiries`, {
        message: MESSAGE,
        preferredDate: inDays(39),
      })
      .expect(201);
    await t.migrator.query(QUOTES);
  });

  it('shows the sample quote and the N10 record', async () => {
    const v = await vendor();
    expect(v.status).toBe('QUOTED');
    expect(v.quotations).toHaveLength(1);
    expect(v.quotations[0]).toMatchObject({
      status: 'SENT',
      amount: { amount: '180000.00' },
      revisionNo: 1,
    });
    const [n] = await t.migrator.query<{ type: string }[]>(
      `SELECT type FROM notifications WHERE type = 'QUOTATION_RECEIVED'`,
    );
    expect(n).toBeDefined();
  });

  it('a revision supersedes the waiting quote (R3)', async () => {
    const first = await latestQuote();
    await t.migrator.query(QUOTES);
    const v = await vendor();
    expect(v.quotations.map((q) => [q.revisionNo, q.status])).toEqual([
      [2, 'SENT'],
      [1, 'SUPERSEDED'],
    ]);
    expect(v.quotations[0].amount.amount).toBe('171000.00');
    const stale = await accept(first.id).expect(409);
    expect(stale.body.error.message).toContain('newer quote');
  });

  it('accepting books exactly once, copying the quoted amount', async () => {
    const quote = await latestQuote();
    const booked = (await accept(quote.id, 'accept-key-1').expect(200)).body
      .data as Vendor;
    expect(booked.status).toBe('BOOKED');
    expect(booked.canEnquire).toBe(false);
    expect(booked.booking).toMatchObject({
      status: 'CONFIRMED',
      agreedAmount: { amount: '180000.00' },
      serviceDate: inDays(39),
      canCancel: true,
      canComplete: false,
    });
    expect(booked.enquiries[0]).toMatchObject({
      status: 'CLOSED',
      closedBy: 'SYSTEM',
    });
    // A retried request replays; a new tap cannot book again.
    const replay = await accept(quote.id, 'accept-key-1').expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    await accept(quote.id, 'accept-key-2').expect(409);
    const [{ count }] = await t.migrator.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM bookings`,
    );
    expect(count).toBe(1);
    // Accept needs an Idempotency-Key.
    await t
      .http()
      .post(`/api/v1${base()}/quotations/${quote.id}/accept`)
      .set('Authorization', 'Bearer uid-a')
      .expect(428);

    const types = (
      await t.migrator.query<{ type: string; recipient_user_id: string }[]>(
        `SELECT type, recipient_user_id FROM notifications
          WHERE type IN ('QUOTATION_ACCEPTED','BOOKING_CONFIRMED') ORDER BY type, audience`,
      )
    ).map((r) => r.type);
    expect(types).toEqual([
      'BOOKING_CONFIRMED',
      'BOOKING_CONFIRMED',
      'QUOTATION_ACCEPTED',
    ]);
    const [vendorNote] = await t.migrator.query<{ data: object }[]>(
      `SELECT data FROM notifications WHERE type = 'QUOTATION_ACCEPTED' AND recipient_user_id = $1`,
      [LOTUS_VENDOR_USER],
    );
    expect(JSON.stringify(vendorNote.data)).not.toMatch(/500000|@|\+91/);
  });

  it('commits the agreed amount in the budget', async () => {
    await accept((await latestQuote()).id).expect(200);
    const budget = (await a().get(`/events/${eventId}/budget`).expect(200)).body
      .data;
    expect(budget.committed).toEqual({ amount: '180000.00', currency: 'INR' });
    expect(budget.remaining).toEqual({ amount: '320000.00', currency: 'INR' });
    const venue = (
      budget.categories as { name: string; committed: { amount: string } }[]
    ).find((c) => c.name === 'Venue')!;
    expect(venue.committed.amount).toBe('180000.00');
  });

  it('rejecting reopens the enquiry for a new quote (R3)', async () => {
    const quote = await latestQuote();
    const after = (
      await a().post(`${base()}/quotations/${quote.id}/reject`).expect(200)
    ).body.data as Vendor;
    expect(after.status).toBe('ENQUIRED');
    expect(after.quotations[0].status).toBe('REJECTED');
    expect(after.enquiries[0].status).toBe('OPEN');
    await a().post(`${base()}/quotations/${quote.id}/reject`).expect(409);
    await t.migrator.query(QUOTES); // the vendor sends a new one
    const v = await vendor();
    expect(v.quotations[0]).toMatchObject({ status: 'SENT', revisionNo: 2 });
  });

  it('an expired or withdrawn quote cannot be accepted', async () => {
    const quote = await latestQuote();
    await t.migrator.query(
      `UPDATE quotations SET valid_until = current_date - 2 WHERE id = $1`,
      [quote.id],
    );
    expect((await latestQuote()).status).toBe('EXPIRED');
    const expired = await accept(quote.id).expect(409);
    expect(expired.body.error.message).toContain('expired');
    await t.migrator.query(
      `UPDATE quotations SET status = 'WITHDRAWN', valid_until = NULL WHERE id = $1`,
      [quote.id],
    );
    await accept(quote.id).expect(409);
  });

  it('cancels with a reason; the vendor can be enquired again', async () => {
    await accept((await latestQuote()).id).expect(200);
    await a().post(`${base()}/booking/cancel`, { reason: 'x' }).expect(422);
    const cancelled = (
      await a()
        .post(`${base()}/booking/cancel`, { reason: 'Venue changed' })
        .expect(200)
    ).body.data as Vendor;
    expect(cancelled.status).toBe('CANCELLED');
    expect(cancelled.booking).toMatchObject({
      status: 'CANCELLED',
      cancelReason: 'Venue changed',
      canCancel: false,
    });
    expect(cancelled.canEnquire).toBe(true);
    await a().post(`${base()}/booking/cancel`, { reason: 'Again' }).expect(404);
    const budget = (await a().get(`/events/${eventId}/budget`).expect(200)).body
      .data;
    expect(budget.committed.amount).toBe('0.00');
    const [n] = await t.migrator.query<{ recipient_user_id: string }[]>(
      `SELECT recipient_user_id FROM notifications WHERE type = 'BOOKING_CANCELLED'`,
    );
    expect(n.recipient_user_id).toBe(LOTUS_VENDOR_USER);
    const audit = await t.migrator.query<{ summary: object }[]>(
      `SELECT summary FROM audit_logs WHERE action = 'BOOKING_CANCELLED'`,
    );
    expect(JSON.stringify(audit)).not.toContain('Venue changed');
    // Bookings survive event cancellation and can be cancelled then.
    await a().post(`${base()}/enquiries`, { message: MESSAGE }).expect(201);
  });

  it('completes on or after the service date, and by the job the day after', async () => {
    await accept((await latestQuote()).id).expect(200);
    const early = await a().post(`${base()}/booking/complete`).expect(409);
    expect(early.body.error.message).toContain('service date');

    await t.migrator.query(
      `UPDATE bookings SET service_date = current_date - 1`,
    );
    const job = t.app.get(BookingAutoCompleteJob);
    expect(await job.run()).toBe(1);
    expect(await job.run()).toBe(0);
    const v = await vendor();
    expect(v.status).toBe('COMPLETED');
    expect(v.booking?.status).toBe('COMPLETED');
    const [n] = await t.migrator.query<{ type: string }[]>(
      `SELECT type FROM notifications WHERE type = 'BOOKING_COMPLETED'`,
    );
    expect(n).toBeDefined();
    await a()
      .post(`${base()}/booking/cancel`, { reason: 'Too late' })
      .expect(409);
  });

  it('the user can mark it completed on the service date', async () => {
    await accept((await latestQuote()).id).expect(200);
    await t.migrator.query(`UPDATE bookings SET service_date = $1`, [
      inDays(0),
    ]);
    const done = (await a().post(`${base()}/booking/complete`).expect(200)).body
      .data as Vendor;
    expect(done.booking?.status).toBe('COMPLETED');
  });

  it('is owner-only and needs a planning event to accept', async () => {
    const quote = await latestQuote();
    await t
      .http()
      .post('/api/v1/auth/session')
      .set('Authorization', 'Bearer uid-b')
      .expect(200);
    await as('uid-b')
      .post(`${base()}/quotations/${quote.id}/accept`)
      .expect(404);
    await as('uid-b')
      .post(`${base()}/quotations/${quote.id}/reject`)
      .expect(404);
    await a().post(`/events/${eventId}/cancel`).expect(200);
    await accept(quote.id).expect(409);
  });

  it('the sample quote script refuses other databases', async () => {
    const elsewhere = QUOTES.replace("'_(dev|test)$'", () => "'_(never)$'");
    await expect(t.migrator.query(elsewhere)).rejects.toThrow(
      /only be created in a \*_dev or \*_test database/,
    );
  });
});
