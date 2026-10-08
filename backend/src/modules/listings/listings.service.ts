import { createHash } from 'node:crypto';
import { HttpStatus, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { Money } from '../../common/money/money';
import {
  decodeCursor,
  toCursorPage,
  type CursorPageMeta,
} from '../../common/pagination/cursor';
import type {
  ListingCardDto,
  ListingDetailDto,
  ListingSort,
  ListListingsQuery,
  RelatedListingsDto,
} from './listings.dto';
import {
  ListingsRepository,
  type ListingCursor,
  type ListingFilters,
  type ListingRow,
} from './listings.repository';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TIMESTAMP_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$/;
const PRICE_PATTERN = /^\d{1,10}\.\d{2}$/;

/** Most listings per related list. */
export const MAX_RELATED = 6;

/** Most cities returned for the city filter. */
export const MAX_CITIES = 500;

/**
 * Public vendor discovery (M12). Only APPROVED listings of ACTIVE vendors
 * in PUBLISHED categories are visible; guests may browse.
 */
@Injectable()
export class ListingsService {
  constructor(private readonly listings: ListingsRepository) {}

  async search(
    query: ListListingsQuery,
    userId?: string,
  ): Promise<{ items: ListingCardDto[]; page: CursorPageMeta }> {
    if (query.saved && !userId) {
      throw new AppException(ErrorCode.AUTH_REQUIRED, HttpStatus.UNAUTHORIZED);
    }
    const filters: ListingFilters = {
      savedByUserId: query.saved ? userId : undefined,
      categoryId: query.categoryId,
      city: query.city,
      q: query.q,
      minPrice: query.minStartingPrice,
      maxPrice: query.maxStartingPrice,
    };
    if (
      filters.minPrice &&
      filters.maxPrice &&
      Money.fromApi(filters.maxPrice, 'INR').compare(
        Money.fromApi(filters.minPrice, 'INR'),
      ) < 0
    ) {
      throw new AppException(
        ErrorCode.VALIDATION_FAILED,
        HttpStatus.UNPROCESSABLE_ENTITY,
        undefined,
        [
          {
            field: 'maxStartingPrice',
            code: 'RANGE_INVERTED',
            message: 'maxStartingPrice must not be less than minStartingPrice',
          },
        ],
      );
    }
    const sort: ListingSort = query.sort ?? 'relevance';
    // A cursor only continues the exact search it came from.
    const fingerprint = fingerprintOf(filters, sort);
    const after = query.cursor
      ? this.readCursor(query.cursor, sort, fingerprint)
      : undefined;
    const rows = await this.listings.search(
      filters,
      sort,
      query.limit + 1,
      after,
    );
    const { items, page } = toCursorPage(rows, query.limit, (last) =>
      cursorOf(last, sort, fingerprint),
    );
    return { items: items.map(toListingCardDto), page };
  }

  /**
   * One visible listing (else 404). Vendor phone/email only for signed-in
   * callers (A10, M13 answer 1).
   */
  async detail(id: string, signedIn: boolean): Promise<ListingDetailDto> {
    const row = await this.listings.findVisible(id);
    if (!row) throw notFound();
    return {
      ...toListingCardDto(row),
      description: row.description,
      photos: [],
      vendor: {
        id: row.vendor_id,
        businessName: row.business_name,
        description: row.vendor_description,
        city: row.vendor_city,
        serviceAreas: row.vendor_service_areas,
        contact: signedIn
          ? { phone: row.vendor_phone, email: row.vendor_email }
          : null,
      },
    };
  }

  /** More from the vendor and similar listings (M13 answer 4). */
  async related(id: string): Promise<RelatedListingsDto> {
    const row = await this.listings.findVisible(id);
    if (!row) throw notFound();
    const [sameVendor, similar] = await Promise.all([
      this.listings.sameVendor(id, row.vendor_id, MAX_RELATED),
      this.listings.similar(
        row.category_id,
        row.city,
        row.vendor_id,
        MAX_RELATED,
      ),
    ]);
    return {
      sameVendor: sameVendor.map(toListingCardDto),
      similar: similar.map(toListingCardDto),
    };
  }

  cities(): Promise<string[]> {
    return this.listings.cities(MAX_CITIES);
  }

  private readCursor(
    cursor: string,
    sort: ListingSort,
    fingerprint: string,
  ): ListingCursor {
    const bound = { f: (v: string) => v === fingerprint };
    const id = (v: string) => UUID_PATTERN.test(v);
    const at = (v: string) => TIMESTAMP_PATTERN.test(v);
    switch (sort) {
      case 'relevance': {
        const c = decodeCursor(cursor, ['f', 'r', 'a', 'i'] as const, {
          ...bound,
          r: (v) => /^[0-3]$/.test(v),
          a: at,
          i: id,
        });
        return { sort, rank: Number(c.r), publishedAt: c.a, id: c.i };
      }
      case '-publishedAt': {
        const c = decodeCursor(cursor, ['f', 'a', 'i'] as const, {
          ...bound,
          a: at,
          i: id,
        });
        return { sort, publishedAt: c.a, id: c.i };
      }
      default: {
        const c = decodeCursor(cursor, ['f', 'p', 'i'] as const, {
          ...bound,
          p: (v) => PRICE_PATTERN.test(v),
          i: id,
        });
        return { sort, price: c.p, id: c.i };
      }
    }
  }
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
}

function fingerprintOf(filters: ListingFilters, sort: ListingSort): string {
  return createHash('sha256')
    .update(
      JSON.stringify([
        sort,
        filters.savedByUserId ?? null,
        filters.categoryId ?? null,
        filters.city?.toLowerCase() ?? null,
        filters.q?.toLowerCase() ?? null,
        filters.minPrice ?? null,
        filters.maxPrice ?? null,
      ]),
    )
    .digest('base64url')
    .slice(0, 16);
}

function cursorOf(
  row: ListingRow,
  sort: ListingSort,
  f: string,
): Record<string, string> {
  switch (sort) {
    case 'relevance':
      return { f, r: String(row.rank), a: row.published_at, i: row.id };
    case '-publishedAt':
      return { f, a: row.published_at, i: row.id };
    default:
      return { f, p: row.starting_price_amount, i: row.id };
  }
}

export function toListingCardDto(row: ListingRow): ListingCardDto {
  return {
    id: row.id,
    title: row.title,
    category: {
      id: row.category_id,
      name: row.category_name,
      slug: row.category_slug,
    },
    vendor: { id: row.vendor_id, businessName: row.business_name },
    city: row.city,
    serviceAreas: row.service_areas,
    startingPrice: Money.fromDb(
      row.starting_price_amount,
      row.currency,
    ).toJSON(),
    rating: {
      average:
        row.rating_count > 0
          ? (Math.round((row.rating_sum * 10) / row.rating_count) / 10).toFixed(
              1,
            )
          : null,
      count: row.rating_count,
    },
    coverImageUrl: null,
    publishedAt: row.published_at.replace(/(\.\d{3})\d{3}Z$/, '$1Z'),
  };
}
