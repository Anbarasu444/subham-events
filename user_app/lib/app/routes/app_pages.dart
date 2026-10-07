import 'package:get/get.dart';

import '../../features/auth/presentation/bindings/auth_bindings.dart';
import '../../features/auth/presentation/views/account_view.dart';
import '../../features/auth/presentation/views/otp_view.dart';
import '../../features/auth/presentation/views/sign_in_view.dart';
import '../../features/diagnostics/presentation/bindings/diagnostics_binding.dart';
import '../../features/diagnostics/presentation/views/diagnostics_view.dart';
import '../../features/home/presentation/views/home_placeholder_view.dart';
import '../config/app_config.dart';
import '../middlewares/auth_guard_middleware.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static List<GetPage<dynamic>> pages(AppConfig config) => [
    GetPage(name: AppRoutes.home, page: HomePlaceholderView.new),
    GetPage(
      name: AppRoutes.signIn,
      page: SignInView.new,
      binding: SignInBinding(),
    ),
    GetPage(name: AppRoutes.otp, page: OtpView.new, binding: OtpBinding()),
    GetPage(
      name: AppRoutes.account,
      page: AccountView.new,
      middlewares: [AuthGuardMiddleware()],
    ),
    if (config.enableDiagnostics)
      GetPage(
        name: AppRoutes.diagnostics,
        page: DiagnosticsView.new,
        binding: DiagnosticsBinding(),
      ),
  ];
}
