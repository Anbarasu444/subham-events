import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/app/routes/app_routes.dart';
import 'package:user_app/app/startup/bootstrapper.dart';
import 'package:user_app/app/startup/startup_router.dart';

import '../../helpers/recording_reporter.dart';

void main() {
  late RecordingReporter reporter;
  setUp(() => reporter = RecordingReporter());

  test('runs steps in order and records timings', () async {
    final order = <String>[];
    final result = await Bootstrapper([
      BootstrapStep('a', () async => order.add('a'), critical: true),
      BootstrapStep('b', () async => order.add('b')),
      BootstrapStep('c', () async => order.add('c')),
    ], reporter).run();
    expect(order, ['a', 'b', 'c']);
    expect(result.succeeded, isTrue);
    expect(result.timings.map((t) => t.name), ['a', 'b', 'c']);
    expect(reporter.logs.single, startsWith('Start-up finished'));
  });

  test(
    'a failing non-critical step is reported and start-up continues',
    () async {
      final order = <String>[];
      final result = await Bootstrapper([
        BootstrapStep('version', () async => throw StateError('no plugin')),
        BootstrapStep('next', () async => order.add('next')),
      ], reporter).run();
      expect(result.succeeded, isTrue);
      expect(order, ['next']);
      expect(reporter.errors.single.fatal, isFalse);
      expect(result.timings.first.succeeded, isFalse);
    },
  );

  test('a failing critical step stops start-up', () async {
    final order = <String>[];
    final result = await Bootstrapper([
      BootstrapStep(
        'config',
        () async => throw StateError('no API_BASE_URL'),
        critical: true,
      ),
      BootstrapStep('later', () async => order.add('later')),
    ], reporter).run();
    expect(result.succeeded, isFalse);
    expect(result.failedCriticalStep, 'config');
    expect(order, isEmpty);
    expect(reporter.errors.single.fatal, isTrue);
  });

  test('StartupRouter starts at home until auth and shell exist', () {
    expect(const StartupRouter().initialRoute(), AppRoutes.home);
  });

  test('a hanging step times out instead of stalling start-up', () async {
    final order = <String>[];
    final result = await Bootstrapper([
      BootstrapStep(
        'slow-network',
        () => Completer<void>().future,
        timeout: const Duration(milliseconds: 20),
      ),
      BootstrapStep('next', () async => order.add('next')),
    ], reporter).run();
    expect(result.succeeded, isTrue);
    expect(order, ['next']);
    expect(reporter.errors.single.error, isA<TimeoutException>());
  });
}
