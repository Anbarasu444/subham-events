import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  Min,
} from 'class-validator';
import type { InvitationStatus } from './invitation.entity';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;
const blankToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() || null : value;

export class SaveInvitationDto {
  @Matches(/^[a-z0-9]+(-[a-z0-9]+)*$/)
  @Length(1, 40)
  templateCode: string;

  @Transform(trim)
  @IsString()
  @Length(1, 120)
  title: string;

  @IsOptional()
  @Transform(blankToNull)
  @IsString()
  @Length(1, 1000)
  message?: string | null;

  @IsOptional()
  @Transform(blankToNull)
  @IsString()
  @Length(1, 200)
  hostNames?: string | null;
}

export class RsvpOpenDto {
  @IsBoolean()
  open: boolean;
}

/** The guest form (application/x-www-form-urlencoded; A6). */
export class GuestRsvpDto {
  @Transform(trim)
  @IsString()
  @Length(1, 80)
  guestName: string;

  @IsIn(['ATTENDING', 'NOT_ATTENDING', 'MAYBE'])
  response: 'ATTENDING' | 'NOT_ATTENDING' | 'MAYBE';

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(20)
  guestCount: number;

  @IsOptional()
  @Transform(blankToNull)
  @IsString()
  @Length(1, 500)
  message?: string | null;
}

export interface InvitationDto {
  id: string;
  eventId: string;
  templateCode: string;
  title: string;
  message: string | null;
  hostNames: string | null;
  eventDate: string;
  startTime: string | null;
  venueName: string | null;
  venueAddress: string | null;
  status: InvitationStatus;
  rsvpOpen: boolean;
  /** RSVPs close the day after the event (§4.14). */
  rsvpClosesOn: string;
  publishedAt: string | null;
  totals: RsvpTotals;
  version: number;
}

export interface RsvpTotals {
  attending: number;
  maybe: number;
  notAttending: number;
  /** Guests of "attending" replies. */
  guests: number;
}

export interface RsvpDto {
  id: string;
  guestName: string;
  response: 'ATTENDING' | 'NOT_ATTENDING' | 'MAYBE';
  guestCount: number;
  message: string | null;
  updatedAt: string;
}
