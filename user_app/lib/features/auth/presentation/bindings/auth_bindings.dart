import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/session_service.dart';
import '../controllers/otp_controller.dart';
import '../controllers/sign_in_controller.dart';

class SignInBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => SignInController(
        Get.find<AuthService>(),
        Get.find<SessionService>(),
        returnTo: safeReturnTo(Get.parameters['returnTo']),
      ),
    );
  }
}

class OtpBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => OtpController(
        Get.find<AuthService>(),
        Get.find<SessionService>(),
        Get.arguments as OtpArgs,
      ),
    );
  }
}

/// Only known in-app routes may be used after sign-in (no arbitrary targets).
String? safeReturnTo(String? route) =>
    route != null && AppRoutes.protectedRoutes.contains(route) ? route : null;
