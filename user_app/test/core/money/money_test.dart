import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/money/money.dart';

void main() {
  test('parses the API object exactly and round-trips it', () {
    final money = Money.fromJson({'amount': '40000.10', 'currency': 'INR'});
    expect(money.minorUnits, BigInt.from(4000010));
    expect(money.toJson(), {'amount': '40000.10', 'currency': 'INR'});
    expect(Money.parse('0.05', 'INR').amount, '0.05');
  });

  test(
    'rejects numbers, wrong decimals, exponents, negatives and currencies',
    () {
      expect(
        () => Money.fromJson({'amount': 10.1, 'currency': 'INR'}),
        throwsFormatException,
      );
      for (final bad in ['10.1', '10', '1e3', '-1.00', '01.00', '10.100']) {
        expect(
          () => Money.parse(bad, 'INR'),
          throwsFormatException,
          reason: bad,
        );
      }
      expect(() => Money.parse('1.00', 'USD'), throwsFormatException);
    },
  );

  test('formats with Indian grouping', () {
    expect(Money.parse('40000.00', 'INR').format(), '₹40,000');
    expect(Money.parse('125000.50', 'INR').format(), '₹1,25,000.50');
    expect(Money.parse('9999999999.99', 'INR').format(), '₹9,99,99,99,999.99');
    expect(Money.parse('999.00', 'INR').format(), '₹999');
    expect(Money.parse('0.10', 'INR').format(), '₹0.10');
  });

  test('value equality', () {
    expect(Money.parse('10.10', 'INR'), Money.parse('10.10', 'INR'));
  });
}
