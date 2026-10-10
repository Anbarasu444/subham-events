/// Pagination metadata from `meta.page` (api-contracts.md §5, ADR-0013).
sealed class PageMeta {
  const PageMeta();

  static PageMeta? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return switch (json['type']) {
      'cursor' => CursorPageMeta(
        limit: json['limit'] as int,
        nextCursor: json['nextCursor'] as String?,
        hasMore: json['hasMore'] as bool,
      ),
      'offset' => OffsetPageMeta(
        page: json['page'] as int,
        pageSize: json['pageSize'] as int,
        totalItems: json['totalItems'] as int,
        totalPages: json['totalPages'] as int,
      ),
      _ => null,
    };
  }
}

class CursorPageMeta extends PageMeta {
  const CursorPageMeta({
    required this.limit,
    required this.nextCursor,
    required this.hasMore,
  });
  final int limit;

  /// Opaque — never constructed or parsed by the client.
  final String? nextCursor;
  final bool hasMore;
}

class OffsetPageMeta extends PageMeta {
  const OffsetPageMeta({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;
}

/// A decoded success envelope `{ data, meta }`.
class ApiResponse<T> {
  const ApiResponse({required this.data, this.requestId, this.page});

  final T data;
  final String? requestId;
  final PageMeta? page;

  /// Decodes the envelope; [decode] converts the raw `data` value.
  static ApiResponse<T> fromEnvelope<T>(
    Object? body,
    T Function(Object? data) decode,
  ) {
    if (body is! Map<String, dynamic> || !body.containsKey('data')) {
      throw const FormatException('Response is not an API envelope');
    }
    final meta = body['meta'];
    final metaMap = meta is Map<String, dynamic>
        ? meta
        : const <String, dynamic>{};
    return ApiResponse<T>(
      data: decode(body['data']),
      requestId: metaMap['requestId'] as String?,
      page: PageMeta.fromJson(metaMap['page']),
    );
  }
}
