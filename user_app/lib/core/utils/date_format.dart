/// Calendar-date helpers for API dates (`YYYY-MM-DD`, api-contracts.md §7).
/// Dates are plain local [DateTime]s at midnight — no time zone conversion.
library;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Parses `2026-12-14`; throws [FormatException] otherwise.
DateTime parseApiDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) throw FormatException('Invalid date', value);
  final date = DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  if (formatApiDate(date) != value) {
    throw FormatException('Invalid date', value);
  }
  return date;
}

String formatApiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// `Sat, 14 Dec 2026`.
String formatLongDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]} '
    '${date.year}';

/// `18:30` → `6:30 PM`; returns the input unchanged if it is not `HH:mm`.
String formatTimeOfDay(String hhmm) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(hhmm);
  if (match == null) return hhmm;
  final hour = int.parse(match.group(1)!);
  final minute = match.group(2)!;
  final suffix = hour < 12 ? 'AM' : 'PM';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12:$minute $suffix';
}

/// Whole days from [today] to [date] (negative when past).
int daysBetween(DateTime today, DateTime date) => DateTime.utc(
  date.year,
  date.month,
  date.day,
).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

/// `Today`, `Tomorrow`, `In 12 days`, `3 days ago`.
String relativeDays(int days) => switch (days) {
  0 => 'Today',
  1 => 'Tomorrow',
  -1 => 'Yesterday',
  > 1 => 'In $days days',
  _ => '${-days} days ago',
};
