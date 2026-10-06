import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

typedef PlatformErrorHandler = bool Function(Object error, StackTrace stack);

/// Routes framework errors and uncaught async/platform errors to [reporter].
/// `PlatformDispatcher.onError` also covers errors that escape zones.
void installErrorHandlers(
  CrashReporter reporter, {
  void Function(PlatformErrorHandler handler)? registerPlatformHandler,
}) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.recordError(
      details.exception,
      details.stack,
      reason: 'Flutter framework error',
      fatal: !details.silent,
    );
  };
  bool onPlatformError(Object error, StackTrace stack) {
    reporter.recordError(error, stack, reason: 'Uncaught error', fatal: true);
    return true;
  }

  (registerPlatformHandler ??
      (handler) =>
          PlatformDispatcher.instance.onError = handler)(onPlatformError);
}
