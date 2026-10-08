import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  Min,
  Validate,
  ValidateIf,
  ValidateNested,
  ValidatorConstraint,
  type ValidatorConstraintInterface,
} from 'class-validator';
import {
  DEFAULT_PAGE_LIMIT,
  MAX_PAGE_LIMIT,
} from '../../common/pagination/cursor';
import { MoneyDto } from '../../common/money/money.dto';
import { Money, type MoneyJson } from '../../common/money/money';
import {
  EVENT_STATUSES,
  type EventEntity,
  type EventStatus,
} from './event.entity';
import { isCalendarDate, isValidTimeZone } from './event-rules';
import type { CoverDto } from '../media/media.dto';
import {
  EMPTY_CHECKLIST_SUMMARY,
  type ChecklistSummaryDto,
} from '../checklist/checklist.dto';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

const TIME_PATTERN = /^([01]\d|2[0-3]):[0-5]\d$/;

@ValidatorConstraint({ name: 'isCalendarDate' })
class IsCalendarDateConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    return typeof value === 'string' && isCalendarDate(value);
  }
  defaultMessage(): string {
    return 'eventDate must be a valid date YYYY-MM-DD';
  }
}

@ValidatorConstraint({ name: 'isTimeZone' })
class IsTimeZoneConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    return typeof value === 'string' && isValidTimeZone(value);
  }
  defaultMessage(): string {
    return 'timeZone must be an IANA time zone, e.g. Asia/Kolkata';
  }
}

/** Fields shared by create and update; `null` clears an optional field. */
class EventFieldsDto {
  @IsOptional()
  @Matches(TIME_PATTERN, { message: 'startTime must be HH:mm (24-hour)' })
  startTime?: string | null;

  /** Defaults to Asia/Kolkata on create; never null. */
  @ValidateIf((o: EventFieldsDto) => o.timeZone !== undefined)
  @Validate(IsTimeZoneConstraint)
  timeZone?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  venueName?: string | null;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @Length(1, 300)
  venueAddress?: string | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100_000)
  guestCountEstimate?: number | null;

  @IsOptional()
  @ValidateNested()
  @Type(() => MoneyDto)
  totalBudget?: MoneyDto | null;
}

export class CreateEventDto extends EventFieldsDto {
  @Transform(trim)
  @IsString()
  @Length(1, 60)
  eventType: string;

  @Transform(trim)
  @IsString()
  @Length(1, 100)
  title: string;

  @Validate(IsCalendarDateConstraint)
  eventDate: string;

  @Transform(trim)
  @IsString()
  @Length(1, 80)
  city: string;
}

/** Partial update; required fields may be omitted but never set to null. */
export class UpdateEventDto extends EventFieldsDto {
  @ValidateIf((o: UpdateEventDto) => o.eventType !== undefined)
  @Transform(trim)
  @IsString()
  @Length(1, 60)
  eventType?: string;

  @ValidateIf((o: UpdateEventDto) => o.title !== undefined)
  @Transform(trim)
  @IsString()
  @Length(1, 100)
  title?: string;

  @ValidateIf((o: UpdateEventDto) => o.eventDate !== undefined)
  @Validate(IsCalendarDateConstraint)
  eventDate?: string;

  @ValidateIf((o: UpdateEventDto) => o.city !== undefined)
  @Transform(trim)
  @IsString()
  @Length(1, 80)
  city?: string;

  /** Version the client last read (optimistic concurrency). */
  @IsInt()
  @Min(1)
  version: number;
}

export class SetCoverDto {
  @IsUUID()
  mediaId: string;
}

export const EVENT_SCOPES = ['all', 'upcoming', 'past'] as const;
export type EventScope = (typeof EVENT_SCOPES)[number];

export class ListEventsQuery {
  /** upcoming = PLANNING and dated today or later; past = everything else. */
  @IsOptional()
  @IsIn(EVENT_SCOPES)
  scope: EventScope = 'all';

  @IsOptional()
  @IsIn(EVENT_STATUSES)
  status?: EventStatus;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MAX_PAGE_LIMIT)
  limit: number = DEFAULT_PAGE_LIMIT;

  @IsOptional()
  @IsString()
  @Length(1, 512)
  cursor?: string;
}

export interface EventDto {
  id: string;
  eventType: string;
  title: string;
  eventDate: string;
  startTime: string | null;
  timeZone: string;
  city: string;
  venueName: string | null;
  venueAddress: string | null;
  guestCountEstimate: number | null;
  totalBudget: MoneyJson | null;
  status: EventStatus;
  /** Checklist progress (M9). */
  checklist: ChecklistSummaryDto;
  /** Signed, resized cover photo URLs (M10), or null. */
  cover: CoverDto | null;
  version: number;
  createdAt: string;
  updatedAt: string;
}

export function toEventDto(
  event: EventEntity,
  checklist: ChecklistSummaryDto = EMPTY_CHECKLIST_SUMMARY,
  cover: CoverDto | null = null,
): EventDto {
  return {
    id: event.id,
    eventType: event.eventType,
    title: event.title,
    eventDate: event.eventDate,
    startTime: event.startTime ? event.startTime.slice(0, 5) : null,
    timeZone: event.timeZone,
    city: event.city,
    venueName: event.venueName,
    venueAddress: event.venueAddress,
    guestCountEstimate: event.guestCountEstimate,
    totalBudget:
      event.totalBudgetAmount === null
        ? null
        : Money.fromDb(event.totalBudgetAmount, event.currency).toJSON(),
    status: event.status,
    checklist,
    cover,
    version: event.version,
    createdAt: event.createdAt.toISOString(),
    updatedAt: event.updatedAt.toISOString(),
  };
}
