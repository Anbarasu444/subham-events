import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, type EntityManager, type Repository } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { uuidv7 } from '../../common/ids/uuid-v7';
import { AuditService } from '../audit/audit.service';
import { localDate } from '../events/event-rules';
import { EventEntity } from '../events/event.entity';
import type { RequestContext } from '../events/events.service';
import { ListingsRepository } from '../listings/listings.repository';
import { toListingCardDto } from '../listings/listings.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EnquiryEntity } from './enquiry.entity';
import { EventVendorEntity } from './event-vendor.entity';
import {
  MAX_EVENT_VENDORS,
  toEnquiryDto,
  type CreateEnquiryDto,
  type EnquiryDto,
  type EventVendorDto,
  type EventVendorListDto,
  type UpdateEventVendorDto,
} from './event-vendors.dto';

const LIVE: EnquiryEntity['status'][] = ['OPEN', 'QUOTED'];
/** Event vendor states a user may remove (§4.7). */
const REMOVABLE = ['ADDED', 'ENQUIRED', 'QUOTED'];
/** States from which a new enquiry may be sent (no live enquiry). */
const ENQUIRABLE = ['ADDED', 'ENQUIRED', 'QUOTED', 'CANCELLED'];

/**
 * An event's vendors and their enquiries (M14, domain-model.md §4.7–4.8).
 * Owner-only through the event (another user's event → 404); writes need a
 * PLANNING event and lock its row. Vendors only see enquiries in their own
 * app (M32); here they get an in-app N9 record with A9 fields only.
 */
@Injectable()
export class EventVendorsService {
  constructor(
    @InjectRepository(EventEntity)
    private readonly events: Repository<EventEntity>,
    private readonly listings: ListingsRepository,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
  ) {}

  async list(userId: string, eventId: string): Promise<EventVendorListDto> {
    const event = await this.events.findOneBy({
      id: eventId,
      ownerUserId: userId,
      deletedAt: IsNull(),
    });
    if (!event) throw notFound();
    return this.listFor(this.events.manager, event);
  }

  /**
   * Adds a visible listing to the event. Naturally idempotent: adding a
   * listing that is already there returns it (`created: false`).
   */
  async add(
    manager: EntityManager,
    userId: string,
    eventId: string,
    listingId: string,
    context: RequestContext,
  ): Promise<{ vendor: EventVendorDto; created: boolean }> {
    const event = await this.lockEditable(manager, userId, eventId);
    const repo = manager.getRepository(EventVendorEntity);
    const existing = await repo
      .createQueryBuilder('ev')
      .where('ev.event_id = :eventId', { eventId })
      .andWhere('ev.listing_id = :listingId', { listingId })
      .andWhere(`ev.status <> 'REMOVED'`)
      .getOne();
    if (existing) {
      return {
        vendor: await this.dtoOf(manager, event, existing),
        created: false,
      };
    }
    const listing = await this.visibleListing(manager, listingId);
    if (listing.owner_user_id === userId) throw ownListing();
    const count = await repo
      .createQueryBuilder('ev')
      .where('ev.event_id = :eventId', { eventId })
      .andWhere(`ev.status <> 'REMOVED'`)
      .getCount();
    if (count >= MAX_EVENT_VENDORS) {
      throw new AppException(
        ErrorCode.LIMIT_REACHED,
        HttpStatus.CONFLICT,
        `An event can have at most ${MAX_EVENT_VENDORS} vendors.`,
      );
    }
    const saved = await repo.save(
      repo.create({
        id: uuidv7(),
        eventId,
        listingId,
        vendorId: listing.vendor_id,
        categoryId: listing.category_id,
        status: 'ADDED',
        notes: null,
        statusChangedAt: new Date(),
      }),
    );
    await this.record(
      manager,
      userId,
      'EVENT_VENDOR_ADDED',
      saved.id,
      context,
      {
        eventId,
        listingId,
      },
    );
    return { vendor: await this.dtoOf(manager, event, saved), created: true };
  }

