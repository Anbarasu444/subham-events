import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import '../../../../core/theme/tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/assets/app_illustrations.dart';
import '../../../../core/storage/app_cache_manager.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/festive.dart';
import '../../../../core/widgets/session_message.dart';
import '../../../shell/presentation/controllers/shell_tab.dart';
import '../../../budget/presentation/views/budget_view.dart';
import '../../../checklist/presentation/checklist_navigation.dart';
import '../../../checklist/presentation/widgets/checklist_progress.dart';
import '../../../events/presentation/views/planning_event_picker_view.dart';
import '../../../reminders/presentation/views/schedule_view.dart';
import 'settings_view.dart';
import '../../../wishlist/presentation/views/saved_vendors_view.dart';
import 'coming_soon_view.dart';
import '../../../profile/presentation/views/help_view.dart';
import '../../../profile/presentation/views/my_reviews_view.dart';
import '../../../profile/presentation/views/profile_view.dart';

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

Widget _savedVendorsPage(BuildContext _) => const SavedVendorsView();

Widget _schedulePage(BuildContext _) => const ScheduleView();

Widget _settingsPage(BuildContext _) => const SettingsView();

Widget _profilePage(BuildContext _) => const ProfileView();

Widget _myReviewsPage(BuildContext _) => const MyReviewsView();

Widget _helpPage(BuildContext _) => const HelpView();

const menuSections = [
  MenuSection('Planning', [
    MenuEntry('Schedule', Icons.schedule_outlined, page: _schedulePage),
    MenuEntry('Checklist', Icons.checklist_outlined, page: _checklistPage),
    MenuEntry(
      'Budget',
      Icons.account_balance_wallet_outlined,
      page: _budgetPage,
    ),
    MenuEntry('Saved vendors', Icons.favorite_border, page: _savedVendorsPage),
    // Messages is hidden until a chat milestone (M21 answer 6).
  ]),
  MenuSection('Account', [
    MenuEntry('My profile', Icons.person_outline, page: _profilePage),
    MenuEntry('My reviews', Icons.star_outline_rounded, page: _myReviewsPage),
    MenuEntry(
      'Settings',
      Icons.settings_outlined,
      guestVisible: true,
      page: _settingsPage,
    ),
    MenuEntry('Help', Icons.help_outline, guestVisible: true, page: _helpPage),
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
      appBar: AppBar(
        title: const ScreenTitle(icon: Icons.grid_view_rounded, title: 'Menu'),
      ),
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
              child: _Card(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: switch (state) {
                  SignedInSession(:final profile) => _SignedInHeader(profile),
                  ProfilePendingSession() => _PendingHeader(
                    onRetry: _session.retry,
                  ),
                  GuestSession(:final message) => _GuestHeader(
                    message: message,
                  ),
                  RestoringSession() => const SizedBox.shrink(),
                },
              ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                0,
              ),
              child: _AboutCard(config: _config),
            ),
            if (signedIn) ...[
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
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page + AppSpacing.xxs,
          AppSpacing.xs,
          AppSpacing.page,
          AppSpacing.xxs,
        ),
        child: Semantics(
          header: true,
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: _Card(
          child: Column(
            children: [
              for (final (i, entry) in visible.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(entry.icon),
                  title: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(entry),
                ),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}

/// White rounded card (Menu groups).
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.all(AppRadii.lg),
      boxShadow: AppShadows.card,
    ),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.all(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// App name, version and Help — like the reference's about card.
class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.config});
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Illustration(
            AppIllustrations.appLogo,
            fallback: Icons.celebration_rounded,
            size: 72,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Event Planner', style: theme.textTheme.titleLarge),
                Text(
                  'Made with ❤️ in India',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'Version ${config.appVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedInHeader extends StatelessWidget {
  const _SignedInHeader(this.profile);
  final MeProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = profile.photoThumbnailUrl;
    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.gold.withValues(alpha: 0.35),
          foregroundImage: thumb == null
              ? null
              : CachedNetworkImageProvider(
                  thumb,
                  cacheKey: AppCacheManager.mediaKey(
                    profile.photoMediaId!,
                    'avatar',
                  ),
                  cacheManager: AppCacheManager.instance,
                ),
          child: const Illustration(
            AppIllustrations.avatarPlaceholder,
            fallback: Icons.person_outline,
            size: 88,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Signed in as', style: theme.textTheme.bodySmall),
        Text(
          profile.label,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        if (profile.phone != null && profile.label != profile.phone)
          Text(profile.phone!, style: theme.textTheme.bodyMedium),
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
