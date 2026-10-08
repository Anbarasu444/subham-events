import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/session_message.dart';
import '../../../shell/presentation/controllers/shell_tab.dart';
import '../../../budget/presentation/views/budget_view.dart';
import '../../../checklist/presentation/checklist_navigation.dart';
import '../../../checklist/presentation/widgets/checklist_progress.dart';
import '../../../events/presentation/views/planning_event_picker_view.dart';
import 'coming_soon_view.dart';

/// One Menu entry (M6 user decision). [guestVisible] entries are shown to
/// guests; the rest need a signed-in user. Entries without a [page] open a
/// "Coming soon" placeholder until their milestone builds them.
class MenuEntry {
  const MenuEntry(
    this.title,
    this.icon, {
    this.guestVisible = false,
    this.page,
  });
  final String title;
  final IconData icon;
  final bool guestVisible;
  final WidgetBuilder? page;
}

class MenuSection {
  const MenuSection(this.title, this.entries);
  final String title;
  final List<MenuEntry> entries;
}

Widget _checklistPage(BuildContext _) => PlanningEventPickerView(
  title: 'Checklist',
  icon: Icons.checklist_outlined,
  emptyMessage: 'Create an event to start its checklist.',
  routeFor: (event) =>
      ChecklistNavigation.route(eventId: event.id, eventTitle: event.title),
  detailBuilder: (event) => ChecklistProgress(summary: event.checklist),
);

Widget _budgetPage(BuildContext _) => PlanningEventPickerView(
  title: 'Budget',
  icon: Icons.account_balance_wallet_outlined,
  emptyMessage: 'Create an event to plan its budget.',
  routeFor: (event) =>
      BudgetNavigation.route(eventId: event.id, eventTitle: event.title),
  detailBuilder: (event) =>
      Text('Total budget: ${event.totalBudget?.format() ?? 'not set'}'),
);

const menuSections = [
  MenuSection('Planning', [
    MenuEntry('Schedule', Icons.schedule_outlined),
    MenuEntry('Checklist', Icons.checklist_outlined, page: _checklistPage),
    MenuEntry(
      'Budget',
      Icons.account_balance_wallet_outlined,
      page: _budgetPage,
    ),
    MenuEntry('Messages', Icons.chat_bubble_outline),
  ]),
  MenuSection('Account', [
    MenuEntry('My profile', Icons.person_outline),
    MenuEntry('Settings', Icons.settings_outlined, guestVisible: true),
    MenuEntry('Help', Icons.help_outline, guestVisible: true),
  ]),
];

class MenuTabView extends StatefulWidget {
  const MenuTabView({super.key});

  @override
  State<MenuTabView> createState() => _MenuTabViewState();
}

class _MenuTabViewState extends State<MenuTabView> {
  final SessionService _session = Get.find<SessionService>();
  final AppConfig _config = Get.find<AppConfig>();
  bool _signingOut = false;

  void _open(MenuEntry entry) {
    // Pushed on the Menu tab's own navigator, so the bottom bar stays.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            entry.page ??
            (_) => ComingSoonView(title: entry.title, icon: entry.icon),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign in again at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await _session.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t sign out. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: Obx(() {
        final state = _session.state.value;
        if (state is RestoringSession) {
          return const Center(child: CircularProgressIndicator());
        }
        // Pending profile = still signed in (server unreachable).
        final signedIn =
            state is SignedInSession || state is ProfilePendingSession;
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: switch (state) {
                SignedInSession(:final profile) => _SignedInHeader(profile),
                ProfilePendingSession() => _PendingHeader(
                  onRetry: _session.retry,
                ),
                GuestSession(:final message) => _GuestHeader(message: message),
                RestoringSession() => const SizedBox.shrink(),
              },
            ),
            for (final section in menuSections)
              ..._sectionTiles(context, section, signedIn: signedIn),
            if (_config.enableDiagnostics) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const Text('Diagnostics'),
                subtitle: const Text('Staging builds only'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed<void>(AppRoutes.diagnostics),
              ),
            ],
            if (signedIn) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: AppButton(
                  label: 'Sign out',
                  icon: Icons.logout,
                  variant: AppButtonVariant.secondary,
                  isBusy: _signingOut,
                  onPressed: _confirmSignOut,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  List<Widget> _sectionTiles(
    BuildContext context,
    MenuSection section, {
    required bool signedIn,
  }) {
    final visible = [
      for (final entry in section.entries)
        if (signedIn || entry.guestVisible) entry,
    ];
    if (visible.isEmpty) return const [];
    return [
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.xxs,
        ),
        child: Semantics(
          header: true,
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
      for (final entry in visible)
        ListTile(
          leading: Icon(entry.icon),
          title: Text(entry.title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(entry),
        ),
    ];
  }
}

class _SignedInHeader extends StatelessWidget {
  const _SignedInHeader(this.profile);
  final MeProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Signed in as', style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(profile.label, style: theme.textTheme.titleLarge),
        if (profile.phone != null && profile.label != profile.phone) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(profile.phone!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _PendingHeader extends StatelessWidget {
  const _PendingHeader({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            'Couldn’t reach the server. You are still signed in.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Try again',
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _GuestHeader extends StatelessWidget {
  const _GuestHeader({this.message});

  /// Why the user was signed out (suspended, deleted, revoked), if any.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null) ...[
          SessionMessage(message!),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text('Sign in to plan your events', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Sign in',
          icon: Icons.login,
          onPressed: () => Get.toNamed<void>(
            AppRoutes.signIn,
            parameters: {'returnTo': AppRoutes.tab(ShellTab.menu)},
          ),
        ),
      ],
    );
  }
}
