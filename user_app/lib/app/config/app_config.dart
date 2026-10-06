/// Build flavors (ADR-0012). Local development runs the staging flavor
/// against the local backend.
enum Flavor { staging, prod }

/// Non-secret runtime configuration supplied with `--dart-define-from-file`
/// (`config/<flavor>.json`). Never put secrets here (environments.md §3).
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.appVersion,
    required this.buildNumber,
  });

  /// Reads the compile-time defines for [flavor].
  factory AppConfig.fromEnvironment(Flavor flavor) {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not set. Run with '
        '--dart-define-from-file=config/${flavor.name}.json',
      );
    }
    if (flavor == Flavor.prod && !apiBaseUrl.startsWith('https://')) {
      throw StateError('Production builds must use an https API_BASE_URL');
    }
    return AppConfig(
      flavor: flavor,
      apiBaseUrl: apiBaseUrl,
      // Replaced with the installed app's version during start-up (M4).
      appVersion: '0.0.0',
      buildNumber: '0',
    );
  }

  final Flavor flavor;

  /// Backend origin, e.g. `http://10.0.2.2:3000`; `/api/v1` is appended by the
  /// API client.
  final String apiBaseUrl;
  final String appVersion;
  final String buildNumber;

  AppConfig withVersion(String version, String build) => AppConfig(
    flavor: flavor,
    apiBaseUrl: apiBaseUrl,
    appVersion: version,
    buildNumber: build,
  );

  bool get isProd => flavor == Flavor.prod;

  /// HTTP logging and the diagnostics screen exist only outside production.
  bool get enableHttpLogging => !isProd;
  bool get enableDiagnostics => !isProd;

  /// Sent as `X-Client` (api-contracts.md §1).
  String get clientHeader => 'user_app/$appVersion+$buildNumber';
}
