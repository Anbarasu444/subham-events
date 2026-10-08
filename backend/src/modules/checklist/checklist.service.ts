import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, type EntityManager, type Repository } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { uuidv7 } from '../../common/ids/uuid-v7';
import { AuditService } from '../audit/audit.service';
import { cancelReminders } from '../reminders/reminders.service';
import { localDate } from '../events/event-rules';
import { EventEntity } from '../events/event.entity';
import type { RequestContext } from '../events/events.service';
import { ChecklistItemEntity } from './checklist-item.entity';
import {
  MAX_CHECKLIST_ITEMS,
  summarize,
  toChecklistItemDto,
  type ChecklistDto,
  type ChecklistItemDto,
  type CreateChecklistItemDto,
  type ReorderChecklistDto,
  type UpdateChecklistItemDto,
} from './checklist.dto';

export type ChecklistAction = 'complete' | 'reopen';

/**
 * An event's checklist (M9). Access goes through the parent event: another
 * user's (or a deleted) event → 404. Writes need a PLANNING event (M9 answer
 * 2: completed/cancelled events are read only) and lock the event row, so
 * item counts and sort orders never race.
 */
@Injectable()
export class ChecklistService {
  constructor(
    @InjectRepository(EventEntity)
    private readonly events: Repository<EventEntity>,
    @InjectRepository(ChecklistItemEntity)
    private readonly items: Repository<ChecklistItemEntity>,
    private readonly audit: AuditService,
  ) {}

  async get(
    userId: string,
    eventId: string,
    now = new Date(),
  ): Promise<ChecklistDto> {
    const event = await this.events.findOneBy({
      id: eventId,
      ownerUserId: userId,
      deletedAt: IsNull(),
    });
    if (!event) throw notFound();
    const rows = await this.items.find({
      where: { eventId, deletedAt: IsNull() },
      order: { sortOrder: 'ASC', createdAt: 'ASC', id: 'ASC' },
    });
    const today = localDate(event.timeZone, now);
    const items = rows.map((row) => toChecklistItemDto(row, today));
    return {
      eventId,
      isEditable: event.status === 'PLANNING',
      summary: summarize(items),
      items,
    };
  }

  async create(
    manager: EntityManager,
    userId: string,
    eventId: string,
    dto: CreateChecklistItemDto,
    context: RequestContext,
    now = new Date(),
  ): Promise<ChecklistItemDto> {
    const event = await this.lockEditableEvent(manager, userId, eventId);
    const [{ count, next }] = await manager.query<
      { count: number; next: number }[]
    >(
      `SELECT count(*)::int AS count, COALESCE(max(sort_order) + 1, 0)::int AS next
         FROM checklist_items WHERE event_id = $1 AND deleted_at IS NULL`,
      [eventId],
    );
    if (count >= MAX_CHECKLIST_ITEMS) {
      throw new AppException(
        ErrorCode.LIMIT_REACHED,
        HttpStatus.CONFLICT,
        `A checklist can have at most ${MAX_CHECKLIST_ITEMS} items.`,
      );
    }
    const repo = manager.getRepository(ChecklistItemEntity);
    const saved = await repo.save(
      repo.create({
        id: uuidv7(),
        eventId,
        title: dto.title,
        notes: dto.notes ?? null,
        dueDate: dto.dueDate ?? null,
        status: 'PENDING',
        completedAt: null,
        sortOrder: next,
        deletedAt: null,
      }),
    );
    await this.record(
      manager,
      userId,
      'CHECKLIST_ITEM_CREATED',
      saved.id,
      context,
      {
        eventId,
      },
    );
    return toChecklistItemDto(saved, localDate(event.timeZone, now));
  }

  async update(
    manager: EntityManager,
    userId: string,
    eventId: string,
    itemId: string,
    dto: UpdateChecklistItemDto,
    context: RequestContext,
    now = new Date(),
  ): Promise<ChecklistItemDto> {
    const event = await this.lockEditableEvent(manager, userId, eventId);
    const item = await this.findItem(manager, eventId, itemId);
    if (item.version !== dto.version) {
      throw new AppException(
        ErrorCode.PRECONDITION_FAILED,
        HttpStatus.PRECONDITION_FAILED,
        'This item was changed elsewhere. Reload the checklist and try again.',
      );
    }
    const changed: string[] = [];
    if (dto.title !== undefined && dto.title !== item.title) {
      item.title = dto.title;
      changed.push('title');
    }
    if (dto.notes !== undefined && dto.notes !== item.notes) {
      item.notes = dto.notes;
      changed.push('notes');
    }
    if (dto.dueDate !== undefined && dto.dueDate !== item.dueDate) {
      item.dueDate = dto.dueDate;
      changed.push('dueDate');
    }
    const today = localDate(event.timeZone, now);
    if (changed.length === 0) return toChecklistItemDto(item, today);
    const saved = await manager.getRepository(ChecklistItemEntity).save(item);
    await this.record(
      manager,
      userId,
      'CHECKLIST_ITEM_UPDATED',
      itemId,
      context,
      {
        eventId,
        fields: changed,
      },
    );
    return toChecklistItemDto(saved, today);
  }

