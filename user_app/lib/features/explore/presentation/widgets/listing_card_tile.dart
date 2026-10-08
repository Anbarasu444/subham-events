import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/listing.dart';
import '../views/listing_detail_view.dart';
import 'category_icon.dart';

/// A listing in discovery: category icon (no photos before M28), title,
/// vendor, city and the "Starting from" price (marketplace info only).
class ListingCardTile extends StatelessWidget {
  const ListingCardTile({super.key, required this.listing, this.onTap});

  final ListingCard listing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final place = listing.serviceAreas.isEmpty
        ? listing.city
        : '${listing.city} · also ${listing.serviceAreas.join(', ')}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: InkWell(
          onTap: onTap ?? () => ListingNavigation.open(context, listing),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: const BorderRadius.all(AppRadii.md),
                    ),
                    child: Icon(
                      categoryIcon(listing.category.slug),
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '${listing.vendorName} · ${listing.category.name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        place,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Starting from ${listing.startingPrice.format()}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                          if (listing.ratingAverage != null)
                            Text(
                              '★ ${listing.ratingAverage} (${listing.ratingCount})',
                              semanticsLabel:
                                  'Rated ${listing.ratingAverage} from '
                                  '${listing.ratingCount} reviews',
                              style: theme.textTheme.labelMedium,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
