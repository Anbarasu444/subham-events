import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/auth/session_service.dart';
import '../routes/app_routes.dart';

/// Sends guests to sign-in and resumes the requested route afterwards
/// (architecture/flutter.md §6). The backend still authorizes every call.
class AuthGuardMiddleware extends GetMiddleware {
  AuthGuardMiddleware({bool Function()? isSignedIn})
    : _isSignedIn = isSignedIn ?? (() => Get.find<SessionService>().isSignedIn);

  final bool Function() _isSignedIn;

  @override
  RouteSettings? redirect(String? route) {
    if (_isSignedIn()) return null;
    final target = Uri(
      path: AppRoutes.signIn,
      queryParameters: {'returnTo': ?route},
    );
    return RouteSettings(name: target.toString());
  }
}
