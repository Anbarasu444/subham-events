import 'dart:io';

import 'package:dio/dio.dart';

import '../error/failure.dart';
import 'api_exception.dart';

/// The single place where transport errors become [Failure]s
/// (architecture/flutter.md §4).
Failure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const CancelledFailure();
    case DioExceptionType.badCertificate:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      return _mapResponse(e.response);
    case DioExceptionType.unknown:
      if (e.error is SocketException || e.error is HttpException) {
        return const NetworkFailure();
      }
      if (e.error is FormatException) {
        return const UnknownFailure(code: 'INVALID_RESPONSE');
      }
      return const UnknownFailure();
  }
}

Failure _mapResponse(Response<dynamic>? response) {
  final status = response?.statusCode ?? 0;
  final error = ApiError.fromBody(response?.data);
  final code = error.code;
  final message = error.message;
  final requestId = error.requestId;
  return switch (status) {
    401 => UnauthorizedFailure(
      code: code,
      message: message,
      requestId: requestId,
    ),
    403 => ForbiddenFailure(code: code, message: message, requestId: requestId),
    404 => NotFoundFailure(code: code, message: message, requestId: requestId),
    409 ||
    412 => ConflictFailure(code: code, message: message, requestId: requestId),
    422 => ValidationFailure(
      fieldErrors: error.details,
      code: code,
      message: message,
      requestId: requestId,
    ),
    429 => RateLimitedFailure(
      retryAfter: parseRetryAfter(response?.headers.value('retry-after')),
      code: code,
      message: message,
      requestId: requestId,
    ),
    >= 500 => ServerFailure(
      statusCode: status,
      code: code,
      message: message,
      requestId: requestId,
    ),
    _ => UnknownFailure(code: code, message: message, requestId: requestId),
  };
}

/// Parses `Retry-After` given in seconds; HTTP-date values are ignored.
Duration? parseRetryAfter(String? value) {
  final seconds = int.tryParse(value?.trim() ?? '');
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}
