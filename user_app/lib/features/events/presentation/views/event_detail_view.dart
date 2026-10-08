import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/platform/external_actions.dart';
import '../../../../core/platform/photo_picker.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/storage/app_cache_manager.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../event_vendors/domain/event_vendor.dart';
import '../../../event_vendors/presentation/controllers/event_vendors_controller.dart';
import '../../../event_vendors/presentation/widgets/event_vendor_slivers.dart';
import '../../../budget/domain/budget.dart';
import '../../../budget/presentation/controllers/budget_controller.dart';
import '../../../budget/presentation/widgets/budget_slivers.dart';
import '../../../checklist/domain/entities/checklist_item.dart';
import '../../../checklist/domain/repositories/checklist_repository.dart';
import '../../../checklist/presentation/controllers/checklist_controller.dart';
import '../../../checklist/presentation/views/checklist_view.dart';
import '../../../checklist/presentation/widgets/checklist_item_sheet.dart';
import '../../../checklist/presentation/widgets/checklist_progress.dart';
import '../../../media/domain/media_repository.dart';
import '../../domain/entities/planner_event.dart';
import '../../domain/repositories/events_repository.dart';
import '../controllers/event_detail_controller.dart';
import '../events_navigation.dart';
import '../widgets/event_status_chip.dart';

/// An event's home screen (M10): cover, key facts and tabs — Overview,
/// Checklist, Budget (M11) and Vendors (M12–M15). Actions live in the menu.
class EventDetailView extends StatelessWidget {
  const EventDetailView({super.key, required this.eventId, this.initial});

  final String eventId;
  final PlannerEvent? initial;

  static T? _optional<T>() => Get.isRegistered<T>() ? Get.find<T>() : null;

  @override
  Widget build(BuildContext context) => GetBuilder<EventDetailController>(
    init: EventDetailController(
      Get.find<EventsRepository>(),
      eventId,
      initial: initial,
      media: _optional<MediaRepository>(),
      picker: _optional<PhotoPicker>(),
    ),
    global: false,
    builder: (c) => GetBuilder<ChecklistController>(
      init: ChecklistController(Get.find<ChecklistRepository>(), eventId),
      global: false,
      builder: (checklist) => Obx(() {
        final state = c.state.value;
        // Tabs need the event; loading and errors use a plain page.
        if (state is! Content<PlannerEvent>) {
          return Scaffold(
            appBar: AppBar(title: const Text('Event')),
            body: AsyncStateView<PlannerEvent>(
              state: state,
              onRetry: c.load,
              builder: (_, _) => const SizedBox.shrink(),
            ),
          );
        }
        return _EventScreen(
          event: state.data,
          isStale: state.isStale,
          controller: c,
          checklist: checklist,
        );
      }),
    ),
  );
}

class _EventScreen extends StatelessWidget {
  const _EventScreen({
    required this.event,
    required this.isStale,
    required this.controller,
    required this.checklist,
  });

  final PlannerEvent event;
  final bool isStale;
  final EventDetailController controller;
  final ChecklistController checklist;

  ExternalActions get _external => Get.isRegistered<ExternalActions>()
      ? Get.find<ExternalActions>()
      : const PlatformExternalActions();

