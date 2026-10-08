/** Vendor discovery (M12) against the local test database with sample data. */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { startDbTestApp, testUrls, type DbTestApp } from './db-harness';

const urls = testUrls();
const describeDb = urls ? describe : describe.skip;

const SEED = readFileSync(
  join(__dirname, '..', '..', 'database', 'seeds', 'dev-sample-vendors.sql'),
  'utf8',
);

interface Card {
  id: string;
  title: string;
  city: string;
  serviceAreas: string[];
  startingPrice: { amount: string; currency: string };
  category: { id: string; slug: string };
  vendor: { businessName: string };
  rating: { average: string | null; count: number };
  coverImageUrl: string | null;
  publishedAt: string;
}
interface Page {
  data: Card[];
  meta: { page: { nextCursor: string | null; hasMore: boolean } };
}

describeDb('Vendor discovery (e2e)', () => {
  let t: DbTestApp;

  beforeAll(async () => {
    t = await startDbTestApp(urls!);
  });

  afterAll(async () => {
    await t?.close();
  });

  beforeEach(async () => {
    await t.reset();
    await t.migrator.query(SEED);
  });

  const get = (query: Record<string, string> = {}) =>
    t.http().get('/api/v1/listings').query(query);
  const titles = (body: Page) => body.data.map((c) => c.title);

  /** Walks every page with [limit] and returns all cards in order. */
  async function all(query: Record<string, string>, limit = 5) {
    const cards: Card[] = [];
    let cursor: string | null = null;
    do {
      const res = await get({
        ...query,
        limit: String(limit),
        ...(cursor ? { cursor } : {}),
      }).expect(200);
      const body = res.body as Page;
      cards.push(...body.data);
      cursor = body.meta.page.nextCursor;
    } while (cursor);
    return cards;
  }

  it('lists only approved listings of active vendors, publicly', async () => {
    const res = await get({ limit: '50' }).expect(200); // no Authorization
    const body = res.body as Page;
    expect(body.data).toHaveLength(18);
    expect(titles(body)).not.toContain('Draft listing, not yet submitted');
    expect(titles(body)).not.toContain('Listing of a suspended vendor');
    const card = body.data.find((c) => c.title.startsWith('Lotus'))!;
    expect(card).toMatchObject({
      city: 'Chennai',
      serviceAreas: ['Tambaram', 'Velachery'],
      startingPrice: { amount: '150000.00', currency: 'INR' },
      vendor: { businessName: 'Lotus Grand Mahal' },
      rating: { average: null, count: 0 },
      coverImageUrl: null,
    });
    expect(card.publishedAt).toMatch(/^\d{4}-\d{2}-\d{2}T[\d:]{8}\.\d{3}Z$/);
    // Default (relevance without a search) = newest first.
    expect(titles(body)[0]).toMatch(/^Lotus/);
  });

  it('hides listings when the category is archived', async () => {
    await t.migrator.query(
      `UPDATE vendor_categories SET status = 'ARCHIVED' WHERE slug = 'venue'`,
    );
    try {
      const body = (await get({ limit: '50' }).expect(200)).body as Page;
      expect(body.data.some((c) => c.category.slug === 'venue')).toBe(false);
    } finally {
      await t.migrator.query(
        `UPDATE vendor_categories SET status = 'PUBLISHED' WHERE slug = 'venue'`,
      );
    }
  });

  it('filters by category and by city or service area, ignoring case', async () => {
    const [{ id }] = await t.migrator.query<{ id: string }[]>(
      `SELECT id FROM vendor_categories WHERE slug = 'catering'`,
    );
    const catering = (await get({ categoryId: id }).expect(200)).body as Page;
    expect(catering.data).toHaveLength(3);
    expect(catering.data.every((c) => c.category.slug === 'catering')).toBe(
      true,
    );

    const tambaram = (await get({ city: '  tambaram ' }).expect(200))
      .body as Page;
    expect(titles(tambaram).sort()).toEqual([
      'Bridal makeup and mehendi',
      'Lotus Grand Mahal — AC wedding hall for 800',
    ]);
    const hosur = (await get({ city: 'HOSUR' }).expect(200)).body as Page;
    expect(hosur.data).toHaveLength(2); // a service area of two Bengaluru listings

    const both = (await get({ categoryId: id, city: 'Tiruppur' }).expect(200))
      .body as Page;
    expect(titles(both)).toEqual(['Kongu-style wedding catering']);
  });

  it('filters by an exact price range', async () => {
    const body = (
      await get({
        minStartingPrice: '320.00',
        maxStartingPrice: '450.00',
        limit: '50',
      }).expect(200)
    ).body as Page;
    expect(body.data.map((c) => c.startingPrice.amount).sort()).toEqual([
      '320.00',
      '380.00',
      '450.00',
    ]);
    await get({
      minStartingPrice: '500.00',
      maxStartingPrice: '100.00',
    }).expect(422);
    for (const bad of ['10', '1e5', '-1.00', '10.123']) {
      await get({ minStartingPrice: bad }).expect(422);
    }
  });

  it('searches title, vendor and category, best matches first', async () => {
    const body = (await get({ q: 'candid' }).expect(200)).body as Page;
    expect(titles(body)).toEqual([
      'Candid wedding photography', // title starts with it
      'Traditional and candid photography', // title contains it
    ]);
    const byVendor = (await get({ q: 'annapoorna' }).expect(200)).body as Page;
    expect(titles(byVendor)).toEqual([
      'Traditional South Indian wedding feast',
    ]);
    const byCategory = (await get({ q: 'videography' }).expect(200))
      .body as Page;
    expect(titles(byCategory)).toEqual(['Cinematic wedding films']);
    // LIKE wildcards are plain text.
    expect(((await get({ q: '%' }).expect(200)).body as Page).data).toEqual([]);
  });

  it('sorts by price and by newest', async () => {
    const asc = await all({ sort: 'startingPrice' });
    const prices = asc.map((c) => Number(c.startingPrice.amount));
    expect(prices).toEqual([...prices].sort((a, b) => a - b));
    expect(asc[0].startingPrice.amount).toBe('150.00');
    const desc = await all({ sort: '-startingPrice' });
    expect(desc[0].startingPrice.amount).toBe('200000.00');
    const newest = await all({ sort: '-publishedAt' });
    const dates = newest.map((c) => c.publishedAt);
    expect(dates).toEqual([...dates].sort().reverse());
  });

  it('pages without repeats or gaps for every sort', async () => {
    const full = ((await get({ limit: '50' }).expect(200)).body as Page).data;
    for (const sort of [
      undefined,
      '-publishedAt',
      'startingPrice',
      '-startingPrice',
    ]) {
      const paged = await all(sort ? { sort } : {}, 4);
      expect(paged).toHaveLength(18);
      expect(new Set(paged.map((c) => c.id)).size).toBe(18);
      if (!sort) expect(paged.map((c) => c.id)).toEqual(full.map((c) => c.id));
    }
    // Searched results page the same way.
    const searched = await all({ q: 'wedding' }, 2);
    expect(new Set(searched.map((c) => c.id)).size).toBe(searched.length);
  });

  it('binds a cursor to its search and rejects bad input', async () => {
    const first = (await get({ limit: '2' }).expect(200)).body as Page;
    const cursor = first.meta.page.nextCursor!;
    await get({ cursor, limit: '2' }).expect(200);
    await get({ cursor, city: 'Chennai' }).expect(422);
    await get({ cursor, sort: 'startingPrice' }).expect(422);
    await get({ cursor: 'not-a-cursor' }).expect(422);
    await get({ sort: 'rating' }).expect(422);
    await get({ limit: '51' }).expect(422);
    await get({ categoryId: 'x' }).expect(422);
    await get({ unknown: '1' }).expect(422);
    await get({ q: 'x'.repeat(101) }).expect(422);
  });

  it('lists cities and service areas once each', async () => {
    const res = await t.http().get('/api/v1/listings/cities').expect(200);
    const cities = res.body.data as string[];
    expect(cities).toContain('Chennai');
    expect(cities).toContain('Tambaram');
    expect(cities.filter((c) => c.toLowerCase() === 'hosur')).toHaveLength(1);
    expect(res.headers['cache-control']).toBe('public, max-age=300');
  });

  it('loads the sample data idempotently, only into dev/test databases', async () => {
    await t.migrator.query(SEED);
    const [{ count }] = await t.migrator.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM vendor_listings`,
    );
    expect(count).toBe(20);
    expect(SEED).toContain(`current_database() !~ '_(dev|test)$'`);
    // The guard aborts the whole script on any other database name.
    const elsewhere = SEED.replace("'_(dev|test)$'", () => "'_(never)$'");
    await expect(t.migrator.query(elsewhere)).rejects.toThrow(
      /only be loaded into a \*_dev or \*_test database/,
    );
  });

  describe('details (M13)', () => {
    const LOTUS = '5c000000-0000-4000-8000-000000000001';
    const DRAFT = '5c000000-0000-4000-8000-000000000019';
    const SUSPENDED = '5c000000-0000-4000-8000-000000000020';
    const detail = (id: string, uid?: string) => {
      const req = t.http().get(`/api/v1/listings/${id}`);
      return uid ? req.set('Authorization', `Bearer ${uid}`) : req;
    };

    beforeEach(async () => {
      await t.migrator.query(
        `UPDATE vendors SET phone = '+919800000001', email = 'lotus@example.invalid'
          WHERE id = '5b000000-0000-4000-8000-000000000001'`,
      );
    });

    it('shows a visible listing; contact details only when signed in', async () => {
      const guest = (await detail(LOTUS).expect(200)).body.data;
      expect(guest).toMatchObject({
        id: LOTUS,
        title: 'Lotus Grand Mahal — AC wedding hall for 800',
        description: expect.stringContaining('[Sample]'),
        startingPrice: { amount: '150000.00', currency: 'INR' },
        photos: [],
        vendor: {
          businessName: 'Lotus Grand Mahal',
          city: 'Chennai',
          serviceAreas: ['Tambaram', 'Velachery'],
          contact: null,
        },
      });

      await t
        .http()
        .post('/api/v1/auth/session')
        .set('Authorization', 'Bearer uid-a')
        .expect(200);
      const member = (await detail(LOTUS, 'uid-a').expect(200)).body.data;
      expect(member.vendor.contact).toEqual({
        phone: '+919800000001',
        email: 'lotus@example.invalid',
      });
      // A token of someone not registered yet: treated as a guest.
      const unregistered = (await detail(LOTUS, 'uid-new').expect(200)).body
        .data;
      expect(unregistered.vendor.contact).toBeNull();
      // A bad token is still rejected, so the app refreshes it.
      await detail(LOTUS, 'fail:EXPIRED').expect(401);
    });

    it('never exposes private vendor fields', async () => {
      const body = JSON.stringify((await detail(LOTUS).expect(200)).body);
      for (const field of [
        'user_id',
        'userId',
        'pending_revision',
        'pendingRevision',
        'rejection',
        'approved_by',
        '5a000000',
      ]) {
        expect(body).not.toContain(field);
      }
    });

    it('returns 404 for hidden, unknown or malformed listings', async () => {
      await detail(DRAFT).expect(404);
      await detail(SUSPENDED).expect(404);
      await detail('00000000-0000-4000-8000-000000000000').expect(404);
      await detail('not-a-uuid').expect(404);
      await t.migrator.query(
        `UPDATE vendor_categories SET status = 'ARCHIVED' WHERE slug = 'venue'`,
      );
      try {
        await detail(LOTUS).expect(404);
        await t.http().get(`/api/v1/listings/${LOTUS}/related`).expect(404);
      } finally {
        await t.migrator.query(
          `UPDATE vendor_categories SET status = 'PUBLISHED' WHERE slug = 'venue'`,
        );
      }
    });

    it('lists more from the vendor and similar vendors', async () => {
      // Give Candid Frames a second, visible listing (videography).
      await t.migrator.query(
        `INSERT INTO vendor_listings (id, vendor_id, category_id, title, starting_price_amount, city, status, approved_at)
         SELECT '5c000000-0000-4000-8000-000000000099', '5b000000-0000-4000-8000-000000000004', id,
                'Candid films', 30000.00, 'Chennai', 'APPROVED', now()
           FROM vendor_categories WHERE slug = 'videography'`,
      );
      const CANDID = '5c000000-0000-4000-8000-000000000004';
      const related = (
        await t.http().get(`/api/v1/listings/${CANDID}/related`).expect(200)
      ).body.data as { sameVendor: Card[]; similar: Card[] };
      expect(related.sameVendor.map((c) => c.title)).toEqual(['Candid films']);
      // Photography elsewhere is excluded; the suspended vendor never shows.
      expect(related.similar).toEqual([]);

      // Hosur Lens Works (Bengaluru, also Hosur) is similar to a listing in
      // Hosur's service area of the same category.
      const HOSUR = '5c000000-0000-4000-8000-000000000018';
      const fromHosur = (
        await t.http().get(`/api/v1/listings/${HOSUR}/related`).expect(200)
      ).body.data as { sameVendor: Card[]; similar: Card[] };
      expect(fromHosur.similar).toEqual([]);

      // Coimbatore photography vs. a new Coimbatore photographer.
      await t.migrator.query(
        `INSERT INTO users (id, firebase_uid) VALUES ('5a000000-0000-4000-8000-000000000099', 'sample-vendor-99');
         INSERT INTO vendors (id, user_id, business_name, city, service_areas)
           VALUES ('5b000000-0000-4000-8000-000000000099', '5a000000-0000-4000-8000-000000000099', 'Ooty Clicks', 'Ooty', ARRAY['Coimbatore']);
         INSERT INTO vendor_listings (id, vendor_id, category_id, title, starting_price_amount, city, service_areas, status, approved_at)
           SELECT '5c000000-0000-4000-8000-000000000098', '5b000000-0000-4000-8000-000000000099', id,
                  'Hill weddings', 15000.00, 'Ooty', ARRAY['Coimbatore'], 'APPROVED', now()
             FROM vendor_categories WHERE slug = 'photography';`,
      );
      const WESTERN = '5c000000-0000-4000-8000-000000000014';
      const coimbatore = (
        await t.http().get(`/api/v1/listings/${WESTERN}/related`).expect(200)
      ).body.data as { sameVendor: Card[]; similar: Card[] };
      expect(coimbatore.similar.map((c) => c.title)).toEqual(['Hill weddings']);
      expect(coimbatore.sameVendor).toEqual([]);
    });
  });
});
