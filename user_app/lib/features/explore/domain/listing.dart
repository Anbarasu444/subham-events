import '../../../core/error/result.dart';
import '../../../core/money/money.dart';

/// A marketplace category (`GET /vendor-categories`, M11/M12).
class VendorCategory {
  const VendorCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;
}

/// One approved vendor listing as shown in discovery (M12). The starting
/// price is marketplace information only — never a budget figure.
class ListingCard {
  const ListingCard({
    required this.id,
    required this.title,
    required this.category,
    required this.vendorName,
    required this.city,
    required this.serviceAreas,
    required this.startingPrice,
    required this.ratingAverage,
    required this.ratingCount,
    required this.coverImageUrl,
  });

  final String id;
  final String title;
  final VendorCategory category;
  final String vendorName;
  final String city;
  final List<String> serviceAreas;
  final Money startingPrice;

  /// One decimal, e.g. "4.5"; null until rated (M20).
  final String? ratingAverage;
  final int ratingCount;

  /// Null until listing photos exist (M28): the category icon is shown.
  final String? coverImageUrl;
}

enum ListingSort {
  relevance(null, 'Relevance'),
  newest('-publishedAt', 'Newest'),
  priceLowToHigh('startingPrice', 'Price: low to high'),
  priceHighToLow('-startingPrice', 'Price: high to low');

  const ListingSort(this.apiValue, this.label);

  /// Null = the server default (relevance).
  final String? apiValue;
  final String label;
}

/// Discovery filters; all optional and combined.
class ListingQuery {
  const ListingQuery({
    this.categoryId,
    this.city,
    this.text,
    this.minPrice,
    this.maxPrice,
    this.sort = ListingSort.relevance,
  });

  final String? categoryId;
  final String? city;
  final String? text;
  final Money? minPrice;
  final Money? maxPrice;
  final ListingSort sort;

  bool get hasFilters =>
      categoryId != null ||
      city != null ||
      text != null ||
      minPrice != null ||
      maxPrice != null ||
      sort != ListingSort.relevance;

  ListingQuery copyWith({
    String? Function()? categoryId,
    String? Function()? city,
    String? Function()? text,
    Money? Function()? minPrice,
    Money? Function()? maxPrice,
    ListingSort? sort,
  }) => ListingQuery(
    categoryId: categoryId == null ? this.categoryId : categoryId(),
    city: city == null ? this.city : city(),
    text: text == null ? this.text : text(),
    minPrice: minPrice == null ? this.minPrice : minPrice(),
    maxPrice: maxPrice == null ? this.maxPrice : maxPrice(),
    sort: sort ?? this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is ListingQuery &&
      other.categoryId == categoryId &&
      other.city == city &&
      other.text == text &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.sort == sort;

  @override
  int get hashCode =>
      Object.hash(categoryId, city, text, minPrice, maxPrice, sort);
}

/// Vendor phone/email (A10): only sent to signed-in users.
class VendorContact {
  const VendorContact({this.phone, this.email});

  final String? phone;
  final String? email;

  bool get isEmpty => phone == null && email == null;
}

/// The vendor behind a listing (public profile).
class VendorProfile {
  const VendorProfile({
    required this.id,
    required this.businessName,
    required this.description,
    required this.city,
    required this.serviceAreas,
    required this.contact,
  });

  final String id;
  final String businessName;
  final String? description;
  final String city;
  final List<String> serviceAreas;

  /// Null for guests (they are asked to sign in).
  final VendorContact? contact;
}

/// One listing with its vendor (M13 details page).
class ListingDetail {
  const ListingDetail({
    required this.card,
    required this.description,
    required this.vendor,
  });

  final ListingCard card;
  final String? description;
  final VendorProfile vendor;
}

class RelatedListings {
  const RelatedListings({required this.sameVendor, required this.similar});

  final List<ListingCard> sameVendor;
  final List<ListingCard> similar;

  bool get isEmpty => sameVendor.isEmpty && similar.isEmpty;
}

class ListingPage {
  const ListingPage({required this.items, required this.nextCursor});

  final List<ListingCard> items;

  /// Null when there are no more pages.
  final String? nextCursor;
}

/// Public marketplace reads (api-contracts.md Part B, M12). Works for guests.
abstract class DiscoveryRepository {
  Future<Result<List<VendorCategory>>> categories();
  Future<Result<ListingPage>> search(
    ListingQuery query, {
    String? cursor,
    int limit = 20,
  });
  Future<Result<List<String>>> cities();

  /// One visible listing; `NotFoundFailure` when it is no longer listed.
  Future<Result<ListingDetail>> detail(String listingId);
  Future<Result<RelatedListings>> related(String listingId);
}
