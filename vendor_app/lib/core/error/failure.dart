/// A user-safe description of why an operation failed. Screens decide what to
/// show from the type; technical detail stays in logs (CLAUDE.md §19).
sealed class Failure {
  const Failure({this.code, this.message, this.requestId});

  /// Stable API error code (api-contracts.md §4), when the server sent one.
  final String? code;

  /// Server-provided safe message, if any.
  final String? message;

  /// Correlates with backend logs for support.
  final String? requestId;

  /// Whether retrying the same request may succeed.
  bool get isRetryable => false;
}

class NetworkFailure extends Failure {
  const NetworkFailure();
  @override
  bool get isRetryable => true;
}

class TimeoutFailure extends Failure {
  const TimeoutFailure();
  @override
  bool get isRetryable => true;
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.code, super.message, super.requestId});
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure({super.code, super.message, super.requestId});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({super.code, super.message, super.requestId});
}

class ConflictFailure extends Failure {
  const ConflictFailure({super.code, super.message, super.requestId});
}

class FieldError {
  const FieldError({this.field, required this.code, required this.message});
  final String? field;
  final String code;
  final String message;
}

class ValidationFailure extends Failure {
  const ValidationFailure({
    this.fieldErrors = const [],
    super.code,
    super.message,
    super.requestId,
  });
  final List<FieldError> fieldErrors;
}

class RateLimitedFailure extends Failure {
  const RateLimitedFailure({
    this.retryAfter,
    super.code,
    super.message,
    super.requestId,
  });
  final Duration? retryAfter;
  @override
  bool get isRetryable => true;
}

class ServerFailure extends Failure {
  const ServerFailure({
    this.statusCode,
    super.code,
    super.message,
    super.requestId,
  });
  final int? statusCode;
  @override
  bool get isRetryable => true;
}

class CancelledFailure extends Failure {
  const CancelledFailure();
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.code, super.message, super.requestId});
  @override
  bool get isRetryable => true;
}
