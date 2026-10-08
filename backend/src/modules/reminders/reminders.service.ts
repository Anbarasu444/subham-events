import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, type EntityManager, type Repository } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { uuidv7 } from '../../common/ids/uuid-v7';
import { AuditService } from '../audit/audit.service';
import { ChecklistItemEntity } from '../checklist/checklist-item.entity';
import { EventEntity } from '../events/event.entity';
import type { RequestContext } from '../events/events.service';
import { ReminderEntity, type ReminderCancelReason } from './reminder.entity';
import {
  MAX_SCHEDULED_REMINDERS,
  toReminderDto,
  type CreateReminderDto,
  type EventRemindersDto,
  type ReminderDto,
  type UpdateReminderDto,
} from './reminders.dto';

/**
 * Reminders (M17, §4.13). Owner-only through the event (404 otherwise);
 * writes need a PLANNING event and lock its row. Fired by
 * ReminderDueJob (N17); auto-cancelled by checklist and event changes.
 */
@Injectable()
export class RemindersService {
  constructor(
    @InjectRepository(EventEntity)
    private readonly events: Repository<EventEntity>,
    private readonly audit: AuditService,
  ) {}

  async list(userId: string, eventId: string): Promise<EventRemindersDto> {
    const event = await this.ownEvent(userId, eventId);
    const manager = this.events.manager;
    const repo = manager.getRepository(ReminderEntity);
    const upcoming = await repo.find({
      where: { eventId, status: 'SCHEDULED' },
      order: { remindAt: 'ASC', id: 'ASC' },
    });
    const past = await repo.find({
      where: { eventId, status: In(['SENT', 'CANCELLED']) },
      order: { remindAt: 'DESC', id: 'DESC' },
      take: 50,
    });
    return {
      eventId,
      isEditable: event.status === 'PLANNING',
      upcoming: await this.dtos(manager, upcoming, [event]),
      past: await this.dtos(manager, past, [event]),
    };
  }

  /** Across the user's events: upcoming scheduled ones, or due-and-unseen. */
  async mine(
    userId: string,
    scope: 'upcoming' | 'due',
    limit: number,
  ): Promise<ReminderDto[]> {
    const manager = this.events.manager;
    const rows = await manager
      .getRepository(ReminderEntity)
      .createQueryBuilder('r')
      .innerJoin(EventEntity, 'e', 'e.id = r.event_id')
      .where('r.user_id = :userId', { userId })
      .andWhere('e.deleted_at IS NULL')
      .andWhere(
        scope === 'upcoming'
          ? `r.status = 'SCHEDULED'`
          : `r.status = 'SENT' AND r.seen_at IS NULL`,
      )
      .orderBy('r.remindAt', scope === 'upcoming' ? 'ASC' : 'DESC')
      .addOrderBy('r.id', 'ASC')
      // limit (not take): the join adds no rows and selects nothing extra.
      .limit(limit)
      .getMany();
    const events = await manager
      .getRepository(EventEntity)
      .findBy({ id: In([...new Set(rows.map((r) => r.eventId))]) });
    return this.dtos(manager, rows, events);
  }

  async create(
    manager: EntityManager,
    userId: string,
    eventId: string,
    dto: CreateReminderDto,
    context: RequestContext,
    now = new Date(),
  ): Promise<ReminderDto> {
    const event = await this.lockEditable(manager, userId, eventId);
    future(dto.remindAt, now);
    const itemId = dto.checklistItemId ?? null;
    if (itemId) await this.liveItem(manager, eventId, itemId);
    const count = await manager
      .getRepository(ReminderEntity)
      .countBy({ eventId, status: 'SCHEDULED' });
    if (count >= MAX_SCHEDULED_REMINDERS) {
      throw new AppException(
        ErrorCode.LIMIT_REACHED,
        HttpStatus.CONFLICT,
        `An event can have at most ${MAX_SCHEDULED_REMINDERS} scheduled reminders.`,
      );
    }
    const repo = manager.getRepository(ReminderEntity);
    const saved = await repo.save(
      repo.create({
        id: uuidv7(),
        userId,
        eventId,
        checklistItemId: itemId,
        title: dto.title,
        remindAt: dto.remindAt,
        status: 'SCHEDULED',
        sentAt: null,
        seenAt: null,
        cancelledAt: null,
        cancelReason: null,
      }),
    );
    await this.record(manager, userId, 'REMINDER_CREATED', saved.id, context, {
      eventId,
    });
    const [dtoOut] = await this.dtos(manager, [saved], [event]);
    return dtoOut;
  }

