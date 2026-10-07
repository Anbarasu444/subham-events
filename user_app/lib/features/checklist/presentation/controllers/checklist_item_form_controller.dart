import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/request_id.dart';
import '../../domain/entities/checklist_item.dart';
import '../../domain/repositories/checklist_repository.dart';

/// Add or edit one checklist item (title 1–120, notes ≤ 1000, M9 answer 3).
class ChecklistItemFormController extends GetxController {
  ChecklistItemFormController(this._repository, this.eventId, {this.existing});

  final ChecklistRepository _repository;
  final String eventId;
  final ChecklistItem? existing;

  late final title = TextEditingController(text: existing?.title);
  late final notes = TextEditingController(text: existing?.notes);
  late final Rx<DateTime?> dueDate = Rx<DateTime?>(existing?.dueDate);

  final Rx<String?> titleError = Rx<String?>(null);
  final Rx<String?> notesError = Rx<String?>(null);
  final Rx<String?> formError = Rx<String?>(null);
  final RxBool saving = false.obs;

  String _idempotencyKey = generateRequestId();
  ChecklistItemInput? _lastAttempt;

  bool get isEdit => existing != null;

  @override
  void onClose() {
    title.dispose();
    notes.dispose();
    super.onClose();
  }

  Future<ChecklistItem?> submit() async {
    if (saving.value) return null;
    formError.value = null;
    final input = _read();
    if (input == null) return null;
    saving.value = true;
    final result = isEdit
        ? await _repository.update(eventId, existing!, input)
        : await _repository.add(eventId, input, idempotencyKey: _keyFor(input));
    if (isClosed) return null;
    saving.value = false;
    switch (result) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        formError.value = _message(failure);
        return null;
    }
  }

  ChecklistItemInput? _read() {
    final titleText = title.text.trim();
    final notesText = notes.text.trim();
    titleError.value = titleText.isEmpty
        ? 'Enter what needs to be done.'
        : titleText.length > 120
        ? 'Use at most 120 characters.'
        : null;
    notesError.value = notesText.length > 1000
        ? 'Use at most 1000 characters.'
        : null;
    if (titleError.value != null || notesError.value != null) return null;
    return ChecklistItemInput(
      title: titleText,
      notes: notesText.isEmpty ? null : notesText,
      dueDate: dueDate.value,
    );
  }

  /// Same input → same key (a retry never duplicates); changed input → new key.
  String _keyFor(ChecklistItemInput input) {
    final last = _lastAttempt;
    if (last != null &&
        (last.title != input.title ||
            last.notes != input.notes ||
            last.dueDate != input.dueDate)) {
      _idempotencyKey = generateRequestId();
    }
    _lastAttempt = input;
    return _idempotencyKey;
  }

  static String _message(Failure failure) => switch (failure) {
    ConflictFailure(code: 'LIMIT_REACHED') =>
      'This checklist already has 200 items. Remove some to add more.',
    ConflictFailure(code: 'INVALID_STATE_TRANSITION') =>
      'This event is no longer being planned, so its checklist is read only.',
    ConflictFailure() =>
      'This item was changed on another device. Close and open the checklist again.',
    NotFoundFailure() => 'This item no longer exists.',
    ValidationFailure() => 'Please check the title and notes.',
    NetworkFailure() => 'You are offline. Check your connection and try again.',
    TimeoutFailure() => 'The server did not respond in time. Try again.',
    RateLimitedFailure() => 'Too many attempts. Please wait a moment.',
    _ => 'Something went wrong. Please try again.',
  };
}