  Future<void> _refresh() async {
    await Future.wait([controller.load(), checklist.load()]);
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    // Four labels need ~400 dp at normal size; scroll rather than clip.
    final largeText =
        MediaQuery.sizeOf(context).width / textScale < 400 || textScale > 1.4;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              title: const Text('Event'),
              actions: [
                Obx(() {
                  final busy = controller.running.value != null;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit event',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: busy ? null : () => _edit(context),
                      ),
                      _EventMenu(
                        event: event,
                        controller: controller,
                        enabled: !busy,
                        onCover: () => _coverOptions(context),
                      ),
                    ],
                  );
                }),
              ],
              // Feedback while complete/cancel/reopen/delete runs.
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: Obx(
                  () => controller.running.value == null
                      ? const SizedBox(height: 2)
                      : const LinearProgressIndicator(minHeight: 2),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isStale) const _StaleBanner(),
                  Obx(
                    () => _Cover(
                      event: event,
                      canChange: controller.canChangeCover,
                      progress: controller.coverProgress.value,
                      removing: controller.removingCover.value,
                      onChange: () => _coverOptions(context),
                    ),
                  ),
                  _Header(event: event, today: controller.today),
                ],
              ),
            ),
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    // Labels scroll instead of truncating at large text sizes.
                    isScrollable: largeText,
                    tabAlignment: largeText ? TabAlignment.start : null,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Checklist'),
                      Tab(text: 'Budget'),
                      Tab(text: 'Vendors'),
                    ],
                  ),
                  Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _TabScroll(
                storageKey: 'overview',
                onRefresh: _refresh,
                slivers: [
                  _OverviewTab(
                    event: event,
                    controller: controller,
                    checklist: checklist,
                    onAddTask: () => _addTask(context),
                    onShare: (origin) => _share(origin),
                    onMaps: () => _openMaps(context),
                  ),
                ],
              ),
              _ChecklistTab(
                eventTitle: event.title,
                checklist: checklist,
                onAdd: () => _addTask(context),
                onRefresh: _refresh,
              ),
              _BudgetTab(eventId: event.id),
              _VendorsTab(event: event),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await Navigator.of(
      context,
    ).push(EventsNavigation.editRoute(event));
    if (updated != null) controller.replace(updated);
  }

  Future<void> _addTask(BuildContext context) async {
    if (!event.checklistEditable) return;
    final saved = await showChecklistItemSheet(context, eventId: event.id);
    if (saved != null) checklist.applySaved(saved);
  }

  Future<void> _share(Rect? origin) => _external.shareText(
    eventShareText(event),
    subject: event.title,
    origin: origin,
  );

  Future<void> _openMaps(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final query = mapsQuery(event);
    if (query == null) return;
    final opened = await _external.openMaps(query);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open a maps app.')),
      );
    }
  }

  Future<void> _coverOptions(BuildContext context) async {
    if (!controller.canChangeCover) return;
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<_CoverChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(sheetContext, _CoverChoice.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, _CoverChoice.camera),
            ),
            if (event.cover != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: const Text('Remove cover photo'),
                onTap: () => Navigator.pop(sheetContext, _CoverChoice.remove),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xs,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Text(
                'JPEG, PNG, WebP or HEIC, up to 5 MB. Visible only to you.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == _CoverChoice.remove && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove cover photo?'),
          content: const Text('The event will show its coloured header again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final message = switch (choice) {
      _CoverChoice.gallery => await controller.changeCover(PhotoSource.gallery),
      _CoverChoice.camera => await controller.changeCover(PhotoSource.camera),
      _CoverChoice.remove => await controller.removeCover(),
    };
    // Null with no change (e.g. picker cancelled) shows nothing.
    final changed = controller.event?.cover?.mediaId != event.cover?.mediaId;
    if (message == null && !changed) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message ??
              (choice == _CoverChoice.remove
                  ? 'Cover photo removed'
                  : 'Cover photo updated'),
        ),
      ),
    );
  }
}

enum _CoverChoice { gallery, camera, remove }

/// Plain-text event details for the share sheet (M10; invitations are M19).
String eventShareText(PlannerEvent event) => [
  event.title,
  [
    event.eventType,
    formatLongDate(event.eventDate),
    if (event.startTime != null) formatTimeOfDay(event.startTime!),
  ].join(' · '),
  ?mapsQuery(event),
].join('\n');

