import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'crash_reporter.dart';
import 'redaction.dart';

/// Error whose message has been redacted; replaces the original object so
/// raw strings (tokens, phone numbers, URLs) never reach Crashlytics.
class RedactedError implements Exception {
  RedactedError(this.type, this.message);
  final String type;
  final String message;

  @override
  String toString() => '$type: $message';
}

class CrashlyticsReporter implements CrashReporter {
  CrashlyticsReporter(this._crashlytics, [this._also]);

  final FirebaseCrashlytics _crashlytics;
  final CrashReporter? _also;

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    bool fatal = false,
  }) {
    _also?.recordError(error, stack, reason: reason, fatal: fatal);
    _crashlytics.recordError(
      RedactedError(error.runtimeType.toString(), redact(error.toString())),
      stack,
      reason: redact(reason),
      fatal: fatal,
    );
  }

  @override
  void log(String message) {
    _also?.log(message);
    _crashlytics.log(redact(message));
  }
}

/// Forwards to whichever reporter is active (console until Firebase is up).
class SwitchableCrashReporter implements CrashReporter {
  SwitchableCrashReporter(this.delegate);
  CrashReporter delegate;

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    bool fatal = false,
  }) => delegate.recordError(error, stack, reason: reason, fatal: fatal);

  @override
  void log(String message) => delegate.log(message);
}
