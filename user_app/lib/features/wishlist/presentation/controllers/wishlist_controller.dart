import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/wishlist.dart';

/// Outcome of tapping a heart.
sealed class SaveOutcome {
  const SaveOutcome();
}

class Saved extends SaveOutcome {
  const Saved();
}

class Unsaved extends SaveOutcome {
  const Unsaved();
}

/// Guests are asked to sign in (M14 answer 4).
class NeedsSignIn extends SaveOutcome {
  const NeedsSignIn();
}

class SaveFailed extends SaveOutcome {
  const SaveFailed(this.failure);
  final Failure failure;
}

/// Which listings the signed-in user saved (heart state everywhere, M14).
/// Kept for the session; cleared on sign-out, reloaded on sign-in.
class WishlistController extends GetxController {
  WishlistController(this._repository, this._session);

  final WishlistRepository _repository;
  final SessionService _session;

  final RxSet<String> savedIds = <String>{}.obs;
  final RxSet<String> busy = <String>{}.obs;

  /// Bumped after every change so the Saved vendors screen reloads.
  final RxInt changes = 0.obs;

  Worker? _sessionWorker;

  /// Bumped by every toggle, so an older id load never overwrites it.
  int _generation = 0;

  @override
  void onInit() {
    super.onInit();
    unawaited(refreshIds());
    _sessionWorker = ever<SessionState>(_session.state, (_) {
      unawaited(refreshIds());
    });
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    super.onClose();
  }

  bool isSaved(String listingId) => savedIds.contains(listingId);

  Future<void> refreshIds() async {
    if (!_session.isSignedIn) {
      savedIds.clear();
      return;
    }
    final generation = ++_generation;
    final result = await _repository.ids();
    if (isClosed || generation != _generation) return;
    if (result case Ok(:final value)) savedIds.assignAll(value);
  }

  /// Optimistic: the heart changes at once and rolls back on failure.
  Future<SaveOutcome> toggle(String listingId) async {
    if (!_session.isSignedIn) return const NeedsSignIn();
    if (busy.contains(listingId)) {
      return isSaved(listingId) ? const Saved() : const Unsaved();
    }
    final save = !isSaved(listingId);
    _generation++;
    busy.add(listingId);
    save ? savedIds.add(listingId) : savedIds.remove(listingId);
    final result = save
        ? await _repository.save(listingId)
        : await _repository.remove(listingId);
    busy.remove(listingId);
    switch (result) {
      case Ok():
        changes.value++;
        return save ? const Saved() : const Unsaved();
      case Err(:final failure):
        save ? savedIds.remove(listingId) : savedIds.add(listingId);
        return SaveFailed(failure);
    }
  }
}
