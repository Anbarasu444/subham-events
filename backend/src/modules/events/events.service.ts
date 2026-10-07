import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, type EntityManager, type Repository } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { uuidv7 } from '../../common/ids/uuid-v7';
import { Money } from '../../common/money/money';
import {
  decodeCursor,
  toCursorPage,
  type CursorPageMeta,
} from '../../common/pagination/cursor';
import { AuditService } from '../audit/audit.service';
import { EventEntity, type EventStatus } from './event.entity';
import {
  DEFAULT_EVENT_TIME_ZONE,
  isCalendarDate,
  localDate,
  nextStatus,
  type EventAction,
} from './event-rules';
import {
  toEventDto,
  type CreateEventDto,
  type EventDto,
  type ListEventsQuery,
  type UpdateEventDto,
} from './events.dto';

/** Request context recorded in the audit log. */
export interface RequestContext {
  requestId?: string;
  ip?: string;
}

const AUDIT_ACTIONS: Record<EventAction, string> = {
  cancel: 'EVENT_CANCELLED',
  complete: 'EVENT_COMPLETED',
  reopen: 'EVENT_REOPENED',
};

/** Field names (API) recorded in the EVENT_UPDATED audit summary. */
type EditableField = keyof Omit<UpdateEventDto, 'version'>;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** "Today" for each row in its own time zone, relative to `$now`. */
const LOCAL_TODAY_SQL = `(CAST(:now AS timestamptz) AT TIME ZONE e.time_zone)::date`;

/**
 * Owner-scoped event management. Another user's event is reported as
 * NOT_FOUND, never FORBIDDEN, so ids do not leak (api-contracts.md §4).
 */
@Injectable()
export class EventsService {
  constructor(
    @InjectRepository(EventEntity)
    private readonly events: Repository<EventEntity>,
    private readonly audit: AuditService,
  ) {}

