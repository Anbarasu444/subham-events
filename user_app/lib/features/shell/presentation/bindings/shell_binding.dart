import 'package:get/get.dart';

import '../controllers/shell_controller.dart';
import '../controllers/shell_tab.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () =>
          ShellController(initialTab: ShellTab.fromName(Get.parameters['tab'])),
    );
  }
}
