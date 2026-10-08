/** Notification center, devices, preferences and push delivery (M18). */
import { PushWorker } from '../src/modules/notifications/push.worker';
import { ReminderJobs } from '../src/modules/reminders/reminder-jobs';
import { localDate } from '../src/modules/events/event-rules';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

const TOKEN_A = 'token-aaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const TOKEN_B = 'token-bbbbbbbbbbbbbbbbbbbbbbbbbbbb';

describeDb('Notifications and push (e2e)', () => {
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
      put: (p: string, body: object) =>
        auth(t.http().put(`/api/v1${p}`)).send(body),
      delete: (p: string) => auth(t.http().delete(`/api/v1${p}`)),
      post: (p: string, body: object = {}) =>
        auth(t.http().post(`/api/v1${p}`))
          .set('Idempotency-Key', `ntf-key-${++seq}`)
          .send(body),
    };
  };
  const a = () => as('uid-a');
  const worker = () => t.app.get(PushWorker);
  const later = () => new Date(Date.now() + 2 * 60_000);

  /** Creates a due reminder for uid-a and fires it (→ a pushable record). */
  async function fireReminder(title = 'Call the caterer') {
    await a()
      .post(`/events/${eventId}/reminders`, {
        title,
        remindAt: new Date(Date.now() + 60_000).toISOString(),
      })
      .expect(201);
    await t.app.get(ReminderJobs).fireDueReminders(later());
  }

  beforeEach(async () => {
    await t.reset();
    t.fcm.sent.length = 0;
    t.fcm.results.clear();
    for (const uid of ['uid-a', 'uid-b']) {
      await t
        .http()
        .post('/api/v1/auth/session')
        .set('Authorization', `Bearer ${uid}`)
        .expect(200);
    }
    // Sign-in creates a welcome notification (M5); start from none.
    await t.migrator.query(`DELETE FROM notifications`);
    eventId = (
      await a()
        .post('/events', {
          eventType: 'Wedding',
          title: 'Asha & Ravi',
          eventDate: localDate(
            'Asia/Kolkata',
            new Date(Date.now() + 30 * 86_400_000),
          ),
          city: 'Chennai',
        })
        .expect(201)
    ).body.data.id as string;
  });

  it('lists, counts and marks notifications read', async () => {
    await fireReminder('First');
    await fireReminder('Second');
    const list = (await a().get('/me/notifications').expect(200)).body.data as {
      id: string;
      title: string;
      body: string;
      readAt: string | null;
    }[];
    expect(list.map((n) => n.body)).toEqual(['Second', 'First']);
    expect(
      (await a().get('/me/notifications/unread-count').expect(200)).body.data,
    ).toEqual({ count: 2 });
    await a().post(`/me/notifications/${list[0].id}/read`).expect(204);
    expect(
      (await a().get('/me/notifications/unread-count').expect(200)).body.data
        .count,
    ).toBe(1);
    await as('uid-b').post(`/me/notifications/${list[1].id}/read`).expect(404);
    expect(
      (await a().post('/me/notifications/read-all').expect(200)).body.data,
    ).toEqual({ updated: 1 });
    expect(
      (await as('uid-b').get('/me/notifications').expect(200)).body.data,
    ).toEqual([]);
  });

  it('pages notifications', async () => {
    for (const title of ['One', 'Two', 'Three']) await fireReminder(title);
    const first = await a().get('/me/notifications?limit=2').expect(200);
    expect(first.body.data).toHaveLength(2);
    const next = await a()
      .get(
        `/me/notifications?limit=2&cursor=${first.body.meta.page.nextCursor}`,
      )
      .expect(200);
    expect((next.body.data as { body: string }[]).map((n) => n.body)).toEqual([
      'One',
    ]);
  });

  it('pushes to active devices with ids only in the data', async () => {
    await a()
      .put('/me/devices', {
        token: TOKEN_A,
        platform: 'ANDROID',
        appVersion: '1.0.0',
      })
      .expect(204);
    await fireReminder('Pay the decorator');
    expect(await worker().run(later())).toBe(1);
    expect(t.fcm.sent).toHaveLength(1);
    const { tokens, message } = t.fcm.sent[0];
    expect(tokens).toEqual([TOKEN_A]);
    expect(message).toMatchObject({
      title: 'Reminder',
      body: 'Pay the decorator',
      androidChannelId: 'reminders',
    });
    expect(Object.keys(message.data).sort()).toEqual(
      ['entityId', 'entityType', 'eventId', 'notificationId', 'type'].sort(),
    );
    const [row] = await t.migrator.query<{ delivery_status: string }[]>(
      `SELECT delivery_status FROM notifications WHERE type = 'REMINDER_DUE'`,
    );
    expect(row.delivery_status).toBe('SENT');
    expect(await worker().run(later())).toBe(0); // at most once per pass
  });

  it('skips when the group is off or there is no device', async () => {
    await fireReminder();
    expect(await worker().run(later())).toBe(1);
    const [noDevice] = await t.migrator.query<
      { delivery_status: string; push_error: string }[]
    >(`SELECT delivery_status, push_error FROM notifications`);
    expect(noDevice).toMatchObject({
      delivery_status: 'SKIPPED',
      push_error: 'no active device',
    });

    await a()
      .put('/me/devices', { token: TOKEN_A, platform: 'IOS' })
      .expect(204);
    const prefs = (
      await a()
        .put('/me/notification-preferences', {
          preferences: [{ group: 'REMINDERS', pushEnabled: false }],
        })
        .expect(200)
    ).body.data;
    expect(prefs).toEqual([
      { group: 'BOOKINGS', pushEnabled: true },
      { group: 'REMINDERS', pushEnabled: false },
      { group: 'OTHER', pushEnabled: true },
    ]);
    await fireReminder('Muted');
    await worker().run(later());
    expect(t.fcm.sent).toHaveLength(0);
    // The in-app record still exists.
    expect(
      (await a().get('/me/notifications').expect(200)).body.data[0].body,
    ).toBe('Muted');
  });

  it('deactivates invalid tokens and retries transient failures', async () => {
    await a()
      .put('/me/devices', { token: TOKEN_A, platform: 'ANDROID' })
      .expect(204);
    await a()
      .put('/me/devices', { token: TOKEN_B, platform: 'ANDROID' })
      .expect(204);
    t.fcm.results.set(TOKEN_A, 'INVALID_TOKEN');
    t.fcm.results.set(TOKEN_B, 'RETRY');
    await fireReminder();
    await worker().run(later());
    const devices = await t.migrator.query<
      { fcm_token: string; is_active: boolean }[]
    >(
      `SELECT fcm_token, is_active FROM notification_devices ORDER BY fcm_token`,
    );
    expect(devices).toEqual([
      { fcm_token: TOKEN_A, is_active: false },
      { fcm_token: TOKEN_B, is_active: true },
    ]);
    const [pending] = await t.migrator.query<
      { delivery_status: string; push_attempts: number; push_next_at: Date }[]
    >(`SELECT delivery_status, push_attempts, push_next_at FROM notifications`);
    expect(pending).toMatchObject({
      delivery_status: 'PENDING',
      push_attempts: 1,
    });
    // Not due again until the backoff passes.
    expect(await worker().run(later())).toBe(0);
    t.fcm.results.delete(TOKEN_B);
    expect(await worker().run(new Date(Date.now() + 10 * 60_000))).toBe(1);
    const [sent] = await t.migrator.query<{ delivery_status: string }[]>(
      `SELECT delivery_status FROM notifications`,
    );
    expect(sent.delivery_status).toBe('SENT');
  });

  it('gives up after five attempts', async () => {
    await a()
      .put('/me/devices', { token: TOKEN_A, platform: 'ANDROID' })
      .expect(204);
    t.fcm.results.set(TOKEN_A, 'RETRY');
    await fireReminder();
    let at = Date.now();
    for (let i = 0; i < 6; i++) {
      at += 60 * 60_000;
      await worker().run(new Date(at));
    }
    const [row] = await t.migrator.query<
      { delivery_status: string; push_attempts: number }[]
    >(`SELECT delivery_status, push_attempts FROM notifications`);
    expect(row).toEqual({ delivery_status: 'FAILED', push_attempts: 5 });
  });

  it('moves a token to the new user and removes it on sign-out', async () => {
    await a()
      .put('/me/devices', { token: TOKEN_A, platform: 'ANDROID' })
      .expect(204);
    await as('uid-b')
      .put('/me/devices', { token: TOKEN_A, platform: 'ANDROID' })
      .expect(204);
    await fireReminder(); // for uid-a, whose phone now belongs to uid-b
    await worker().run(later());
    expect(t.fcm.sent).toHaveLength(0);
    await as('uid-b').delete(`/me/devices/${TOKEN_A}`).expect(204);
    const [{ count }] = await t.migrator.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM notification_devices`,
    );
    expect(count).toBe(0);
  });

  it('validates device and preference input', async () => {
    await a()
      .put('/me/devices', { token: 'short', platform: 'ANDROID' })
      .expect(422);
    await a()
      .put('/me/devices', { token: TOKEN_A, platform: 'WEB' })
      .expect(422);
    await a()
      .put('/me/notification-preferences', {
        preferences: [{ group: 'ALL', pushEnabled: false }],
      })
      .expect(422);
    await t.http().get('/api/v1/me/notifications').expect(401);
  });

  it('vendor-audience records are never queued for push', async () => {
    await t.migrator.query(
      `INSERT INTO notifications (id, recipient_type, recipient_user_id, audience, category, type, title, body, push_policy)
       SELECT gen_random_uuid(), 'USER', id, 'VENDOR', 'BOOKING', 'ENQUIRY_RECEIVED', 't', 'b', 'NEVER'
         FROM users WHERE firebase_uid = 'uid-a'`,
    );
    expect(await worker().run(later())).toBe(0);
    expect((await a().get('/me/notifications').expect(200)).body.data).toEqual(
      [],
    );
  });
});
