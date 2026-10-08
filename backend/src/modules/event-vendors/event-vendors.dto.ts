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
import type { MoneyJson } from '../../common/money/money';
import type { BookingCancelledBy, BookingStatus } from './booking.entity';

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

export class CancelBookingDto {
  /** Shown to the vendor (A7: reason required). */
  @Transform(trim)
  @IsString()
  @Length(3, 500)
  reason: string;
}

/** EXPIRED is derived (R3); the others are stored. */
export type QuotationStatusDto =
  'SENT' | 'EXPIRED' | 'ACCEPTED' | 'REJECTED' | 'SUPERSEDED' | 'WITHDRAWN';

export interface QuotationDto {
  id: string;
  enquiryId: string;
  status: QuotationStatusDto;
  amount: MoneyJson;
  description: string | null;
  /** The last day it can be accepted (the event date when not set). */
  validUntil: string;
  revisionNo: number;
  createdAt: string;
  respondedAt: string | null;
}

export interface BookingDto {
  id: string;
  status: BookingStatus;
  /** Copied from the accepted quote; never changes. */
  agreedAmount: MoneyJson;
  /** Sum of the user's payment notes on this booking (M16). */
  paid: MoneyJson;
  serviceDate: string;
  cancelledBy: BookingCancelledBy | null;
  cancelReason: string | null;
  completedAt: string | null;
  createdAt: string;
  canCancel: boolean;
  canComplete: boolean;
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
  /** Newest first (all revisions). */
  quotations: QuotationDto[];
  /** The active booking, else the latest cancelled one, else null. */
  booking: BookingDto | null;
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
