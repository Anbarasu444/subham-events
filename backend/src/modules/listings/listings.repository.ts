import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import type { ListingSort } from './listings.dto';

/** Validated, normalised discovery filters. */
export interface ListingFilters {
  categoryId?: string;
  city?: string;
  q?: string;
  minPrice?: string;
  maxPrice?: string;
}

/** Position after the last row of a page, per sort. */
export type ListingCursor =
  | { sort: 'relevance'; rank: number; publishedAt: string; id: string }
  | { sort: '-publishedAt'; publishedAt: string; id: string }
  | { sort: 'startingPrice' | '-startingPrice'; price: string; id: string };

export interface ListingRow {
  id: string;
  title: string;
  category_id: string;
  category_name: string;
  category_slug: string;
  vendor_id: string;
  business_name: string;
  city: string;
  service_areas: string[];
  starting_price_amount: string;
  currency: string;
  rating_count: number;
  rating_sum: number;
  /** Exact (microsecond) UTC text, so cursors never skip or repeat rows. */
  published_at: string;
  rank: number;
}

// Visible in the marketplace (domain-model.md): APPROVED listing, ACTIVE
// vendor, PUBLISHED category.
const VISIBLE = `l.status = 'APPROVED' AND v.status = 'ACTIVE' AND c.status = 'PUBLISHED'`;

/** Escapes LIKE wildcards in user text. */
function likeEscape(text: string): string {
  return text.replace(/[\\%_]/g, (ch) => `\\${ch}`);
}

/** Read-only marketplace queries (M12); written by M26–M28 and M40+. */
@Injectable()
export class ListingsRepository {
  constructor(private readonly dataSource: DataSource) {}

  async search(
    filters: ListingFilters,
    sort: ListingSort,
    limit: number,
    after?: ListingCursor,
  ): Promise<ListingRow[]> {
    const params: unknown[] = [];
    const p = (value: unknown) => {
      params.push(value);
      return `$${params.length}`;
    };
    const where = [VISIBLE];
    if (filters.categoryId)
      where.push(`l.category_id = ${p(filters.categoryId)}::uuid`);
    if (filters.city) {
      const city = p(filters.city.toLowerCase());
      where.push(
        `(lower(l.city) = ${city} OR EXISTS (SELECT 1 FROM unnest(l.service_areas) AS s(area) WHERE lower(s.area) = ${city}))`,
      );
    }
    if (filters.minPrice)
      where.push(`l.starting_price_amount >= ${p(filters.minPrice)}::numeric`);
    if (filters.maxPrice)
      where.push(`l.starting_price_amount <= ${p(filters.maxPrice)}::numeric`);

    let rank = '0';
    if (filters.q) {
      const prefix = p(`${likeEscape(filters.q)}%`);
      const anywhere = p(`%${likeEscape(filters.q)}%`);
      where.push(
        `(l.title ILIKE ${anywhere} OR v.business_name ILIKE ${anywhere} OR c.name ILIKE ${anywhere})`,
      );
      rank = `CASE WHEN l.title ILIKE ${prefix} THEN 0 WHEN l.title ILIKE ${anywhere} THEN 1 WHEN v.business_name ILIKE ${anywhere} THEN 2 ELSE 3 END`;
    }

    let order: string;
    switch (sort) {
      case 'relevance':
        order = `rank ASC, l.approved_at DESC, l.id DESC`;
        if (after?.sort === 'relevance') {
          const r = p(after.rank);
          const a = p(after.publishedAt);
          const i = p(after.id);
          where.push(
            `((${rank}) > ${r}::int OR ((${rank}) = ${r}::int AND (l.approved_at, l.id) < (${a}::timestamptz, ${i}::uuid)))`,
          );
        }
        break;
      case '-publishedAt':
        order = `l.approved_at DESC, l.id DESC`;
        if (after?.sort === '-publishedAt') {
          where.push(
            `(l.approved_at, l.id) < (${p(after.publishedAt)}::timestamptz, ${p(after.id)}::uuid)`,
          );
        }
        break;
      case 'startingPrice':
      case '-startingPrice': {
        const desc = sort === '-startingPrice';
        order = desc
          ? `l.starting_price_amount DESC, l.id DESC`
          : `l.starting_price_amount ASC, l.id ASC`;
        if (after?.sort === sort) {
          where.push(
            `(l.starting_price_amount, l.id) ${desc ? '<' : '>'} (${p(after.price)}::numeric, ${p(after.id)}::uuid)`,
          );
        }
        break;
      }
    }

    return this.dataSource.query<ListingRow[]>(
      `SELECT l.id, l.title, c.id AS category_id, c.name AS category_name,
              c.slug AS category_slug, v.id AS vendor_id, v.business_name,
              l.city, l.service_areas, l.starting_price_amount::text AS starting_price_amount,
              l.currency, l.rating_count, l.rating_sum,
              to_char(l.approved_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS published_at,
              (${rank})::int AS rank
         FROM vendor_listings l
         JOIN vendors v ON v.id = l.vendor_id
         JOIN vendor_categories c ON c.id = l.category_id
        WHERE ${where.join(' AND ')}
        ORDER BY ${order}
        LIMIT ${p(limit)}::int`,
      params,
    );
  }

  /** Cities and service areas of visible listings, case-insensitively unique. */
  async cities(max: number): Promise<string[]> {
    const rows = await this.dataSource.query<{ name: string }[]>(
      `SELECT min(place) AS name
         FROM (
           SELECT l.city AS place FROM vendor_listings l
             JOIN vendors v ON v.id = l.vendor_id
             JOIN vendor_categories c ON c.id = l.category_id
            WHERE ${VISIBLE}
           UNION ALL
           SELECT s.area FROM vendor_listings l
             JOIN vendors v ON v.id = l.vendor_id
             JOIN vendor_categories c ON c.id = l.category_id
             CROSS JOIN unnest(l.service_areas) AS s(area)
            WHERE ${VISIBLE}
         ) places
        GROUP BY lower(place)
        ORDER BY lower(place)
        LIMIT $1`,
      [max],
    );
    return rows.map((r) => r.name);
  }
}
