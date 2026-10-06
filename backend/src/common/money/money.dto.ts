import { IsIn, IsString, Matches } from 'class-validator';
import {
  type Currency,
  Money,
  MONEY_AMOUNT_PATTERN,
  SUPPORTED_CURRENCIES,
} from './money';

/**
 * Request DTO for money values: `{ "amount": "10.10", "currency": "INR" }`.
 * Use with `@ValidateNested() @Type(() => MoneyDto)` on the parent property.
 */
export class MoneyDto {
  @IsString()
  @Matches(MONEY_AMOUNT_PATTERN, {
    message:
      'amount must be a decimal string with exactly 2 decimals, e.g. "10.10"',
  })
  amount: string;

  @IsIn(SUPPORTED_CURRENCIES)
  currency: Currency;

  toMoney(): Money {
    return Money.fromApi(this.amount, this.currency);
  }
}
