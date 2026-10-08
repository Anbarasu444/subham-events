import '../../../../core/money/money.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/entities/planner_event.dart';

/// JSON mapping for `EventDto` (api-contracts.md Part B, M8).
abstract final class EventModel {
  static PlannerEvent fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    final budget = map['totalBudget'];
    return PlannerEvent(
      id: map['id'] as String,
      eventType: map['eventType'] as String,
      title: map['title'] as String,
      eventDate: parseApiDate(map['eventDate'] as String),
      startTime: map['startTime'] as String?,
      timeZone: map['timeZone'] as String,
      city: map['city'] as String,
      venueName: map['venueName'] as String?,
      venueAddress: map['venueAddress'] as String?,
      guestCountEstimate: map['guestCountEstimate'] as int?,
      totalBudget: budget == null
          ? null
          : Money.fromJson(budget as Map<String, dynamic>),
      status: EventStatus.fromApi(map['status'] as String),
      version: map['version'] as int,
      checklist: checklistSummaryFromJson(map['checklist']),
      cover: coverFromJson(map['cover']),
    );
  }

  static EventCover? coverFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return EventCover(
      mediaId: json['mediaId'] as String,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  /// `{ total, done, overdue }`; absent → empty (older responses).
  static ChecklistSummary checklistSummaryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return ChecklistSummary.empty;
    return ChecklistSummary(
      total: json['total'] as int,
      done: json['done'] as int,
      overdue: json['overdue'] as int,
    );
  }

  static List<PlannerEvent> listFromJson(Object? json) =>
      (json as List<dynamic>).map(fromJson).toList(growable: false);

  /// Create body: optional fields are omitted when empty.
  static Map<String, dynamic> createJson(EventInput input) => {
    'eventType': input.eventType,
    'title': input.title,
    'eventDate': formatApiDate(input.eventDate),
    'city': input.city,
    'startTime': ?input.startTime,
    'venueName': ?input.venueName,
    'venueAddress': ?input.venueAddress,
    'guestCountEstimate': ?input.guestCountEstimate,
    if (input.totalBudget != null) 'totalBudget': input.totalBudget!.toJson(),
  };

  /// PATCH body with only the changed fields (null clears) plus `version`.
  static Map<String, dynamic> updateJson(
    PlannerEvent current,
    EventInput input,
  ) => {
    if (input.eventType != current.eventType) 'eventType': input.eventType,
    if (input.title != current.title) 'title': input.title,
    if (input.eventDate != current.eventDate)
      'eventDate': formatApiDate(input.eventDate),
    if (input.city != current.city) 'city': input.city,
    if (input.startTime != current.startTime) 'startTime': input.startTime,
    if (input.venueName != current.venueName) 'venueName': input.venueName,
    if (input.venueAddress != current.venueAddress)
      'venueAddress': input.venueAddress,
    if (input.guestCountEstimate != current.guestCountEstimate)
      'guestCountEstimate': input.guestCountEstimate,
    if (input.totalBudget != current.totalBudget)
      'totalBudget': input.totalBudget?.toJson(),
    'version': current.version,
  };
}
