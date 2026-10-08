import '../../../core/error/result.dart';
import '../../../core/money/money.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/listing.dart';

/// Network-only, except categories and cities, which change rarely and are
/// kept in memory for [_ttl] (the server also sends `max-age=300`).
class DiscoveryRepositoryImpl implements DiscoveryRepository {
  DiscoveryRepositoryImpl(this._api, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _clock;
  static const _ttl = Duration(minutes: 5);

  (DateTime, List<VendorCategory>)? _categories;
  (DateTime, List<String>)? _cities;

  bool _fresh(DateTime? at) => at != null && _clock().difference(at) < _ttl;

  @override
  Future<Result<List<VendorCategory>>> categories() async {
    final cached = _categories;
    if (cached != null && _fresh(cached.$1)) return Ok(cached.$2);
    final result = await _api.get(
      '/vendor-categories',
      decode: (json) => (json as List<dynamic>)
          .map((raw) => categoryFromJson(raw as Map<String, dynamic>))
          .toList(growable: false),
    );
    return switch (result) {
      Ok(:final value) => Ok((_categories = (_clock(), value.data)).$2),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<List<String>>> cities() async {
    final cached = _cities;
    if (cached != null && _fresh(cached.$1)) return Ok(cached.$2);
    final result = await _api.get(
      '/listings/cities',
      decode: (json) =>
          (json as List<dynamic>).cast<String>().toList(growable: false),
    );
    return switch (result) {
      Ok(:final value) => Ok((_cities = (_clock(), value.data)).$2),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<ListingPage>> search(
    ListingQuery query, {
    String? cursor,
    int limit = 20,
  }) async {
    final result = await _api.get(
      '/listings',
      query: {
        if (query.saved) 'saved': 'true',
        'categoryId': ?query.categoryId,
        'city': ?query.city,
        'q': ?query.text,
        'minStartingPrice': ?query.minPrice?.amount,
        'maxStartingPrice': ?query.maxPrice?.amount,
        'sort': ?query.sort.apiValue,
        'limit': limit,
        'cursor': ?cursor,
      },
      decode: (json) => (json as List<dynamic>)
          .map((raw) => listingFromJson(raw as Map<String, dynamic>))
          .toList(growable: false),
    );
    return switch (result) {
      Ok(:final value) => Ok(
        ListingPage(
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
  Future<Result<ListingDetail>> detail(String listingId) async {
    final result = await _api.get(
      '/listings/$listingId',
      decode: (json) => detailFromJson(json as Map<String, dynamic>),
    );
    return switch (result) {
      Ok(:final value) => Ok(value.data),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<RelatedListings>> related(String listingId) async {
    List<ListingCard> cards(Object? list) => (list as List<dynamic>)
        .map((raw) => listingFromJson(raw as Map<String, dynamic>))
        .toList(growable: false);
    final result = await _api.get(
      '/listings/$listingId/related',
      decode: (json) {
        final map = json as Map<String, dynamic>;
        return RelatedListings(
          sameVendor: cards(map['sameVendor']),
          similar: cards(map['similar']),
        );
      },
    );
    return switch (result) {
      Ok(:final value) => Ok(value.data),
      Err(:final failure) => Err(failure),
    };
  }

  static ListingDetail detailFromJson(Map<String, dynamic> json) {
    final vendor = json['vendor'] as Map<String, dynamic>;
    final contact = vendor['contact'] as Map<String, dynamic>?;
    return ListingDetail(
      card: listingFromJson(json),
      description: json['description'] as String?,
      vendor: VendorProfile(
        id: vendor['id'] as String,
        businessName: vendor['businessName'] as String,
        description: vendor['description'] as String?,
        city: vendor['city'] as String,
        serviceAreas: (vendor['serviceAreas'] as List<dynamic>).cast<String>(),
        contact: contact == null
            ? null
            : VendorContact(
                phone: contact['phone'] as String?,
                email: contact['email'] as String?,
              ),
      ),
    );
  }

  static VendorCategory categoryFromJson(Map<String, dynamic> json) =>
      VendorCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
      );

  static ListingCard listingFromJson(Map<String, dynamic> json) {
    final vendor = json['vendor'] as Map<String, dynamic>;
    final rating = json['rating'] as Map<String, dynamic>;
    return ListingCard(
      id: json['id'] as String,
      title: json['title'] as String,
      category: categoryFromJson(json['category'] as Map<String, dynamic>),
      vendorName: vendor['businessName'] as String,
      city: json['city'] as String,
      serviceAreas: (json['serviceAreas'] as List<dynamic>).cast<String>(),
      startingPrice: Money.fromJson(
        json['startingPrice'] as Map<String, dynamic>,
      ),
      ratingAverage: rating['average'] as String?,
      ratingCount: rating['count'] as int,
      coverImageUrl: json['coverImageUrl'] as String?,
    );
  }
}
