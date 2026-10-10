import 'package:vendor_app/core/crash/crash_reporter.dart';

class RecordedError {
  RecordedError(this.error, this.reason, {required this.fatal});
  final Object error;
  final String reason;
  final bool fatal;
}

class RecordingReporter implements CrashReporter {
  final errors = <RecordedError>[];
  final logs = <String>[];

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    bool fatal = false,
  }) => errors.add(RecordedError(error, reason, fatal: fatal));

  @override
  void log(String message) => logs.add(message);
}
