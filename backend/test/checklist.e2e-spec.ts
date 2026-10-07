/** Checklist (M9) against the real local test database. */
import { localDate } from '../src/modules/events/event-rules';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

function day(days: number): string {
  return localDate('Asia/Kolkata', new Date(Date.now() + days * 86_400_000));
}

interface ItemBody {
  id: string;
  title: string;
  status: string;
  isOverdue: boolean;
  version: number;
}

const titles = (items: unknown): string[] =>
  (items as ItemBody[]).map((i) => i.title);

describeDb('Checklist with PostgreSQL (e2e)', () => {
  let t: DbTestApp;
  let keySeq = 0;
  let eventId: string;

  beforeAll(async () => {
    t = await startDbTestApp(urls!);
  });

  afterAll(async () => {
    await t?.close();
  });

  const as = (uid: string) => {
    const auth = (r: ReturnType<ReturnType<DbTestApp['http']>['get']>) =>
      r.set('Authorization', `Bearer ${uid}`);
    return {
      get: (p: string) => auth(t.http().get(`/api/v1${p}`)),
      post: (p: string, body?: object) =>
        auth(t.http().post(`/api/v1${p}`))
          .set('Idempotency-Key', `ck-${++keySeq}-${Date.now()}`)
          .send(body ?? {}),
      patch: (p: string, body: object) =>
        auth(t.http().patch(`/api/v1${p}`)).send(body),
      put: (p: string, body: object) =>
        auth(t.http().put(`/api/v1${p}`)).send(body),
      delete: (p: string) => auth(t.http().delete(`/api/v1${p}`)),
    };
  };
  const a = () => as('uid-a');
  const path = (suffix = '') => `/events/${eventId}/checklist${suffix}`;
  const add = async (title: string, extra: object = {}) =>
    (
      await a()
        .post(path(), { title, ...extra })
        .expect(201)
    ).body.data as ItemBody;

  beforeEach(async () => {
    await t.reset();
    for (const uid of ['uid-a', 'uid-b']) {
      await t
        .http()
        .post('/api/v1/auth/session')
        .set('Authorization', `Bearer ${uid}`)
        .expect(200);
    }
    const created = await a()
      .post('/events', {
        eventType: 'Wedding',
        title: 'Wedding',
        eventDate: day(30),
        city: 'Chennai',
      })
      .expect(201);
    eventId = created.body.data.id as string;
  });

  it('adds items in order, derives overdue and summarises on the event', async () => {
    await add('Book photographer', { dueDate: day(-1) });
    await add('Send invitations', { dueDate: day(5), notes: 'Family first' });
    const third = await add('Order cake');
    expect(third.status).toBe('PENDING');

    const list = (await a().get(path()).expect(200)).body.data;
    expect(list.isEditable).toBe(true);
    expect(titles(list.items)).toEqual([
      'Book photographer',
      'Send invitations',
      'Order cake',
    ]);
    expect((list.items as ItemBody[]).map((i) => i.isOverdue)).toEqual([
      true,
      false,
      false,
    ]);
    expect(list.summary).toEqual({ total: 3, done: 0, overdue: 1 });

    const event = (await a().get(`/events/${eventId}`).expect(200)).body.data;
    expect(event.checklist).toEqual({ total: 3, done: 0, overdue: 1 });
    const events = (await a().get('/events').expect(200)).body.data;
    expect(events[0].checklist).toEqual({ total: 3, done: 0, overdue: 1 });
  });

  it('completes and reopens items, setting completedAt', async () => {
    const item = await add('Book photographer', { dueDate: day(-1) });
    const done = (
      await a()
        .post(path(`/${item.id}/complete`))
        .expect(200)
    ).body.data;
    expect(done.status).toBe('DONE');
    expect(done.isOverdue).toBe(false);
    expect(done.completedAt).not.toBeNull();
    const again = await a()
      .post(path(`/${item.id}/complete`))
      .expect(409);
    expect(again.body.error.code).toBe('INVALID_STATE_TRANSITION');
    const reopened = (
      await a()
        .post(path(`/${item.id}/reopen`))
        .expect(200)
    ).body.data;
    expect(reopened).toMatchObject({ status: 'PENDING', completedAt: null });
  });

  it('edits with a version check; null clears optional fields', async () => {
    const item = await add('Venue', {
      notes: 'Ask about parking',
      dueDate: day(3),
    });
    const edited = (
      await a()
        .patch(path(`/${item.id}`), {
          title: 'Venue visit',
          notes: null,
          dueDate: null,
          version: item.version,
        })
        .expect(200)
    ).body.data;
    expect(edited).toMatchObject({
      title: 'Venue visit',
      notes: null,
      dueDate: null,
      version: item.version + 1,
    });
    await a()
      .patch(path(`/${item.id}`), { title: 'Stale', version: item.version })
      .expect(412);
    await a()
      .patch(path(`/${item.id}`), { title: null, version: edited.version })
      .expect(422);
  });

  it('validates input', async () => {
    await a().post(path(), { title: '' }).expect(422);
    await a()
      .post(path(), { title: 'x'.repeat(121) })
      .expect(422);
    await a()
      .post(path(), { title: 'ok', notes: 'n'.repeat(1001) })
      .expect(422);
    await a().post(path(), { title: 'ok', dueDate: '2026-02-30' }).expect(422);
    await a().post(path(), { title: 'ok', status: 'DONE' }).expect(422);
  });

  it('reorders all items and rejects partial lists', async () => {
    const one = await add('One');
    const two = await add('Two');
    const three = await add('Three');
    const res = await a()
      .put(path('/order'), { itemIds: [three.id, one.id, two.id] })
      .expect(200);
    expect(titles(res.body.data.items)).toEqual(['Three', 'One', 'Two']);
    // Order is presentation only: versions are unchanged.
    expect((res.body.data.items as ItemBody[]).map((i) => i.version)).toEqual([
      1, 1, 1,
    ]);
    await a()
      .put(path('/order'), { itemIds: [one.id, two.id] })
      .expect(422);
  });

  it('soft-deletes items', async () => {
    const item = await add('Temporary');
    await a()
      .delete(path(`/${item.id}`))
      .expect(204);
    await a()
      .delete(path(`/${item.id}`))
      .expect(404);
    const list = (await a().get(path()).expect(200)).body.data;
    expect(list.items).toEqual([]);
    const [row] = await t.migrator.query<{ deleted_at: Date | null }[]>(
      `SELECT deleted_at FROM checklist_items WHERE id = $1`,
      [item.id],
    );
    expect(row.deleted_at).not.toBeNull();
  });

  it('is read only once the event is completed or cancelled', async () => {
    const item = await add('Book photographer');
    await a().post(`/events/${eventId}/cancel`).expect(200);
    const list = (await a().get(path()).expect(200)).body.data;
    expect(list.isEditable).toBe(false);
    expect(list.items).toHaveLength(1);
    const blocked = await a().post(path(), { title: 'More' }).expect(409);
    expect(blocked.body.error.code).toBe('INVALID_STATE_TRANSITION');
    await a()
      .post(path(`/${item.id}/complete`))
      .expect(409);
    await a()
      .delete(path(`/${item.id}`))
      .expect(409);

    await a().post(`/events/${eventId}/reopen`).expect(200);
    await a()
      .post(path(`/${item.id}/complete`))
      .expect(200);
  });

  it('hides another user’s checklist and a deleted event’s items', async () => {
    const item = await add('Private');
    const b = as('uid-b');
    await b.get(path()).expect(404);
    await b.post(path(), { title: 'Intrude' }).expect(404);
    await b.post(path(`/${item.id}/complete`)).expect(404);
    await b.delete(path(`/${item.id}`)).expect(404);
    await a().get('/events/not-a-uuid/checklist').expect(404);

    await a().delete(`/events/${eventId}`).expect(204);
    await a().get(path()).expect(404);
  });

  it('replays a retried add and rejects a reused key', async () => {
    const send = (key: string, title: string) =>
      t
        .http()
        .post(`/api/v1${path()}`)
        .set('Authorization', 'Bearer uid-a')
        .set('Idempotency-Key', key)
        .send({ title });
    const first = await send('ck-replay-key-1', 'Cake').expect(201);
    const retry = await send('ck-replay-key-1', 'Cake').expect(201);
    expect(retry.headers['idempotent-replayed']).toBe('true');
    expect(retry.body.data.id).toBe(first.body.data.id);
    const reused = await send('ck-replay-key-1', 'Flowers').expect(409);
    expect(reused.body.error.code).toBe('IDEMPOTENCY_KEY_REUSED');
    expect((await a().get(path()).expect(200)).body.data.items).toHaveLength(1);
  });

  it('rejects every write by another user and items under the wrong event', async () => {
    const item = await add('Private');
    const b = as('uid-b');
    await b.patch(path(`/${item.id}`), { title: 'x', version: 1 }).expect(404);
    await b.put(path('/order'), { itemIds: [item.id] }).expect(404);
    await b.post(path(`/${item.id}/reopen`)).expect(404);

    // Same owner, but the item belongs to a different event.
    const other = await a()
      .post('/events', {
        eventType: 'Party',
        title: 'Other',
        eventDate: day(10),
        city: 'Chennai',
      })
      .expect(201);
    const otherPath = `/events/${other.body.data.id}/checklist/${item.id}`;
    await a().post(`${otherPath}/complete`).expect(404);
    await a().patch(otherPath, { title: 'x', version: 1 }).expect(404);
    await a().delete(otherPath).expect(404);
  });

  it('computes overdue in the event time zone, not UTC', async () => {
    // Pago Pago (UTC−11) is always 1–2 calendar days behind Kiritimati
    // (UTC+14), so "today in Pago Pago" is overdue in Kiritimati only.
    const dueDate = localDate('Pacific/Pago_Pago', new Date());
    const ids: Record<string, string> = {};
    for (const timeZone of ['Pacific/Pago_Pago', 'Pacific/Kiritimati']) {
      const created = await a()
        .post('/events', {
          eventType: 'Party',
          title: timeZone,
          eventDate: localDate(timeZone, new Date(Date.now() + 5 * 86_400_000)),
          city: 'Somewhere',
          timeZone,
        })
        .expect(201);
      ids[timeZone] = created.body.data.id as string;
      await a()
        .post(`/events/${ids[timeZone]}/checklist`, { title: 'Due', dueDate })
        .expect(201);
    }
    const pago = (
      await a().get(`/events/${ids['Pacific/Pago_Pago']}/checklist`).expect(200)
    ).body.data;
    const kiri = (
      await a()
        .get(`/events/${ids['Pacific/Kiritimati']}/checklist`)
        .expect(200)
    ).body.data;
    expect(pago.items[0].isOverdue).toBe(false);
    expect(kiri.items[0].isOverdue).toBe(true);
    const event = (
      await a().get(`/events/${ids['Pacific/Kiritimati']}`).expect(200)
    ).body.data;
    expect(event.checklist.overdue).toBe(1);
  });

  it('treats blank notes as no notes', async () => {
    const item = await add('Venue', { notes: '   ' });
    expect((item as unknown as { notes: string | null }).notes).toBeNull();
  });

  it('limits a checklist to 200 items', async () => {
    await t.migrator.query(
      `INSERT INTO checklist_items (id, event_id, title, sort_order)
       SELECT gen_random_uuid(), $1, 'Item ' || n, n FROM generate_series(0, 199) AS n`,
      [eventId],
    );
    const res = await a().post(path(), { title: 'One too many' }).expect(409);
    expect(res.body.error.code).toBe('LIMIT_REACHED');
  });

  it('audits every change', async () => {
    const item = await add('Audited');
    await a()
      .post(path(`/${item.id}/complete`))
      .expect(200);
    await a()
      .put(path('/order'), { itemIds: [item.id] })
      .expect(200);
    await a()
      .delete(path(`/${item.id}`))
      .expect(204);
    const rows = await t.migrator.query<{ action: string }[]>(
      `SELECT action FROM audit_logs WHERE action LIKE 'CHECKLIST_%' ORDER BY occurred_at, id`,
    );
    expect(rows.map((r) => r.action)).toEqual([
      'CHECKLIST_ITEM_CREATED',
      'CHECKLIST_ITEM_COMPLETED',
      'CHECKLIST_REORDERED',
      'CHECKLIST_ITEM_DELETED',
    ]);
  });
});
