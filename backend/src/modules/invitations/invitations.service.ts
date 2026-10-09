import { createHash, randomBytes } from 'node:crypto';
import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, type EntityManager, type Repository } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { uuidv7 } from '../../common/ids/uuid-v7';
import { AuditService } from '../audit/audit.service';
import { localDate } from '../events/event-rules';
import { EventEntity } from '../events/event.entity';
import type { RequestContext } from '../events/events.service';
import { InvitationEntity } from './invitation.entity';
import type {
  GuestRsvpDto,
  InvitationDto,
  RsvpDto,
  RsvpTotals,
  SaveInvitationDto,
} from './invitations.dto';
import { templateByCode, type InvitationTemplate } from './templates';

/** Most RSVPs per invitation (§4.15 abuse limit). */
export const MAX_RSVPS = 1000;

export function hashToken(token: string): Buffer {
  return createHash('sha256').update(token, 'utf8').digest();
}

/** An unguessable token for links and guests (256 bits, base64url). */
export function newToken(): string {
  return randomBytes(32).toString('base64url');
}

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;

export interface PublicInvitation {
  invitation: InvitationEntity;
  template: InvitationTemplate;
  rsvpOpen: boolean;
}

/**
 * Event invitations (M19; R9, A6). Owner-only through the event (404);
 * content changes need a PLANNING event, closing RSVPs and revoking do not.
 * Share tokens are returned once (publish / new link) and stored hashed.
 */
@Injectable()
export class InvitationsService {
  constructor(
    @InjectRepository(EventEntity)
    private readonly events: Repository<EventEntity>,
    private readonly audit: AuditService,
  ) {}

  async get(userId: string, eventId: string): Promise<InvitationDto | null> {
    await this.ownEvent(this.events.manager, userId, eventId, false);
    const inv = await this.events.manager
      .getRepository(InvitationEntity)
      .findOneBy({ eventId });
    return inv ? this.dto(this.events.manager, inv) : null;
  }

  async save(
    manager: EntityManager,
    userId: string,
    eventId: string,
    dto: SaveInvitationDto,
    context: RequestContext,
  ): Promise<InvitationDto> {
    const event = await this.ownEvent(manager, userId, eventId, true);
    if (!templateByCode(dto.templateCode)) {
      throw invalid(
        'templateCode',
        'UNKNOWN_TEMPLATE',
        'templateCode is not in the catalogue',
      );
    }
    const repo = manager.getRepository(InvitationEntity);
    const existing = await repo.findOneBy({ eventId });
    // Event details are copied at every save, so the invitation shows the
    // date, time and venue as they were when the user last edited it.
    const fields = {
      templateCode: dto.templateCode,
      title: dto.title,
      message: dto.message ?? null,
      hostNames: dto.hostNames ?? null,
      eventDate: event.eventDate,
      startTime: event.startTime,
      venueName: event.venueName,
      venueAddress: event.venueAddress,
    };
    const saved = existing
      ? await repo.save(Object.assign(existing, fields))
      : await repo.save(
          repo.create({
            id: uuidv7(),
            eventId,
            userId,
            ...fields,
            status: 'DRAFT',
            rsvpOpen: true,
            shareTokenHash: null,
            publishedAt: null,
            revokedAt: null,
            lastRsvpNotifiedAt: null,
          }),
        );
    await this.record(
      manager,
      userId,
      existing ? 'INVITATION_UPDATED' : 'INVITATION_CREATED',
      saved.id,
      context,
      { eventId },
    );
    return this.dto(manager, saved);
  }

  /** DRAFT/REVOKED → PUBLISHED with a new link. Returns the raw token once. */
  async publish(
    manager: EntityManager,
    userId: string,
    eventId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<{ invitation: InvitationDto; token: string }> {
    await this.ownEvent(manager, userId, eventId, true);
    const inv = await this.find(manager, eventId);
    if (inv.status === 'PUBLISHED') {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'This invitation is already published. Create a new link instead.',
      );
    }
    return this.issueLink(
      manager,
      userId,
      inv,
      'INVITATION_PUBLISHED',
      context,
      now,
    );
  }

  /** PUBLISHED: replaces the link (the old one stops working). */
  async newLink(
    manager: EntityManager,
    userId: string,
    eventId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<{ invitation: InvitationDto; token: string }> {
    await this.ownEvent(manager, userId, eventId, true);
    const inv = await this.find(manager, eventId);
    if (inv.status !== 'PUBLISHED') {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'Publish the invitation first.',
      );
    }
    return this.issueLink(
      manager,
      userId,
      inv,
      'INVITATION_LINK_REPLACED',
      context,
      now,
    );
  }

