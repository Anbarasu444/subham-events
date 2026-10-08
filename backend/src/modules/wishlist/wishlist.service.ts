import { HttpStatus, Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import {
  decodeCursor,
  toCursorPage,
  type CursorPageMeta,
} from '../../common/pagination/cursor';
import type { ListingCardDto } from '../listings/listings.dto';
import { ListingsRepository } from '../listings/listings.repository';
import { toListingCardDto } from '../listings/listings.service';

/** Most saved listings per user. */
export const MAX_WISHLIST = 500;

export interface WishlistItemDto {
  listing: ListingCardDto;
  /** False when the listing was hidden after it was saved. */
  isAvailable: boolean;
  savedAt: string;
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TIMESTAMP_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$/;

/**
 * Saved listings (M14), private to their user. Only visible listings can be
 * saved; saved ones that were hidden later stay, marked unavailable. Saving
 * is idempotent; removing is a soft delete (R11).
 */
@Injectable()
export class WishlistService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly listings: ListingsRepository,
  ) {}

  async list(
    userId: string,
    limit: number,
    cursor?: string,
  ): Promise<{ items: WishlistItemDto[]; page: CursorPageMeta }> {
    const params: unknown[] = [userId, limit + 1];
    let after = '';
    if (cursor) {
      const c = decodeCursor(cursor, ['s', 'i'] as const, {
        s: (v) => TIMESTAMP_PATTERN.test(v),
        i: (v) => UUID_PATTERN.test(v),
      });
      params.push(c.s, c.i);
      after = `AND (w.created_at, w.listing_id) < ($3::timestamptz, $4::uuid)`;
    }
    const rows = await this.dataSource.query<
      { listing_id: string; saved_at: string }[]
    >(
      `SELECT w.listing_id,
              to_char(w.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS saved_at
         FROM wishlist_items w
        WHERE w.user_id = $1::uuid AND w.deleted_at IS NULL ${after}
        ORDER BY w.created_at DESC, w.listing_id DESC
        LIMIT $2`,
      params,
    );
    const { items, page } = toCursorPage(rows, limit, (last) => ({
      s: last.saved_at,
      i: last.listing_id,
    }));
    const cards = new Map(
      (await this.listings.cardsByIds(items.map((r) => r.listing_id))).map(
        (c) => [c.id, c],
      ),
    );
    return {
      items: items.flatMap((r) => {
        const card = cards.get(r.listing_id);
        return card
          ? [
              {
                listing: toListingCardDto(card),
                isAvailable: card.is_available,
                savedAt: r.saved_at.replace(/(\.\d{3})\d{3}Z$/, '$1Z'),
              },
            ]
          : [];
      }),
      page,
    };
  }

  /** Ids of every saved listing (the app's heart state; ≤ MAX_WISHLIST). */
  async ids(userId: string): Promise<string[]> {
    const rows = await this.dataSource.query<{ listing_id: string }[]>(
      `SELECT listing_id FROM wishlist_items
        WHERE user_id = $1::uuid AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT $2`,
      [userId, MAX_WISHLIST],
    );
    return rows.map((r) => r.listing_id);
  }

  /** Idempotent: saving a saved listing changes nothing. */
  async save(userId: string, listingId: string): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      // Serialise one user's saves so the limit cannot race.
      await manager.query(`SELECT id FROM users WHERE id = $1 FOR UPDATE`, [
        userId,
      ]);
      const [visible] = await manager.query<{ ok: boolean }[]>(
        `SELECT true AS ok FROM vendor_listings l
           JOIN vendors v ON v.id = l.vendor_id
           JOIN vendor_categories c ON c.id = l.category_id
          WHERE l.id = $1::uuid AND l.status = 'APPROVED'
            AND v.status = 'ACTIVE' AND c.status = 'PUBLISHED'`,
        [listingId],
      );
      if (!visible) {
        throw new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
      }
      const [{ count }] = await manager.query<{ count: number }[]>(
        `SELECT count(*)::int AS count FROM wishlist_items
          WHERE user_id = $1::uuid AND deleted_at IS NULL AND listing_id <> $2::uuid`,
        [userId, listingId],
      );
      if (count >= MAX_WISHLIST) {
        throw new AppException(
          ErrorCode.LIMIT_REACHED,
          HttpStatus.CONFLICT,
          `You can save at most ${MAX_WISHLIST} vendors.`,
        );
      }
      await manager.query(
        `INSERT INTO wishlist_items (user_id, listing_id) VALUES ($1, $2)
         ON CONFLICT (user_id, listing_id) DO UPDATE
           SET deleted_at = NULL,
               created_at = CASE WHEN wishlist_items.deleted_at IS NULL
                                 THEN wishlist_items.created_at ELSE now() END`,
        [userId, listingId],
      );
    });
  }

  /** Soft delete; removing an unsaved listing is a no-op. */
  async remove(userId: string, listingId: string): Promise<void> {
    await this.dataSource.query(
      `UPDATE wishlist_items SET deleted_at = now()
        WHERE user_id = $1::uuid AND listing_id = $2::uuid AND deleted_at IS NULL`,
      [userId, listingId],
    );
  }
}
