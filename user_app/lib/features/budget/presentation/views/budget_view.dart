import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/festive.dart';
import '../../../events/domain/repositories/events_repository.dart';
import '../../domain/budget.dart';
import '../controllers/budget_controller.dart';
import '../widgets/budget_slivers.dart';

/// Standalone budget page (Home and Menu → Budget); the event screen shows
/// the same content in its Budget tab.
class BudgetView extends StatelessWidget {
  const BudgetView({super.key, required this.eventId, this.eventTitle});

  final String eventId;
  final String? eventTitle;

  @override
  Widget build(BuildContext context) => GetBuilder<BudgetController>(
    init: BudgetController(
      Get.find<BudgetRepository>(),
      Get.find<EventsRepository>(),
      eventId,
    ),
    global: false,
    builder: (c) => Scaffold(
      appBar: AppBar(
        title: const ScreenTitle(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Budget',
        ),
      ),
      body: Obx(
        () => AsyncStateView<Budget>(
          state: c.state.value,
          onRetry: c.load,
          builder: (context, budget) => RefreshIndicator(
            onRefresh: c.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (eventTitle != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.md,
                      AppSpacing.page,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Semantics(
                        header: true,
                        child: Text(
                          eventTitle!,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ...budgetSlivers(context, budget, c),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

abstract final class BudgetNavigation {
  static Route<void> route({required String eventId, String? eventTitle}) =>
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'budget-$eventId'),
        builder: (_) => BudgetView(eventId: eventId, eventTitle: eventTitle),
      );
}
