/// Named route constants (architecture/flutter.md §6).
abstract final class AppRoutes {
  static const home = '/';
  static const diagnostics = '/diagnostics';
  static const signIn = '/sign-in';
  static const otp = '/sign-in/otp';

  /// Protected.
  static const account = '/account';

  /// Routes a guest may be returned to after signing in.
  static const protectedRoutes = {account};
}
