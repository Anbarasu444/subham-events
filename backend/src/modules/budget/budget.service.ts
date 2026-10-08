import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, type EntityManager, type Repository } from 'typeorm';
import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { uuidv7 } from '../../common/ids/uuid-v7';
import { Money } from '../../common/money/money';
import { AuditService } from '../audit/audit.service';
import { VendorCategoryEntity } from '../categories/vendor-category.entity';
import { EventEntity } from '../events/event.entity';
import type { RequestContext } from '../events/events.service';
import { BudgetAllocationEntity } from './budget-allocation.entity';
import { EventExpenseEntity } from './event-expense.entity';
import type { BudgetDto } from './budget.dto';

/**
 * Per-event budget (M11, domain-model.md §7). Owner-only through the event
 * (another user's or a deleted event → 404). Changes need a PLANNING event
 * (read-only otherwise, like the checklist) and lock the event row.
 * Committed (M15) and Paid (M16) are zero until bookings and payment notes
 * exist; the user's own expenses (answer 5) count as spent.
 */
@Injectable()
export class BudgetService {
  constructor(
    @InjectRepository(EventEntity)
    private readonly events: Repository<EventEntity>,
    private readonly audit: AuditService,
  ) {}

  async get(userId: string, eventId: string): Promise<BudgetDto> {
    const event = await this.events.findOneBy({
      id: eventId,
      ownerUserId: userId,
      deletedAt: IsNull(),
    });
    if (!event) throw notFound();
    return this.build(this.events.manager, event);
  }

  async setAllocation(
    manager: EntityManager,
    userId: string,
    eventId: string,
    categoryId: string,
    planned: Money,
    context: RequestContext,
  ): Promise<BudgetDto> {
    const event = await this.lockEditable(manager, userId, eventId);
    await this.publishedCategory(manager, categoryId);
    if (planned.currency !== event.currency) {
      throw new AppException(
        ErrorCode.VALIDATION_FAILED,
        HttpStatus.UNPROCESSABLE_ENTITY,
        undefined,
        [
          {
            field: 'planned.currency',
            code: 'CURRENCY_MISMATCH',
            message: 'planned.currency must match the event currency',
          },
        ],
      );
    }
    const repo = manager.getRepository(BudgetAllocationEntity);
    const current = await repo.findOneBy({
      eventId,
      categoryId,
      deletedAt: IsNull(),
    });
    const amount = planned.toString();
    if (current) {
      if (
        Money.fromDb(current.plannedAmount, current.currency).equals(planned)
      ) {
        return this.build(manager, event);
      }
      current.plannedAmount = amount;
      await repo.save(current);
    } else {
      await repo.insert({
        id: uuidv7(),
        eventId,
        categoryId,
        plannedAmount: amount,
        currency: planned.currency,
      });
    }
    await this.record(
      manager,
      userId,
      'BUDGET_ALLOCATION_SET',
      eventId,
      context,
      // Like event updates: ids and what changed, not the amounts themselves.
      { categoryId, created: !current },
    );
    return this.build(manager, event);
  }

  /** Clears a category's plan (soft delete, R11). */
  async clearAllocation(
    manager: EntityManager,
    userId: string,
    eventId: string,
    categoryId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<BudgetDto> {
    const event = await this.lockEditable(manager, userId, eventId);
    const result = await manager.update(
      BudgetAllocationEntity,
      { eventId, categoryId, deletedAt: IsNull() },
      { deletedAt: now },
    );
    if (result.affected) {
      await this.record(
        manager,
        userId,
        'BUDGET_ALLOCATION_CLEARED',
        eventId,
        context,
        {
          categoryId,
        },
      );
    }
    return this.build(manager, event);
  }

  private async build(
    manager: EntityManager,
    event: EventEntity,
  ): Promise<BudgetDto> {
    const categories = await manager.getRepository(VendorCategoryEntity).find({
      where: { status: 'PUBLISHED' },
      order: { sortOrder: 'ASC', name: 'ASC' },
    });
    const allocations = await manager
      .getRepository(BudgetAllocationEntity)
      .findBy({
        eventId: event.id,
        deletedAt: IsNull(),
      });
    const expenseRows = await manager
      .getRepository(EventExpenseEntity)
      .findBy({ eventId: event.id, deletedAt: IsNull() });
    const expensesBy = new Map<string, Money>();
    let expenses = Money.zero();
    for (const e of expenseRows) {
      const amount = Money.fromDb(e.amount, e.currency);
      expenses = expenses.add(amount);
      if (e.categoryId) {
        expensesBy.set(
          e.categoryId,
          (expensesBy.get(e.categoryId) ?? Money.zero()).add(amount),
        );
      }
    }
    const byCategory = new Map(
      allocations.map((a) => [
        a.categoryId,
        Money.fromDb(a.plannedAmount, a.currency),
      ]),
    );
    // Plans for categories that are no longer offered stay visible.
    const published = new Set(categories.map((c) => c.id));
    const archivedIds = [
      ...new Set([
        ...allocations.map((a) => a.categoryId),
        ...expensesBy.keys(),
      ]),
    ].filter((id) => !published.has(id));
    const archived = archivedIds.length
      ? await manager
          .getRepository(VendorCategoryEntity)
          .findBy({ id: In(archivedIds) })
      : [];
    // Plans for categories no longer published still count towards the total.
    const planned = allocations.reduce(
      (sum, a) => sum.add(Money.fromDb(a.plannedAmount, a.currency)),
      Money.zero(),
    );
    const zero = Money.zero();
    const total =
      event.totalBudgetAmount === null
        ? null
        : Money.fromDb(event.totalBudgetAmount, event.currency);
    const unplanned = total ? total.subtract(planned) : null;
    return {
      eventId: event.id,
      isEditable: event.status === 'PLANNING',
      totalBudget: total ? total.toJSON() : null,
      planned: planned.toJSON(),
      unplanned: unplanned ? unplanned.toJSON() : null,
      isOverPlanned: unplanned ? unplanned.isNegative() : false,
      committed: zero.toJSON(),
      paid: zero.toJSON(),
      expenses: expenses.toJSON(),
      spent: zero.add(expenses).toJSON(),
      remaining: total
        ? total.subtract(zero).subtract(expenses).toJSON()
        : null,
      categories: [...categories, ...archived].map((c) => ({
        categoryId: c.id,
        name: c.name,
        isArchived: !published.has(c.id),
        planned: byCategory.get(c.id)?.toJSON() ?? null,
        committed: zero.toJSON(),
        paid: zero.toJSON(),
        expenses: (expensesBy.get(c.id) ?? zero).toJSON(),
      })),
    };
  }

  /** Locks the owner's PLANNING event (404 / 409 otherwise). */
  async lockEditable(
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
        'This event is no longer being planned, so its budget is read only.',
      );
    }
    return event;
  }

  private async publishedCategory(
    manager: EntityManager,
    categoryId: string,
  ): Promise<void> {
    const category = await manager
      .getRepository(VendorCategoryEntity)
      .findOneBy({ id: categoryId, status: 'PUBLISHED' });
    if (!category) throw notFound();
  }

  private record(
    manager: EntityManager,
    userId: string,
    action: string,
    eventId: string,
    context: RequestContext,
    summary: Record<string, unknown>,
  ): Promise<void> {
    return this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action,
      entityType: 'EVENT',
      entityId: eventId,
      requestId: context.requestId,
      ip: context.ip,
      summary,
    });
  }
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND, HttpStatus.NOT_FOUND);
}
