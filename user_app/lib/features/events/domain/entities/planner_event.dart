import '../../../../core/money/money.dart';

/// Event lifecycle (domain-model.md §4.6).
enum EventStatus {
  planning,
  completed,
  cancelled;

  static EventStatus fromApi(String value) => switch (value) {
    'PLANNING' => planning,
    'COMPLETED' => completed,
    'CANCELLED' => cancelled,
    _ => throw FormatException('Unknown event status', value),
  };

  String get label => switch (this) {
    planning => 'Planning',
    completed => 'Completed',
    cancelled => 'Cancelled',
  };
}

/// A user's event (M8). [eventDate] is a calendar date (local midnight).
class PlannerEvent {
  const PlannerEvent({
    required this.id,
    required this.eventType,
    required this.title,
    required this.eventDate,
    required this.startTime,
    required this.timeZone,
    required this.city,
    required this.venueName,
    required this.venueAddress,
    required this.guestCountEstimate,
    required this.totalBudget,
    required this.status,
    required this.version,
  });

  final String id;
  final String eventType;
  final String title;
  final DateTime eventDate;

  /// `HH:mm` (24-hour) or null.
  final String? startTime;
  final String timeZone;
  final String city;
  final String? venueName;
  final String? venueAddress;
  final int? guestCountEstimate;
  final Money? totalBudget;
  final EventStatus status;

  /// Server version for optimistic concurrency on edit.
  final int version;

  /// Allowed actions mirror the backend rules; the server stays authoritative.
  bool get canCancel => status == EventStatus.planning;
  bool get canComplete => status == EventStatus.planning;
  bool canReopen(DateTime today) =>
      status != EventStatus.planning && !eventDate.isBefore(today);
}

/// Values entered in the event form. For updates, null clears optional fields.
class EventInput {
  const EventInput({
    required this.eventType,
    required this.title,
    required this.eventDate,
    required this.city,
    this.startTime,
    this.venueName,
    this.venueAddress,
    this.guestCountEstimate,
    this.totalBudget,
  });

  final String eventType;
  final String title;
  final DateTime eventDate;
  final String city;
  final String? startTime;
  final String? venueName;
  final String? venueAddress;
  final int? guestCountEstimate;
  final Money? totalBudget;
}
