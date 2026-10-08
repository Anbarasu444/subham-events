/** Reminders and checklist alerts (M17, §4.13, N16/N17). */
import { ReminderJobs } from '../src/modules/reminders/reminder-jobs';
import { localDate } from '../src/modules/events/event-rules';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

interface Reminder {
  id: string;
  title: string;
  remindAt: string;
  status: string;
  checklistItemId: string | null;
  checklistItemTitle: string | null;
  cancelReason: string | null;
  version: number;
  eventTitle: string;
}

describeDb('Reminders (e2e)', () => {
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
      patch: (p: string, body: object) =>
        auth(t.http().patch(`/api/v1${p}`)).send(body),
      post: (p: string, body: object = {}, key = `rem-key-${++seq}`) =>
        auth(t.http().post(`/api/v1${p}`))
          .set('Idempotency-Key', key)
          .send(body),
      delete: (p: string) => auth(t.http().delete(`/api/v1${p}`)),
    };
  };
  const a = () => as('uid-a');
  const inMinutes = (m: number) =>
    new Date(Date.now() + m * 60_000).toISOString();
  const inDays = (days: number) =>
    localDate('Asia/Kolkata', new Date(Date.now() + days * 86_400_000));
  const path = () => `/events/${eventId}/reminders`;
  const create = (body: object) => a().post(path(), body);
  const jobs = () => t.app.get(ReminderJobs);
  const list = async () =>
    (await a().get(path()).expect(200)).body.data as {
      isEditable: boolean;
      upcoming: Reminder[];
      past: Reminder[];
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
          eventDate: inDays(40),
          city: 'Chennai',
        })
        .expect(201)
    ).body.data.id as string;
  });

  it('creates, lists, reschedules and cancels reminders', async () => {
    const later = inMinutes(120);
    const r = (
      await create({ title: ' Call the caterer ', remindAt: later }).expect(201)
    ).body.data as Reminder;
    expect(r).toMatchObject({
      title: 'Call the caterer',
      remindAt: later,
      status: 'SCHEDULED',
      eventTitle: 'Asha & Ravi',
    });
    await create({ title: 'Sooner', remindAt: inMinutes(30) }).expect(201);
    expect((await list()).upcoming.map((x) => x.title)).toEqual([
      'Sooner',
      'Call the caterer',
    ]);

    const moved = (
      await a()
        .patch(`${path()}/${r.id}`, {
          remindAt: inMinutes(10),
          version: r.version,
        })
        .expect(200)
    ).body.data as Reminder;
    expect((await list()).upcoming[0].id).toBe(moved.id);
    await a()
      .patch(`${path()}/${r.id}`, { title: 'X', version: r.version })
      .expect(412);

    const cancelled = (await a().post(`${path()}/${r.id}/cancel`).expect(200))
      .body.data as Reminder;
    expect(cancelled).toMatchObject({
      status: 'CANCELLED',
      cancelReason: 'USER',
    });
    await a().post(`${path()}/${r.id}/cancel`).expect(409);
    expect((await list()).past.map((x) => x.id)).toEqual([r.id]);

    const audit = await t.migrator.query<{ action: string }[]>(
      `SELECT action, summary FROM audit_logs WHERE action LIKE 'REMINDER_%' ORDER BY occurred_at, id`,
    );
    expect(audit.map((x) => x.action)).toEqual([
      'REMINDER_CREATED',
      'REMINDER_CREATED',
      'REMINDER_UPDATED',
      'REMINDER_CANCELLED',
    ]);
    expect(JSON.stringify(audit)).not.toContain('caterer');
  });

  it('validates the time, title and linked task', async () => {
    for (const body of [
      { title: 'Past', remindAt: inMinutes(-1) },
      { title: 'No zone', remindAt: '2026-12-01T10:00:00' },
      { title: 'Bad', remindAt: 'tomorrow' },
      { title: '   ', remindAt: inMinutes(5) },
      { title: 'x'.repeat(121), remindAt: inMinutes(5) },
      {
        title: 'Task',
        remindAt: inMinutes(5),
        checklistItemId: '00000000-0000-4000-8000-000000000000',
      },
    ]) {
      await create(body).expect(422);
    }
    await t
      .http()
      .post(`/api/v1${path()}`)
      .set('Authorization', 'Bearer uid-a')
      .send({ title: 'Hi', remindAt: inMinutes(5) })
      .expect(428);
  });

  it('is owner-only and read only once the event is not planning', async () => {
    const r = (
      await create({ title: 'Mine', remindAt: inMinutes(60) }).expect(201)
    ).body.data as Reminder;
    await as('uid-b').get(path()).expect(404);
    await as('uid-b')
      .post(path(), { title: 'X', remindAt: inMinutes(5) })
      .expect(404);
    await as('uid-b').post(`${path()}/${r.id}/cancel`).expect(404);
    await a().post(`/events/${eventId}/cancel`).expect(200);
    const after = await list();
    expect(after.isEditable).toBe(false);
    // Cancelling the event cancelled its reminders (§4.13).
    expect(after.past[0]).toMatchObject({
      status: 'CANCELLED',
      cancelReason: 'EVENT_CANCELLED',
    });
    await create({ title: 'Late', remindAt: inMinutes(5) }).expect(409);
  });

  it('fires due reminders exactly once with N17, then lists them as due', async () => {
    const r = (
      await create({ title: 'Book the hall', remindAt: inMinutes(1) }).expect(
        201,
      )
    ).body.data as Reminder;
    expect(await jobs().fireDueReminders(new Date())).toBe(0); // not yet
    const later = new Date(Date.now() + 2 * 60_000);
    expect(await jobs().fireDueReminders(later)).toBe(1);
    expect(await jobs().fireDueReminders(later)).toBe(0);
    const [n] = await t.migrator.query<{ type: string; body: string }[]>(
      `SELECT type, body FROM notifications WHERE type = 'REMINDER_DUE'`,
    );
    expect(n).toMatchObject({ type: 'REMINDER_DUE', body: 'Book the hall' });

    const due = (await a().get('/me/reminders?scope=due').expect(200)).body
      .data as Reminder[];
    expect(due.map((x) => x.id)).toEqual([r.id]);
    await a().post(`${path()}/${r.id}/seen`).expect(204);
    expect(
      (await a().get('/me/reminders?scope=due').expect(200)).body.data,
    ).toEqual([]);
    // A sent reminder can no longer be changed.
    const sent = (await list()).past.find((x) => x.id === r.id)!;
    expect(sent.status).toBe('SENT');
    await a()
      .patch(`${path()}/${r.id}`, { title: 'X', version: sent.version })
      .expect(409);
  });

  it('lists upcoming reminders across my events', async () => {
    await create({ title: 'Second', remindAt: inMinutes(90) }).expect(201);
    await create({ title: 'First', remindAt: inMinutes(30) }).expect(201);
    const mine = (await a().get('/me/reminders?limit=1').expect(200)).body
      .data as Reminder[];
    expect(mine.map((x) => x.title)).toEqual(['First']);
    expect(
      (await as('uid-b').get('/me/reminders').expect(200)).body.data,
    ).toEqual([]);
  });

  it('links to a task and is cancelled when the task is done or deleted', async () => {
    const task = (
      await a()
        .post(`/events/${eventId}/checklist`, { title: 'Book photographer' })
        .expect(201)
    ).body.data as { id: string };
    const r = (
      await create({
        title: 'Remind me',
        remindAt: inMinutes(60),
        checklistItemId: task.id,
      }).expect(201)
    ).body.data as Reminder;
    expect(r.checklistItemTitle).toBe('Book photographer');
    await a()
      .post(`/events/${eventId}/checklist/${task.id}/complete`)
      .expect(200);
    expect((await list()).past[0]).toMatchObject({
      id: r.id,
      status: 'CANCELLED',
      cancelReason: 'TASK_DONE',
    });

    const other = (
      await a()
        .post(`/events/${eventId}/checklist`, { title: 'Order cake' })
        .expect(201)
    ).body.data as { id: string };
    await create({
      title: 'Cake',
      remindAt: inMinutes(60),
      checklistItemId: other.id,
    }).expect(201);
    await a().delete(`/events/${eventId}/checklist/${other.id}`).expect(204);
    const past = (await list()).past;
    expect(past.find((x) => x.title === 'Cake')!.cancelReason).toBe(
      'TASK_DELETED',
    );
  });

  it('sends checklist alerts once per task per state from 09:00 local', async () => {
    const today = localDate('Asia/Kolkata', new Date());
    const due = (
      await a()
        .post(`/events/${eventId}/checklist`, {
          title: 'Due today',
          dueDate: today,
        })
        .expect(201)
    ).body.data as { id: string };
    const late = (
      await a()
        .post(`/events/${eventId}/checklist`, {
          title: 'Overdue',
          dueDate: inDays(-2),
        })
        .expect(201)
    ).body.data as { id: string };
    const done = (
      await a()
        .post(`/events/${eventId}/checklist`, { title: 'Done', dueDate: today })
        .expect(201)
    ).body.data as { id: string };
    await a()
      .post(`/events/${eventId}/checklist/${done.id}/complete`)
      .expect(200);

    // 08:59 in India: nothing yet.
    const at = (hhmm: string) => new Date(`${today}T${hhmm}:00+05:30`);
    expect(await jobs().sendChecklistAlerts(at('08:59'))).toBe(0);
    expect(await jobs().sendChecklistAlerts(at('09:00'))).toBe(2);
    expect(await jobs().sendChecklistAlerts(at('15:00'))).toBe(0); // once only
    const rows = await t.migrator.query<{ entity_id: string; type: string }[]>(
      `SELECT entity_id, type FROM notifications
        WHERE type LIKE 'CHECKLIST_%' ORDER BY type`,
    );
    expect(rows).toEqual([
      { entity_id: due.id, type: 'CHECKLIST_DUE_TODAY' },
      { entity_id: late.id, type: 'CHECKLIST_OVERDUE' },
    ]);
    // The next day the due-today task becomes overdue: one more alert.
    const tomorrow = new Date(at('09:30').getTime() + 86_400_000);
    expect(await jobs().sendChecklistAlerts(tomorrow)).toBe(1);
  });
});