  async update(
    manager: EntityManager,
    userId: string,
    eventId: string,
    eventVendorId: string,
    dto: UpdateEventVendorDto,
    context: RequestContext,
  ): Promise<EventVendorDto> {
    const event = await this.lockEditable(manager, userId, eventId);
    const ev = await this.findLive(manager, eventId, eventVendorId);
    if (ev.version !== dto.version) throw changedElsewhere();
    if (dto.notes !== undefined && dto.notes !== ev.notes) {
      ev.notes = dto.notes;
      await manager.getRepository(EventVendorEntity).save(ev);
      // Field names only: the note is private text.
      await this.record(
        manager,
        userId,
        'EVENT_VENDOR_UPDATED',
        ev.id,
        context,
        {
          eventId,
          fields: ['notes'],
        },
      );
    }
    return this.dtoOf(manager, event, ev);
  }

  /** → REMOVED (from ADDED/ENQUIRED/QUOTED); live enquiries close. */
  async remove(
    manager: EntityManager,
    userId: string,
    eventId: string,
    eventVendorId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<void> {
    await this.lockEditable(manager, userId, eventId);
    const ev = await this.findLive(manager, eventId, eventVendorId);
    if (!REMOVABLE.includes(ev.status)) {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'A booked vendor cannot be removed; cancel the booking instead.',
      );
    }
    await closeLiveEnquiries(manager, { eventVendorId: ev.id }, 'USER', now);
    ev.status = 'REMOVED';
    ev.statusChangedAt = now;
    await manager.getRepository(EventVendorEntity).save(ev);
    await this.record(manager, userId, 'EVENT_VENDOR_REMOVED', ev.id, context, {
      eventId,
    });
  }

  /** Sends an enquiry (→ ENQUIRED) and creates N9 for the vendor (A9). */
  async enquire(
    manager: EntityManager,
    userId: string,
    eventId: string,
    eventVendorId: string,
    dto: CreateEnquiryDto,
    context: RequestContext,
    now = new Date(),
  ): Promise<EventVendorDto> {
    const event = await this.lockEditable(manager, userId, eventId);
    const ev = await this.findLive(manager, eventId, eventVendorId);
    if (!ENQUIRABLE.includes(ev.status)) {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'This vendor is already booked for the event.',
      );
    }
    const live = await manager
      .getRepository(EnquiryEntity)
      .existsBy({ eventVendorId: ev.id, status: In(LIVE) });
    if (live) {
      throw new AppException(
        ErrorCode.DUPLICATE,
        HttpStatus.CONFLICT,
        'You already have an open enquiry with this vendor.',
      );
    }
    const listing = await this.visibleListing(manager, ev.listingId);
    if (listing.owner_user_id === userId) throw ownListing();
    if (
      dto.preferredDate &&
      dto.preferredDate < localDate(event.timeZone, now)
    ) {
      throw new AppException(
        ErrorCode.VALIDATION_FAILED,
        HttpStatus.UNPROCESSABLE_ENTITY,
        undefined,
        [
          {
            field: 'preferredDate',
            code: 'DATE_IN_PAST',
            message: 'preferredDate must be today or later',
          },
        ],
      );
    }
    const enquiries = manager.getRepository(EnquiryEntity);
    const enquiry = await enquiries.save(
      enquiries.create({
        id: uuidv7(),
        eventVendorId: ev.id,
        eventId,
        vendorId: ev.vendorId,
        userId,
        message: dto.message,
        preferredDate: dto.preferredDate ?? null,
        status: 'OPEN',
        declineReason: null,
        closedByType: null,
        closedAt: null,
      }),
    );
    ev.status = 'ENQUIRED';
    ev.statusChangedAt = now;
    await manager.getRepository(EventVendorEntity).save(ev);

