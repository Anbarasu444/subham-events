/** Invitations, the public guest page and RSVPs (M19; R9, A6). */
import { createHash } from 'node:crypto';
import { RsvpDigestJob } from '../src/modules/invitations/rsvp-digest.job';
import { localDate } from '../src/modules/events/event-rules';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

describeDb('Invitations (e2e)', () => {
  let t: DbTestApp;
  let eventId: string;

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
      post: (p: string, body: object = {}) =>
        auth(t.http().post(`/api/v1${p}`))
          .set(
            'Idempotency-Key',
            `inv-key-${Math.random().toString(36).slice(2, 12)}`,
          )
          .send(body),
    };
  };
  const a = () => as('uid-a');
  const path = () => `/events/${eventId}/invitation`;
  const save = (over: object = {}) =>
    a().put(path(), {
      templateCode: 'floral',
      title: 'Asha weds Ravi',
      message: 'Join us <b>please</b>',
      hostNames: 'The Kumar family',
      ...over,
    });
  const tokenOf = (shareUrl: unknown) => String(shareUrl).split('/i/')[1];
  const guest = () => t.http();
  /** Posts the RSVP form like a browser; returns the response. */
  const rsvp = (
    token: string,
    fields: Record<string, string>,
    cookie?: string,
  ) => {
    const req = guest()
      .post(`/api/v1/i/${token}/rsvp`)
      .type('form')
      .send(fields);
    return cookie ? req.set('Cookie', cookie) : req;
  };

  beforeEach(async () => {
    await t.reset();
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
          eventDate: localDate(
            'Asia/Kolkata',
            new Date(Date.now() + 30 * 86_400_000),
          ),
          startTime: '18:30',
          city: 'Chennai',
          venueName: 'Lotus Hall',
        })
        .expect(201)
    ).body.data.id as string;
  });

  it('lists the template catalogue publicly', async () => {
    const res = await guest().get('/api/v1/invitation-templates').expect(200);
    const codes = (res.body.data as { code: string }[]).map((x) => x.code);
    expect(codes).toEqual(
      expect.arrayContaining(['classic', 'floral', 'minimal', 'festive']),
    );
  });

  it('creates, edits and publishes; the token is stored only as a hash', async () => {
    expect((await a().get(path()).expect(200)).body.data).toEqual({
      invitation: null,
    });
    const created = (await save().expect(200)).body.data;
    expect(created).toMatchObject({
      status: 'DRAFT',
      templateCode: 'floral',
      startTime: '18:30',
      venueName: 'Lotus Hall',
      totals: { attending: 0, maybe: 0, notAttending: 0, guests: 0 },
    });
    await save({ templateCode: 'nope' }).expect(422);
    await save({ title: '' }).expect(422);

    const published = (await a().post(`${path()}/publish`).expect(200)).body
      .data;
    expect(published.invitation.status).toBe('PUBLISHED');
    const token = tokenOf(published.shareUrl as string);
    expect(token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const [row] = await t.migrator.query<{ share_token_hash: Buffer }[]>(
      `SELECT share_token_hash FROM invitations`,
    );
    expect(
      row.share_token_hash.equals(createHash('sha256').update(token).digest()),
    ).toBe(true);
    // The owner endpoints never return the token again.
    expect(
      JSON.stringify((await a().get(path()).expect(200)).body),
    ).not.toContain(token);
    await a().post(`${path()}/publish`).expect(409);
  });

  it('serves a safe, private guest page and records replies (A6)', async () => {
    await save().expect(200);
    const token = tokenOf(
      (await a().post(`${path()}/publish`).expect(200)).body.data.shareUrl,
    );
    const page = await guest().get(`/api/v1/i/${token}`).expect(200);
    expect(page.headers['content-type']).toContain('text/html');
    expect(page.headers['x-robots-tag']).toBe('noindex, nofollow');
    expect(page.headers['referrer-policy']).toBe('no-referrer');
    expect(page.headers['content-security-policy']).toContain(
      "default-src 'none'",
    );
    expect(page.text).toContain('Asha weds Ravi');
    expect(page.text).toContain('Join us &lt;b&gt;please&lt;/b&gt;'); // escaped
    expect(page.text).toContain('Send my reply');

    const sent = await rsvp(token, {
      guestName: 'Meena',
      response: 'ATTENDING',
      guestCount: '3',
      message: 'See you!',
    }).expect(303);
    expect(sent.headers.location).toBe(`../${token}?sent=1`);
    const cookie = (sent.headers['set-cookie'] as unknown as string[])[0].split(
      ';',
    )[0];
    // Same browser: the reply is updated, not duplicated.
    await rsvp(
      token,
      { guestName: 'Meena K', response: 'MAYBE', guestCount: '2' },
      cookie,
    ).expect(303);
    const again = await guest()
      .get(`/api/v1/i/${token}`)
      .set('Cookie', cookie)
      .expect(200);
    expect(again.text).toContain('value="Meena K"');
    expect(again.text).toContain('Update my reply');
    // Another browser adds a second reply.
    await rsvp(token, {
      guestName: 'Ravi',
      response: 'ATTENDING',
      guestCount: '4',
    }).expect(303);
    await rsvp(token, {
      guestName: 'Sam',
      response: 'NOT_ATTENDING',
      guestCount: '1',
    }).expect(303);

    const list = (await a().get(`${path()}/rsvps`).expect(200)).body.data;
    expect(list.totals).toEqual({
      attending: 1,
      maybe: 1,
      notAttending: 1,
      guests: 4,
    });
    expect(list.rsvps).toHaveLength(3);
    const audit = await t.migrator.query<{ summary: object }[]>(
      `SELECT summary FROM audit_logs WHERE actor_type = 'GUEST'`,
    );
    expect(audit).toHaveLength(4);
    expect(JSON.stringify(audit)).not.toMatch(/Meena|See you/);
  });

  it('rejects bad replies with a friendly page', async () => {
    await save().expect(200);
    const token = tokenOf(
      (await a().post(`${path()}/publish`).expect(200)).body.data.shareUrl,
    );
    for (const fields of [
      { guestName: '', response: 'ATTENDING', guestCount: '1' },
      { guestName: 'X', response: 'YES', guestCount: '1' },
      { guestName: 'X', response: 'ATTENDING', guestCount: '21' },
      { guestName: 'X', response: 'ATTENDING', guestCount: '0' },
      { guestName: 'X'.repeat(81), response: 'ATTENDING', guestCount: '1' },
    ]) {
      const res = await rsvp(token, fields).expect(303);
      expect(res.headers.location).toBe(`../${token}?invalid=1`);
    }
    const [{ count }] = await t.migrator.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM invitation_rsvps`,
    );
    expect(count).toBe(0);
  });

  it('closes replies, replaces the link and revokes', async () => {
    await save().expect(200);
    const first = tokenOf(
      (await a().post(`${path()}/publish`).expect(200)).body.data.shareUrl,
    );
    await a().post(`${path()}/rsvp-open`, { open: false }).expect(200);
    const closed = await guest().get(`/api/v1/i/${first}`).expect(200);
    expect(closed.text).toContain('Replies for this invitation are closed');
    await rsvp(first, {
      guestName: 'X',
      response: 'ATTENDING',
      guestCount: '1',
    }).expect(303);
    await a().post(`${path()}/rsvp-open`, { open: true }).expect(200);

    const second = tokenOf(
      (await a().post(`${path()}/new-link`).expect(200)).body.data.shareUrl,
    );
    await guest().get(`/api/v1/i/${first}`).expect(404);
    await guest().get(`/api/v1/i/${second}`).expect(200);

    await a().post(`${path()}/revoke`).expect(200);
    const gone = await guest().get(`/api/v1/i/${second}`).expect(404);
    expect(gone.text).toContain('This invitation is no longer available');
    // Publishing again gives a fresh link.
    const third = tokenOf(
      (await a().post(`${path()}/publish`).expect(200)).body.data.shareUrl,
    );
    await guest().get(`/api/v1/i/${third}`).expect(200);
  });

  it('hides the page when the event is cancelled; unknown tokens look the same', async () => {
    await save().expect(200);
    const token = tokenOf(
      (await a().post(`${path()}/publish`).expect(200)).body.data.shareUrl,
    );
    await guest().get('/api/v1/i/not-a-token').expect(404);
    await guest()
      .get(`/api/v1/i/${'x'.repeat(43)}`)
      .expect(404);
    await a().post(`/events/${eventId}/cancel`).expect(200);
    await guest().get(`/api/v1/i/${token}`).expect(404);
    // Closing replies still works for the owner after cancelling.
    await a().post(`${path()}/rsvp-open`, { open: false }).expect(200);
    await save().expect(409); // content is read only
  });

  it('is owner-only', async () => {
    await save().expect(200);
    await as('uid-b').get(path()).expect(404);
    await as('uid-b')
      .put(path(), { templateCode: 'classic', title: 'X' })
      .expect(404);
    await as('uid-b').post(`${path()}/publish`).expect(404);
    await as('uid-b').get(`${path()}/rsvps`).expect(404);
  });

  it('sends at most one RSVP digest per invitation per hour (N18)', async () => {
    await save().expect(200);
    const token = tokenOf(
      (await a().post(`${path()}/publish`).expect(200)).body.data.shareUrl,
    );
    await rsvp(token, {
      guestName: 'A',
      response: 'ATTENDING',
      guestCount: '1',
    }).expect(303);
    await rsvp(token, {
      guestName: 'B',
      response: 'MAYBE',
      guestCount: '1',
    }).expect(303);
    const job = t.app.get(RsvpDigestJob);
    expect(await job.run(new Date())).toBe(1);
    await rsvp(token, {
      guestName: 'C',
      response: 'ATTENDING',
      guestCount: '1',
    }).expect(303);
    expect(await job.run(new Date())).toBe(0); // within the hour
    expect(await job.run(new Date(Date.now() + 61 * 60_000))).toBe(1);
    const notes = await t.migrator.query<
      { title: string; delivery_status: string }[]
    >(
      `SELECT title, delivery_status FROM notifications WHERE type = 'RSVP_RECEIVED' ORDER BY created_at`,
    );
    expect(notes.map((n) => n.title)).toEqual(['2 new RSVPs', 'New RSVP']);
    expect(notes[0].delivery_status).toBe('PENDING'); // queued for push
  });
});
