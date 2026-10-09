import { HttpStatus, Injectable } from '@nestjs/common';
import { DataSource, type EntityManager } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { uuidv7 } from '../../common/ids/uuid-v7';
import {
  DEFAULT_PAGE_LIMIT,
  decodeCursor,
  toCursorPage,
  type CursorPageMeta,
} from '../../common/pagination/cursor';
import { AuditService } from '../audit/audit.service';
import { localDate } from '../events/event-rules';
import type { RequestContext } from '../events/events.service';
import { NotificationsService } from '../notifications/notifications.service';
import type {
  CommentStatus,
  CreateReviewDto,
  PublicReviewDto,
  RatingSummaryDto,
  ReviewDto,
} from './reviews.dto';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isInstant = (v: string) => !Number.isNaN(Date.parse(v));

interface ReviewRow {
  id: string;
  booking_id: string;
  listing_id: string;
  listing_title: string;
  rating: number;
  comment: string | null;
  comment_status: CommentStatus;
  created_at: Date;
}

/**
 * Reviews (M20; R7, A4, A5, A12, domain-model.md §4.16). The rating is
 * public at once; the comment waits for admin moderation (M51).
 */
@Injectable()
export class ReviewsService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly notifications: NotificationsService,
    private readonly audit: AuditService,
  ) {}

  async create(
    manager: EntityManager,
    userId: string,
    eventId: string,
    bookingId: string,
    dto: CreateReviewDto,
    context: RequestContext,
    now = new Date(),
  ): Promise<ReviewDto> {
    const [b] = await manager.query<
      {
        status: string;
        service_date: string;
        time_zone: string;
        vendor_id: string;
        listing_id: string;
        listing_title: string;
        owner_user_id: string;
      }[]
    >(
      `SELECT b.status, b.service_date::text AS service_date, e.time_zone,
              l.vendor_id, l.id AS listing_id, l.title AS listing_title,
              v.user_id AS owner_user_id
         FROM bookings b
         JOIN events e ON e.id = b.event_id
         JOIN event_vendors ev ON ev.id = b.event_vendor_id
         JOIN vendor_listings l ON l.id = ev.listing_id
         JOIN vendors v ON v.id = l.vendor_id
        WHERE b.id = $1 AND b.event_id = $2
          AND e.owner_user_id = $3 AND e.deleted_at IS NULL
        FOR UPDATE OF b`,
      [bookingId, eventId, userId],
    );
    if (!b) throw notFound();
    // A12: never your own listing.
    if (b.owner_user_id === userId) {
      throw new AppException(
        ErrorCode.FORBIDDEN_PERMISSION,
        HttpStatus.FORBIDDEN,
        'You cannot review your own vendor listing.',
      );
    }
    // A5: completed bookings only; A12: from the service date.
    if (
      b.status !== 'COMPLETED' ||
      b.service_date > localDate(b.time_zone, now)
    ) {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'You can review a vendor once the booking is completed.',
      );
    }
    const [existing] = await manager.query<{ id: string }[]>(
      `SELECT id FROM reviews WHERE booking_id = $1`,
      [bookingId],
    );
    if (existing) {
      throw new AppException(
        ErrorCode.DUPLICATE,
        HttpStatus.CONFLICT,
        'You have already reviewed this booking.',
      );
    }
    const id = uuidv7();
    const comment = dto.comment ?? null;
    const commentStatus: CommentStatus = comment
      ? 'PENDING_MODERATION'
      : 'NONE';
    await manager.query(
      `INSERT INTO reviews (id, booking_id, user_id, vendor_id, listing_id,
                            rating, comment, comment_status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $9)`,
      [
        id,
        bookingId,
        userId,
        b.vendor_id,
        b.listing_id,
        dto.rating,
        comment,
        commentStatus,
        now,
      ],
    );
    // A4: the rating counts at once (atomic increment, same transaction).
    await manager.query(
      `UPDATE vendor_listings
          SET rating_sum = rating_sum + $2, rating_count = rating_count + 1
        WHERE id = $1`,
      [b.listing_id, dto.rating],
    );
    // N19 (vendor, in-app; vendor pushes from M36). The comment is not
    // shown until approved. N23 (admins) waits for admin accounts (M40+):
    // until then the moderation queue is the PENDING_MODERATION index.
    const [author] = await manager.query<{ display_name: string | null }[]>(
      `SELECT display_name FROM users WHERE id = $1`,
      [userId],
    );
    await this.notifications.createInApp(manager, {
      recipientUserId: b.owner_user_id,
      audience: 'VENDOR',
      category: 'REVIEW',
      type: 'REVIEW_RECEIVED',
      title: 'New rating',
      body: `${publicName(author?.display_name ?? null)} rated “${b.listing_title}” ${dto.rating} out of 5.`,
      entityType: 'REVIEW',
      entityId: id,
      data: { listingId: b.listing_id, rating: dto.rating },
    });
    await this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action: 'REVIEW_CREATED',
      entityType: 'REVIEW',
      entityId: id,
      requestId: context.requestId,
      ip: context.ip,
      // No comment text in the audit log.
      summary: {
        bookingId,
        listingId: b.listing_id,
        rating: dto.rating,
        hasComment: comment !== null,
      },
    });
    return {
      id,
      bookingId,
      listing: { id: b.listing_id, title: b.listing_title },
      rating: dto.rating,
      comment,
      commentStatus,
      createdAt: now.toISOString(),
    };
  }

  /** The caller's reviews, newest first. */
  async mine(
    userId: string,
    limit = DEFAULT_PAGE_LIMIT,
    cursor?: string,
  ): Promise<{ items: ReviewDto[]; page: CursorPageMeta }> {
    const after = cursor
      ? decodeCursor(cursor, ['createdAt', 'id'], {
          createdAt: isInstant,
          id: (v) => UUID.test(v),
        })
      : null;
    const rows = await this.dataSource.query<ReviewRow[]>(
      `SELECT r.id, r.booking_id, r.listing_id, l.title AS listing_title,
              r.rating, r.comment, r.comment_status, r.created_at
         FROM reviews r JOIN vendor_listings l ON l.id = r.listing_id
        WHERE r.user_id = $1
          AND ($2::timestamptz IS NULL OR (r.created_at, r.id) < ($2::timestamptz, $3::uuid))
        ORDER BY r.created_at DESC, r.id DESC
        LIMIT $4`,
      [userId, after?.createdAt ?? null, after?.id ?? null, limit + 1],
    );
    const { items, page } = toCursorPage(rows, limit, (last) => ({
      createdAt: last.created_at.toISOString(),
      id: last.id,
    }));
    return { items: items.map(toReviewDto), page };
  }

  /** Star breakdown of a visible listing (ratings count at once, A4). */
  async summary(listingId: string): Promise<RatingSummaryDto> {
    await this.assertVisible(listingId);
    const rows = await this.dataSource.query<
      { rating: number; count: number }[]
    >(
      `SELECT rating, count(*)::int AS count FROM reviews
        WHERE listing_id = $1 AND rating_status = 'ACTIVE'
        GROUP BY rating`,
      [listingId],
    );
    const byStars = new Map(rows.map((r) => [Number(r.rating), r.count]));
    const count = rows.reduce((s, r) => s + r.count, 0);
    const sum = rows.reduce((s, r) => s + Number(r.rating) * r.count, 0);
    return {
      average:
        count > 0 ? (Math.round((sum * 10) / count) / 10).toFixed(1) : null,
      count,
      stars: [5, 4, 3, 2, 1].map((stars) => ({
        stars,
        count: byStars.get(stars) ?? 0,
      })),
    };
  }

  /** Approved comments of a visible listing, newest first. */
  async publicList(
    listingId: string,
    limit = DEFAULT_PAGE_LIMIT,
    cursor?: string,
  ): Promise<{ items: PublicReviewDto[]; page: CursorPageMeta }> {
    await this.assertVisible(listingId);
    const after = cursor
      ? decodeCursor(cursor, ['createdAt', 'id'], {
          createdAt: isInstant,
          id: (v) => UUID.test(v),
        })
      : null;
    const rows = await this.dataSource.query<
      {
        id: string;
        rating: number;
        comment: string;
        display_name: string | null;
        created_at: Date;
      }[]
    >(
      `SELECT r.id, r.rating, r.comment, u.display_name, r.created_at
         FROM reviews r JOIN users u ON u.id = r.user_id
        WHERE r.listing_id = $1
          AND r.comment_status = 'APPROVED' AND r.rating_status = 'ACTIVE'
          AND ($2::timestamptz IS NULL OR (r.created_at, r.id) < ($2::timestamptz, $3::uuid))
        ORDER BY r.created_at DESC, r.id DESC
        LIMIT $4`,
      [listingId, after?.createdAt ?? null, after?.id ?? null, limit + 1],
    );
    const { items, page } = toCursorPage(rows, limit, (last) => ({
      createdAt: last.created_at.toISOString(),
      id: last.id,
    }));
    return {
      items: items.map((r) => ({
        id: r.id,
        rating: Number(r.rating),
        comment: r.comment,
        reviewerName: publicName(r.display_name),
        createdAt: r.created_at.toISOString(),
      })),
      page,
    };
  }

  private async assertVisible(listingId: string): Promise<void> {
    const [row] = await this.dataSource.query<{ id: string }[]>(
      `SELECT l.id FROM vendor_listings l
         JOIN vendors v ON v.id = l.vendor_id
         JOIN vendor_categories c ON c.id = l.category_id
        WHERE l.id = $1 AND l.status = 'APPROVED'
          AND v.status = 'ACTIVE' AND c.status = 'PUBLISHED'`,
      [listingId],
    );
    if (!row) throw notFound();
  }
}

/** "Asha Kumar" → "Asha K." (M20 answer 4); no name → "Customer". */
export function publicName(displayName: string | null): string {
  const parts = (displayName ?? '').trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'Customer';
  const first = [...parts[0]].slice(0, 30).join('');
  if (parts.length === 1) return first;
  const initial = [...parts[parts.length - 1]][0].toUpperCase();
  return `${first} ${initial}.`;
}

function toReviewDto(r: ReviewRow): ReviewDto {
  return {
    id: r.id,
    bookingId: r.booking_id,
    listing: { id: r.listing_id, title: r.listing_title },
    rating: Number(r.rating),
    comment: r.comment,
    commentStatus: r.comment_status,
    createdAt: r.created_at.toISOString(),
  };
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
}
