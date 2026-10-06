import Decimal from 'decimal.js';

/** Currencies accepted at launch (ADR-0014). */
export const SUPPORTED_CURRENCIES = ['INR'] as const;
export type Currency = (typeof SUPPORTED_CURRENCIES)[number];

/** Rupees with exactly two decimals, max numeric(12,2): 10 integer digits. */
export const MONEY_AMOUNT_PATTERN = /^(0|[1-9]\d{0,9})\.\d{2}$/;

export interface MoneyJson {
  amount: string;
  currency: Currency;
}

const Dec = Decimal.clone({ precision: 40, rounding: Decimal.ROUND_HALF_UP });

/**
 * Exact decimal money in rupees (ADR-0014). Never use JS `number` arithmetic
 * for amounts; convert to paise only at the Razorpay boundary.
 */
export class Money {
  private constructor(
    private readonly value: Decimal,
    readonly currency: Currency,
  ) {}

  /** Parses an API amount string such as "10.10"; rejects anything else. */
  static fromApi(amount: string, currency: string): Money {
    if (!MONEY_AMOUNT_PATTERN.test(amount)) {
      throw new RangeError(`Invalid money amount: ${amount}`);
    }
    return new Money(new Dec(amount), Money.assertCurrency(currency));
  }

  /** Parses a PostgreSQL numeric(12,2) value (TypeORM returns strings). */
  static fromDb(amount: string, currency: string): Money {
    return new Money(
      new Dec(amount).toDecimalPlaces(2),
      Money.assertCurrency(currency),
    );
  }

  static zero(currency: Currency = 'INR'): Money {
    return new Money(new Dec(0), currency);
  }

  private static assertCurrency(currency: string): Currency {
    if (!(SUPPORTED_CURRENCIES as readonly string[]).includes(currency)) {
      throw new RangeError(`Unsupported currency: ${currency}`);
    }
    return currency as Currency;
  }

  add(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.value.plus(other.value), this.currency);
  }

  subtract(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.value.minus(other.value), this.currency);
  }

  /** Applies a rate in basis points (1 bps = 0.01 %), rounding half-up to paise. */
  applyBasisPoints(bps: number): Money {
    if (!Number.isInteger(bps)) {
      throw new RangeError('Basis points must be an integer');
    }
    return new Money(
      this.value.times(bps).dividedBy(10_000).toDecimalPlaces(2),
      this.currency,
    );
  }

  isNegative(): boolean {
    return this.value.isNegative() && !this.value.isZero();
  }

  compare(other: Money): -1 | 0 | 1 {
    this.assertSameCurrency(other);
    return this.value.comparedTo(other.value) as -1 | 0 | 1;
  }

  equals(other: Money): boolean {
    return this.currency === other.currency && this.value.equals(other.value);
  }

  /** Integer paise for Razorpay; throws if the amount is not a whole number of paise. */
  toPaise(): number {
    const paise = this.value.times(100);
    if (!paise.isInteger()) {
      throw new RangeError('Amount is not a whole number of paise');
    }
    return paise.toNumber();
  }

  static fromPaise(paise: number, currency: string): Money {
    if (!Number.isSafeInteger(paise)) {
      throw new RangeError('Paise must be a safe integer');
    }
    return new Money(
      new Dec(paise).dividedBy(100),
      Money.assertCurrency(currency),
    );
  }

  /** Two-decimal string for the API and for numeric(12,2) columns. */
  toString(): string {
    return this.value.toFixed(2);
  }

  toJSON(): MoneyJson {
    return { amount: this.toString(), currency: this.currency };
  }

  private assertSameCurrency(other: Money): void {
    if (other.currency !== this.currency) {
      throw new RangeError('Currency mismatch');
    }
  }
}
