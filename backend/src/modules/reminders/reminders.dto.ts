import { Transform, Type } from 'class-transformer';
import {
  IsDate,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
  ValidateIf,
} from 'class-validator';
import type {
  ReminderCancelReason,
  ReminderEntity,
  ReminderStatus,
} from './reminder.entity';

/** Most scheduled reminders per event. */
export const MAX_SCHEDULED_REMINDERS = 200;

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

/** ISO-8601 instant with an offset, e.g. "2026-11-06T12:30:00.000Z". */
const toDate = ({ value }: { value: unknown }) =>
  typeof value === 'string' &&
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?(Z|[+-]\d{2}:\d{2})$/.test(
    value,
  )
    ? new Date(value)
    : value;

export class CreateReminderDto {
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  title: string;

  /** Must be in the future (checked in the service). */
  @Transform(toDate)
  @IsDate({ message: 'remindAt must be an ISO-8601 date-time with an offset' })
  remindAt: Date;

  @IsOptional()
  @IsUUID()
  checklistItemId?: string | null;
}

export class UpdateReminderDto {
  @ValidateIf((o: UpdateReminderDto) => o.title !== undefined)
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  title?: string;

  @ValidateIf((o: UpdateReminderDto) => o.remindAt !== undefined)
  @Transform(toDate)
  @IsDate({ message: 'remindAt must be an ISO-8601 date-time with an offset' })
  remindAt?: Date;

  @IsOptional()
  @IsUUID()
  checklistItemId?: string | null;

  @IsInt()
  @Min(1)
  version: number;
}

export class MyRemindersQuery {
  @IsOptional()
  @IsIn(['upcoming', 'due'])
  scope: 'upcoming' | 'due' = 'upcoming';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit: number = 20;
}

export interface ReminderDto {
  id: string;
  eventId: string;
  eventTitle: string;
  title: string;
  remindAt: string;
  status: ReminderStatus;
  checklistItemId: string | null;
  checklistItemTitle: string | null;
  sentAt: string | null;
  seenAt: string | null;
  cancelReason: ReminderCancelReason | null;
  version: number;
}

export interface EventRemindersDto {
  eventId: string;
  /** False when the event is not PLANNING (read only). */
  isEditable: boolean;
  /** Scheduled, soonest first. */
  upcoming: ReminderDto[];
  /** Sent or cancelled, newest first (at most 50). */
  past: ReminderDto[];
}

export function toReminderDto(
  r: ReminderEntity,
  eventTitle: string,
  itemTitle: string | null,
): ReminderDto {
  return {
    id: r.id,
    eventId: r.eventId,
    eventTitle,
    title: r.title,
    remindAt: r.remindAt.toISOString(),
    status: r.status,
    checklistItemId: r.checklistItemId,
    checklistItemTitle: itemTitle,
    sentAt: r.sentAt ? r.sentAt.toISOString() : null,
    seenAt: r.seenAt ? r.seenAt.toISOString() : null,
    cancelReason: r.cancelReason,
    version: r.version,
  };
}
