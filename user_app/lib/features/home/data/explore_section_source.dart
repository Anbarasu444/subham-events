import '../../../core/error/result.dart';
import '../../events/domain/repositories/events_repository.dart';
import '../../explore/domain/listing.dart';
import '../domain/dashboard_section.dart';

class ExploreSectionData {
  const ExploreSectionData({
    required this.categories,
    required this.listings,
    required this.city,
  });

  final List<VendorCategory> categories;
  final List<ListingCard> listings;

  /// The next planning event's city the listings are from, if any.
  final String? city;
}

/// Home "Explore vendors" (M12): categories and a few listings, near the
/// next event's city when signed in (falls back to everywhere). Guests too.
class ExploreSectionSource implements DashboardSectionSource {
  ExploreSectionSource(this._discovery, this._events, {this.count = 3});

  final DiscoveryRepository _discovery;
  final EventsRepository _events;
  final int count;

  @override
  DashboardSectionId get id => DashboardSectionId.explore;

  @override
  bool get requiresSignIn => false;

  /// A new event can change the city.
  @override
  Stream<void>? get changes => _events.changes;

  @override
  Future<Result<SectionData>> load({required bool signedIn}) async {
    final List<VendorCategory> categories;
    switch (await _discovery.categories()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        categories = value;
    }
    String? city;
    if (signedIn) {
      final upcoming = await _events.list(scope: EventScope.upcoming, limit: 1);
      if (upcoming case Ok(:final value) when value.items.isNotEmpty) {
        final c = value.items.first.city.trim();
        city = c.isEmpty ? null : c;
      }
    }
    var page = await _discovery.search(ListingQuery(city: city), limit: count);
    // Nothing in that city yet: show what there is.
    final emptyCity = switch (page) {
      Ok(:final value) => value.items.isEmpty,
      Err() => false,
    };
    if (city != null && emptyCity) {
      city = null;
      page = await _discovery.search(const ListingQuery(), limit: count);
    }
    return switch (page) {
      Err(:final failure) => Err(failure),
      Ok(:final value) when value.items.isEmpty && categories.isEmpty =>
        const Ok(null),
      Ok(:final value) => Ok(
        ExploreSectionData(
          categories: categories,
          listings: value.items,
          city: city,
        ),
      ),
    };
  }
}
