import '../../core/crash/crash_reporter.dart';

/// One ordered start-up step. A failing **critical** step stops start-up and
/// shows the start-failure screen; a failing non-critical step is reported and
/// start-up continues (architecture/flutter.md §9).
class BootstrapStep {
  const BootstrapStep(this.name, this.run, {this.critical = false});

  final String name;
  final Future<void> Function() run;
  final bool critical;
}

class StepTiming {
  const StepTiming(this.name, this.elapsed, {required this.succeeded});
  final String name;
  final Duration elapsed;
  final bool succeeded;
}

class BootstrapResult {
  const BootstrapResult({required this.timings, this.failedCriticalStep});

  final List<StepTiming> timings;
  final String? failedCriticalStep;

  bool get succeeded => failedCriticalStep == null;
  Duration get total =>
      timings.fold(Duration.zero, (sum, t) => sum + t.elapsed);
}

class Bootstrapper {
  Bootstrapper(this.steps, this.reporter);

  final List<BootstrapStep> steps;
  final CrashReporter reporter;

  Future<BootstrapResult> run() async {
    final timings = <StepTiming>[];
    for (final step in steps) {
      final watch = Stopwatch()..start();
      try {
        await step.run();
        timings.add(StepTiming(step.name, watch.elapsed, succeeded: true));
      } catch (error, stack) {
        timings.add(StepTiming(step.name, watch.elapsed, succeeded: false));
        reporter.recordError(
          error,
          stack,
          reason: 'Start-up step "${step.name}" failed',
          fatal: step.critical,
        );
        if (step.critical) {
          return BootstrapResult(
            timings: timings,
            failedCriticalStep: step.name,
          );
        }
      }
    }
    reporter.log(
      'Start-up finished: ${timings.map((t) => '${t.name} ${t.elapsed.inMilliseconds}ms').join(', ')}',
    );
    return BootstrapResult(timings: timings);
  }
}
