import 'package:get/get.dart';

import '../../../../core/auth/session_service.dart';
import '../../../../core/crash/crash_reporter.dart';
import '../../../home/data/empty_section_source.dart';
import '../../../home/presentation/controllers/home_controller.dart';

import '../controllers/shell_controller.dart';
import '../controllers/shell_tab.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    // Home tab dashboard (M7). Sections are filled by later milestones.
    Get.lazyPut(
      () => HomeController(
        Get.find<SessionService>(),
        defaultDashboardSources,
        reporter: Get.find<CrashReporter>(),
      ),
    );
    Get.lazyPut(
      () =>
          ShellController(initialTab: ShellTab.fromName(Get.parameters['tab'])),
    );
  }
}
