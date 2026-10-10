import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_app/core/security/runtime_protection.dart';

import '../../helpers/recording_reporter.dart';

RuntimeProtectionConfig _config({
  String mail = '',
  List<String> hashes = const [],
  String teamId = '',
}) => RuntimeProtectionConfig(
  watcherMail: mail,
  androidPackageName: 'com.example.user_app.stg',
  androidSigningCertHashes: hashes,
  iosBundleId: 'com.example.userApp',
  iosTeamId: teamId,
  isProd: false,
);

void main() {
  setUp(RuntimeProtection.resetForTest);

  test('stays off without the report e-mail and logs why', () async {
    final reporter = RecordingReporter();
    final started = await RuntimeProtection(
      _config(),
      reporter,
    ).start(platform: TargetPlatform.android);
    expect(started, isFalse);
    expect(reporter.logs.single, contains('TALSEC_WATCHER_MAIL'));
  });

  test('needs the platform signing identity', () {
    final android = _config(mail: 'security@example.com');
    expect(
      android.missingSetting(TargetPlatform.android),
      'TALSEC_SIGNING_CERT_HASHES',
    );
    expect(android.missingSetting(TargetPlatform.iOS), 'TALSEC_IOS_TEAM_ID');
    final complete = _config(
      mail: 'security@example.com',
      hashes: ['h'],
      teamId: 'T',
    );
    expect(complete.missingSetting(TargetPlatform.android), isNull);
    expect(complete.missingSetting(TargetPlatform.iOS), isNull);
  });

  test('does nothing on unsupported platforms', () async {
    final reporter = RecordingReporter();
    final started = await RuntimeProtection(
      _config(),
      reporter,
    ).start(platform: TargetPlatform.macOS);
    expect(started, isFalse);
    expect(reporter.logs, isEmpty);
  });

  test('a prod build without configuration reports an error', () async {
    final reporter = RecordingReporter();
    const prodConfig = RuntimeProtectionConfig(
      watcherMail: '',
      androidPackageName: 'com.example.user_app',
      androidSigningCertHashes: [],
      iosBundleId: 'com.example.userApp',
      iosTeamId: '',
      isProd: true,
    );
    final started = await RuntimeProtection(
      prodConfig,
      reporter,
    ).start(platform: TargetPlatform.iOS);
    expect(started, isFalse);
    expect(reporter.errors.single.reason, contains('TALSEC_WATCHER_MAIL'));
    expect(reporter.errors.single.fatal, isFalse);
  });
}
