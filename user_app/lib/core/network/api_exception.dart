import '../error/failure.dart';

/// Error envelope fields parsed from a non-2xx response
/// (`{ error: { code, message, details, requestId } }`).
class ApiError {
  const ApiError({
    this.code,
    this.message,
    this.details = const [],
    this.requestId,
  });

  /// Parses an error envelope; returns an empty [ApiError] for any other body.
  factory ApiError.fromBody(Object? body) {
    if (body is! Map<String, dynamic>) return const ApiError();
    final error = body['error'];
    if (error is! Map<String, dynamic>) return const ApiError();
    final rawDetails = error['details'];
    return ApiError(
      code: _string(error['code']),
      message: _string(error['message']),
      requestId: _string(error['requestId']),
      details: rawDetails is List
          ? rawDetails
                .whereType<Map<String, dynamic>>()
                .map(
                  (d) => FieldError(
                    field: _string(d['field']),
                    code: _string(d['code']) ?? 'INVALID',
                    message: _string(d['message']) ?? '',
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  final String? code;
  final String? message;
  final List<FieldError> details;
  final String? requestId;

  /// Tolerates bodies from proxies/gateways that do not follow the contract.
  static String? _string(Object? value) => value is String ? value : null;
}
