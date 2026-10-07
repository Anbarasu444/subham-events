import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/utils/date_format.dart';

void main() {
  test('parses and formats API dates', () {
    final date = parseApiDate('2026-12-14');
    expect(date, DateTime(2026, 12, 14));
    expect(formatApiDate(date), '2026-12-14');
    expect(() => parseApiDate('2026-02-30'), throwsFormatException);
    expect(() => parseApiDate('14-12-2026'), throwsFormatException);
  });

  test('formats dates, times and relative days for display', () {
    expect(formatLongDate(DateTime(2026, 12, 14)), 'Mon, 14 Dec 2026');
    expect(formatTimeOfDay('18:30'), '6:30 PM');
    expect(formatTimeOfDay('00:05'), '12:05 AM');
    expect(formatTimeOfDay('12:00'), '12:00 PM');
    final today = DateTime(2026, 10, 7);
    expect(daysBetween(today, DateTime(2026, 10, 19)), 12);
    expect(relativeDays(0), 'Today');
    expect(relativeDays(1), 'Tomorrow');
    expect(relativeDays(12), 'In 12 days');
    expect(relativeDays(-3), '3 days ago');
  });
}
