import '../../../../core/error/result.dart';
import '../entities/backend_health.dart';

abstract class HealthRepository {
  Future<Result<BackendHealth>> checkReady();
}
