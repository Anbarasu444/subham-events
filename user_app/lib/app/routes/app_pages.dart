import 'package:get/get.dart';

import '../../features/diagnostics/presentation/bindings/diagnostics_binding.dart';
import '../../features/diagnostics/presentation/views/diagnostics_view.dart';
import '../../features/home/presentation/views/home_placeholder_view.dart';
import '../config/app_config.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static List<GetPage<dynamic>> pages(AppConfig config) => [
    GetPage(name: AppRoutes.home, page: HomePlaceholderView.new),
    if (config.enableDiagnostics)
      GetPage(
        name: AppRoutes.diagnostics,
        page: DiagnosticsView.new,
        binding: DiagnosticsBinding(),
      ),
  ];
}
