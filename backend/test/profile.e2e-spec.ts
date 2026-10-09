/** Profile, photo and account deletion (M21; R11 interim, A8 as changed). */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { localDate } from '../src/modules/events/event-rules';
import { ImageKitClient } from '../src/modules/media/imagekit.client';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';
import { FakeImageKitClient } from './fakes';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

const seed = (file: string) =>
  readFileSync(join(__dirname, '..', '..', 'database', 'seeds', file), 'utf8');
const VENDORS = seed('dev-sample-vendors.sql');
const QUOTES = seed('dev-sample-quotes.sql');
const LOTUS = '5c000000-0000-4000-8000-000000000001';

interface Me {
  id: string;
  displayName: string | null;
  status: string;
  photo: { mediaId: string; url: string } | null;
}

describeDb('Profile and account deletion (e2e)', () => {
  let t: DbTestApp;
  const imageKit = new FakeImageKitClient();
  let seq = 0;

  beforeAll(async () => {
    t = await startDbTestApp(urls!, [
      { provide: ImageKitClient, useValue: imageKit },
    ]);
  });

  afterAll(async () => {
    await t?.close();
  });

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
      put: (p: string, body: object) =>
        auth(t.http().put(`/api/v1${p}`)).send(body),
      post: (p: string, body: object = {}) =>
        auth(t.http().post(`/api/v1${p}`))
          .set('Idempotency-Key', `profile-key-${++seq}`)
          .send(body),
    };
  };
  const a = () => as('uid-a');
  const signIn = (uid: string) =>
    t.http().post('/api/v1/auth/session').set('Authorization', `Bearer ${uid}`);
  const me = async () => (await a().get('/me').expect(200)).body.data as Me;

  beforeEach(async () => {
    await t.reset();
    imageKit.isEnabled = true;
    imageKit.files.clear();
    await signIn('uid-a').expect(200);
  });

  it('edits the name; phone and email cannot be changed', async () => {
    expect(await me()).toMatchObject({ displayName: null, photo: null });
    const updated = await a()
      .patch('/me', { displayName: '  Asha   Kumar ' })
      .expect(200);
    expect(updated.body.data.displayName).toBe('Asha Kumar');
    for (const body of [
      {},
      { displayName: '' },
      { displayName: 'x'.repeat(61) },
      { displayName: 'Asha', phone: '+910000000000' },
    ]) {
      await a().patch('/me', body).expect(422);
    }
    const [audit] = await t.migrator.query<{ summary: object }[]>(
      `SELECT summary FROM audit_logs WHERE action = 'PROFILE_UPDATED'`,
    );
    expect(JSON.stringify(audit.summary)).not.toContain('Asha');
  });

  it('sets, replaces and removes a profile photo', async () => {
    const { id } = await me();
    await a()
      .post('/media/uploads', {
        kind: 'USER_PHOTO',
        ownerId: '00000000-0000-4000-8000-000000000000',
        contentType: 'image/jpeg',
        sizeBytes: 1024,
      })
      .expect(404);
    const upload = async () => {
      const intent = (
        await a()
          .post('/media/uploads', {
            kind: 'USER_PHOTO',
            ownerId: id,
            contentType: 'image/jpeg',
            sizeBytes: 1024,
          })
          .expect(201)
      ).body.data as {
        mediaId: string;
        fields: { folder: string; fileName: string };
      };
      expect(intent.fields.folder).toBe(`/test/user-photo/user/${id}`);
      const fileId = `file_${++seq}_abcdef`;
      imageKit.put({
        fileId,
        filePath: `${intent.fields.folder}/${intent.fields.fileName}`,
      });
      await a()
        .post(`/media/uploads/${intent.mediaId}/complete`, { fileId })
        .expect(200);
      return intent.mediaId;
    };
    const first = await upload();
    const set = await a().put('/me/photo', { mediaId: first }).expect(200);
    expect(set.body.data.photo).toMatchObject({ mediaId: first });
    const second = await upload();
    await a().put('/me/photo', { mediaId: second }).expect(200);
    const [old] = await t.migrator.query<{ deleted_at: Date | null }[]>(
      `SELECT deleted_at FROM media WHERE id = $1`,
      [first],
    );
    expect(old.deleted_at).not.toBeNull();
    // Someone else's media can't be used.
    await signIn('uid-b').expect(200);
    await as('uid-b').put('/me/photo', { mediaId: second }).expect(422);
    const removed = await a().delete('/me/photo').expect(200);
    expect(removed.body.data.photo).toBeNull();
  });

  it('deletes the account, cancels its plans and restores on sign-in', async () => {
    await t.migrator.query(VENDORS);
    const eventId = (
      await a()
        .post('/events', {
          eventType: 'Wedding',
          title: 'Asha & Ravi',
          eventDate: inDays(40),
          city: 'Chennai',
        })
        .expect(201)
    ).body.data.id as string;
    const evId = (
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
    await a()
      .post(
        `/events/${eventId}/vendors/${evId}/quotations/${vendor.quotations[0].id}/accept`,
      )
      .expect(200);
    await a()
      .post(`/events/${eventId}/reminders`, {
        title: 'Call the caterer',
        remindAt: new Date(Date.now() + 86_400_000).toISOString(),
      })
      .expect(201);
    await a()
      .put(`/events/${eventId}/invitation`, {
        templateCode: 'classic',
        title: 'Asha & Ravi',
      })
      .expect(200);
    await a().post(`/events/${eventId}/invitation/publish`).expect(200);
    await a()
      .put('/me/devices', { token: 't'.repeat(40), platform: 'ANDROID' })
      .expect(204);

    await a().post('/me/delete', { confirm: 'delete' }).expect(422);
    await a().post('/me/delete', { confirm: 'DELETE' }).expect(204);

    const q = <T>(sql: string) => t.migrator.query<T[]>(sql);
    const [user] = await q<{ status: string; deleted_at: Date | null }>(
      `SELECT status, deleted_at FROM users WHERE firebase_uid = 'uid-a'`,
    );
    expect(user.status).toBe('DELETED');
    const [booking] = await q<{ status: string; cancel_reason: string }>(
      `SELECT status, cancel_reason FROM bookings`,
    );
    expect(booking).toEqual({
      status: 'CANCELLED',
      cancel_reason: 'Account deleted',
    });
    const [event] = await q<{ status: string }>(`SELECT status FROM events`);
    expect(event.status).toBe('CANCELLED');
    const [reminder] = await q<{ status: string }>(
      `SELECT status FROM reminders`,
    );
    expect(reminder.status).toBe('CANCELLED');
    const [inv] = await q<{ status: string; share_token_hash: unknown }>(
      `SELECT status, share_token_hash FROM invitations`,
    );
    expect(inv).toEqual({ status: 'REVOKED', share_token_hash: null });
    const [device] = await q<{ is_active: boolean }>(
      `SELECT is_active FROM notification_devices`,
    );
    expect(device.is_active).toBe(false);
    const vendorNote = await q<{ audience: string; data: { reason: string } }>(
      `SELECT audience, data FROM notifications WHERE type = 'BOOKING_CANCELLED'`,
    );
    expect(vendorNote).toEqual([
      expect.objectContaining({
        audience: 'VENDOR',
        data: expect.objectContaining({ reason: 'Account deleted' }),
      }),
    ]);
    expect(t.verifier.revoked).toContain('uid-a');
    // Data is kept (R11 interim): nothing removed.
    expect(await q(`SELECT id FROM events`)).toHaveLength(1);

    const refused = await a().get('/me').expect(403);
    expect(refused.body.error.code).toBe('ACCOUNT_DELETED');

    // Signing in again restores the same account (user answer A).
    const back = await signIn('uid-a').expect(200);
    expect(back.body.data.user).toMatchObject({ status: 'ACTIVE' });
    expect(back.body.data.isNewUser).toBe(false);
    expect((await me()).status).toBe('ACTIVE');
    const events = (await a().get('/events').expect(200)).body.data as {
      status: string;
    }[];
    expect(events.map((e) => e.status)).toEqual(['CANCELLED']);
    const [restored] = await q<{ action: string }>(
      `SELECT action FROM audit_logs WHERE action = 'ACCOUNT_RESTORED'`,
    );
    expect(restored).toBeDefined();
  });
});
