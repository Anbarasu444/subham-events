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
import { BudgetService } from './budget.service';
import { EventExpenseEntity } from './event-expense.entity';
import {
  MAX_EXPENSES,
  toExpenseDto,
  type CreateExpenseDto,
  type ExpenseDto,
  type ExpenseListDto,
  type UpdateExpenseDto,
} from './expenses.dto';

/**
 * The owner's own expenses for an event (M11, user answer 5). Same access
 * rules as the budget: owner-only through the event (404), writes need a
 * PLANNING event and lock its row, so the per-event limit never races.
 */
@Injectable()
export class ExpensesService {
  constructor(
    @InjectRepository(EventEntity)
    private readonly events: Repository<EventEntity>,
    private readonly budget: BudgetService,
    private readonly audit: AuditService,
  ) {}

  async list(userId: string, eventId: string): Promise<ExpenseListDto> {
    const event = await this.events.findOneBy({
      id: eventId,
      ownerUserId: userId,
      deletedAt: IsNull(),
    });
    if (!event) throw notFound();
    const rows = await this.events.manager
      .getRepository(EventExpenseEntity)
      .find({
        where: { eventId, deletedAt: IsNull() },
        order: { spentOn: 'DESC', createdAt: 'DESC', id: 'DESC' },
      });
    const names = await this.categoryNames(
      this.events.manager,
      rows.map((r) => r.categoryId),
    );
    return {
      eventId,
      isEditable: event.status === 'PLANNING',
      total: rows
        .reduce(
          (sum, r) => sum.add(Money.fromDb(r.amount, r.currency)),
          Money.zero(),
        )
        .toJSON(),
      expenses: rows.map((r) => toExpenseDto(r, names)),
    };
  }

  async create(
    manager: EntityManager,
    userId: string,
    eventId: string,
    dto: CreateExpenseDto,
    context: RequestContext,
  ): Promise<ExpenseDto> {
    const event = await this.budget.lockEditable(manager, userId, eventId);
    const amount = this.validAmount(dto.amount.toMoney(), event);
    const categoryId = dto.categoryId ?? null;
    if (categoryId) await this.publishedCategory(manager, categoryId);
    const [{ count }] = await manager.query<{ count: number }[]>(
      `SELECT count(*)::int AS count FROM event_expenses
        WHERE event_id = $1 AND deleted_at IS NULL`,
      [eventId],
    );
    if (count >= MAX_EXPENSES) {
      throw new AppException(
        ErrorCode.LIMIT_REACHED,
        HttpStatus.CONFLICT,
        `An event can have at most ${MAX_EXPENSES} expenses.`,
      );
    }
    const repo = manager.getRepository(EventExpenseEntity);
    const saved = await repo.save(
      repo.create({
        id: uuidv7(),
        eventId,
        title: dto.title,
        amount: amount.toString(),
        currency: amount.currency,
        spentOn: dto.spentOn,
        categoryId,
        note: dto.note ?? null,
        deletedAt: null,
      }),
    );
    // Ids only: amounts and the user's text stay out of the audit log.
    await this.record(manager, userId, 'EXPENSE_CREATED', saved.id, context, {
      eventId,
    });
    return toExpenseDto(saved, await this.categoryNames(manager, [categoryId]));
  }

