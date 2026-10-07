import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/crash/crash_reporter.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/dashboard_section.dart';

/// Home dashboard: greeting plus independently loaded sections.
class HomeController extends GetxController {
  HomeController(
    this._session,
    this.sources, {
    CrashReporter? reporter,
    DateTime Function()? clock,
  }) : assert(
         sources.map((s) => s.id).toSet().length == sources.length,
         'Dashboard section ids must be unique',
       ),
       _reporter = reporter ?? const ConsoleCrashReporter(),
       _clock = clock ?? DateTime.now,
       _sourceById = {for (final s in sources) s.id: s};

  final SessionService _session;
  final List<DashboardSectionSource> sources;
  final CrashReporter _reporter;
  final DateTime Function() _clock;
  final Map<DashboardSectionId, DashboardSectionSource> _sourceById;

  late final Map<DashboardSectionId, Rx<ViewState<SectionData>>> sections = {
    for (final s in sources) s.id: Rx<ViewState<SectionData>>(const Loading()),
  };

  /// Latest load per section; older results that finish later are dropped.
  final Map<DashboardSectionId, int> _generation = {};

  /// Time used for the greeting; refreshed on reload and app resume.
  late final Rx<DateTime> _now = _clock().obs;

  Worker? _sessionWorker;
  AppLifecycleListener? _lifecycle;
  final List<StreamSubscription<void>> _sourceChanges = [];

  bool get signedIn => _session.state.value is SignedInSession;

  /// Whether the signed-in user has any event (drives the call-to-action
  /// label "Create your first event" vs "Create event").
  bool get hasEvents =>
      sections[DashboardSectionId.upcomingEvent]?.value is Content<SectionData>;

  /// First name when known, otherwise null (generic welcome).
  String? get firstName {
    final state = _session.state.value;
    if (state is! SignedInSession) return null;
    final name = state.profile.displayName?.trim();
    if (name == null || name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).first;
  }

  String get greeting {
    final hour = _now.value.hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final name = firstName;
    return name == null ? part : '$part, $name';
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(refreshAll());
    // Reload only when the user signs in or out, not on profile updates.
    var wasSignedIn = signedIn;
    _sessionWorker = ever<SessionState>(_session.state, (_) {
      if (signedIn == wasSignedIn) return;
      wasSignedIn = signedIn;
      unawaited(refreshAll());
    });
    _lifecycle = AppLifecycleListener(onResume: () => _now.value = _clock());
    for (final source in sources) {
      final changes = source.changes;
      if (changes != null) {
        _sourceChanges.add(
          changes.listen((_) => unawaited(loadSection(source.id))),
        );
      }
    }
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    _lifecycle?.dispose();
    for (final subscription in _sourceChanges) {
      unawaited(subscription.cancel());
    }
    super.onClose();
  }

  /// Loads every section in parallel; each settles on its own.
  Future<void> refreshAll() {
    _now.value = _clock();
    return Future.wait([for (final s in sources) loadSection(s.id)]);
  }

  Future<void> loadSection(DashboardSectionId id) async {
    final source = _sourceById[id];
    final state = sections[id];
    if (source == null || state == null) return;
    final generation = _generation[id] = (_generation[id] ?? 0) + 1;

    // Sections that need an account stay empty for guests without loading.
    if (source.requiresSignIn && !signedIn) {
      state.value = const Empty();
      return;
    }

    // Keep what is shown during a refresh; only first loads and retries
    // after an error show the skeleton.
    state.value = switch (state.value) {
      Content(:final data) => Content(data, isStale: true),
      Empty() => const Empty(),
      _ => const Loading(),
    };

    ViewState<SectionData> next;
    try {
      final result = await source.load(signedIn: signedIn);
      next = switch (result) {
        Ok(:final value) => value == null ? const Empty() : Content(value),
        Err(:final failure) => Failed(failure),
      };
    } catch (error, stack) {
      // A crashing section must never break the dashboard.
      _reporter.recordError(error, stack, reason: 'Dashboard section $id');
      next = const Failed(UnknownFailure());
    }
    if (isClosed || generation != _generation[id]) return;
    state.value = next;
  }
}