  /** PENDING ↔ DONE; `completed_at` is set or cleared (§4.12). */
  async transition(
    manager: EntityManager,
    userId: string,
    eventId: string,
    itemId: string,
    action: ChecklistAction,
    context: RequestContext,
    now = new Date(),
  ): Promise<ChecklistItemDto> {
    const event = await this.lockEditableEvent(manager, userId, eventId);
    const item = await this.findItem(manager, eventId, itemId);
    const target = action === 'complete' ? 'DONE' : 'PENDING';
    if (item.status === target) {
      throw new AppException(
        ErrorCode.INVALID_STATE_TRANSITION,
        HttpStatus.CONFLICT,
        action === 'complete'
          ? 'This item is already done.'
          : 'This item is not done.',
      );
    }
    item.status = target;
    item.completedAt = target === 'DONE' ? now : null;
    // A finished task's reminders are no longer needed (§4.13).
    if (target === 'DONE') {
      await cancelReminders(
        manager,
        { checklistItemId: itemId },
        'TASK_DONE',
        now,
      );
    }
    const saved = await manager.getRepository(ChecklistItemEntity).save(item);
    await this.record(
      manager,
      userId,
      action === 'complete'
        ? 'CHECKLIST_ITEM_COMPLETED'
        : 'CHECKLIST_ITEM_REOPENED',
      itemId,
      context,
      { eventId },
    );
    return toChecklistItemDto(saved, localDate(event.timeZone, now));
  }

  /**
   * Sets the order of all items. The list must contain exactly the event's
   * non-deleted items. Order is presentation only: item versions don't change.
   */
  async reorder(
    manager: EntityManager,
    userId: string,
    eventId: string,
    dto: ReorderChecklistDto,
    context: RequestContext,
    now = new Date(),
  ): Promise<ChecklistDto> {
    await this.lockEditableEvent(manager, userId, eventId);
    const current = await manager.getRepository(ChecklistItemEntity).find({
      select: { id: true },
      where: { eventId, deletedAt: IsNull() },
    });
    const known = new Set(current.map((row) => row.id));
    if (
      dto.itemIds.length !== known.size ||
      dto.itemIds.some((id) => !known.has(id))
    ) {
      throw new AppException(
        ErrorCode.VALIDATION_FAILED,
        HttpStatus.UNPROCESSABLE_ENTITY,
        undefined,
        [
          {
            field: 'itemIds',
            code: 'ITEMS_MISMATCH',
            message:
              'itemIds must list every item of the checklist exactly once',
          },
        ],
      );
    }
    if (dto.itemIds.length > 0) {
      await manager.query(
        `UPDATE checklist_items AS ci SET sort_order = o.position - 1
           FROM unnest($1::uuid[]) WITH ORDINALITY AS o(id, position)
          WHERE ci.id = o.id AND ci.event_id = $2`,
        [dto.itemIds, eventId],
      );
    }
    await this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action: 'CHECKLIST_REORDERED',
      entityType: 'EVENT',
      entityId: eventId,
      requestId: context.requestId,
      ip: context.ip,
      summary: { count: dto.itemIds.length },
    });
    return this.getWith(manager, userId, eventId, now);
  }

  /** Soft delete (R11). */
  async remove(
    manager: EntityManager,
    userId: string,
    eventId: string,
    itemId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<void> {
    await this.lockEditableEvent(manager, userId, eventId);
    const item = await this.findItem(manager, eventId, itemId);
    await cancelReminders(
      manager,
      { checklistItemId: itemId },
      'TASK_DELETED',
      now,
    );
    item.deletedAt = now;
    await manager.getRepository(ChecklistItemEntity).save(item);
    await this.record(
      manager,
      userId,
      'CHECKLIST_ITEM_DELETED',
      itemId,
      context,
      {
        eventId,
      },
    );
  }

  /** Reads inside the caller's transaction (after a write). */
  private async getWith(
    manager: EntityManager,
    userId: string,
    eventId: string,
    now: Date,
  ): Promise<ChecklistDto> {
    const event = await manager
      .getRepository(EventEntity)
      .findOneByOrFail({ id: eventId, ownerUserId: userId });
    const rows = await manager.getRepository(ChecklistItemEntity).find({
      where: { eventId, deletedAt: IsNull() },
      order: { sortOrder: 'ASC', createdAt: 'ASC', id: 'ASC' },
    });
    const today = localDate(event.timeZone, now);
    const items = rows.map((row) => toChecklistItemDto(row, today));
    return {
      eventId,
      isEditable: event.status === 'PLANNING',
      summary: summarize(items),
      items,
    };
  }

  private async lockEditableEvent(
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
        'This event is no longer being planned, so its checklist is read only.',
      );
    }
    return event;
  }

  private async findItem(
    manager: EntityManager,
    eventId: string,
    itemId: string,
  ): Promise<ChecklistItemEntity> {
    const item = await manager
      .getRepository(ChecklistItemEntity)
      .findOneBy({ id: itemId, eventId, deletedAt: IsNull() });
    if (!item) throw notFound();
    return item;
  }

  private record(
    manager: EntityManager,
    userId: string,
    action: string,
    itemId: string,
    context: RequestContext,
    summary: Record<string, unknown>,
  ): Promise<void> {
    return this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action,
      entityType: 'CHECKLIST_ITEM',
      entityId: itemId,
      requestId: context.requestId,
      ip: context.ip,
      summary,
    });
  }
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
}