/// Venue, address and city for Maps; null when nothing is known.
String? mapsQuery(PlannerEvent event) {
  final parts = [
    event.venueName,
    event.venueAddress,
    event.city,
  ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();
  return parts.isEmpty ? null : parts.join(', ');
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, this.background);

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      Material(color: background, elevation: overlaps ? 1 : 0, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.background != background;
}

/// One tab's scroll view below the pinned header (overlap injected).
class _TabScroll extends StatelessWidget {
  const _TabScroll({
    required this.storageKey,
    required this.onRefresh,
    required this.slivers,
  });

  final String storageKey;
  final Future<void> Function() onRefresh;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: Builder(
      builder: (context) => CustomScrollView(
        key: PageStorageKey(storageKey),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          ...slivers,
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    ),
  );
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        color: scheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          'Showing saved details — you may be offline',
          style: TextStyle(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}

/// Cover photo, or a coloured band with an icon for the event type.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.event,
    required this.canChange,
    required this.progress,
    required this.removing,
    required this.onChange,
  });

  final PlannerEvent event;
  final bool canChange;
  final double? progress;
  final bool removing;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final cover = event.cover;
    final band = _CoverBand(eventType: event.eventType);
    final busy = progress != null || removing;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final label = cover == null ? 'Add cover photo' : 'Change cover';
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            if (cover == null)
              band
            else
              CachedNetworkImage(
                imageUrl: cover.url,
                // Keyed by media id: a fresh signed URL still hits the cache.
                cacheKey: AppCacheManager.mediaKey(cover.mediaId, 'cover'),
                cacheManager: AppCacheManager.instance,
                // Decode at display size, not the stored 1200 px.
                memCacheWidth:
                    (constraints.maxWidth *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                fit: BoxFit.cover,
                fadeInDuration: AppDurations.fast,
                placeholder: (_, _) => band,
                errorWidget: (_, _, _) => band,
                imageBuilder: (context, image) => Semantics(
                  image: true,
                  label: 'Cover photo of ${event.title}',
                  child: Image(image: image, fit: BoxFit.cover),
                ),
              ),
            if (canChange)
              Positioned(
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                // Icon only at large text, so it doesn't cover the photo.
                child: largeText
                    ? IconButton.filledTonal(
                        tooltip: label,
                        onPressed: busy ? null : onChange,
                        icon: const Icon(Icons.photo_camera_outlined),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: busy ? null : onChange,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(label),
                      ),
              ),
            if (busy)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Semantics(
                  liveRegion: true,
                  label: removing
                      ? 'Removing cover photo'
                      : 'Uploading cover photo',
                  value: removing || progress == 0
                      ? null
                      : '${((progress ?? 0) * 100).round()}%',
                  child: LinearProgressIndicator(
                    value: removing || progress == 0 ? null : progress,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverBand extends StatelessWidget {
  const _CoverBand({required this.eventType});

  final String eventType;

  static IconData iconFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('wedding') || t.contains('marriage')) return Icons.favorite;
    if (t.contains('engage')) return Icons.diamond_outlined;
    if (t.contains('birthday')) return Icons.cake_outlined;
    if (t.contains('anniversary')) return Icons.celebration_outlined;
    if (t.contains('baby')) return Icons.child_friendly_outlined;
    if (t.contains('house')) return Icons.house_outlined;
    if (t.contains('corporate') || t.contains('office')) {
      return Icons.business_center_outlined;
    }
    return Icons.celebration_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.tertiaryContainer],
          ),
        ),
        child: Center(
          child: Icon(
            iconFor(eventType),
            size: 56,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Title, type, date/time, countdown and status.
class _Header extends StatelessWidget {
  const _Header({required this.event, required this.today});

  final PlannerEvent event;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = daysBetween(today, event.eventDate);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(event.title, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            [
              event.eventType,
              formatLongDate(event.eventDate),
              if (event.startTime != null) formatTimeOfDay(event.startTime!),
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              EventStatusChip(event.status),
              if (event.status == EventStatus.planning)
                Text(relativeDays(days), style: theme.textTheme.labelLarge),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.event,
    required this.controller,
    required this.checklist,
    required this.onAddTask,
    required this.onShare,
    required this.onMaps,
  });

  final PlannerEvent event;
  final EventDetailController controller;
  final ChecklistController checklist;
  final VoidCallback onAddTask;
  final void Function(Rect? origin) onShare;
  final VoidCallback onMaps;

  @override
  Widget build(BuildContext context) {
    final where = mapsQuery(event);
    final today = controller.today;
    final datePassed = event.eventDate.isBefore(today);
    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.page),
      sliver: SliverList.list(
        children: [
          if (event.canComplete && datePassed) ...[
            _CompleteSuggestion(controller: controller),
            const SizedBox(height: AppSpacing.md),
          ],
          Obx(() {
            final busy = controller.running.value != null;
            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (event.checklistEditable)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onAddTask,
                    icon: const Icon(Icons.add_task),
                    label: const Text('Add task'),
                  ),
                if (where != null)
                  OutlinedButton.icon(
                    onPressed: onMaps,
                    icon: const Icon(Icons.directions_outlined),
                    label: const Text('Open in Maps'),
                  ),
                Builder(
                  builder: (buttonContext) => OutlinedButton.icon(
                    onPressed: () {
                      final box =
                          buttonContext.findRenderObject() as RenderBox?;
                      onShare(
                        box == null
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size,
                      );
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.md),
          if (event.startTime != null)
            _Row(
              icon: Icons.schedule_outlined,
              label: 'Start time',
              value: formatTimeOfDay(event.startTime!),
            ),
          _Row(
            icon: Icons.location_city_outlined,
            label: 'City',
            value: event.city,
          ),
          if (event.venueName != null)
            _Row(
              icon: Icons.place_outlined,
              label: 'Venue',
              value: event.venueName!,
            ),
          if (event.venueAddress != null)
            _Row(
              icon: Icons.map_outlined,
              label: 'Address',
              value: event.venueAddress!,
            ),
          if (event.guestCountEstimate != null)
            _Row(
              icon: Icons.groups_outlined,
              label: 'Expected guests',
              value: '${event.guestCountEstimate}',
            ),
          _Row(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Total budget',
            value: event.totalBudget?.format() ?? 'Not set',
          ),
          const SizedBox(height: AppSpacing.md),
          _ChecklistSummaryCard(
            event: event,
            checklist: checklist,
            onOpen: () => DefaultTabController.of(context).animateTo(1),
            onAddTask: event.checklistEditable ? onAddTask : null,
          ),
          if (!event.canReopen(today) && event.status != EventStatus.planning)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                'To reopen this event, edit it and choose today or a later date first.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Progress plus the next three open tasks; opens the Checklist tab.
class _ChecklistSummaryCard extends StatelessWidget {
  const _ChecklistSummaryCard({
    required this.event,
    required this.checklist,
    required this.onOpen,
    this.onAddTask,
  });

  final PlannerEvent event;
  final ChecklistController checklist;
  final VoidCallback onOpen;
  final VoidCallback? onAddTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        hint: 'Opens the checklist',
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Obx(() {
              final list = checklist.checklist;
              final summary = list?.summary ?? event.checklist;
              if (summary.total == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Tasks', style: theme.textTheme.titleMedium),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('No tasks yet.'),
                    if (onAddTask != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Add task',
                        icon: Icons.add,
                        variant: AppButtonVariant.secondary,
                        onPressed: onAddTask,
                      ),
                    ],
                  ],
                );
              }
              final next = list == null
                  ? const <ChecklistItem>[]
                  : list.pending.take(3).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Tasks', style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ChecklistProgress(summary: summary),
                  for (final task in next)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        task.isOverdue ? '${task.title} · overdue' : task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: task.isOverdue
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Open checklist',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ChecklistTab extends StatelessWidget {
  const _ChecklistTab({
    required this.eventTitle,
    required this.checklist,
    required this.onAdd,
    required this.onRefresh,
  });

  final String eventTitle;
  final ChecklistController checklist;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Obx(() {
    final state = checklist.state.value;
    final List<Widget> slivers = switch (state) {
      Loading() => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      Failed(:final failure) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  failureTitle(failure),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(failureMessage(failure)),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Try again',
                  icon: Icons.refresh,
                  onPressed: checklist.load,
                ),
              ],
            ),
          ),
        ),
      ],
      Empty() => const [],
      Content(:final data) when data.items.isEmpty => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'No tasks yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.isEditable
                      ? 'Write down everything you need to do for $eventTitle.'
                      : '$eventTitle is no longer being planned.',
                ),
                if (data.isEditable) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Add task',
                    icon: Icons.add,
                    onPressed: onAdd,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      Content(:final data) => checklistContentSlivers(
        context,
        data,
        checklist,
        onAdd: onAdd,
      ),
    };
    return _TabScroll(
      storageKey: 'checklist',
      onRefresh: onRefresh,
      slivers: slivers,
    );
  });
}

