import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/app/config/app_config.dart';

void main() {
  test('diagnostics and HTTP logging are disabled in prod', () {
    const prod = AppConfig(
      flavor: Flavor.prod,
      apiBaseUrl: 'https://api.example.com',
      appVersion: '1.2.3',
      buildNumber: '4',
    );
    expect(prod.enableDiagnostics, isFalse);
    expect(prod.enableHttpLogging, isFalse);
    expect(prod.clientHeader, 'user_app/1.2.3+4');
  });

  test('fromEnvironment requires API_BASE_URL', () {
    // Tests run without --dart-define, so the define is empty.
    expect(() => AppConfig.fromEnvironment(Flavor.staging), throwsStateError);
  });
}
