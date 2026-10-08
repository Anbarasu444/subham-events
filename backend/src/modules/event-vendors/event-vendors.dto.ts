import { Transform } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Min,
  Validate,
  ValidatorConstraint,
  type ValidatorConstraintInterface,
} from 'class-validator';
import type { ListingCardDto } from '../listings/listings.dto';
import { isCalendarDate } from '../events/event-rules';
import type {
  EnquiryClosedBy,
  EnquiryEntity,
  EnquiryStatus,
} from './enquiry.entity';
import type { EventVendorStatus } from './event-vendor.entity';

/** Most vendors (not removed) per event. */
export const MAX_EVENT_VENDORS = 100;

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;
const blankToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() || null : value;

@ValidatorConstraint({ name: 'isCalendarDate' })
class IsCalendarDateConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    return typeof value === 'string' && isCalendarDate(value);
  }
  defaultMessage(): string {
    return 'preferredDate must be a valid date YYYY-MM-DD';
  }
}

export class AddEventVendorDto {
  @IsUUID()
  listingId: string;
}

export class UpdateEventVendorDto {
  /** Private note; null or blank clears it. */
  @IsOptional()
  @Transform(blankToNull)
  @IsString()
  @Length(1, 1000)
  notes?: string | null;

  @IsInt()
  @Min(1)
  version: number;
}

export class CreateEnquiryDto {
  /** 10–1000 characters (M14 answer 3). */
  @Transform(trim)
  @IsString()
  @Length(10, 1000)
  message: string;

  /** Today or later in the event's time zone. */
  @IsOptional()
  @Validate(IsCalendarDateConstraint)
  preferredDate?: string | null;
}

export interface EnquiryDto {
  id: string;
  status: EnquiryStatus;
  message: string;
  preferredDate: string | null;
  closedBy: EnquiryClosedBy | null;
  closedAt: string | null;
  createdAt: string;
}

export interface EventVendorDto {
  id: string;
  status: EventVendorStatus;
  /** Private to the event owner. */
  notes: string | null;
  listing: ListingCardDto;
  /** False when the listing was hidden after it was added. */
  isAvailable: boolean;
  /** Newest first. */
  enquiries: EnquiryDto[];
  /** Whether a new enquiry can be sent now. */
  canEnquire: boolean;
  version: number;
  createdAt: string;
}

export interface EventVendorListDto {
  eventId: string;
  /** False when the event is not PLANNING (read only). */
  isEditable: boolean;
  vendors: EventVendorDto[];
}

export function toEnquiryDto(e: EnquiryEntity): EnquiryDto {
  return {
    id: e.id,
    status: e.status,
    message: e.message,
    preferredDate: e.preferredDate,
    closedBy: e.closedByType,
    closedAt: e.closedAt ? e.closedAt.toISOString() : null,
    createdAt: e.createdAt.toISOString(),
  };
}
