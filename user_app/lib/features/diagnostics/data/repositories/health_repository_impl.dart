import '../../../../core/error/result.dart';
import '../../domain/entities/backend_health.dart';
import '../../domain/repositories/health_repository.dart';
import '../datasources/health_remote_data_source.dart';

class HealthRepositoryImpl implements HealthRepository {
  HealthRepositoryImpl(this._remote, {Stopwatch Function()? stopwatch})
    : _stopwatch = stopwatch ?? Stopwatch.new;

  final HealthRemoteDataSource _remote;
  final Stopwatch Function() _stopwatch;

  @override
  Future<Result<BackendHealth>> checkReady() async {
    final watch = _stopwatch()..start();
    final result = await _remote.ready();
    watch.stop();
    return switch (result) {
      Ok(:final value) => Ok(
        BackendHealth(
          status: value.data.status,
          checks: value.data.checks,
          requestId: value.requestId,
          latency: watch.elapsed,
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
