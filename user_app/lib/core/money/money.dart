/// Money as exact decimal rupees (ADR-0014): the API sends
/// `{ "amount": "40000.10", "currency": "INR" }`. Amounts stay strings and
/// whole paise (`BigInt`) — never `double`.
class Money {
  Money._(this.minorUnits, this.currency);

  /// Parses the API object; throws [FormatException] for anything else.
  factory Money.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    final currency = json['currency'];
    if (amount is! String || currency is! String) {
      throw const FormatException('Money must be {amount: String, currency}');
    }
    return Money.parse(amount, currency);
  }

  factory Money.parse(String amount, String currency) {
    if (!_pattern.hasMatch(amount)) {
      throw FormatException('Invalid money amount', amount);
    }
    if (!supportedCurrencies.contains(currency)) {
      throw FormatException('Unsupported currency', currency);
    }
    return Money._(BigInt.parse(amount.replaceFirst('.', '')), currency);
  }

  static const supportedCurrencies = {'INR'};
  static final RegExp _pattern = RegExp(r'^(0|[1-9]\d{0,9})\.\d{2}$');

  /// Amount in paise.
  final BigInt minorUnits;
  final String currency;

  /// Two-decimal API string, e.g. `"10.10"`.
  String get amount {
    final digits = minorUnits.toString().padLeft(3, '0');
    final split = digits.length - 2;
    return '${digits.substring(0, split)}.${digits.substring(split)}';
  }

  Map<String, dynamic> toJson() => {'amount': amount, 'currency': currency};

  /// Display text with Indian digit grouping: `₹40,000` for whole rupees,
  /// `₹1,25,000.50` otherwise.
  String format() {
    final rupees = minorUnits ~/ BigInt.from(100);
    final paise = (minorUnits % BigInt.from(100)).toInt();
    final grouped = _indianGrouping(rupees.toString());
    final fraction = paise == 0 ? '' : '.${paise.toString().padLeft(2, '0')}';
    return '${_symbol(currency)}$grouped$fraction';
  }

  static String _symbol(String currency) =>
      currency == 'INR' ? '₹' : '$currency ';

  static String _indianGrouping(String digits) {
    if (digits.length <= 3) return digits;
    final lastThree = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$lastThree';
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money($amount $currency)';
}
