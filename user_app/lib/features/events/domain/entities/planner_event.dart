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

/// Checklist progress of an event (M9).
class ChecklistSummary {
  const ChecklistSummary({
    required this.total,
    required this.done,
    required this.overdue,
  });

  static const empty = ChecklistSummary(total: 0, done: 0, overdue: 0);

  final int total;
  final int done;
  final int overdue;

  int get pending => total - done;

  /// 0.0–1.0; 0 when the checklist is empty.
  double get progress => total == 0 ? 0 : done / total;

  @override
  bool operator ==(Object other) =>
      other is ChecklistSummary &&
      other.total == total &&
      other.done == done &&
      other.overdue == overdue;

  @override
  int get hashCode => Object.hash(total, done, overdue);
}

/// Signed, resized cover photo URLs (M10). URLs expire ([expiresAt]); images
/// are cached by [mediaId] so a fresh URL still hits the cache.
class EventCover {
  const EventCover({
    required this.mediaId,
    required this.url,
    required this.thumbnailUrl,
    required this.expiresAt,
  });

  final String mediaId;
  final String url;
  final String thumbnailUrl;
  final DateTime expiresAt;
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
    this.checklist = ChecklistSummary.empty,
    this.cover,
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

  /// Checklist progress (M9).
  final ChecklistSummary checklist;

  /// Cover photo (M10), or null.
  final EventCover? cover;

  /// The checklist can be changed only while the event is being planned.
  bool get checklistEditable => status == EventStatus.planning;

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
