/// Readiness of the backend as reported by `GET /health/ready`.
class BackendHealth {
  const BackendHealth({
    required this.status,
    required this.checks,
    required this.requestId,
    required this.latency,
  });

  final String status;
  final Map<String, String> checks;
  final String? requestId;
  final Duration latency;
}
