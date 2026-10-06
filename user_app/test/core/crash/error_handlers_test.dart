import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/crash/error_handlers.dart';

import '../../helpers/recording_reporter.dart';

void main() {
  test('framework and uncaught platform errors reach the reporter', () {
    final originalFlutterOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalFlutterOnError);

    final reporter = RecordingReporter();
    PlatformErrorHandler? platformHandler;
    installErrorHandlers(
      reporter,
      registerPlatformHandler: (handler) => platformHandler = handler,
    );

    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('build failed'), silent: true),
    );
    final handled = platformHandler!(StateError('async'), StackTrace.empty);

    expect(handled, isTrue);
    expect(reporter.errors.map((e) => e.reason), [
      'Flutter framework error',
      'Uncaught error',
    ]);
    expect(reporter.errors.first.fatal, isFalse);
    expect(reporter.errors.last.fatal, isTrue);
  });
}
