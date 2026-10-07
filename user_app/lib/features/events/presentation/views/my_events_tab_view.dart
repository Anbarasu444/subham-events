import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../shell/presentation/controllers/shell_tab.dart';

/// My Events tab. Guests see a sign-in prompt (user decision); event
/// management arrives in M8.
class MyEventsTabView extends StatelessWidget {
  const MyEventsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    return Scaffold(
      appBar: AppBar(title: const Text('My Events')),
      body: Obx(
        () => switch (session.state.value) {
          RestoringSession() => const Center(
            child: CircularProgressIndicator(),
          ),
          GuestSession(message: final reason) => EmptyStateView(
            icon: Icons.event_note_outlined,
            title: 'Plan your events',
            message:
                'Sign in to create events and keep everything in one place.',
            notice: reason,
            action: AppButton(
              label: 'Sign in',
              icon: Icons.login,
              onPressed: () => Get.toNamed<void>(
                AppRoutes.signIn,
                parameters: {'returnTo': AppRoutes.tab(ShellTab.events)},
              ),
            ),
          ),
          ProfilePendingSession() => EmptyStateView(
            icon: Icons.cloud_off_outlined,
            title: 'Couldn’t reach the server',
            message: 'You are still signed in. Try again in a moment.',
            action: AppButton(
              label: 'Try again',
              icon: Icons.refresh,
              onPressed: session.retry,
            ),
          ),
          SignedInSession() => const EmptyStateView(
            icon: Icons.event_available_outlined,
            title: 'No events yet',
            message: 'You will be able to create your first event here soon.',
          ),
        },
      ),
    );
  }
}
