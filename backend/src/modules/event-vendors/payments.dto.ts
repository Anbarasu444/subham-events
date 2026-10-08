import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
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
import {
  PAYMENT_KINDS,
  PAYMENT_METHODS,
  type PaymentKind,
  type PaymentMethod,
  type PaymentNoteEntity,
} from './payment-note.entity';

/** Most notes per booking. */
export const MAX_PAYMENTS = 100;

const blankToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() || null : value;

@ValidatorConstraint({ name: 'isCalendarDate' })
class IsCalendarDateConstraint implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    return typeof value === 'string' && isCalendarDate(value);
  }
  defaultMessage(): string {
    return 'paidOn must be a valid date YYYY-MM-DD';
  }
}

export class CreatePaymentDto {
  /** Greater than zero (checked in the service). */
  @ValidateNested()
  @Type(() => MoneyDto)
  amount: MoneyDto;

  /** Today or earlier in the event's time zone. */
  @Validate(IsCalendarDateConstraint)
  paidOn: string;

  @IsIn(PAYMENT_METHODS)
  method: PaymentMethod;

  @IsIn(PAYMENT_KINDS)
  kind: PaymentKind;

  @IsOptional()
  @Transform(blankToNull)
  @IsString()
  @Length(1, 1000)
  note?: string | null;
}

/** Partial update; `null` clears the note. */
export class UpdatePaymentDto {
  @ValidateIf((o: UpdatePaymentDto) => o.amount !== undefined)
  @ValidateNested()
  @Type(() => MoneyDto)
  amount?: MoneyDto;

  @ValidateIf((o: UpdatePaymentDto) => o.paidOn !== undefined)
  @Validate(IsCalendarDateConstraint)
  paidOn?: string;

  @ValidateIf((o: UpdatePaymentDto) => o.method !== undefined)
  @IsIn(PAYMENT_METHODS)
  method?: PaymentMethod;

  @ValidateIf((o: UpdatePaymentDto) => o.kind !== undefined)
  @IsIn(PAYMENT_KINDS)
  kind?: PaymentKind;

  @IsOptional()
  @Transform(blankToNull)
  @IsString()
  @Length(1, 1000)
  note?: string | null;

  @IsInt()
  @Min(1)
  version: number;
}

export interface PaymentDto {
  id: string;
  amount: MoneyJson;
  paidOn: string;
  method: PaymentMethod;
  kind: PaymentKind;
  note: string | null;
  version: number;
  createdAt: string;
}

/** A booking's payments with exact totals (R5: records only). */
export interface PaymentListDto {
  bookingId: string;
  bookingStatus: string;
  agreedAmount: MoneyJson;
  paid: MoneyJson;
  /** Agreed − paid; null when overpaid. */
  balance: MoneyJson | null;
  /** Paid − agreed when more was paid than agreed, else null. */
  overpaidBy: MoneyJson | null;
  /** Newest first (paid date, then creation). */
  payments: PaymentDto[];
}

export function toPaymentDto(p: PaymentNoteEntity): PaymentDto {
  return {
    id: p.id,
    amount: Money.fromDb(p.amount, p.currency).toJSON(),
    paidOn: p.paidOn,
    method: p.method,
    kind: p.kind,
    note: p.note,
    version: p.version,
    createdAt: p.createdAt.toISOString(),
  };
}
