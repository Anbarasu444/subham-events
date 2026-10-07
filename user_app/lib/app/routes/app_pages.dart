import 'package:get/get.dart';

import '../../features/auth/presentation/bindings/auth_bindings.dart';
import '../../features/auth/presentation/views/otp_view.dart';
import '../../features/auth/presentation/views/sign_in_view.dart';
import '../../features/diagnostics/presentation/bindings/diagnostics_binding.dart';
import '../../features/diagnostics/presentation/views/diagnostics_view.dart';
import '../../features/shell/presentation/bindings/shell_binding.dart';
import '../../features/shell/presentation/views/shell_view.dart';
import '../config/app_config.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static List<GetPage<dynamic>> pages(AppConfig config) => [
    GetPage(name: AppRoutes.home, page: ShellView.new, binding: ShellBinding()),
    GetPage(
      name: AppRoutes.signIn,
      page: SignInView.new,
      binding: SignInBinding(),
    ),
    GetPage(name: AppRoutes.otp, page: OtpView.new, binding: OtpBinding()),
    if (config.enableDiagnostics)
      GetPage(
        name: AppRoutes.diagnostics,
        page: DiagnosticsView.new,
        binding: DiagnosticsBinding(),
      ),
  ];
}
