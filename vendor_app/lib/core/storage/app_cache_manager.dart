import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Image/media cache with bounded size and age (architecture/flutter.md §7).
/// Images are keyed by media id + variant, not by signed URL, so URL rotation
/// does not defeat caching (media-and-deep-links.md §4).
class AppCacheManager extends CacheManager with ImageCacheManager {
  AppCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 14),
          maxNrOfCacheObjects: 400,
        ),
      );

  static const key = 'app_media_cache';
  static final AppCacheManager instance = AppCacheManager._();

  /// Cache key for a media variant, e.g. `mediaId:thumb`.
  static String mediaKey(String mediaId, String variant) => '$mediaId:$variant';
}
