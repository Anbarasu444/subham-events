import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/platform/photo_picker.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/storage/app_cache_manager.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../media/domain/media_repository.dart';
import '../../domain/profile_repository.dart';
import '../controllers/profile_controller.dart';
import 'delete_account_view.dart';
import 'my_reviews_view.dart';

enum _PhotoChoice { gallery, camera, remove }

/// Menu → My profile (M21).
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  bool get _photoEnabled =>
      !Get.isRegistered<AppConfig>() ||
      Get.find<AppConfig>().profilePhotoEnabled;

  void _toast(BuildContext context, String? message) {
    if (message == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveName(BuildContext context, ProfileController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await c.saveName();
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _photo(BuildContext context, ProfileController c) async {
    final hasPhoto = c.profile?.photoMediaId != null;
    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.of(sheet).pop(_PhotoChoice.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheet).pop(_PhotoChoice.camera),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.of(sheet).pop(_PhotoChoice.remove),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final message = switch (choice) {
      _PhotoChoice.gallery => await c.changePhoto(PhotoSource.gallery),
      _PhotoChoice.camera => await c.changePhoto(PhotoSource.camera),
      _PhotoChoice.remove => await c.removePhoto(),
    };
    if (context.mounted) _toast(context, message);
  }

  @override
  Widget build(BuildContext context) => GetBuilder<ProfileController>(
    init: ProfileController(
      Get.find<ProfileRepository>(),
      Get.find<SessionService>(),
      media: Get.isRegistered<MediaRepository>()
          ? Get.find<MediaRepository>()
          : null,
      picker: Get.isRegistered<PhotoPicker>() ? Get.find<PhotoPicker>() : null,
    ),
    global: false,
    builder: (c) => Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: Obx(
        () => AsyncStateView<MeProfile>(
          state: c.state.value,
          onRetry: c.load,
          builder: (context, me) => RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                if (c.state.value case Content(isStale: true))
                  const StaleBanner(),
                if (_photoEnabled) ...[
                  Center(
                    child: _Avatar(
                      profile: me,
                      progress: c.photoProgress.value,
                      busy: c.photoBusy,
                      onTap: () => _photo(context, c),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextField(
                  controller: c.name,
                  maxLength: ProfileController.maxName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveName(context, c),
                  decoration: InputDecoration(
                    labelText: 'Your name',
                    helperText: 'Vendors see this name on your enquiries.',
                    errorText: c.nameError.value,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: 'Save name',
                  icon: Icons.check,
                  variant: AppButtonVariant.secondary,
                  isBusy: c.savingName.value,
                  onPressed: () => _saveName(context, c),
                ),
                const SizedBox(height: AppSpacing.md),
                _ReadOnly(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: me.phone ?? 'Not added',
                ),
                _ReadOnly(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: me.email ?? 'Not added',
                ),
                if (me.createdAt != null)
                  _ReadOnly(
                    icon: Icons.event_available_outlined,
                    label: 'Member since',
                    value: formatLongDate(me.createdAt!),
                  ),
                Text(
                  'Phone and email come from how you sign in.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: AppSpacing.xl),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.star_outline_rounded),
                  title: const Text('My reviews'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MyReviewsView(),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.person_remove_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Delete account',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DeleteAccountView(controller: c),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.profile,
    required this.progress,
    required this.busy,
    required this.onTap,
  });

  final MeProfile profile;
  final double? progress;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = profile.photoThumbnailUrl;
    final initial = profile.label.characters.first.toUpperCase();
    return Semantics(
      button: true,
      label: url == null ? 'Add profile photo' : 'Change profile photo',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundImage: url == null
                  ? null
                  : CachedNetworkImageProvider(
                      url,
                      cacheKey: AppCacheManager.mediaKey(
                        profile.photoMediaId!,
                        'avatar',
                      ),
                      cacheManager: AppCacheManager.instance,
                    ),
              child: Text(initial, style: theme.textTheme.headlineMedium),
            ),
            if (progress != null)
              SizedBox(
                width: 104,
                height: 104,
                child: CircularProgressIndicator(
                  value: progress == 0 ? null : progress,
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 18,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnly extends StatelessWidget {
  const _ReadOnly({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(value),
  );
}
