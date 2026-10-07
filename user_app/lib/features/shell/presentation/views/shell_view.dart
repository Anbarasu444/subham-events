import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../events/presentation/views/my_events_tab_view.dart';
import '../../../explore/presentation/views/explore_tab_view.dart';
import '../../../home/presentation/views/home_tab_view.dart';
import '../../../menu/presentation/views/menu_tab_view.dart';
import '../controllers/shell_controller.dart';
import '../controllers/shell_tab.dart';
import '../widgets/tab_navigator.dart';

/// App shell: bottom navigation with one nested navigator per tab.
class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  static Widget _rootOf(ShellTab tab) => switch (tab) {
    ShellTab.home => const HomeTabView(),
    ShellTab.explore => const ExploreTabView(),
    ShellTab.events => const MyEventsTabView(),
    ShellTab.menu => const MenuTabView(),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final handled = await controller.handleBack();
        if (!handled) await SystemNavigator.pop();
      },
      child: Obx(() {
        final current = controller.current.value;
        return Scaffold(
          body: IndexedStack(
            index: current.index,
            children: [
              for (final tab in ShellTab.values)
                controller.isBuilt(tab)
                    // Hidden tabs stop their animations.
                    ? TickerMode(
                        enabled: tab == current,
                        child: TabNavigator(
                          navigatorKey: controller.navigatorKeys[tab]!,
                          root: (_) => _rootOf(tab),
                        ),
                      )
                    : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: current.index,
            onDestinationSelected: (i) => controller.select(ShellTab.values[i]),
            destinations: [
              for (final tab in ShellTab.values)
                NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                ),
            ],
          ),
        );
      }),
    );
  }
}
