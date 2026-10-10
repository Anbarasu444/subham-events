import 'package:get/get.dart';

import '../../features/diagnostics/presentation/bindings/diagnostics_binding.dart';
import '../../features/diagnostics/presentation/views/diagnostics_view.dart';
import '../../features/home/presentation/bindings/vendor_home_binding.dart';
import '../../features/home/presentation/views/vendor_home_view.dart';
import '../config/app_config.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static List<GetPage<dynamic>> pages(AppConfig config) => [
    GetPage(
      name: AppRoutes.home,
      page: VendorHomeView.new,
      binding: VendorHomeBinding(),
    ),
    if (config.enableDiagnostics)
      GetPage(
        name: AppRoutes.diagnostics,
        page: DiagnosticsView.new,
        binding: DiagnosticsBinding(),
      ),
  ];
}