/// After the event date: a visible way to mark the event completed (the
/// auto-complete job does it the next day otherwise).
class _CompleteSuggestion extends StatelessWidget {
  const _CompleteSuggestion({required this.controller});

  final EventDetailController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This event date has passed.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: AppSpacing.sm),
            Obx(
              () => AppButton(
                label: 'Mark as completed',
                icon: Icons.task_alt,
                isBusy: controller.running.value == EventCommand.complete,
                onPressed: controller.running.value != null
                    ? null
                    : () => _markCompleted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markCompleted(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure = await controller.run(EventCommand.complete);
    if (failure != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('${failureTitle(failure)}.')),
      );
    }
  }
}

/// Budget tab (M11): the event's budget; its controller is created when
/// the tab is first built.
class _BudgetTab extends StatelessWidget {
  const _BudgetTab({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) => GetBuilder<BudgetController>(
    init: BudgetController(
      Get.find<BudgetRepository>(),
      Get.find<EventsRepository>(),
      eventId,
    ),
    global: false,
    builder: (budget) => Obx(() {
      final state = budget.state.value;
      final List<Widget> slivers = switch (state) {
        Content(:final data, :final isStale) => [
          if (isStale) const SliverToBoxAdapter(child: StaleBanner()),
          ...budgetSlivers(context, data, budget),
        ],
        Failed(:final failure) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    failureTitle(failure),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(failureMessage(failure)),
                  if (failure.isRetryable) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Try again',
                      icon: Icons.refresh,
                      onPressed: budget.load,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        _ => const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      };
      return _TabScroll(
        storageKey: 'budget',
        onRefresh: budget.load,
        slivers: slivers,
      );
    }),
  );
}

class _VendorsTab extends StatelessWidget {
  const _VendorsTab({required this.event});

