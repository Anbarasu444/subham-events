import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';

class HealthDto {
  const HealthDto({required this.status, required this.checks});

  factory HealthDto.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    final checks = (map['checks'] as Map<String, dynamic>?) ?? const {};
    return HealthDto(
      status: map['status'] as String,
      checks: checks.map((k, v) => MapEntry(k, v as String)),
    );
  }

  final String status;
  final Map<String, String> checks;
}

class HealthRemoteDataSource {
  const HealthRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<ApiResponse<HealthDto>>> ready() =>
      _api.get('/health/ready', decode: HealthDto.fromJson);
}
