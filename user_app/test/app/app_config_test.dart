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

  test('withVersion replaces the placeholder version', () {
    const config = AppConfig(
      flavor: Flavor.staging,
      apiBaseUrl: 'http://localhost:3000',
      appVersion: '0.0.0',
      buildNumber: '0',
    );
    expect(config.withVersion('1.0.0', '7').clientHeader, 'user_app/1.0.0+7');
  });
}