  final PlannerEvent event;

  @override
  Widget build(BuildContext context) => GetBuilder<EventVendorsController>(
    init: EventVendorsController(
      Get.find<EventVendorsRepository>(),
      Get.find<EventsRepository>(),
      event.id,
    ),
    global: false,
    builder: (vendors) => Obx(() {
      final state = vendors.state.value;
      final List<Widget> slivers = switch (state) {
        Content(:final data, :final isStale) => [
          if (isStale) const SliverToBoxAdapter(child: StaleBanner()),
          ...eventVendorSlivers(context, data, vendors, event),
        ],
        Failed(:final failure) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    failureTitle(failure),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(failureMessage(failure)),
                  if (failure.isRetryable) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Try again',
                      icon: Icons.refresh,
                      onPressed: vendors.load,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        _ => const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading vendors',
              ),
            ),
          ),
        ],
      };
      return _TabScroll(
        storageKey: 'vendors',
        onRefresh: vendors.load,
        slivers: slivers,
      );
    }),
  );
}

enum _MenuAction { cover, complete, reopen, cancel, delete }

/// Cover, status changes and delete (M8 rules and confirmations).
class _EventMenu extends StatelessWidget {
  const _EventMenu({
    required this.event,
    required this.controller,
    required this.enabled,
    required this.onCover,
  });

  final PlannerEvent event;
  final EventDetailController controller;
  final bool enabled;
  final VoidCallback onCover;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_MenuAction>(
    tooltip: 'More actions',
    enabled: enabled,
    onSelected: (action) => _onSelected(context, action),
    itemBuilder: (menuContext) => [
      if (controller.canChangeCover)
        _item(
          _MenuAction.cover,
          Icons.photo_camera_outlined,
          event.cover == null ? 'Add cover photo' : 'Change cover photo',
        ),
      if (event.canComplete)
        _item(_MenuAction.complete, Icons.task_alt, 'Mark as completed'),
      if (event.canReopen(controller.today))
        _item(_MenuAction.reopen, Icons.replay, 'Reopen event'),
      if (event.canCancel)
        _item(_MenuAction.cancel, Icons.event_busy_outlined, 'Cancel event'),
      const PopupMenuDivider(),
      _item(
        _MenuAction.delete,
        Icons.delete_outline,
        'Delete event',
        color: Theme.of(menuContext).colorScheme.error,
      ),
    ],
  );

  static PopupMenuItem<_MenuAction> _item(
    _MenuAction value,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: value,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
    ),
  );

  Future<void> _onSelected(BuildContext context, _MenuAction action) async {
    switch (action) {
      case _MenuAction.cover:
        onCover();
      case _MenuAction.complete:
        await _run(
          context,
          EventCommand.complete,
          confirm: (
            'Mark this event as completed?',
            'You can reopen it later while its date is today or later.',
            'Mark completed',
            'Not now',
          ),
        );
      case _MenuAction.reopen:
        await _run(context, EventCommand.reopen);
      case _MenuAction.cancel:
        await _run(
          context,
          EventCommand.cancel,
          confirm: (
            'Cancel this event?',
            'It moves to Past. You can reopen it while its date is today or later.',
            'Cancel event',
            'Keep',
          ),
        );
      case _MenuAction.delete:
        await _run(
          context,
          EventCommand.delete,
          destructive: true,
          confirm: (
            'Delete this event?',
            'It will be removed from your events. This cannot be undone in the app.',
            'Delete',
            'Keep',
          ),
        );
    }
  }

  Future<void> _run(
    BuildContext context,
    EventCommand command, {
    (String, String, String, String)? confirm,
    bool destructive = false,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (confirm != null) {
      final (title, message, action, keep) = confirm;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(keep),
            ),
            TextButton(
              style: destructive
                  ? TextButton.styleFrom(
                      foregroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.error,
                    )
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(action),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final failure = await controller.run(command);
    if (failure == null) {
      if (command == EventCommand.delete) {
        navigator.pop();
        messenger.showSnackBar(const SnackBar(content: Text('Event deleted')));
      }
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(_failureText(failure))));
  }

  static String _failureText(Failure failure) => switch (failure) {
    ConflictFailure() =>
      'This event changed in the meantime. Showing the latest version.',
    NotFoundFailure() => 'This event no longer exists.',
    _ => '${failureTitle(failure)}. ${failureMessage(failure)}'.trim(),
  };
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium),
                  Text(value, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