  async update(
    manager: EntityManager,
    userId: string,
    eventId: string,
    expenseId: string,
    dto: UpdateExpenseDto,
    context: RequestContext,
  ): Promise<ExpenseDto> {
    const event = await this.budget.lockEditable(manager, userId, eventId);
    const expense = await this.find(manager, eventId, expenseId);
    if (expense.version !== dto.version) {
      throw new AppException(
        ErrorCode.PRECONDITION_FAILED,
        HttpStatus.PRECONDITION_FAILED,
        'This expense was changed elsewhere. Reload and try again.',
      );
    }
    const changed: string[] = [];
    if (dto.title !== undefined && dto.title !== expense.title) {
      expense.title = dto.title;
      changed.push('title');
    }
    if (dto.amount !== undefined) {
      const amount = this.validAmount(dto.amount.toMoney(), event);
      if (!Money.fromDb(expense.amount, expense.currency).equals(amount)) {
        expense.amount = amount.toString();
        changed.push('amount');
      }
    }
    if (dto.spentOn !== undefined && dto.spentOn !== expense.spentOn) {
      expense.spentOn = dto.spentOn;
      changed.push('spentOn');
    }
    if (dto.categoryId !== undefined && dto.categoryId !== expense.categoryId) {
      // A retired category may stay, but cannot be chosen again.
      if (dto.categoryId) await this.publishedCategory(manager, dto.categoryId);
      expense.categoryId = dto.categoryId;
      changed.push('categoryId');
    }
    if (dto.note !== undefined && dto.note !== expense.note) {
      expense.note = dto.note;
      changed.push('note');
    }
    const saved = changed.length
      ? await manager.getRepository(EventExpenseEntity).save(expense)
      : expense;
    if (changed.length) {
      await this.record(
        manager,
        userId,
        'EXPENSE_UPDATED',
        expenseId,
        context,
        {
          eventId,
          fields: changed,
        },
      );
    }
    return toExpenseDto(
      saved,
      await this.categoryNames(manager, [saved.categoryId]),
    );
  }

  /** Soft delete (R11). */
  async remove(
    manager: EntityManager,
    userId: string,
    eventId: string,
    expenseId: string,
    context: RequestContext,
    now = new Date(),
  ): Promise<void> {
    await this.budget.lockEditable(manager, userId, eventId);
    const expense = await this.find(manager, eventId, expenseId);
    expense.deletedAt = now;
    await manager.getRepository(EventExpenseEntity).save(expense);
    await this.record(manager, userId, 'EXPENSE_DELETED', expenseId, context, {
      eventId,
    });
  }

  private validAmount(amount: Money, event: EventEntity): Money {
    if (amount.currency !== event.currency) {
      throw invalid(
        'amount.currency',
        'CURRENCY_MISMATCH',
        'amount.currency must match the event currency',
      );
    }
    if (amount.isNegative() || amount.equals(Money.zero(amount.currency))) {
      throw invalid(
        'amount',
        'AMOUNT_NOT_POSITIVE',
        'amount must be more than 0.00',
      );
    }
    return amount;
  }

  private async publishedCategory(
    manager: EntityManager,
    categoryId: string,
  ): Promise<void> {
    const found = await manager
      .getRepository(VendorCategoryEntity)
      .existsBy({ id: categoryId, status: 'PUBLISHED' });
    if (!found) {
      throw invalid(
        'categoryId',
        'UNKNOWN_CATEGORY',
        'categoryId must be an offered vendor category',
      );
    }
  }

  private async categoryNames(
    manager: EntityManager,
    ids: (string | null)[],
  ): Promise<Map<string, string>> {
    const unique = [...new Set(ids.filter((id): id is string => !!id))];
    if (unique.length === 0) return new Map();
    const rows = await manager
      .getRepository(VendorCategoryEntity)
      .findBy({ id: In(unique) });
    return new Map(rows.map((c) => [c.id, c.name]));
  }

  private async find(
    manager: EntityManager,
    eventId: string,
    expenseId: string,
  ): Promise<EventExpenseEntity> {
    const expense = await manager
      .getRepository(EventExpenseEntity)
      .findOneBy({ id: expenseId, eventId, deletedAt: IsNull() });
    if (!expense) throw notFound();
    return expense;
  }

  private record(
    manager: EntityManager,
    userId: string,
    action: string,
    expenseId: string,
    context: RequestContext,
    summary: Record<string, unknown>,
  ): Promise<void> {
    return this.audit.record(manager, {
      actorType: 'USER',
      actorId: userId,
      action,
      entityType: 'EVENT_EXPENSE',
      entityId: expenseId,
      requestId: context.requestId,
      ip: context.ip,
      summary,
    });
  }
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
