import '../routes/app_routes.dart';

/// Decides the first screen after start-up. M5 adds the auth state and M6 the
/// navigation shell; they extend this instead of changing bootstrap.
class StartupRouter {
  const StartupRouter();

  String initialRoute() => AppRoutes.home;
}
