import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Scripted HTTP adapter: each call pops the next response or error.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this._script);

  final List<Object> _script;
  final List<RequestOptions> requests = [];

  static ResponseBody json(
    int status,
    Object body, {
    Map<String, List<String>>? headers,
  }) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?headers,
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final next = _script.removeAt(0);
    if (next is DioExceptionType) {
      throw DioException(requestOptions: options, type: next);
    }
    return next as ResponseBody;
  }

  @override
  void close({bool force = false}) {}
}
