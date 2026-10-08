import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../controllers/wishlist_controller.dart';

/// Heart toggle for a listing (M14). Guests get a sign-in prompt.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.listingId, required this.name});

  final String listingId;

  /// For the screen-reader label, e.g. the listing title.
  final String name;

  static Future<void> toggle(BuildContext context, String listingId) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await Get.find<WishlistController>().toggle(listingId);
    switch (outcome) {
      case NeedsSignIn():
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Sign in to save vendors.'),
              action: SnackBarAction(label: 'Sign in', onPressed: _signIn),
            ),
          );
      case SaveFailed(:final failure):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(switch (failure) {
                ConflictFailure(code: 'LIMIT_REACHED') =>
                  'You can save at most 500 vendors. Remove some first.',
                NotFoundFailure() => 'This vendor is no longer listed.',
                _ =>
                  '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
              }),
            ),
          );
      case Saved() || Unsaved():
        break;
    }
  }

  static void _signIn() {
    final tab = Get.isRegistered<ShellController>()
        ? Get.find<ShellController>().current.value
        : null;
    Get.toNamed<void>(
      AppRoutes.signIn,
      parameters: {if (tab != null) 'returnTo': AppRoutes.tab(tab)},
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WishlistController>();
    return Obx(() {
      final saved = controller.isSaved(listingId);
      return IconButton(
        tooltip: saved ? 'Remove $name from saved' : 'Save $name',
        isSelected: saved,
        icon: const Icon(Icons.favorite_border),
        selectedIcon: Icon(
          Icons.favorite,
          color: Theme.of(context).colorScheme.error,
        ),
        onPressed: controller.busy.contains(listingId)
            ? null
            : () => toggle(context, listingId),
      );
    });
  }
}
