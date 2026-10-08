/** Media uploads and event covers (M10) against the local test database. */
import { localDate } from '../src/modules/events/event-rules';
import { ImageKitClient } from '../src/modules/media/imagekit.client';
import { MediaService } from '../src/modules/media/media.service';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';
import { FakeImageKitClient } from './fakes';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

interface Intent {
  mediaId: string;
  token: string;
  fields: Record<string, string>;
  maxBytes: number;
}

describeDb('Media uploads and event covers (e2e)', () => {
  let t: DbTestApp;
  const imageKit = new FakeImageKitClient();
  let eventId: string;
  let fileSeq = 0;

  beforeAll(async () => {
    t = await startDbTestApp(urls!, [
      { provide: ImageKitClient, useValue: imageKit },
    ]);
  });

  afterAll(async () => {
    await t?.close();
  });

  const as = (uid: string) => ({
    get: (p: string) =>
      t.http().get(`/api/v1${p}`).set('Authorization', `Bearer ${uid}`),
    post: (p: string, body: object = {}) =>
      t
        .http()
        .post(`/api/v1${p}`)
        .set('Authorization', `Bearer ${uid}`)
        .set('Idempotency-Key', `media-${Date.now()}-${++fileSeq}`)
        .send(body),
    put: (p: string, body: object) =>
      t
        .http()
        .put(`/api/v1${p}`)
        .set('Authorization', `Bearer ${uid}`)
        .send(body),
    delete: (p: string) =>
      t.http().delete(`/api/v1${p}`).set('Authorization', `Bearer ${uid}`),
  });
  const a = () => as('uid-a');

  const intent = async (body: object = {}) =>
    (
      await a()
        .post('/media/uploads', {
          kind: 'EVENT_COVER',
          ownerId: eventId,
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          ...body,
        })
        .expect(201)
    ).body.data as Intent;

  /** Simulates the app uploading [i] to ImageKit, then completing it. */
  const upload = async (i: Intent, file: object = {}) => {
    const fileId = `file_${++fileSeq}_abcdef`;
    imageKit.put({
      fileId,
      filePath: `${i.fields.folder}/${i.fields.fileName}`,
      ...file,
    });
    return {
      fileId,
      res: await a().post(`/media/uploads/${i.mediaId}/complete`, { fileId }),
    };
  };

  beforeEach(async () => {
    await t.reset();
    imageKit.isEnabled = true;
    imageKit.files.clear();
    imageKit.deleted.length = 0;
    imageKit.tokens.length = 0;
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
          title: 'Wedding',
          eventDate: localDate(
            'Asia/Kolkata',
            new Date(Date.now() + 30 * 86_400_000),
          ),
          city: 'Chennai',
        })
        .expect(201)
    ).body.data.id as string;
  });

  it('creates an upload intent with signed, fixed private settings', async () => {
    const i = await intent();
    expect(i.fields).toMatchObject({
      folder: `/test/event-cover/event/${eventId}`,
      fileName: `${i.mediaId}.jpg`,
      isPrivateFile: 'true',
      overwriteFile: 'false',
    });
    expect(i.token).toBe(`jwt-${imageKit.tokens.length}`);
    expect(i.maxBytes).toBe(5 * 1024 * 1024);
  });

  it('allows at most 3 unfinished uploads per event', async () => {
    await intent();
    await intent();
    await intent();
    const res = await a()
      .post('/media/uploads', {
        kind: 'EVENT_COVER',
        ownerId: eventId,
        contentType: 'image/jpeg',
        sizeBytes: 1024,
      })
      .expect(409);
    expect(res.body.error.code).toBe('LIMIT_REACHED');
  });

  it('validates the intent and ownership', async () => {
    const base = {
      kind: 'EVENT_COVER',
      ownerId: eventId,
      contentType: 'image/jpeg',
      sizeBytes: 1024,
    };
    await a()
      .post('/media/uploads', { ...base, contentType: 'image/gif' })
      .expect(422);
    await a()
      .post('/media/uploads', { ...base, sizeBytes: 5 * 1024 * 1024 + 1 })
      .expect(422);
    await as('uid-b').post('/media/uploads', base).expect(404);
    imageKit.isEnabled = false;
    await a().post('/media/uploads', base).expect(503);
  });

  it('verifies the upload, sets the cover and serves signed resized URLs', async () => {
    const i = await intent();
    const { res } = await upload(i);
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('READY');

    const event = (
      await a()
        .put(`/events/${eventId}/cover`, { mediaId: i.mediaId })
        .expect(200)
    ).body.data;
    expect(event.cover.mediaId).toBe(i.mediaId);
    expect(event.cover.url).toContain(
      `${i.fields.folder}/${i.fields.fileName}?tr=w-1200`,
    );
    expect(event.cover.url).toContain('md-false');
    expect(event.cover.thumbnailUrl).toContain('tr=w-480');
    expect(event.cover.url).toContain('ik-s=');

    const list = (await a().get('/events').expect(200)).body.data;
    expect(list[0].cover.mediaId).toBe(i.mediaId);
  });

  it('rejects files that are too large, the wrong type or public, and deletes them', async () => {
    for (const [file, code] of [
      [{ size: 5 * 1024 * 1024 + 1 }, 'TOO_LARGE'],
      [{ size: 0 }, 'EMPTY'],
      [{ mime: 'image/gif' }, 'TYPE_NOT_ALLOWED'],
      [{ isPrivateFile: false }, 'NOT_PRIVATE'],
    ] as const) {
      const i = await intent();
      const { fileId, res } = await upload(i, file);
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('MEDIA_INVALID');
      expect(res.body.error.details[0].code).toBe(code);
      expect(imageKit.deleted).toContain(fileId);
      await a()
        .put(`/events/${eventId}/cover`, { mediaId: i.mediaId })
        .expect(422);
    }
  });

  it('never accepts a file outside the reserved path (and does not delete it)', async () => {
    const i = await intent();
    const fileId = 'someone_elses_file_1';
    imageKit.put({ fileId, filePath: '/test/event-cover/event/other/x.jpg' });
    const res = await a()
      .post(`/media/uploads/${i.mediaId}/complete`, { fileId })
      .expect(422);
    expect(res.body.error.details[0].code).toBe('WRONG_PATH');
    expect(imageKit.deleted).not.toContain(fileId);
    await a()
      .post(`/media/uploads/${(await intent()).mediaId}/complete`, {
        fileId: 'missing_file_x',
      })
      .expect(422);
  });

  it("does not let another user complete or use someone's upload", async () => {
    const i = await intent();
    imageKit.put({
      fileId: 'file_b_abcdef',
      filePath: `${i.fields.folder}/${i.fields.fileName}`,
    });
    await as('uid-b')
      .post(`/media/uploads/${i.mediaId}/complete`, { fileId: 'file_b_abcdef' })
      .expect(404);
    await a()
      .post(`/media/uploads/${i.mediaId}/complete`, { fileId: 'file_b_abcdef' })
      .expect(200);
    await as('uid-b')
      .put(`/events/${eventId}/cover`, { mediaId: i.mediaId })
      .expect(404);
  });

  it('replaces and removes the cover, keeping old media soft-deleted and audited', async () => {
    const first = await intent();
    await upload(first);
    await a()
      .put(`/events/${eventId}/cover`, { mediaId: first.mediaId })
      .expect(200);
    const second = await intent();
    await upload(second);
    await a()
      .put(`/events/${eventId}/cover`, { mediaId: second.mediaId })
      .expect(200);

    const [old] = await t.migrator.query<{ deleted_at: Date | null }[]>(
      `SELECT deleted_at FROM media WHERE id = $1`,
      [first.mediaId],
    );
    expect(old.deleted_at).not.toBeNull();

    const removed = (await a().delete(`/events/${eventId}/cover`).expect(200))
      .body.data;
    expect(removed.cover).toBeNull();
    const actions = (
      await t.migrator.query<{ action: string }[]>(
        `SELECT action FROM audit_logs WHERE action LIKE 'EVENT_COVER_%' OR action = 'MEDIA_UPLOADED' ORDER BY occurred_at, id`,
      )
    ).map((r) => r.action);
    expect(actions).toEqual([
      'MEDIA_UPLOADED',
      'EVENT_COVER_SET',
      'MEDIA_UPLOADED',
      'EVENT_COVER_SET',
      'EVENT_COVER_REMOVED',
    ]);
  });

  it('allows a cover on a cancelled event (event details stay editable)', async () => {
    await a().post(`/events/${eventId}/cancel`).expect(200);
    const i = await intent();
    await upload(i);
    const event = (
      await a()
        .put(`/events/${eventId}/cover`, { mediaId: i.mediaId })
        .expect(200)
    ).body.data;
    expect(event.cover.mediaId).toBe(i.mediaId);
  });

  it('a late rejection does not undo a completed upload', async () => {
    const i = await intent();
    const { fileId } = await upload(i);
    // A second completion with a bad file id after success: rejected, the
    // good file stays.
    const res = await a()
      .post(`/media/uploads/${i.mediaId}/complete`, {
        fileId: 'missing_file_x',
      })
      .expect(409);
    expect(res.body.error.code).toBe('INVALID_STATE_TRANSITION');
    expect(imageKit.deleted).not.toContain(fileId);
  });

  it('rejects uploads abandoned for over a day and removes their files', async () => {
    const i = await intent();
    imageKit.put({
      fileId: 'abandoned_file_1',
      filePath: `${i.fields.folder}/${i.fields.fileName}`,
    });
    await t.migrator.query(
      `UPDATE media SET created_at = now() - interval '25 hours' WHERE id = $1`,
      [i.mediaId],
    );
    expect(await t.app.get(MediaService).rejectAbandoned()).toBe(1);
    const [row] = await t.migrator.query<{ status: string }[]>(
      `SELECT status FROM media WHERE id = $1`,
      [i.mediaId],
    );
    expect(row.status).toBe('REJECTED');
    expect(imageKit.deleted).toContain('abandoned_file_1');
  });
});