  async update(
    manager: EntityManager,
    userId: string,
    eventId: string,
    reminderId: string,
    dto: UpdateReminderDto,
    context: RequestContext,
    now = new Date(),
  ): Promise<ReminderDto> {
    const event = await this.lockEditable(manager, userId, eventId);
    const reminder = await this.find(manager, eventId, reminderId);
    if (reminder.version !== dto.version) {
      throw new AppException(
        ErrorCode.PRECONDITION_FAILED,
        HttpStatus.PRECONDITION_FAILED,
        'This reminder was changed elsewhere. Reload and try again.',
      );
    }
    if (reminder.status !== 'SCHEDULED') {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'Only a scheduled reminder can be changed.',
      );
    }
    const changed: string[] = [];
    if (dto.title !== undefined && dto.title !== reminder.title) {
      reminder.title = dto.title;
      changed.push('title');
    }
    if (
      dto.remindAt !== undefined &&
      dto.remindAt.getTime() !== reminder.remindAt.getTime()
    ) {
      future(dto.remindAt, now);
      reminder.remindAt = dto.remindAt;
      changed.push('remindAt');
    }
    if (
      dto.checklistItemId !== undefined &&
      dto.checklistItemId !== reminder.checklistItemId
    ) {
      if (dto.checklistItemId) {
        await this.liveItem(manager, eventId, dto.checklistItemId);
      }
      reminder.checklistItemId = dto.checklistItemId;
      changed.push('checklistItemId');
    }
    const saved = changed.length
      ? await manager.getRepository(ReminderEntity).save(reminder)
      : reminder;
    if (changed.length) {
      await this.record(
        manager,
        userId,
        'REMINDER_UPDATED',
        reminder.id,
        context,
        {
          eventId,
          fields: changed,
        },
      );
    }
    const [dtoOut] = await this.dtos(manager, [saved], [event]);
    return dtoOut;
  }

  async cancel(
    manager: EntityManager,
    userId: string,
    eventId: string,
    reminderId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<ReminderDto> {
    const event = await this.lockEditable(manager, userId, eventId);
    const reminder = await this.find(manager, eventId, reminderId);
    if (reminder.status !== 'SCHEDULED') {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        'Only a scheduled reminder can be cancelled.',
      );
    }
    reminder.status = 'CANCELLED';
    reminder.cancelledAt = now;
    reminder.cancelReason = 'USER';
    const saved = await manager.getRepository(ReminderEntity).save(reminder);
    await this.record(
      manager,
      userId,
      'REMINDER_CANCELLED',
      reminder.id,
      context,
      {
        eventId,
      },
    );
    const [dtoOut] = await this.dtos(manager, [saved], [event]);
    return dtoOut;
  }

  /** Dismisses the in-app "due" banner (any event status). */
  async markSeen(
    userId: string,
    eventId: string,
    reminderId: string,
    now = new Date(),
  ): Promise<void> {
    await this.ownEvent(userId, eventId);
    const result = await this.events.manager
      .getRepository(ReminderEntity)
      .update(
        { id: reminderId, eventId, userId, status: 'SENT', seenAt: IsNull() },
        { seenAt: now },
      );
    if (!result.affected) {
      const exists = await this.events.manager
        .getRepository(ReminderEntity)
        .existsBy({ id: reminderId, eventId, userId });
      if (!exists) throw notFound();
    }
  }

  private async dtos(
    manager: EntityManager,
    rows: ReminderEntity[],
    events: EventEntity[],
  ): Promise<ReminderDto[]> {
    const titles = new Map(events.map((e) => [e.id, e.title]));
    const itemIds = [
      ...new Set(rows.map((r) => r.checklistItemId).filter((id) => !!id)),
    ] as string[];
    const items = itemIds.length
      ? await manager
          .getRepository(ChecklistItemEntity)
          .findBy({ id: In(itemIds) })
      : [];
    const itemTitles = new Map(items.map((i) => [i.id, i.title]));
    return rows.map((r) =>
      toReminderDto(
        r,
        titles.get(r.eventId) ?? '',
        r.checklistItemId ? (itemTitles.get(r.checklistItemId) ?? null) : null,
      ),
    );
  }

  private async ownEvent(
    userId: string,
    eventId: string,
  ): Promise<EventEntity> {
    const event = await this.events.findOneBy({
      id: eventId,
      ownerUserId: userId,
      deletedAt: IsNull(),
    });
    if (!event) throw notFound();
    return event;
  }

  private async liveItem(
    manager: EntityManager,
    eventId: string,
    itemId: string,
  ): Promise<void> {
    const item = await manager
      .getRepository(ChecklistItemEntity)
      .findOneBy({ id: itemId, eventId, deletedAt: IsNull() });
    if (!item) {
      throw new AppException(
        ErrorCode.VALIDATION_FAILED,
        HttpStatus.UNPROCESSABLE_ENTITY,
        undefined,
        [
          {
            field: 'checklistItemId',
            code: 'UNKNOWN_TASK',
            message: 'checklistItemId must be a task of this event',
          },
        ],
      );
    }
  }

  private async find(
    manager: EntityManager,
    eventId: string,
    reminderId: string,
  ): Promise<ReminderEntity> {
    const reminder = await manager
      .getRepository(ReminderEntity)
      .findOneBy({ id: reminderId, eventId });
    if (!reminder) throw notFound();
    return reminder;
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
        'This event is no longer being planned, so its reminders are read only.',
      );
    }
    return event;
  }

  private record(
    manager: EntityManager,
    userId: string,
    action: string,
    reminderId: string,
    context: RequestContext,
    summary: Record<string, unknown>,
  ): Promise<void> {
    // Ids and field names only: titles are the user's text.
    return this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action,
      entityType: 'REMINDER',
      entityId: reminderId,
      requestId: context.requestId,
      ip: context.ip,
      summary,
    });
  }
}

/**
 * Cancels scheduled reminders matching [where] (§4.13 auto-cancel): a task
 * done or deleted, an event cancelled or deleted. Returns how many.
 */
export async function cancelReminders(
  manager: EntityManager,
  where: { checklistItemId: string } | { eventId: string },
  reason: ReminderCancelReason,
  now: Date,
): Promise<number> {
  const result = await manager
    .createQueryBuilder()
    .update(ReminderEntity)
    .set({ status: 'CANCELLED', cancelledAt: now, cancelReason: reason })
    .where(where)
    .andWhere(`status = 'SCHEDULED'`)
    .execute();
  return result.affected ?? 0;
}

function future(at: Date, now: Date): void {
  if (at.getTime() <= now.getTime()) {
    throw new AppException(
      ErrorCode.VALIDATION_FAILED,
      HttpStatus.UNPROCESSABLE_ENTITY,
      undefined,
      [
        {
          field: 'remindAt',
          code: 'TIME_IN_PAST',
          message: 'remindAt must be in the future',
        },
      ],
    );
  }
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
}
