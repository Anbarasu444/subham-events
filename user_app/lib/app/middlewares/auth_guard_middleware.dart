import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Guards protected routes. Authentication arrives in M5; until then there are
/// no protected routes and every user is a guest, so nothing is redirected.
class AuthGuardMiddleware extends GetMiddleware {
  AuthGuardMiddleware({this.isSignedIn = _guest});

  final bool Function() isSignedIn;

  static bool _guest() => false;

  @override
  RouteSettings? redirect(String? route) => null;
}
