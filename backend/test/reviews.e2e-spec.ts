/** Reviews (M20; R7, A4, A5, A12). */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { localDate } from '../src/modules/events/event-rules';
import { ReviewReminderJob } from '../src/modules/reviews/review-reminder.job';
import { publicName } from '../src/modules/reviews/reviews.service';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

const seed = (file: string) =>
  readFileSync(join(__dirname, '..', '..', 'database', 'seeds', file), 'utf8');
const VENDORS = seed('dev-sample-vendors.sql');
const QUOTES = seed('dev-sample-quotes.sql');
const LOTUS = '5c000000-0000-4000-8000-000000000001';

interface Booking {
  status: string;
  review: { rating: number; commentStatus: string } | null;
  canReview: boolean;
}

test('public names are first name + last initial (answer 4)', () => {
  expect(publicName('Asha Kumar')).toBe('Asha K.');
  expect(publicName('  asha  ravi kumar ')).toBe('asha K.');
  expect(publicName('Asha')).toBe('Asha');
  expect(publicName(null)).toBe('Customer');
  expect(publicName('   ')).toBe('Customer');
});

describeDb('Reviews (e2e)', () => {
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
      post: (p: string, body: object = {}, key = `review-key-${++seq}`) =>
        auth(t.http().post(`/api/v1${p}`))
          .set('Idempotency-Key', key)
          .send(body),
    };
  };
  const a = () => as('uid-a');
  const path = () => `/events/${eventId}/bookings/${bookingId}/review`;
  const money = (amount: string) => ({ amount, currency: 'INR' });

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

  const complete = async (serviceDate = today()) => {
    await t.migrator.query(
      `UPDATE bookings SET status = 'COMPLETED', completed_at = now(),
              service_date = $2 WHERE id = $1`,
      [bookingId, serviceDate],
    );
  };
  const booking = async () =>
    (
      (await a().get(`/events/${eventId}/vendors`).expect(200)).body.data
        .vendors[0] as { booking: Booking }
    ).booking;
  const rating = async () =>
    (await t.http().get(`/api/v1/listings/${LOTUS}/rating`).expect(200)).body
      .data as {
      average: string | null;
      count: number;
      stars: { stars: number; count: number }[];
    };

  it('only a completed booking can be reviewed, once (A5)', async () => {
    expect((await booking()).canReview).toBe(false);
    const early = await a().post(path(), { rating: 5 }).expect(409);
    expect(early.body.error.code).toBe('INVALID_STATE_TRANSITION');

    await complete();
    expect(await booking()).toMatchObject({ canReview: true, review: null });
    const body = { rating: 4, comment: '  Lovely hall, helpful staff.  ' };
    const created = await a().post(path(), body, 'review-key-once').expect(201);
    // A retry with the same key is replayed, not a second review.
    const replay = await a().post(path(), body, 'review-key-once').expect(201);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect(created.body.data).toMatchObject({
      rating: 4,
      comment: 'Lovely hall, helpful staff.',
      commentStatus: 'PENDING_MODERATION',
      listing: { id: LOTUS },
    });
    expect(await booking()).toMatchObject({
      canReview: false,
      review: { rating: 4, commentStatus: 'PENDING_MODERATION' },
    });
    const again = await a().post(path(), { rating: 1 }).expect(409);
    expect(again.body.error.code).toBe('DUPLICATE');

    const mine = (await a().get('/me/reviews').expect(200)).body.data as {
      rating: number;
    }[];
    expect(mine).toHaveLength(1);
  });

  it('counts the rating at once; the comment waits for approval (A4)', async () => {
    await complete();
    await a().post(path(), { rating: 4, comment: 'Great food' }).expect(201);
    const r = await rating();
    expect(r).toMatchObject({ average: '4.0', count: 1 });
    expect(r.stars).toEqual([
      { stars: 5, count: 0 },
      { stars: 4, count: 1 },
      { stars: 3, count: 0 },
      { stars: 2, count: 0 },
      { stars: 1, count: 0 },
    ]);
    const card = (await t.http().get(`/api/v1/listings/${LOTUS}`).expect(200))
      .body.data as { rating: { average: string; count: number } };
    expect(card.rating).toEqual({ average: '4.0', count: 1 });

    // Pending comments are not public.
    const pending = await t
      .http()
      .get(`/api/v1/listings/${LOTUS}/reviews`)
      .expect(200);
    expect(pending.body.data).toEqual([]);

    // Once approved (M51 admin), it is public with "Asha K." only.
    await t.migrator.query(
      `UPDATE users SET display_name = 'Asha Kumar' WHERE firebase_uid = 'uid-a'`,
    );
    await t.migrator.query(
      `UPDATE reviews SET comment_status = 'APPROVED', moderated_at = now()`,
    );
    const pub = await t
      .http()
      .get(`/api/v1/listings/${LOTUS}/reviews`)
      .expect(200);
    expect(pub.body.data).toEqual([
      {
        id: expect.any(String),
        rating: 4,
        comment: 'Great food',
        reviewerName: 'Asha K.',
        createdAt: expect.any(String),
      },
    ]);
    expect(pub.body.meta.page).toMatchObject({ hasMore: false });
    expect(JSON.stringify(pub.body)).not.toContain('Kumar');
  });

  it('tells the vendor (N19, in-app) and audits without the comment', async () => {
    await complete();
    await a().post(path(), { rating: 5, comment: 'Private words' }).expect(201);
    const [n] = await t.migrator.query<
      { audience: string; type: string; body: string; push_policy: string }[]
    >(
      `SELECT audience, type, body, push_policy FROM notifications
        WHERE type = 'REVIEW_RECEIVED'`,
    );
    expect(n).toMatchObject({
      audience: 'VENDOR',
      push_policy: 'NEVER',
    });
    expect(n.body).toContain('5 out of 5');
    expect(n.body).not.toContain('Private words');
    const [audit] = await t.migrator.query<{ summary: object }[]>(
      `SELECT summary FROM audit_logs WHERE action = 'REVIEW_CREATED'`,
    );
    expect(JSON.stringify(audit.summary)).not.toContain('Private words');
  });

  it('refuses before the service date, own listings and other users (A12)', async () => {
    await complete(inDays(2));
    expect((await booking()).canReview).toBe(false);
    await a().post(path(), { rating: 5 }).expect(409);

    await complete();
    await as('uid-b').post(path(), { rating: 1 }).expect(404);

    await t.migrator.query(
      `UPDATE vendors SET user_id = (SELECT id FROM users WHERE firebase_uid = 'uid-a')
        WHERE id = (SELECT vendor_id FROM vendor_listings WHERE id = $1)`,
      [LOTUS],
    );
    await a().post(path(), { rating: 5 }).expect(403);
    expect((await rating()).count).toBe(0);
  });

  it('validates the rating and comment', async () => {
    await complete();
    for (const body of [
      {},
      { rating: 0 },
      { rating: 6 },
      { rating: 4.5 },
      { rating: 4, comment: 'x'.repeat(1001) },
    ]) {
      await a().post(path(), body).expect(422);
    }
    // A blank comment is "no comment".
    const ok = await a()
      .post(path(), { rating: 2, comment: '   ' })
      .expect(201);
    expect(ok.body.data).toMatchObject({
      comment: null,
      commentStatus: 'NONE',
    });
  });

  it('hides reviews of listings that are not visible', async () => {
    await t.migrator.query(
      `UPDATE vendor_listings SET status = 'SUSPENDED' WHERE id = $1`,
      [LOTUS],
    );
    await t.http().get(`/api/v1/listings/${LOTUS}/rating`).expect(404);
    await t.http().get(`/api/v1/listings/${LOTUS}/reviews`).expect(404);
  });
  it('reminds once, 3 days after completion, only if not rated', async () => {
    const job = t.app.get(ReviewReminderJob);
    const completedAgo = (days: number) =>
      t.migrator.query(
        `UPDATE bookings SET status = 'COMPLETED', service_date = $2,
                completed_at = now() - make_interval(days => $3)
          WHERE id = $1`,
        [bookingId, today(), days],
      );
    const reminders = () =>
      t.migrator.query<{ delivery_status: string; body: string }[]>(
        `SELECT delivery_status, body FROM notifications WHERE type = 'REVIEW_REMINDER'`,
      );

    await completedAgo(2);
    expect(await job.run()).toBe(0);
    await completedAgo(4);
    expect(await job.run()).toBe(1);
    expect(await job.run()).toBe(0); // only once
    const [n] = await reminders();
    expect(n.delivery_status).toBe('PENDING'); // pushed (group OTHER)
    expect(n.body).toContain('Rate “');

    // Already rated, or completed long ago: no reminder.
    await t.migrator.query(
      `UPDATE bookings SET review_reminded_at = NULL WHERE id = $1`,
      [bookingId],
    );
    await t.migrator.query(
      `DELETE FROM notifications WHERE type = 'REVIEW_REMINDER'`,
    );
    await a().post(path(), { rating: 5 }).expect(201);
    expect(await job.run()).toBe(0);
    await t.migrator.query(`DELETE FROM reviews`);
    await completedAgo(40);
    expect(await job.run()).toBe(0);
  });
});
