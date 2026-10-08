import 'package:get/get.dart';
import 'package:user_app/core/auth/session_service.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/error/result.dart';
import 'package:user_app/core/money/money.dart';
import 'package:user_app/features/events/domain/repositories/events_repository.dart';
import 'package:user_app/features/explore/domain/listing.dart';
import 'package:user_app/features/explore/presentation/controllers/explore_controller.dart';

const sampleCategories = [
  VendorCategory(id: 'cat-venue', name: 'Venue', slug: 'venue'),
  VendorCategory(id: 'cat-catering', name: 'Catering', slug: 'catering'),
  VendorCategory(id: 'cat-photo', name: 'Photography', slug: 'photography'),
];

ListingCard sampleListing(
  int n, {
  String title = '',
  String city = 'Chennai',
  List<String> areas = const [],
  VendorCategory category = const VendorCategory(
    id: 'cat-photo',
    name: 'Photography',
    slug: 'photography',
  ),
  String price = '25000.00',
}) => ListingCard(
  id: 'l$n',
  title: title.isEmpty ? 'Listing $n' : title,
  category: category,
  vendorName: 'Vendor $n',
  city: city,
  serviceAreas: areas,
  startingPrice: Money.parse(price, 'INR'),
  ratingAverage: null,
  ratingCount: 0,
  coverImageUrl: null,
);

/// In-memory discovery that filters like the server (enough for widgets).
class FakeDiscoveryRepository implements DiscoveryRepository {
  FakeDiscoveryRepository({
    this.listings = const [],
    this.categoryList = sampleCategories,
    this.cityList = const ['Chennai', 'Coimbatore'],
  });

  List<ListingCard> listings;
  final List<VendorCategory> categoryList;
  final List<String> cityList;
  final List<ListingQuery> queries = [];

  /// Contact details returned by [detail] (null = guest view).
  VendorContact? contact = const VendorContact(
    phone: '+919800000001',
    email: 'vendor@example.invalid',
  );
  Failure? failDetailNext;
  final List<String> detailCalls = [];
  final List<String?> cursors = [];
  Failure? failNext;
  Failure? failCategoriesNext;

  @override
  Future<Result<List<VendorCategory>>> categories() async {
    final failure = failCategoriesNext;
    failCategoriesNext = null;
    return failure == null ? Ok(categoryList) : Err(failure);
  }

  @override
  Future<Result<List<String>>> cities() async => Ok(cityList);

  @override
  Future<Result<ListingDetail>> detail(String listingId) async {
    detailCalls.add(listingId);
    final failure = failDetailNext;
    failDetailNext = null;
    if (failure != null) return Err(failure);
    final card = listings.where((l) => l.id == listingId).firstOrNull;
    if (card == null) return const Err(NotFoundFailure());
    return Ok(
      ListingDetail(
        card: card,
        description: 'About ${card.title}',
        vendor: VendorProfile(
          id: 'v-${card.vendorName}',
          businessName: card.vendorName,
          description: null,
          city: card.city,
          serviceAreas: card.serviceAreas,
          contact: contact,
        ),
      ),
    );
  }

  @override
  Future<Result<RelatedListings>> related(String listingId) async {
    final card = listings.where((l) => l.id == listingId).firstOrNull;
    if (card == null) return const Err(NotFoundFailure());
    final others = listings.where((l) => l.id != listingId);
    return Ok(
      RelatedListings(
        sameVendor: others
            .where((l) => l.vendorName == card.vendorName)
            .take(6)
            .toList(),
        similar: others
            .where(
              (l) =>
                  l.vendorName != card.vendorName &&
                  l.category.id == card.category.id &&
                  l.city == card.city,
            )
            .take(6)
            .toList(),
      ),
    );
  }

  @override
  Future<Result<ListingPage>> search(
    ListingQuery query, {
    String? cursor,
    int limit = 20,
  }) async {
    queries.add(query);
    cursors.add(cursor);
    final failure = failNext;
    failNext = null;
    if (failure != null) return Err(failure);
    final city = query.city?.toLowerCase();
    final text = query.text?.toLowerCase();
    final matches = listings.where((l) {
      if (query.categoryId != null && l.category.id != query.categoryId) {
        return false;
      }
      if (city != null &&
          l.city.toLowerCase() != city &&
          !l.serviceAreas.any((a) => a.toLowerCase() == city)) {
        return false;
      }
      if (text != null &&
          !'${l.title} ${l.vendorName} ${l.category.name}'
              .toLowerCase()
              .contains(text)) {
        return false;
      }
      final paise = l.startingPrice.minorUnits;
      if (query.minPrice != null && paise < query.minPrice!.minorUnits) {
        return false;
      }
      if (query.maxPrice != null && paise > query.maxPrice!.minorUnits) {
        return false;
      }
      return true;
    }).toList();
    switch (query.sort) {
      case ListingSort.priceLowToHigh:
        matches.sort(
          (a, b) =>
              a.startingPrice.minorUnits.compareTo(b.startingPrice.minorUnits),
        );
      case ListingSort.priceHighToLow:
        matches.sort(
          (a, b) =>
              b.startingPrice.minorUnits.compareTo(a.startingPrice.minorUnits),
        );
      case ListingSort.relevance:
      case ListingSort.newest:
        break;
    }
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + limit).clamp(0, matches.length);
    return Ok(
      ListingPage(
        items: matches.sublist(start.clamp(0, matches.length), end),
        nextCursor: end < matches.length ? '$end' : null,
      ),
    );
  }
}

/// Registers discovery and the Explore controller (needs EventsRepository
/// and SessionService already registered).
FakeDiscoveryRepository registerExplore([FakeDiscoveryRepository? repo]) {
  final discovery = repo ?? FakeDiscoveryRepository();
  Get.put<DiscoveryRepository>(discovery);
  Get.put(
    ExploreController(
      discovery,
      Get.find<EventsRepository>(),
      Get.find<SessionService>(),
      searchDelay: Duration.zero,
    ),
  );
  return discovery;
}