  async create(
    manager: EntityManager,
    userId: string,
    dto: CreateEventDto,
    context: RequestContext,
    now = new Date(),
  ): Promise<EventDto> {
    const timeZone = dto.timeZone ?? DEFAULT_EVENT_TIME_ZONE;
    if (dto.timeZone) await assertDatabaseKnowsZone(manager, dto.timeZone);
    if (dto.eventDate < localDate(timeZone, now)) {
      throw pastDateError();
    }
    const repo = manager.getRepository(EventEntity);
    const event = repo.create({
      id: uuidv7(),
      ownerUserId: userId,
      eventType: dto.eventType,
      title: dto.title,
      eventDate: dto.eventDate,
      startTime: dto.startTime ?? null,
      timeZone,
      city: dto.city,
      venueName: dto.venueName ?? null,
      venueAddress: dto.venueAddress ?? null,
      guestCountEstimate: dto.guestCountEstimate ?? null,
      totalBudgetAmount: dto.totalBudget
        ? dto.totalBudget.toMoney().toString()
        : null,
      currency: dto.totalBudget?.currency ?? 'INR',
      status: 'PLANNING',
      statusChangedAt: now,
      deletedAt: null,
    });
    const saved = await repo.save(event);
    await this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action: 'EVENT_CREATED',
      entityType: 'EVENT',
      entityId: saved.id,
      requestId: context.requestId,
      ip: context.ip,
      summary: { status: saved.status },
    });
    return toEventDto(saved);
  }

  async list(
    userId: string,
    query: ListEventsQuery,
    now = new Date(),
  ): Promise<{ items: EventDto[]; page: CursorPageMeta }> {
    const descending = query.scope === 'past';
    const qb = this.events
      .createQueryBuilder('e')
      .where('e.owner_user_id = :userId', { userId })
      .andWhere('e.deleted_at IS NULL')
      .setParameter('now', now.toISOString());

    if (query.scope === 'upcoming') {
      qb.andWhere(
        `e.status = 'PLANNING' AND e.event_date >= ${LOCAL_TODAY_SQL}`,
      );
    } else if (query.scope === 'past') {
      qb.andWhere(
        `(e.status <> 'PLANNING' OR e.event_date < ${LOCAL_TODAY_SQL})`,
      );
    }
    if (query.status) {
      qb.andWhere('e.status = :status', { status: query.status });
    }
    if (query.cursor) {
      // A cursor only continues the list (scope) it came from.
      const cursor = decodeCursor(query.cursor, ['s', 'd', 'i'] as const, {
        s: (v) => v === query.scope,
        d: isCalendarDate,
        i: (v) => UUID_PATTERN.test(v),
      });
      qb.andWhere(
        `(e.event_date, e.id) ${descending ? '<' : '>'} (CAST(:cd AS date), CAST(:ci AS uuid))`,
        { cd: cursor.d, ci: cursor.i },
      );
    }
    const direction = descending ? 'DESC' : 'ASC';
    const rows = await qb
      .orderBy('e.event_date', direction)
      .addOrderBy('e.id', direction)
      .limit(query.limit + 1)
      .getMany();

    const { items, page } = toCursorPage(rows, query.limit, (last) => ({
      s: query.scope,
      d: last.eventDate,
      i: last.id,
    }));
    return { items: items.map(toEventDto), page };
  }

  async get(userId: string, id: string): Promise<EventDto> {
    const event = await this.events.findOneBy({
      id,
      ownerUserId: userId,
      deletedAt: IsNull(),
    });
    if (!event) throw notFound();
    return toEventDto(event);
  }

  async update(
    manager: EntityManager,
    userId: string,
    id: string,
    dto: UpdateEventDto,
    context: RequestContext,
  ): Promise<EventDto> {
    const event = await this.lockOwned(manager, userId, id);
    if (event.version !== dto.version) {
      throw new AppException(
        ErrorCode.PRECONDITION_FAILED,
        HttpStatus.PRECONDITION_FAILED,
        'This event was changed elsewhere. Reload it and try again.',
      );
    }

    const changed: string[] = [];
    const assign = <K extends keyof EventEntity>(
      field: EditableField,
      key: K,
      value: EventEntity[K] | undefined,
    ) => {
      if (value === undefined || event[key] === value) return;
      event[key] = value;
      changed.push(field);
    };
    assign('eventType', 'eventType', dto.eventType);
    assign('title', 'title', dto.title);
    // Moving an existing event to a past date is allowed (M8 answer 4).
    assign('eventDate', 'eventDate', dto.eventDate);
    if (dto.startTime !== undefined) {
      const current = event.startTime ? event.startTime.slice(0, 5) : null;
      if (current !== dto.startTime) {
        event.startTime = dto.startTime;
        changed.push('startTime');
      }
    }
    if (dto.timeZone && dto.timeZone !== event.timeZone) {
      await assertDatabaseKnowsZone(manager, dto.timeZone);
    }
    assign('timeZone', 'timeZone', dto.timeZone);
    assign('city', 'city', dto.city);
    assign('venueName', 'venueName', dto.venueName);
    assign('venueAddress', 'venueAddress', dto.venueAddress);
    assign('guestCountEstimate', 'guestCountEstimate', dto.guestCountEstimate);
    if (dto.totalBudget !== undefined) {
      const next = dto.totalBudget ? dto.totalBudget.toMoney() : null;
      const current =
        event.totalBudgetAmount === null
          ? null
          : Money.fromDb(event.totalBudgetAmount, event.currency);
      const same =
        next === null || current === null
          ? next === current
          : next.equals(current);
      if (!same) {
        event.totalBudgetAmount = next ? next.toString() : null;
        if (next) event.currency = next.currency;
        changed.push('totalBudget');
      }
    }

    if (changed.length === 0) return toEventDto(event);
    const saved = await manager.getRepository(EventEntity).save(event);
    await this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action: 'EVENT_UPDATED',
      entityType: 'EVENT',
      entityId: id,
      requestId: context.requestId,
      ip: context.ip,
      summary: { fields: changed },
    });
    return toEventDto(saved);
  }

  async transition(
    manager: EntityManager,
    userId: string,
    id: string,
    action: EventAction,
    context: RequestContext,
    now = new Date(),
  ): Promise<EventDto> {
    const event = await this.lockOwned(manager, userId, id);
    const target = nextStatus(action, event, now);
    if (!target) {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        transitionMessage(action, event.status),
      );
    }
    const from = event.status;
    event.status = target;
    event.statusChangedAt = now;
    const saved = await manager.getRepository(EventEntity).save(event);
    await this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action: AUDIT_ACTIONS[action],
      entityType: 'EVENT',
      entityId: id,
      requestId: context.requestId,
      ip: context.ip,
      summary: { from, to: target },
    });
    return toEventDto(saved);
  }

  /** Soft delete (R11): the row is kept and hidden. */
  async remove(
    manager: EntityManager,
    userId: string,
    id: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<void> {
    const event = await this.lockOwned(manager, userId, id);
    event.deletedAt = now;
    await manager.getRepository(EventEntity).save(event);
    await this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action: 'EVENT_DELETED',
      entityType: 'EVENT',
      entityId: id,
      requestId: context.requestId,
      ip: context.ip,
      summary: { status: event.status },
    });
  }

  private async lockOwned(
    manager: EntityManager,
    userId: string,
    id: string,
  ): Promise<EventEntity> {
    const event = await manager
      .getRepository(EventEntity)
      .createQueryBuilder('e')
      .setLock('pessimistic_write')
      .where('e.id = :id', { id })
      .andWhere('e.owner_user_id = :userId', { userId })
      .andWhere('e.deleted_at IS NULL')
      .getOne();
    if (!event) throw notFound();
    return event;
  }
}

/**
 * The zone must exist in PostgreSQL's tzdata too, or date queries and the
 * auto-complete job would fail for this row.
 */
async function assertDatabaseKnowsZone(
  manager: EntityManager,
  timeZone: string,
): Promise<void> {
  const [row] = await manager.query<{ known: boolean }[]>(
    `SELECT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = $1) AS known`,
    [timeZone],
  );
  if (!row?.known) {
    throw new AppException(
      ErrorCode.VALIDATION_FAILED,
      HttpStatus.UNPROCESSABLE_ENTITY,
      undefined,
      [
        {
          field: 'timeZone',
          code: 'UNKNOWN_TIME_ZONE',
          message: 'timeZone is not a supported time zone',
        },
      ],
    );
  }
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
}

function pastDateError(): AppException {
  return new AppException(
    ErrorCode.VALIDATION_FAILED,
    HttpStatus.UNPROCESSABLE_ENTITY,
    undefined,
    [
      {
        field: 'eventDate',
        code: 'MUST_NOT_BE_PAST',
        message: 'Event date cannot be in the past.',
      },
    ],
  );
}

function transitionMessage(action: EventAction, status: EventStatus): string {
  if (action === 'reopen' && status !== 'PLANNING') {
    return 'Only events dated today or later can be reopened. Change the date first.';
  }
  const verb = {
    cancel: 'cancelled',
    complete: 'completed',
    reopen: 'reopened',
  }[action];
  return `A ${status.toLowerCase()} event cannot be ${verb}.`;
}
