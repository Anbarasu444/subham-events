/** Wishlist, event vendors and enquiries (M14) against the test database. */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { localDate } from '../src/modules/events/event-rules';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

const SEED = readFileSync(
  join(__dirname, '..', '..', 'database', 'seeds', 'dev-sample-vendors.sql'),
  'utf8',
);
const LOTUS = '5c000000-0000-4000-8000-000000000001'; // venue, Chennai
const CANDID = '5c000000-0000-4000-8000-000000000004'; // photography
const DRAFT = '5c000000-0000-4000-8000-000000000019';
const LOTUS_VENDOR_USER = '5a000000-0000-4000-8000-000000000001';

interface EventVendor {
  id: string;
  status: string;
  notes: string | null;
  isAvailable: boolean;
  canEnquire: boolean;
  version: number;
  listing: { id: string; title: string };
  enquiries: { id: string; status: string; closedBy: string | null }[];
}

describeDb('Wishlist, event vendors and enquiries (e2e)', () => {
  let t: DbTestApp;
  let eventId: string;
  let seq = 0;

  beforeAll(async () => {
    t = await startDbTestApp(urls!);
  });

  afterAll(async () => {
    await t?.close();
  });

  const as = (uid: string) => {
    const auth = (r: import('supertest').Test) =>
      r.set('Authorization', `Bearer ${uid}`);
    return {
      get: (p: string) => auth(t.http().get(`/api/v1${p}`)),
      put: (p: string) => auth(t.http().put(`/api/v1${p}`)),
      delete: (p: string) => auth(t.http().delete(`/api/v1${p}`)),
      patch: (p: string, body: object) =>
        auth(t.http().patch(`/api/v1${p}`)).send(body),
      post: (p: string, body: object = {}, key = `ev-key-${++seq}`) =>
        auth(t.http().post(`/api/v1${p}`))
          .set('Idempotency-Key', key)
          .send(body),
    };
  };
  const a = () => as('uid-a');
  const inDays = (days: number) =>
    localDate('Asia/Kolkata', new Date(Date.now() + days * 86_400_000));
  const vendors = async () =>
    (await a().get(`/events/${eventId}/vendors`).expect(200)).body.data as {
      isEditable: boolean;
      vendors: EventVendor[];
    };
  const add = (listingId: string) =>
    a().post(`/events/${eventId}/vendors`, { listingId });
  const enquire = (evId: string, body: object, key?: string) =>
    a().post(`/events/${eventId}/vendors/${evId}/enquiries`, body, key);
  const MESSAGE = 'Hi, we are planning a wedding and would like a quote.';

  beforeEach(async () => {
    await t.reset();
    await t.migrator.query(SEED);
    for (const uid of ['uid-a', 'uid-b']) {
      await t
        .http()
        .post('/api/v1/auth/session')
        .set('Authorization', `Bearer ${uid}`)
        .expect(200);
    }
    await t.migrator.query(
      `UPDATE users SET display_name = 'Asha' WHERE firebase_uid = 'uid-a'`,
    );
    eventId = (
      await a()
        .post('/events', {
          eventType: 'Wedding',
          title: 'Asha & Ravi',
          eventDate: inDays(40),
          city: 'Chennai',
          guestCountEstimate: 300,
          venueName: 'Secret Hall',
          totalBudget: { amount: '900000.00', currency: 'INR' },
        })
        .expect(201)
    ).body.data.id as string;
  });

  describe('wishlist', () => {
    it('saves idempotently, lists newest first and removes', async () => {
      await a().put(`/me/wishlist/${LOTUS}`).expect(204);
      await a().put(`/me/wishlist/${LOTUS}`).expect(204);
      await a().put(`/me/wishlist/${CANDID}`).expect(204);
      const list = (await a().get('/me/wishlist').expect(200)).body.data as {
        listing: { id: string };
        isAvailable: boolean;
      }[];
      expect(list.map((i) => i.listing.id)).toEqual([CANDID, LOTUS]);
      expect(list.every((i) => i.isAvailable)).toBe(true);
      expect((await a().get('/me/wishlist/ids').expect(200)).body.data).toEqual(
        [CANDID, LOTUS],
      );
      // Only the owner's list.
      expect(
        (await as('uid-b').get('/me/wishlist').expect(200)).body.data,
      ).toEqual([]);
      await a().delete(`/me/wishlist/${LOTUS}`).expect(204);
      await a().delete(`/me/wishlist/${LOTUS}`).expect(204); // no-op
      expect((await a().get('/me/wishlist/ids').expect(200)).body.data).toEqual(
        [CANDID],
      );
    });

    it('pages, marks hidden listings and rejects hidden or guest saves', async () => {
      await a().put(`/me/wishlist/${LOTUS}`).expect(204);
      await a().put(`/me/wishlist/${CANDID}`).expect(204);
      await a().put(`/me/wishlist/${DRAFT}`).expect(404);
      await t.http().put(`/api/v1/me/wishlist/${LOTUS}`).expect(401);
      const first = await a().get('/me/wishlist?limit=1').expect(200);
      const cursor = first.body.meta.page.nextCursor as string;
      const second = await a()
        .get(`/me/wishlist?limit=1&cursor=${cursor}`)
        .expect(200);
      expect(second.body.data[0].listing.id).toBe(LOTUS);
      await t.migrator.query(
        `UPDATE vendor_listings SET status = 'SUSPENDED' WHERE id = $1`,
        [LOTUS],
      );
      const list = (await a().get('/me/wishlist').expect(200)).body.data as {
        listing: { id: string };
        isAvailable: boolean;
      }[];
      expect(list.find((i) => i.listing.id === LOTUS)!.isAvailable).toBe(false);
    });

    it('filters discovery by saved listings for signed-in users only', async () => {
      await a().put(`/me/wishlist/${CANDID}`).expect(204);
      const saved = await a().get('/listings?saved=true').expect(200);
      expect((saved.body.data as { id: string }[]).map((c) => c.id)).toEqual([
        CANDID,
      ]);
      await t.http().get('/api/v1/listings?saved=true').expect(401);
      await a().get('/listings?saved=false').expect(422);
    });
  });

  describe('event vendors', () => {
    it('adds once, keeps private notes and removes', async () => {
      const created = await add(LOTUS).expect(201);
      const ev = created.body.data as EventVendor;
      expect(ev).toMatchObject({
        status: 'ADDED',
        isAvailable: true,
        canEnquire: true,
        listing: { id: LOTUS },
      });
      const again = await add(LOTUS).expect(200);
      expect(again.body.data.id).toBe(ev.id);

      const noted = (
        await a()
          .patch(`/events/${eventId}/vendors/${ev.id}`, {
            notes: 'Ask about parking',
            version: ev.version,
          })
          .expect(200)
      ).body.data as EventVendor;
      expect(noted.notes).toBe('Ask about parking');
      await a()
        .patch(`/events/${eventId}/vendors/${ev.id}`, {
          notes: 'x',
          version: ev.version,
        })
        .expect(412);

      await a().delete(`/events/${eventId}/vendors/${ev.id}`).expect(204);
      expect((await vendors()).vendors).toEqual([]);
      // A removed vendor can be added again (new row).
      const readded = (await add(LOTUS).expect(201)).body.data as EventVendor;
      expect(readded.id).not.toBe(ev.id);
    });

    it('is owner-only, visible-only, and read only when not planning', async () => {
      await add(DRAFT).expect(404);
      await add('00000000-0000-4000-8000-000000000000').expect(404);
      await as('uid-b')
        .post(`/events/${eventId}/vendors`, { listingId: LOTUS })
        .expect(404);
      await as('uid-b').get(`/events/${eventId}/vendors`).expect(404);
      const ev = (await add(LOTUS).expect(201)).body.data as EventVendor;
      await as('uid-b')
        .delete(`/events/${eventId}/vendors/${ev.id}`)
        .expect(404);

      await a().post(`/events/${eventId}/cancel`).expect(200);
      const list = await vendors();
      expect(list.isEditable).toBe(false);
      expect(list.vendors[0].canEnquire).toBe(false);
      await add(CANDID).expect(409);
    });

    it('blocks adding your own listing (A12)', async () => {
      await t.migrator.query(
        `UPDATE vendors SET user_id = (SELECT id FROM users WHERE firebase_uid = 'uid-a')
          WHERE id = '5b000000-0000-4000-8000-000000000004'`,
      );
      const res = await add(CANDID).expect(403);
      expect(res.body.error.code).toBe('FORBIDDEN_PERMISSION');
    });

    it('audits without private text', async () => {
      const ev = (await add(LOTUS).expect(201)).body.data as EventVendor;
      await a()
        .patch(`/events/${eventId}/vendors/${ev.id}`, {
          notes: 'Secret note',
          version: ev.version,
        })
        .expect(200);
      const rows = await t.migrator.query<{ action: string }[]>(
        `SELECT action, summary FROM audit_logs WHERE action LIKE 'EVENT_VENDOR_%' ORDER BY occurred_at, id`,
      );
      expect(rows.map((r) => r.action)).toEqual([
        'EVENT_VENDOR_ADDED',
        'EVENT_VENDOR_UPDATED',
      ]);
      expect(JSON.stringify(rows)).not.toContain('Secret note');
    });
  });

  describe('enquiries', () => {
    it('sends one open enquiry, notifies the vendor with A9 fields only', async () => {
      const ev = (await add(LOTUS).expect(201)).body.data as EventVendor;
      const sent = (
        await enquire(ev.id, {
          message: MESSAGE,
          preferredDate: inDays(5),
        }).expect(201)
      ).body.data as EventVendor;
      expect(sent.status).toBe('ENQUIRED');
      expect(sent.canEnquire).toBe(false);
      expect(sent.enquiries).toHaveLength(1);
      expect(sent.enquiries[0].status).toBe('OPEN');

      const dup = await enquire(ev.id, { message: MESSAGE }).expect(409);
      expect(dup.body.error.code).toBe('DUPLICATE');

      const [n] = await t.migrator.query<
        {
          recipient_user_id: string;
          audience: string;
          type: string;
          body: string;
          data: Record<string, unknown>;
          push_policy: string;
        }[]
      >(`SELECT * FROM notifications WHERE type = 'ENQUIRY_RECEIVED'`);
      expect(n).toMatchObject({
        recipient_user_id: LOTUS_VENDOR_USER,
        audience: 'VENDOR',
        push_policy: 'NEVER',
      });
      expect(n.data).toEqual({
        customerName: 'Asha',
        eventType: 'Wedding',
        eventDate: inDays(40),
        city: 'Chennai',
        guestCountEstimate: 300,
        listingId: LOTUS,
      });
      // A9: never the user's phone, email, venue, budget or notes.
      const text = JSON.stringify(n);
      for (const secret of ['+9198', '@', 'Secret Hall', '900000', 'uid-a']) {
        expect(text).not.toContain(secret);
      }
    });

    it('replays a retried enquiry instead of sending a second one', async () => {
      const ev = (await add(LOTUS).expect(201)).body.data as EventVendor;
      await enquire(ev.id, { message: MESSAGE }, 'same-key').expect(201);
      const again = await enquire(
        ev.id,
        { message: MESSAGE },
        'same-key',
      ).expect(201);
      expect(again.headers['idempotent-replayed']).toBe('true');
      const [{ count }] = await t.migrator.query<{ count: number }[]>(
        `SELECT count(*)::int AS count FROM enquiries`,
      );
      expect(count).toBe(1);
      await t
        .http()
        .post(`/api/v1/events/${eventId}/vendors/${ev.id}/enquiries`)
        .set('Authorization', 'Bearer uid-a')
        .send({ message: MESSAGE })
        .expect(428);
    });

    it('validates the message and preferred date', async () => {
      const ev = (await add(LOTUS).expect(201)).body.data as EventVendor;
      for (const body of [
        { message: 'too short' },
        { message: 'x'.repeat(1001) },
        { message: '   ' },
        { message: MESSAGE, preferredDate: '2026-02-30' },
        { message: MESSAGE, preferredDate: inDays(-1) },
      ]) {
        await enquire(ev.id, body).expect(422);
      }
    });

    it('closes an enquiry; the vendor can be enquired again', async () => {
      const ev = (await add(LOTUS).expect(201)).body.data as EventVendor;
      const sent = (await enquire(ev.id, { message: MESSAGE }).expect(201)).body
        .data as EventVendor;
      const enquiryId = sent.enquiries[0].id;
      const closed = (
        await a()
          .post(
            `/events/${eventId}/vendors/${ev.id}/enquiries/${enquiryId}/close`,
          )
          .expect(200)
      ).body.data as EventVendor;
      expect(closed.status).toBe('ADDED');
      expect(closed.enquiries[0]).toMatchObject({
        status: 'CLOSED',
        closedBy: 'USER',
      });
      expect(closed.canEnquire).toBe(true);
      await a()
        .post(
          `/events/${eventId}/vendors/${ev.id}/enquiries/${enquiryId}/close`,
        )
        .expect(409);
      await enquire(ev.id, { message: MESSAGE }).expect(201);
    });

    it('closes open enquiries when the vendor is removed or the event cancelled', async () => {
      const lotus = (await add(LOTUS).expect(201)).body.data as EventVendor;
      const candid = (await add(CANDID).expect(201)).body.data as EventVendor;
      await enquire(lotus.id, { message: MESSAGE }).expect(201);
      await enquire(candid.id, { message: MESSAGE }).expect(201);
      await a().delete(`/events/${eventId}/vendors/${lotus.id}`).expect(204);
      await a().post(`/events/${eventId}/cancel`).expect(200);
      const rows = await t.migrator.query<
        { event_vendor_id: string; status: string; closed_by_type: string }[]
      >(`SELECT event_vendor_id, status, closed_by_type FROM enquiries`);
      expect(rows.find((r) => r.event_vendor_id === lotus.id)).toMatchObject({
        status: 'CLOSED',
        closed_by_type: 'USER',
      });
      expect(rows.find((r) => r.event_vendor_id === candid.id)).toMatchObject({
        status: 'CLOSED',
        closed_by_type: 'SYSTEM',
      });
    });

    it('blocks enquiring when the listing was hidden after adding', async () => {
      const ev = (await add(LOTUS).expect(201)).body.data as EventVendor;
      await t.migrator.query(
        `UPDATE vendor_listings SET status = 'SUSPENDED' WHERE id = $1`,
        [LOTUS],
      );
      const list = await vendors();
      expect(list.vendors[0]).toMatchObject({
        isAvailable: false,
        canEnquire: false,
      });
      await enquire(ev.id, { message: MESSAGE }).expect(404);
    });
  });
});
