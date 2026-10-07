import '../../../../core/utils/date_format.dart';
import '../../domain/entities/checklist_item.dart';

/// JSON mapping for `ChecklistDto` / `ChecklistItemDto` (M9).
abstract final class ChecklistModel {
  static ChecklistItem itemFromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    final due = map['dueDate'] as String?;
    final completed = map['completedAt'] as String?;
    return ChecklistItem(
      id: map['id'] as String,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      dueDate: due == null ? null : parseApiDate(due),
      status: ChecklistStatus.fromApi(map['status'] as String),
      isOverdue: map['isOverdue'] as bool,
      completedAt: completed == null ? null : DateTime.parse(completed),
      sortOrder: map['sortOrder'] as int,
      version: map['version'] as int,
    );
  }

  static Checklist fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return Checklist(
      eventId: map['eventId'] as String,
      isEditable: map['isEditable'] as bool,
      items: (map['items'] as List<dynamic>)
          .map(itemFromJson)
          .toList(growable: false),
    );
  }

  static Map<String, dynamic> createJson(ChecklistItemInput input) => {
    'title': input.title,
    'notes': ?input.notes,
    if (input.dueDate != null) 'dueDate': formatApiDate(input.dueDate!),
  };

  /// Only changed fields (null clears) plus `version`.
  static Map<String, dynamic> updateJson(
    ChecklistItem current,
    ChecklistItemInput input,
  ) => {
    if (input.title != current.title) 'title': input.title,
    if (input.notes != current.notes) 'notes': input.notes,
    if (input.dueDate != current.dueDate)
      'dueDate': input.dueDate == null ? null : formatApiDate(input.dueDate!),
    'version': current.version,
  };
}