  async setRsvpOpen(
    manager: EntityManager,
    userId: string,
    eventId: string,
    open: boolean,
    context: RequestContext,
  ): Promise<InvitationDto> {
    await this.ownEvent(manager, userId, eventId, false);
    const inv = await this.find(manager, eventId);
    if (inv.rsvpOpen !== open) {
      inv.rsvpOpen = open;
      await manager.getRepository(InvitationEntity).save(inv);
      await this.record(
        manager,
        userId,
        open ? 'INVITATION_RSVP_OPENED' : 'INVITATION_RSVP_CLOSED',
        inv.id,
        context,
        { eventId },
      );
    }
    return this.dto(manager, inv);
  }

  /** PUBLISHED → REVOKED: the link stops working; RSVPs stay. */
  async revoke(
    manager: EntityManager,
    userId: string,
    eventId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<InvitationDto> {
    await this.ownEvent(manager, userId, eventId, false);
    const inv = await this.find(manager, eventId);
    if (inv.status !== 'PUBLISHED') {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'Only a published invitation can be revoked.',
      );
    }
    inv.status = 'REVOKED';
    inv.revokedAt = now;
    inv.shareTokenHash = null;
    await manager.getRepository(InvitationEntity).save(inv);
    await this.record(manager, userId, 'INVITATION_REVOKED', inv.id, context, {
      eventId,
    });
    return this.dto(manager, inv);
  }

  async rsvps(
    userId: string,
    eventId: string,
  ): Promise<{ totals: RsvpTotals; rsvps: RsvpDto[] }> {
    const manager = this.events.manager;
    await this.ownEvent(manager, userId, eventId, false);
    const inv = await this.find(manager, eventId);
    const rows = await manager.query<
      {
        id: string;
        guest_name: string;
        response: RsvpDto['response'];
        guest_count: number;
        message: string | null;
        updated_at: Date;
      }[]
    >(
      `SELECT id, guest_name, response, guest_count, message, updated_at
         FROM invitation_rsvps WHERE invitation_id = $1
        ORDER BY updated_at DESC, id DESC`,
      [inv.id],
    );
    return {
      totals: await this.totals(manager, inv.id),
      rsvps: rows.map((r) => ({
        id: r.id,
        guestName: r.guest_name,
        response: r.response,
        guestCount: r.guest_count,
        message: r.message,
        updatedAt: r.updated_at.toISOString(),
      })),
    };
  }

  // ---- Public (guests) ----

  /** A visible invitation for a share token, else null (any reason). */
  async findPublic(
    token: string,
    now = new Date(),
  ): Promise<PublicInvitation | null> {
    if (!TOKEN_PATTERN.test(token)) return null;
    const manager = this.events.manager;
    const inv = await manager
      .getRepository(InvitationEntity)
      .findOneBy({ shareTokenHash: hashToken(token), status: 'PUBLISHED' });
    if (!inv) return null;
    const event = await manager
      .getRepository(EventEntity)
      .findOneBy({ id: inv.eventId, deletedAt: IsNull() });
    if (!event || event.status === 'CANCELLED') return null;
    const template =
      templateByCode(inv.templateCode) ?? templateByCode('classic')!;
    return { invitation: inv, template, rsvpOpen: rsvpOpen(inv, event, now) };
  }

  async guestRsvp(invitationId: string, responderToken: string) {
    const [row] = await this.events.manager.query<
      {
        guest_name: string;
        response: RsvpDto['response'];
        guest_count: number;
        message: string | null;
      }[]
    >(
      `SELECT guest_name, response, guest_count, message FROM invitation_rsvps
        WHERE invitation_id = $1 AND responder_token_hash = $2`,
      [invitationId, hashToken(responderToken)],
    );
    return row
      ? {
          guestName: row.guest_name,
          response: row.response,
          guestCount: row.guest_count,
          message: row.message,
        }
      : null;
  }

