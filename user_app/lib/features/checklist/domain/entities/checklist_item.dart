import '../../../events/domain/entities/planner_event.dart';

enum ChecklistStatus {
  pending,
  done;

  static ChecklistStatus fromApi(String value) => switch (value) {
    'PENDING' => pending,
    'DONE' => done,
    _ => throw FormatException('Unknown checklist status', value),
  };
}

/// One task of an event's checklist (M9). [isOverdue] is computed by the
/// server in the event's time zone.
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.title,
    required this.notes,
    required this.dueDate,
    required this.status,
    required this.isOverdue,
    required this.completedAt,
    required this.sortOrder,
    required this.version,
  });

  final String id;
  final String title;
  final String? notes;

  /// Calendar date (local midnight) or null.
  final DateTime? dueDate;
  final ChecklistStatus status;
  final bool isOverdue;

  /// When it was ticked off (UTC instant), null while pending.
  final DateTime? completedAt;
  final int sortOrder;
  final int version;

  bool get isDone => status == ChecklistStatus.done;

  ChecklistItem copyWith({
    ChecklistStatus? status,
    bool? isOverdue,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? sortOrder,
  }) => ChecklistItem(
    id: id,
    title: title,
    notes: notes,
    dueDate: dueDate,
    status: status ?? this.status,
    isOverdue: isOverdue ?? this.isOverdue,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    sortOrder: sortOrder ?? this.sortOrder,
    version: version,
  );
}

/// An event's checklist as shown on the checklist screen.
class Checklist {
  const Checklist({
    required this.eventId,
    required this.isEditable,
    required this.items,
  });

  final String eventId;

  /// False once the event is completed or cancelled (M9 answer 2).
  final bool isEditable;

  /// In the user's order.
  final List<ChecklistItem> items;

  List<ChecklistItem> get pending =>
      items.where((i) => !i.isDone).toList(growable: false);

  /// Most recently completed first.
  List<ChecklistItem> get done =>
      items.where((i) => i.isDone).toList(growable: false)..sort(
        (a, b) => (b.completedAt ?? DateTime(0)).compareTo(
          a.completedAt ?? DateTime(0),
        ),
      );

  /// Counts derived from the items, so optimistic changes show at once.
  ChecklistSummary get summary => ChecklistSummary(
    total: items.length,
    done: items.where((i) => i.isDone).length,
    overdue: items.where((i) => i.isOverdue).length,
  );

  Checklist withItems(List<ChecklistItem> next) =>
      Checklist(eventId: eventId, isEditable: isEditable, items: next);
}

/// Values from the add/edit sheet. For updates, null clears notes/due date.
class ChecklistItemInput {
  const ChecklistItemInput({required this.title, this.notes, this.dueDate});

  final String title;
  final String? notes;
  final DateTime? dueDate;
}
