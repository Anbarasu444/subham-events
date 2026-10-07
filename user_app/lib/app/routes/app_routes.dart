import '../../features/shell/presentation/controllers/shell_tab.dart';

/// Named route constants (architecture/flutter.md §6).
abstract final class AppRoutes {
  /// The navigation shell (bottom bar); `?tab=` selects the initial tab.
  static const home = '/';
  static const diagnostics = '/diagnostics';
  static const signIn = '/sign-in';
  static const otp = '/sign-in/otp';

  /// Shell route opening [tab].
  static String tab(ShellTab tab) => '/?tab=${tab.name}';

  /// Routes a user may be returned to after signing in.
  static final Set<String> returnRoutes = {
    for (final t in ShellTab.values) tab(t),
  };
}
