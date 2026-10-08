import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../explore/data/discovery_repository_impl.dart';
import '../domain/wishlist.dart';

class WishlistRepositoryImpl implements WishlistRepository {
  WishlistRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<Set<String>>> ids() async {
    final result = await _api.get(
      '/me/wishlist/ids',
      decode: (json) => (json as List<dynamic>).cast<String>().toSet(),
    );
    return switch (result) {
      Ok(:final value) => Ok(value.data),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<WishlistPage>> list({String? cursor, int limit = 20}) async {
    final result = await _api.get(
      '/me/wishlist',
      query: {'limit': limit, 'cursor': ?cursor},
      decode: (json) => (json as List<dynamic>)
          .map((raw) {
            final map = raw as Map<String, dynamic>;
            return WishlistItem(
              listing: DiscoveryRepositoryImpl.listingFromJson(
                map['listing'] as Map<String, dynamic>,
              ),
              isAvailable: map['isAvailable'] as bool,
              savedAt: DateTime.parse(map['savedAt'] as String),
            );
          })
          .toList(growable: false),
    );
    return switch (result) {
      Ok(:final value) => Ok(
        WishlistPage(
          items: value.data,
          nextCursor: switch (value.page) {
            CursorPageMeta(:final nextCursor, :final hasMore) =>
              hasMore ? nextCursor : null,
            _ => null,
          },
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> save(String listingId) async =>
      _void(await _api.put('/me/wishlist/$listingId', decode: (_) {}));

  @override
  Future<Result<void>> remove(String listingId) async =>
      _void(await _api.delete('/me/wishlist/$listingId', decode: (_) {}));

  Result<void> _void(Result<ApiResponse<void>> result) => switch (result) {
    Ok() => const Ok(null),
    Err(:final failure) => Err(failure),
  };
}