    // N9 (notification-matrix.md): in-app for the vendor's user now; push
    // once vendor devices exist (M36). A9: name, event type, date, city and
    // guest estimate only — never email, phone, budget, venue or notes.
    const [customer] = await manager.query<{ display_name: string | null }[]>(
      `SELECT display_name FROM users WHERE id = $1`,
      [userId],
    );
    const name = customer?.display_name?.trim() || 'A customer';
    await this.notifications.createInApp(manager, {
      recipientUserId: listing.owner_user_id,
      audience: 'VENDOR',
      category: 'BOOKING',
      type: 'ENQUIRY_RECEIVED',
      title: 'New enquiry',
      body: `${name} asked about “${listing.title}” for a ${event.eventType} on ${event.eventDate} in ${event.city}.`,
      entityType: 'ENQUIRY',
      entityId: enquiry.id,
      data: {
        customerName: name,
        eventType: event.eventType,
        eventDate: event.eventDate,
        city: event.city,
        guestCountEstimate: event.guestCountEstimate,
        listingId: ev.listingId,
      },
    });
    // Ids only: the message is the user's text.
    await this.record(
      manager,
      userId,
      'ENQUIRY_SENT',
      enquiry.id,
      context,
      {
        eventId,
        eventVendorId: ev.id,
      },
      'ENQUIRY',
    );
    return this.dtoOf(manager, event, ev);
  }

  /** The user closes their live enquiry; the vendor goes back to ADDED. */
  async closeEnquiry(
    manager: EntityManager,
    userId: string,
    eventId: string,
    eventVendorId: string,
    enquiryId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<EventVendorDto> {
    const event = await this.lockEditable(manager, userId, eventId);
    const ev = await this.findLive(manager, eventId, eventVendorId);
    const enquiry = await manager
      .getRepository(EnquiryEntity)
      .findOneBy({ id: enquiryId, eventVendorId: ev.id });
    if (!enquiry) throw notFound();
    if (!LIVE.includes(enquiry.status)) {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'This enquiry is already closed.',
      );
    }
    enquiry.status = 'CLOSED';
    enquiry.closedByType = 'USER';
    enquiry.closedAt = now;
    await manager.getRepository(EnquiryEntity).save(enquiry);
    if (ev.status === 'ENQUIRED' || ev.status === 'QUOTED') {
      ev.status = 'ADDED';
      ev.statusChangedAt = now;
      await manager.getRepository(EventVendorEntity).save(ev);
    }
    await this.record(
      manager,
      userId,
      'ENQUIRY_CLOSED',
      enquiry.id,
      context,
      {
        eventId,
        eventVendorId: ev.id,
      },
      'ENQUIRY',
    );
    return this.dtoOf(manager, event, ev);
  }

  private async listFor(
    manager: EntityManager,
    event: EventEntity,
  ): Promise<EventVendorListDto> {
    const rows = await manager
      .getRepository(EventVendorEntity)
      .createQueryBuilder('ev')
      .where('ev.event_id = :eventId', { eventId: event.id })
      .andWhere(`ev.status <> 'REMOVED'`)
      .orderBy('ev.created_at', 'ASC')
      .addOrderBy('ev.id', 'ASC')
      .getMany();
    return {
      eventId: event.id,
      isEditable: event.status === 'PLANNING',
      vendors: await this.dtos(manager, event, rows),
    };
  }

  private async dtoOf(
    manager: EntityManager,
    event: EventEntity,
    ev: EventVendorEntity,
  ): Promise<EventVendorDto> {
    const [dto] = await this.dtos(manager, event, [ev]);
    return dto;
  }

  private async dtos(
    manager: EntityManager,
    event: EventEntity,
    rows: EventVendorEntity[],
  ): Promise<EventVendorDto[]> {
    if (rows.length === 0) return [];
    const cards = new Map(
      (await this.listings.cardsByIds(rows.map((r) => r.listingId))).map(
        (c) => [c.id, c],
      ),
    );
    const enquiries = await manager.getRepository(EnquiryEntity).find({
      where: { eventVendorId: In(rows.map((r) => r.id)) },
      order: { createdAt: 'DESC', id: 'DESC' },
    });
    const byVendor = new Map<string, EnquiryDto[]>();
    const liveFor = new Set<string>();
    for (const e of enquiries) {
      byVendor.set(e.eventVendorId, [
        ...(byVendor.get(e.eventVendorId) ?? []),
        toEnquiryDto(e),
      ]);
      if (LIVE.includes(e.status)) liveFor.add(e.eventVendorId);
    }
    return rows.map((r) => {
      const card = cards.get(r.listingId)!;
      return {
        id: r.id,
        status: r.status,
        notes: r.notes,
        listing: toListingCardDto(card),
        isAvailable: card.is_available,
        enquiries: byVendor.get(r.id) ?? [],
        canEnquire:
          event.status === 'PLANNING' &&
          card.is_available &&
          ENQUIRABLE.includes(r.status) &&
          !liveFor.has(r.id),
        version: r.version,
        createdAt: r.createdAt.toISOString(),
      };
    });
  }

  private async visibleListing(manager: EntityManager, listingId: string) {
    const [row] = await manager.query<
      {
        vendor_id: string;
        category_id: string;
        owner_user_id: string;
        title: string;
      }[]
    >(
      `SELECT l.vendor_id, l.category_id, v.user_id AS owner_user_id, l.title
         FROM vendor_listings l
         JOIN vendors v ON v.id = l.vendor_id
         JOIN vendor_categories c ON c.id = l.category_id
        WHERE l.id = $1::uuid AND l.status = 'APPROVED'
          AND v.status = 'ACTIVE' AND c.status = 'PUBLISHED'`,
      [listingId],
    );
    if (!row) {
      throw new AppException(
        ErrorCode.NOT_FOUND,
        HttpStatus.NOT_FOUND,
        'This vendor is no longer listed.',
      );
    }
    return row;
  }

  private async findLive(
    manager: EntityManager,
    eventId: string,
    eventVendorId: string,
  ): Promise<EventVendorEntity> {
    const ev = await manager
      .getRepository(EventVendorEntity)
      .findOneBy({ id: eventVendorId, eventId });
    if (!ev || ev.status === 'REMOVED') throw notFound();
    return ev;
  }

  private async lockEditable(
    manager: EntityManager,
    userId: string,
    eventId: string,
  ): Promise<EventEntity> {
    const event = await manager
      .getRepository(EventEntity)
      .createQueryBuilder('e')
      .setLock('pessimistic_write')
      .where('e.id = :eventId', { eventId })
      .andWhere('e.owner_user_id = :userId', { userId })
      .andWhere('e.deleted_at IS NULL')
      .getOne();
    if (!event) throw notFound();
    if (event.status !== 'PLANNING') {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'This event is no longer being planned, so its vendors are read only.',
      );
    }
    return event;
  }

  private record(
    manager: EntityManager,
    userId: string,
    action: string,
    entityId: string,
    context: RequestContext,
    summary: Record<string, unknown>,
    entityType = 'EVENT_VENDOR',
  ): Promise<void> {
    return this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action,
      entityType,
      entityId,
      requestId: context.requestId,
      ip: context.ip,
      summary,
    });
  }
}

/**
 * Closes live enquiries (OPEN/QUOTED) matching [where] — used when a vendor
 * is removed and when an event is cancelled or deleted (§4.6).
 */
export async function closeLiveEnquiries(
  manager: EntityManager,
  where: { eventVendorId: string } | { eventId: string },
  by: 'USER' | 'SYSTEM',
  now: Date,
): Promise<number> {
  const result = await manager
    .createQueryBuilder()
    .update(EnquiryEntity)
    .set({ status: 'CLOSED', closedByType: by, closedAt: now })
    .where(where)
    .andWhere('status IN (:...live)', { live: LIVE })
    .execute();
  return result.affected ?? 0;
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
}

function ownListing(): AppException {
  return new AppException(
    ErrorCode.FORBIDDEN_PERMISSION,
    HttpStatus.FORBIDDEN,
    'You cannot add or enquire with your own vendor listing.',
  );
}

function changedElsewhere(): AppException {
  return new AppException(
    ErrorCode.PRECONDITION_FAILED,
    HttpStatus.PRECONDITION_FAILED,
    'This vendor was changed elsewhere. Reload and try again.',
  );
}
