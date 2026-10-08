import '../../../core/error/result.dart';
import '../../explore/domain/listing.dart';

/// A saved listing (M14). [isAvailable] is false when it was hidden later.
class WishlistItem {
  const WishlistItem({
    required this.listing,
    required this.isAvailable,
    required this.savedAt,
  });

  final ListingCard listing;
  final bool isAvailable;
  final DateTime savedAt;
}

class WishlistPage {
  const WishlistPage({required this.items, required this.nextCursor});

  final List<WishlistItem> items;
  final String? nextCursor;
}

/// The signed-in user's saved vendors (api-contracts.md Part B, M14).
abstract class WishlistRepository {
  Future<Result<Set<String>>> ids();
  Future<Result<WishlistPage>> list({String? cursor, int limit = 20});
  Future<Result<void>> save(String listingId);
  Future<Result<void>> remove(String listingId);
}
