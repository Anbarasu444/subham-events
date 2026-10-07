import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Min,
  Validate,
  ValidateIf,
  ValidatorConstraint,
  type ValidatorConstraintInterface,
} from 'class-validator';
import { isCalendarDate } from '../events/event-rules';
import type {
  ChecklistItemEntity,
  ChecklistStatus,
} from './checklist-item.entity';

/** Maximum non-deleted items per event (M9 answer 3). */
export const MAX_CHECKLIST_ITEMS = 200;

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

/** Blank notes mean "no notes" (null), not a validation error. */
const blankToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() || null : value;

@ValidatorConstraint({ name: 'isCalendarDate' })
class IsCalendarDateConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    return typeof value === 'string' && isCalendarDate(value);
  }
  defaultMessage(): string {
    return 'dueDate must be a valid date YYYY-MM-DD';
  }
}

export class CreateChecklistItemDto {
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  title: string;

  @IsOptional()
  @Transform(blankToNull)
  @IsString()
  @Length(1, 1000)
  notes?: string | null;

  /** Any date is allowed: a past due date simply shows as overdue. */
  @IsOptional()
  @Validate(IsCalendarDateConstraint)
  dueDate?: string | null;
}

/** Partial update; `null` clears notes or the due date. */
export class UpdateChecklistItemDto {
  @ValidateIf((o: UpdateChecklistItemDto) => o.title !== undefined)
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  title?: string;

  @IsOptional()
  @Transform(blankToNull)
  @IsString()
  @Length(1, 1000)
  notes?: string | null;

  @IsOptional()
  @Validate(IsCalendarDateConstraint)
  dueDate?: string | null;

  /** Version the client last read (optimistic concurrency). */
  @IsInt()
  @Min(1)
  version: number;
}

export class ReorderChecklistDto {
  /** Every non-deleted item id of the event, in the new order. */
  @IsArray()
  @ArrayMaxSize(MAX_CHECKLIST_ITEMS)
  @ArrayUnique()
  @IsUUID('all', { each: true })
  itemIds: string[];
}

export interface ChecklistSummaryDto {
  total: number;
  done: number;
  overdue: number;
}

export const EMPTY_CHECKLIST_SUMMARY: ChecklistSummaryDto = {
  total: 0,
  done: 0,
  overdue: 0,
};

export interface ChecklistItemDto {
  id: string;
  title: string;
  notes: string | null;
  dueDate: string | null;
  status: ChecklistStatus;
  isOverdue: boolean;
  completedAt: string | null;
  sortOrder: number;
  version: number;
  createdAt: string;
  updatedAt: string;
}

export interface ChecklistDto {
  eventId: string;
  /** False when the event is not PLANNING (M9 answer 2: read only). */
  isEditable: boolean;
  summary: ChecklistSummaryDto;
  items: ChecklistItemDto[];
}

/** [today] is the current date in the event's time zone. */
export function toChecklistItemDto(
  item: ChecklistItemEntity,
  today: string,
): ChecklistItemDto {
  return {
    id: item.id,
    title: item.title,
    notes: item.notes,
    dueDate: item.dueDate,
    status: item.status,
    isOverdue:
      item.status === 'PENDING' &&
      item.dueDate !== null &&
      item.dueDate < today,
    completedAt: item.completedAt ? item.completedAt.toISOString() : null,
    sortOrder: item.sortOrder,
    version: item.version,
    createdAt: item.createdAt.toISOString(),
    updatedAt: item.updatedAt.toISOString(),
  };
}

export function summarize(items: ChecklistItemDto[]): ChecklistSummaryDto {
  return {
    total: items.length,
    done: items.filter((i) => i.status === 'DONE').length,
    overdue: items.filter((i) => i.isOverdue).length,
  };
}
