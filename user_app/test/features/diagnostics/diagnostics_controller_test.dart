import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_app/app/config/app_config.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/state/view_state.dart';
import 'package:user_app/features/diagnostics/domain/entities/backend_health.dart';
import 'package:user_app/features/diagnostics/domain/repositories/health_repository.dart';
import 'package:user_app/features/diagnostics/presentation/controllers/diagnostics_controller.dart';

class _MockRepo extends Mock implements HealthRepository {}

const _config = AppConfig(
  flavor: Flavor.staging,
  apiBaseUrl: 'http://localhost:3000',
  appVersion: '1.0.0',
  buildNumber: '1',
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  test('ready backend becomes Content', () async {
    when(() => repo.checkReady()).thenAnswer(
      (_) async => const Ok(
        BackendHealth(
          status: 'ok',
          checks: {'database': 'up'},
          requestId: 'r',
          latency: Duration.zero,
        ),
      ),
    );
    final controller = DiagnosticsController(repo, _config);
    await controller.check();
    expect(controller.state.value, isA<Content<BackendHealth>>());
  });

  test('backend down becomes Error and retry recovers', () async {
    when(() => repo.checkReady()).thenAnswer(
      (_) async => const Err(
        ServerFailure(statusCode: 503, code: 'SERVICE_UNAVAILABLE'),
      ),
    );
    final controller = DiagnosticsController(repo, _config);
    await controller.check();
    final state = controller.state.value as Failed<BackendHealth>;
    expect(state.failure.isRetryable, isTrue);

    when(() => repo.checkReady()).thenAnswer(
      (_) async => const Ok(
        BackendHealth(
          status: 'ok',
          checks: {},
          requestId: null,
          latency: Duration.zero,
        ),
      ),
    );
    await controller.check();
    expect(controller.state.value, isA<Content<BackendHealth>>());
  });
}
