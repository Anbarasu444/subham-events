import { Transform, Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Min,
  Validate,
  ValidateIf,
  ValidateNested,
  ValidatorConstraint,
  type ValidatorConstraintInterface,
} from 'class-validator';
import { Money, type MoneyJson } from '../../common/money/money';
import { MoneyDto } from '../../common/money/money.dto';
import { isCalendarDate } from '../events/event-rules';
import type { EventExpenseEntity } from './event-expense.entity';

/** Maximum non-deleted expenses per event. */
export const MAX_EXPENSES = 500;

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

/** A blank note means "no note" (null), not a validation error. */
const blankToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() || null : value;

@ValidatorConstraint({ name: 'isCalendarDate' })
class IsCalendarDateConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    return typeof value === 'string' && isCalendarDate(value);
  }
  defaultMessage(): string {
    return 'spentOn must be a valid date YYYY-MM-DD';
  }
}

export class CreateExpenseDto {
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  title: string;

  /** Greater than zero (checked in the service). */
  @ValidateNested()
  @Type(() => MoneyDto)
  amount: MoneyDto;

  @Validate(IsCalendarDateConstraint)
  spentOn: string;

  /** A published vendor category, or null for "no category". */
  @IsOptional()
  @IsUUID()
  categoryId?: string | null;

  @IsOptional()
  @Transform(blankToNull)
  @IsString()
  @Length(1, 1000)
  note?: string | null;
}

/** Partial update; `null` clears the category or the note. */
export class UpdateExpenseDto {
  @ValidateIf((o: UpdateExpenseDto) => o.title !== undefined)
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  title?: string;

  @ValidateIf((o: UpdateExpenseDto) => o.amount !== undefined)
  @ValidateNested()
  @Type(() => MoneyDto)
  amount?: MoneyDto;

  @ValidateIf((o: UpdateExpenseDto) => o.spentOn !== undefined)
  @Validate(IsCalendarDateConstraint)
  spentOn?: string;

  @IsOptional()
  @IsUUID()
  categoryId?: string | null;

  @IsOptional()
  @Transform(blankToNull)
  @IsString()
  @Length(1, 1000)
  note?: string | null;

  /** Version the client last read (optimistic concurrency). */
  @IsInt()
  @Min(1)
  version: number;
}

export interface ExpenseDto {
  id: string;
  title: string;
  amount: MoneyJson;
  spentOn: string;
  categoryId: string | null;
  /** The category's name, also when it is no longer offered. */
  categoryName: string | null;
  note: string | null;
  version: number;
  createdAt: string;
  updatedAt: string;
}

export interface ExpenseListDto {
  eventId: string;
  /** False when the event is not PLANNING (read-only, like the budget). */
  isEditable: boolean;
  total: MoneyJson;
  /** Newest first (spent date, then creation). */
  expenses: ExpenseDto[];
}

export function toExpenseDto(
  expense: EventExpenseEntity,
  categoryNames: ReadonlyMap<string, string>,
): ExpenseDto {
  return {
    id: expense.id,
    title: expense.title,
    amount: Money.fromDb(expense.amount, expense.currency).toJSON(),
    spentOn: expense.spentOn,
    categoryId: expense.categoryId,
    categoryName: expense.categoryId
      ? (categoryNames.get(expense.categoryId) ?? null)
      : null,
    note: expense.note,
    version: expense.version,
    createdAt: expense.createdAt.toISOString(),
    updatedAt: expense.updatedAt.toISOString(),
  };
}
