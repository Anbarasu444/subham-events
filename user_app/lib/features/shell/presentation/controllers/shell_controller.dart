import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/auth/session.dart';
import '../../../../core/auth/session_service.dart';
import 'shell_tab.dart';

/// Bottom-navigation state: selected tab, which tabs were built, and one
/// navigator per tab so pages pushed inside a tab keep the bottom bar.
class ShellController extends GetxController {
  ShellController({ShellTab initialTab = ShellTab.home})
    : current = initialTab.obs,
      _visited = {initialTab};

  final Rx<ShellTab> current;

  /// Tabs are built lazily on first visit, then kept alive.
  final Set<ShellTab> _visited;

  final Map<ShellTab, GlobalKey<NavigatorState>> navigatorKeys = {
    for (final tab in ShellTab.values)
      tab: GlobalKey<NavigatorState>(debugLabel: 'tab-${tab.name}'),
  };

  bool isBuilt(ShellTab tab) => _visited.contains(tab);

  Worker? _sessionWorker;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<SessionService>()) {
      // After sign-out no tab may keep pages that belonged to the user.
      _sessionWorker = ever<SessionState>(Get.find<SessionService>().state, (
        state,
      ) {
        if (state is GuestSession) popAllToRoot();
      });
    }
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    super.onClose();
  }

  void popAllToRoot() {
    for (final key in navigatorKeys.values) {
      key.currentState?.popUntil((route) => route.isFirst);
    }
  }

  /// Selecting the active tab again returns it to its first page.
  void select(ShellTab tab) {
    if (tab == current.value) {
      navigatorKeys[tab]?.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    _visited.add(tab);
    current.value = tab;
  }

  /// Switches to [tab] and pushes [route] on its navigator once the tab is
  /// built (tabs are built lazily on first visit).
  void pushInTab<T>(ShellTab tab, Route<T> route) {
    select(tab);
    void push() => navigatorKeys[tab]?.currentState?.push(route);
    if (navigatorKeys[tab]?.currentState != null) {
      push();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => push());
    }
  }

  /// System back: pop inside the tab, then go to Home, then let the app close.
  /// Returns true when the back press was handled.
  Future<bool> handleBack() async {
    final navigator = navigatorKeys[current.value]?.currentState;
    if (navigator != null && navigator.canPop()) {
      await navigator.maybePop();
      return true;
    }
    if (current.value != ShellTab.home) {
      select(ShellTab.home);
      return true;
    }
    return false;
  }
}
