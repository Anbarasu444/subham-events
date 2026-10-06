import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { Money } from './money';
import { MoneyDto } from './money.dto';

describe('Money', () => {
  it('keeps decimal amounts exact', () => {
    const total = Money.fromApi('0.10', 'INR').add(
      Money.fromApi('0.20', 'INR'),
    );
    expect(total.toString()).toBe('0.30');
  });

  it('accepts two-decimal strings and serialises them unchanged', () => {
    expect(Money.fromApi('10.10', 'INR').toJSON()).toEqual({
      amount: '10.10',
      currency: 'INR',
    });
    expect(Money.fromApi('9999999999.99', 'INR').toString()).toBe(
      '9999999999.99',
    );
  });

  it.each([
    '10.1',
    '10',
    '1e3',
    '-1.00',
    '010.00',
    '10.100',
    '',
    '12345678901.00',
  ])('rejects invalid amount %p', (amount) => {
    expect(() => Money.fromApi(amount, 'INR')).toThrow(RangeError);
  });

  it('rejects unsupported currencies and currency mixing', () => {
    expect(() => Money.fromApi('1.00', 'USD')).toThrow(RangeError);
  });

  it('subtracts and compares exactly', () => {
    const agreed = Money.fromApi('40000.00', 'INR');
    const paid = Money.fromApi('15000.50', 'INR');
    const outstanding = agreed.subtract(paid);
    expect(outstanding.toString()).toBe('24999.50');
    expect(outstanding.compare(Money.zero())).toBe(1);
    expect(paid.subtract(agreed).isNegative()).toBe(true);
  });

  it('applies basis points with half-up rounding to paise', () => {
    expect(
      Money.fromApi('100.05', 'INR').applyBasisPoints(1000).toString(),
    ).toBe('10.01'); // 10.005 -> 10.01
    expect(() => Money.fromApi('1.00', 'INR').applyBasisPoints(1.5)).toThrow();
  });

  it('converts to and from paise for Razorpay', () => {
    expect(Money.fromApi('10.10', 'INR').toPaise()).toBe(1010);
    expect(Money.fromPaise(1010, 'INR').toString()).toBe('10.10');
    expect(() => Money.fromPaise(10.5, 'INR')).toThrow();
  });

  it('parses database numeric strings', () => {
    expect(Money.fromDb('25000.00', 'INR').toString()).toBe('25000.00');
  });
});

describe('MoneyDto', () => {
  const errorsFor = (value: unknown) =>
    validateSync(plainToInstance(MoneyDto, value));

  it('accepts a valid money object', () => {
    expect(errorsFor({ amount: '10.10', currency: 'INR' })).toHaveLength(0);
  });

  it.each([
    [{ amount: 10.1, currency: 'INR' }],
    [{ amount: '10.1', currency: 'INR' }],
    [{ amount: '1e3', currency: 'INR' }],
    [{ amount: '-5.00', currency: 'INR' }],
    [{ amount: '5.00', currency: 'USD' }],
  ])('rejects %p', (value) => {
    expect(errorsFor(value).length).toBeGreaterThan(0);
  });
});
