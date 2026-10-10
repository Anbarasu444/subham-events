import 'dart:developer' as developer;

/// Destination for uncaught and reported errors. M4 logs to the console;
/// M5 adds a Crashlytics implementation (architecture/quality.md §3).
/// Implementations must not include personal data in reports.
abstract class CrashReporter {
  void recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    bool fatal = false,
  });

  void log(String message);
}

class ConsoleCrashReporter implements CrashReporter {
  const ConsoleCrashReporter();

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    bool fatal = false,
  }) {
    developer.log(
      '${fatal ? 'FATAL ' : ''}$reason',
      name: 'crash',
      error: error,
      stackTrace: stack,
      level: fatal ? 1200 : 1000,
    );
  }

  @override
  void log(String message) => developer.log(message, name: 'app');
}
