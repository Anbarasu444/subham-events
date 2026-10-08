/** Vendor categories and event budgets (M11) against the local test database. */
import { localDate } from '../src/modules/events/event-rules';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

interface Category {
  id: string;
  name: string;
  slug: string;
}
interface Line {
  categoryId: string;
  planned: { amount: string } | null;
}

describeDb('Categories and budget (e2e)', () => {
  let t: DbTestApp;
  let eventId: string;
  let categories: Category[];
  let seq = 0;

  beforeAll(async () => {
    t = await startDbTestApp(urls!);
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
        .set('Idempotency-Key', `budget-key-${++seq}`)
        .send(body),
    put: (p: string, body: object) =>
      t
        .http()
        .put(`/api/v1${p}`)
        .set('Authorization', `Bearer ${uid}`)
        .send(body),
    patch: (p: string, body: object) =>
      t
        .http()
        .patch(`/api/v1${p}`)
        .set('Authorization', `Bearer ${uid}`)
        .send(body),
    delete: (p: string) =>
      t.http().delete(`/api/v1${p}`).set('Authorization', `Bearer ${uid}`),
  });
  const a = () => as('uid-a');
  const money = (amount: string) => ({ amount, currency: 'INR' });
  const plan = (categoryId: string, amount: string) =>
    a().put(`/events/${eventId}/budget/allocations/${categoryId}`, {
      planned: money(amount),
    });
  const byId = (lines: unknown, id: string) =>
    (lines as Line[]).find((l) => l.categoryId === id)!;

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
          title: 'Wedding',
          eventDate: localDate(
            'Asia/Kolkata',
            new Date(Date.now() + 30 * 86_400_000),
          ),
          city: 'Chennai',
          totalBudget: money('500000.00'),
        })
        .expect(201)
    ).body.data.id as string;
    categories = (await t.http().get('/api/v1/vendor-categories').expect(200))
      .body.data as Category[];
  });

  it('lists the seeded categories publicly, in order', () => {
    expect(categories.map((c) => c.slug)).toEqual([
      'venue',
      'catering',
      'decoration',
      'photography',
      'videography',
      'makeup-mehendi',
      'music-dj',
      'invitations-printing',
      'transport',
      'gifts-return-gifts',
      'priest-rituals',
      'other-services',
    ]);
  });

  it('plans per category with exact sums', async () => {
    const [venue, catering] = categories;
    await plan(venue.id, '200000.10').expect(200);
    const res = await plan(catering.id, '150000.25').expect(200);
    const budget = res.body.data;
    expect(budget).toMatchObject({
      isEditable: true,
      totalBudget: money('500000.00'),
      planned: money('350000.35'),
      unplanned: money('149999.65'),
      isOverPlanned: false,
      committed: money('0.00'),
      paid: money('0.00'),
      expenses: money('0.00'),
      spent: money('0.00'),
      remaining: money('500000.00'),
    });
    expect(byId(budget.categories, venue.id).planned).toEqual(
      money('200000.10'),
    );
    expect(byId(budget.categories, categories[2].id).planned).toBeNull();
  });

  it('warns when the plan exceeds the total, and handles no total', async () => {
    const res = await plan(categories[0].id, '600000.00').expect(200);
    expect(res.body.data.isOverPlanned).toBe(true);
    expect(res.body.data.unplanned).toEqual(money('-100000.00'));

    const event = (await a().get(`/events/${eventId}`).expect(200)).body.data;
    await a()
      .patch(`/events/${eventId}`, {
        totalBudget: null,
        version: event.version,
      })
      .expect(200);
    const noTotal = (await a().get(`/events/${eventId}/budget`).expect(200))
      .body.data;
    expect(noTotal).toMatchObject({
      totalBudget: null,
      unplanned: null,
      remaining: null,
      isOverPlanned: false,
    });
  });

  it('changes and clears a plan, keeping cleared rows and auditing', async () => {
    const id = categories[0].id;
    await plan(id, '1000.00').expect(200);
    await plan(id, '2000.00').expect(200);
    await plan(id, '2000.00').expect(200); // unchanged: no audit
    const cleared = (
      await a()
        .delete(`/events/${eventId}/budget/allocations/${id}`)
        .expect(200)
    ).body.data;
    expect(byId(cleared.categories, id).planned).toBeNull();
    expect(cleared.planned).toEqual(money('0.00'));
    await plan(id, '500.00').expect(200);

    const [{ count }] = await t.migrator.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM budget_allocations WHERE event_id = $1`,
      [eventId],
    );
    expect(count).toBe(2); // one cleared, one live
    const actions = (
      await t.migrator.query<{ action: string }[]>(
        `SELECT action FROM audit_logs WHERE action LIKE 'BUDGET_%' ORDER BY occurred_at, id`,
      )
    ).map((r) => r.action);
    expect(actions).toEqual([
      'BUDGET_ALLOCATION_SET',
      'BUDGET_ALLOCATION_SET',
      'BUDGET_ALLOCATION_CLEARED',
      'BUDGET_ALLOCATION_SET',
    ]);
  });

  it('keeps plans of archived categories visible and counted', async () => {
    const venue = categories[0];
    await plan(venue.id, '1000.00').expect(200);
    await t.migrator.query(
      `UPDATE vendor_categories SET status = 'ARCHIVED' WHERE id = $1`,
      [venue.id],
    );
    try {
      const budget = (await a().get(`/events/${eventId}/budget`).expect(200))
        .body.data;
      expect(budget.planned).toEqual(money('1000.00'));
      const line = (
        budget.categories as (Line & { isArchived: boolean })[]
      ).find((l) => l.categoryId === venue.id)!;
      expect(line.isArchived).toBe(true);
      await plan(venue.id, '5.00').expect(404); // no new plans for it
      await a()
        .delete(`/events/${eventId}/budget/allocations/${venue.id}`)
        .expect(200); // but its plan can be cleared
    } finally {
      await t.migrator.query(
        `UPDATE vendor_categories SET status = 'PUBLISHED' WHERE id = $1`,
        [venue.id],
      );
    }
  });

  it('seeding again changes nothing', async () => {
    await t.migrator.query(
      `INSERT INTO vendor_categories (slug, name, status, sort_order)
       VALUES ('venue', 'Venue', 'PUBLISHED', 10)
       ON CONFLICT (slug) DO NOTHING`,
    );
    const [{ count }] = await t.migrator.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM vendor_categories`,
    );
    expect(count).toBe(12);
  });

  it('validates money exactly (no floats, no negatives)', async () => {
    const id = categories[0].id;
    for (const amount of ['10.1', '-5.00', '1e5', '10000000000.00']) {
      await a()
        .put(`/events/${eventId}/budget/allocations/${id}`, {
          planned: money(amount),
        })
        .expect(422);
    }
    await a()
      .put(`/events/${eventId}/budget/allocations/${id}`, { planned: 1000 })
      .expect(422);
    await a()
      .put(`/events/${eventId}/budget/allocations/${id}`, {
        planned: { amount: '10.00', currency: 'USD' },
      })
      .expect(422);
  });

  it('is owner-only and read only once the event is not planning', async () => {
    const id = categories[0].id;
    await as('uid-b').get(`/events/${eventId}/budget`).expect(404);
    await as('uid-b')
      .put(`/events/${eventId}/budget/allocations/${id}`, {
        planned: money('1.00'),
      })
      .expect(404);
    await plan('00000000-0000-4000-8000-000000000000', '1.00').expect(404);

    await a().post(`/events/${eventId}/cancel`).expect(200);
    const budget = (await a().get(`/events/${eventId}/budget`).expect(200)).body
      .data;
    expect(budget.isEditable).toBe(false);
    const blocked = await plan(id, '1.00').expect(409);
    expect(blocked.body.error.code).toBe('INVALID_STATE_TRANSITION');
    await a().delete(`/events/${eventId}/budget/allocations/${id}`).expect(409);
  });

  describe('own expenses', () => {
    const add = (body: object, uid = 'uid-a') =>
      as(uid).post(`/events/${eventId}/expenses`, body);
    const expense = (over: object = {}) => ({
      title: 'Flowers from the market',
      amount: money('1250.50'),
      spentOn: '2026-09-01',
      ...over,
    });

    it('adds expenses and counts them as spent', async () => {
      const venue = categories[0];
      const created = (
        await add(expense({ categoryId: venue.id, note: '  ' })).expect(201)
      ).body.data;
      expect(created).toMatchObject({
        title: 'Flowers from the market',
        amount: money('1250.50'),
        spentOn: '2026-09-01',
        categoryId: venue.id,
        categoryName: 'Venue',
        note: null,
        version: 1,
      });
      await add(
        expense({
          title: 'Auto fare',
          amount: money('99.75'),
          spentOn: '2026-09-03',
        }),
      ).expect(201);

      const list = (await a().get(`/events/${eventId}/expenses`).expect(200))
        .body.data;
      expect(list.isEditable).toBe(true);
      expect(list.total).toEqual(money('1350.25'));
      expect(
        (list.expenses as { title: string }[]).map((e) => e.title),
      ).toEqual(['Auto fare', 'Flowers from the market']);

      const budget = (await a().get(`/events/${eventId}/budget`).expect(200))
        .body.data;
      expect(budget).toMatchObject({
        expenses: money('1350.25'),
        spent: money('1350.25'),
        remaining: money('498649.75'),
      });
      expect(
        (budget.categories as { categoryId: string; expenses: unknown }[]).find(
          (l) => l.categoryId === venue.id,
        )!.expenses,
      ).toEqual(money('1250.50'));
    });

    it('edits with a version and deletes softly, auditing without amounts', async () => {
      const created = (await add(expense()).expect(201)).body.data;
      const path = `/events/${eventId}/expenses/${created.id}`;
      const edited = (
        await a()
          .patch(path, {
            amount: money('2000.00'),
            note: 'Paid in cash',
            version: 1,
          })
          .expect(200)
      ).body.data;
      expect(edited).toMatchObject({
        amount: money('2000.00'),
        note: 'Paid in cash',
        version: 2,
      });
      const stale = await a()
        .patch(path, { title: 'X', version: 1 })
        .expect(412);
      expect(stale.body.error.code).toBe('PRECONDITION_FAILED');
      await a().delete(path).expect(204);
      await a().delete(path).expect(404);
      const budget = (await a().get(`/events/${eventId}/budget`).expect(200))
        .body.data;
      expect(budget.expenses).toEqual(money('0.00'));

      const [{ count }] = await t.migrator.query<{ count: number }[]>(
        `SELECT count(*)::int AS count FROM event_expenses WHERE deleted_at IS NOT NULL`,
      );
      expect(count).toBe(1);
      const audits = await t.migrator.query<
        { action: string; summary: object }[]
      >(
        `SELECT action, summary FROM audit_logs WHERE action LIKE 'EXPENSE_%' ORDER BY occurred_at, id`,
      );
      expect(audits.map((r) => r.action)).toEqual([
        'EXPENSE_CREATED',
        'EXPENSE_UPDATED',
        'EXPENSE_DELETED',
      ]);
      expect(JSON.stringify(audits)).not.toMatch(/2000|cash|Flowers/);
    });

    it('shows remaining as negative when spending passes the total', async () => {
      await add(expense({ amount: money('500000.01') })).expect(201);
      const budget = (await a().get(`/events/${eventId}/budget`).expect(200))
        .body.data;
      expect(budget.remaining).toEqual(money('-0.01'));
    });

    it('validates input', async () => {
      for (const body of [
        expense({ amount: money('0.00') }),
        expense({ amount: money('10.5') }),
        expense({ amount: { amount: '10.00', currency: 'USD' } }),
        expense({ title: '   ' }),
        expense({ title: 'x'.repeat(121) }),
        expense({ spentOn: '2026-02-30' }),
        expense({ note: 'x'.repeat(1001) }),
        expense({ categoryId: '00000000-0000-4000-8000-000000000000' }),
      ]) {
        await add(body).expect(422);
      }
      await a()
        .post(`/events/${eventId}/expenses`, expense())
        .unset('Idempotency-Key')
        .expect(428);
      const created = (await add(expense()).expect(201)).body.data;
      for (const patch of [
        { amount: null },
        { spentOn: null },
        { title: null },
        { amount: money('0.00') },
        {},
      ]) {
        await a()
          .patch(`/events/${eventId}/expenses/${created.id}`, {
            ...patch,
            ...('version' in patch ? {} : { version: 1 }),
          })
          .expect((res) =>
            expect(res.status).toBe(Object.keys(patch).length ? 422 : 200),
          );
      }
    });

    it('replays a create with the same idempotency key', async () => {
      const send = () =>
        t
          .http()
          .post(`/api/v1/events/${eventId}/expenses`)
          .set('Authorization', 'Bearer uid-a')
          .set('Idempotency-Key', 'expense-replay')
          .send(expense());
      const first = (await send().expect(201)).body.data;
      const again = await send().expect(201);
      expect(again.headers['idempotent-replayed']).toBe('true');
      expect(again.body.data.id).toBe(first.id);
      const list = (await a().get(`/events/${eventId}/expenses`).expect(200))
        .body.data;
      expect(list.expenses).toHaveLength(1);
    });

    it('is owner-only and read only once the event is not planning', async () => {
      const created = (await add(expense()).expect(201)).body.data;
      await as('uid-b').get(`/events/${eventId}/expenses`).expect(404);
      await add(expense(), 'uid-b').expect(404);
      await as('uid-b')
        .patch(`/events/${eventId}/expenses/${created.id}`, {
          title: 'X',
          version: 1,
        })
        .expect(404);
      await as('uid-b')
        .delete(`/events/${eventId}/expenses/${created.id}`)
        .expect(404);

      await a().post(`/events/${eventId}/cancel`).expect(200);
      const list = (await a().get(`/events/${eventId}/expenses`).expect(200))
        .body.data;
      expect(list.isEditable).toBe(false);
      await add(expense()).expect(409);
      await a().delete(`/events/${eventId}/expenses/${created.id}`).expect(409);
    });
  });
});