  /** Creates or updates this browser's RSVP (A6). */
  async submitRsvp(
    pub: PublicInvitation,
    responderToken: string,
    dto: GuestRsvpDto,
    ip: string | undefined,
  ): Promise<void> {
    if (!pub.rsvpOpen) {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'Replies are closed.',
      );
    }
    await this.events.manager.transaction(async (manager) => {
      // Serialise RSVPs per invitation so the cap cannot race.
      await manager.query(
        `SELECT id FROM invitations WHERE id = $1 FOR UPDATE`,
        [pub.invitation.id],
      );
      const hash = hashToken(responderToken);
      const [{ count, mine }] = await manager.query<
        { count: number; mine: number }[]
      >(
        `SELECT count(*)::int AS count,
                count(*) FILTER (WHERE responder_token_hash = $2)::int AS mine
           FROM invitation_rsvps WHERE invitation_id = $1`,
        [pub.invitation.id, hash],
      );
      if (!mine && count >= MAX_RSVPS) {
        throw new AppException(
          ErrorCode.LIMIT_REACHED,
          HttpStatus.CONFLICT,
          'This invitation cannot take more replies.',
        );
      }
      await manager.query(
        `INSERT INTO invitation_rsvps (id, invitation_id, responder_token_hash, guest_name, response, guest_count, message)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (invitation_id, responder_token_hash) DO UPDATE
           SET guest_name = EXCLUDED.guest_name, response = EXCLUDED.response,
               guest_count = EXCLUDED.guest_count, message = EXCLUDED.message,
               updated_at = now()`,
        [
          uuidv7(),
          pub.invitation.id,
          hash,
          dto.guestName,
          dto.response,
          dto.guestCount,
          dto.message ?? null,
        ],
      );
      await this.audit.record(manager, {
        actorType: 'GUEST',
        action: mine ? 'RSVP_UPDATED' : 'RSVP_CREATED',
        entityType: 'INVITATION',
        entityId: pub.invitation.id,
        ip: ip ?? null,
        // No names or messages in the audit log.
        summary: { response: dto.response },
      });
    });
  }

  // ---- helpers ----

  private async issueLink(
    manager: EntityManager,
    userId: string,
    inv: InvitationEntity,
    action: string,
    context: RequestContext,
    now: Date,
  ) {
    const token = newToken();
    inv.status = 'PUBLISHED';
    inv.shareTokenHash = hashToken(token);
    inv.publishedAt = now;
    inv.revokedAt = null;
    const saved = await manager.getRepository(InvitationEntity).save(inv);
    await this.record(manager, userId, action, inv.id, context, {
      eventId: inv.eventId,
    });
    return { invitation: await this.dto(manager, saved), token };
  }

  private async totals(
    manager: EntityManager,
    invitationId: string,
  ): Promise<RsvpTotals> {
    const [t] = await manager.query<RsvpTotals[]>(
      `SELECT count(*) FILTER (WHERE response = 'ATTENDING')::int AS attending,
              count(*) FILTER (WHERE response = 'MAYBE')::int AS maybe,
              count(*) FILTER (WHERE response = 'NOT_ATTENDING')::int AS "notAttending",
              COALESCE(sum(guest_count) FILTER (WHERE response = 'ATTENDING'), 0)::int AS guests
         FROM invitation_rsvps WHERE invitation_id = $1`,
      [invitationId],
    );
    return t;
  }

  private async dto(
    manager: EntityManager,
    inv: InvitationEntity,
  ): Promise<InvitationDto> {
    return {
      id: inv.id,
      eventId: inv.eventId,
      templateCode: inv.templateCode,
      title: inv.title,
      message: inv.message,
      hostNames: inv.hostNames,
      eventDate: inv.eventDate,
      startTime: inv.startTime ? inv.startTime.slice(0, 5) : null,
      venueName: inv.venueName,
      venueAddress: inv.venueAddress,
      status: inv.status,
      rsvpOpen: inv.rsvpOpen,
      rsvpClosesOn: dayAfter(inv.eventDate),
      publishedAt: inv.publishedAt ? inv.publishedAt.toISOString() : null,
      totals: await this.totals(manager, inv.id),
      version: inv.version,
    };
  }

  private async find(
    manager: EntityManager,
    eventId: string,
  ): Promise<InvitationEntity> {
    const inv = await manager
      .getRepository(InvitationEntity)
      .findOneBy({ eventId });
    if (!inv) throw notFound();
    return inv;
  }

  /** The owner's (not deleted) event, row-locked; planning-only when asked. */
  private async ownEvent(
    manager: EntityManager,
    userId: string,
    eventId: string,
    planningOnly: boolean,
  ): Promise<EventEntity> {
    const event = await manager
      .getRepository(EventEntity)
      .findOneBy({ id: eventId, ownerUserId: userId, deletedAt: IsNull() });
    if (!event) throw notFound();
    if (planningOnly && event.status !== 'PLANNING') {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'This event is no longer being planned, so its invitation cannot be changed.',
      );
    }
    return event;
  }

  private record(
    manager: EntityManager,
    userId: string,
    action: string,
    invitationId: string,
    context: RequestContext,
    summary: Record<string, unknown>,
  ): Promise<void> {
    return this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action,
      entityType: 'INVITATION',
      entityId: invitationId,
      requestId: context.requestId,
      ip: context.ip,
      summary,
    });
  }
}

function dayAfter(date: string): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

/** Open until the owner closes it, and only up to the day after the event. */
function rsvpOpen(
  inv: InvitationEntity,
  event: EventEntity,
  now: Date,
): boolean {
  return (
    inv.rsvpOpen && localDate(event.timeZone, now) <= dayAfter(event.eventDate)
  );
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
}

function invalid(field: string, code: string, message: string): AppException {
  return new AppException(
    ErrorCode.VALIDATION_FAILED,
    HttpStatus.UNPROCESSABLE_ENTITY,
    undefined,
    [{ field, code, message }],
  );
}
