import '../routes/app_routes.dart';

/// Decides the first screen after start-up: the navigation shell (Home tab).
/// Later milestones extend this instead of changing bootstrap.
class StartupRouter {
  const StartupRouter();

  String initialRoute() => AppRoutes.home;
}
