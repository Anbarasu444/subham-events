import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/invitation.dart';

/// What the invitation card shows: the catalogue, the invitation (if any)
/// and this phone's copy of its link.
class InvitationState {
  const InvitationState({
    required this.templates,
    required this.invitation,
    required this.link,
  });

  final List<InvitationTemplate> templates;
  final Invitation? invitation;

  /// Null when this phone doesn't know the link (published elsewhere).
  final String? link;

  InvitationTemplate templateFor(String code) => templates.firstWhere(
    (t) => t.code == code,
    orElse: () => templates.first,
  );
}

/// An event's invitation (M19): load, save, publish, link, replies, revoke.
class InvitationController extends GetxController {
  InvitationController(this._repository, this.eventId);

  final InvitationsRepository _repository;
  final String eventId;

  final Rx<ViewState<InvitationState>> state = Rx<ViewState<InvitationState>>(
    const Loading(),
  );
  final RxBool busy = false.obs;

  InvitationState? get current => switch (state.value) {
    Content(:final data) => data,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    if (current == null) state.value = const Loading();
    final templates = await _repository.templates();
    final invitation = await _repository.get(eventId);
    if (isClosed) return;
    switch ((templates, invitation)) {
      case (Ok(value: final t), Ok(value: final inv)):
        final link = inv == null ? null : await _repository.savedLink(inv.id);
        if (isClosed) return;
        state.value = Content(
          InvitationState(templates: t, invitation: inv, link: link),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        state.value = current != null && failure.isRetryable
            ? Content(current!, isStale: true)
            : Failed(failure);
    }
  }

  void _apply(Invitation invitation, {String? link}) {
    final now = current;
    if (now == null) return;
    state.value = Content(
      InvitationState(
        templates: now.templates,
        invitation: invitation,
        // A revoked or unpublished invitation has no working link.
        link: invitation.status == InvitationStatus.published
            ? (link ?? now.link)
            : null,
      ),
    );
  }

  Future<Failure?> _run<T>(
    Future<Result<T>> Function() request,
    void Function(T value) onOk,
  ) async {
    if (busy.value) return null;
    busy.value = true;
    try {
      final result = await request();
      if (isClosed) return null;
      switch (result) {
        case Ok(:final value):
          onOk(value);
          return null;
        case Err(:final failure):
          if (failure is ConflictFailure || failure is NotFoundFailure) {
            unawaited(load());
          }
          return failure;
      }
    } finally {
      busy.value = false;
    }
  }

  Future<Failure?> save(InvitationInput input) =>
      _run(() => _repository.save(eventId, input), _apply);

  Future<Failure?> publish() => _run(
    () => _repository.publish(eventId),
    (p) => _apply(p.invitation, link: p.link),
  );

  Future<Failure?> newLink() => _run(
    () => _repository.newLink(eventId),
    (p) => _apply(p.invitation, link: p.link),
  );

  Future<Failure?> setRsvpOpen(bool open) =>
      _run(() => _repository.setRsvpOpen(eventId, open), _apply);

  Future<Failure?> revoke() => _run(() => _repository.revoke(eventId), _apply);
}
