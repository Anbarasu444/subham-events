import 'package:flutter/foundation.dart';
import 'package:freerasp/freerasp.dart';

import '../crash/crash_reporter.dart';

/// FreeRASP settings from `--dart-define` (no secrets — architecture/flutter.md §10).
class RuntimeProtectionConfig {
  const RuntimeProtectionConfig({
    required this.watcherMail,
    required this.androidPackageName,
    required this.androidSigningCertHashes,
    required this.iosBundleId,
    required this.iosTeamId,
    required this.isProd,
  });

  factory RuntimeProtectionConfig.fromEnvironment({
    required String androidPackageName,
    required String iosBundleId,
    required bool isProd,
  }) {
    const hashes = String.fromEnvironment('TALSEC_SIGNING_CERT_HASHES');
    return RuntimeProtectionConfig(
      watcherMail: const String.fromEnvironment('TALSEC_WATCHER_MAIL'),
      androidPackageName: androidPackageName,
      androidSigningCertHashes: hashes.isEmpty
          ? const []
          : hashes.split(',').map((h) => h.trim()).toList(growable: false),
      iosBundleId: iosBundleId,
      iosTeamId: const String.fromEnvironment('TALSEC_IOS_TEAM_ID'),
      isProd: isProd,
    );
  }

  /// FreeRASP sends threat reports to Talsec; it runs only when the user has
  /// supplied the report e-mail and the platform's signing identity.
  final String watcherMail;
  final String androidPackageName;
  final List<String> androidSigningCertHashes;
  final String iosBundleId;
  final String iosTeamId;
  final bool isProd;

  String? missingSetting(TargetPlatform platform) {
    if (watcherMail.isEmpty) return 'TALSEC_WATCHER_MAIL';
    if (platform == TargetPlatform.android &&
        androidSigningCertHashes.isEmpty) {
      return 'TALSEC_SIGNING_CERT_HASHES';
    }
    if (platform == TargetPlatform.iOS && iosTeamId.isEmpty) {
      return 'TALSEC_IOS_TEAM_ID';
    }
    return null;
  }
}

/// Starts FreeRASP in **observe mode**: threats are reported/logged only.
/// Blocking reactions are decided in M22 (architecture/threat-model.md T10).
class RuntimeProtection {
  RuntimeProtection(this._config, this._reporter, [this._talsec]);

  final RuntimeProtectionConfig _config;
  final CrashReporter _reporter;
  final Talsec? _talsec;

  /// FreeRASP must be started once per process (start-up retry re-runs steps).
  static bool _started = false;

  @visibleForTesting
  static void resetForTest() => _started = false;

  /// Returns true when protection is running.
  Future<bool> start({TargetPlatform? platform}) async {
    final target = platform ?? defaultTargetPlatform;
    if (target != TargetPlatform.android && target != TargetPlatform.iOS) {
      return false;
    }
    if (_started) return true;
    final missing = _config.missingSetting(target);
    if (missing != null) {
      final message = 'Runtime protection disabled: $missing not set';
      if (_config.isProd) {
        // A production build must not silently ship without protection.
        _reporter.recordError(StateError(message), null, reason: message);
      } else {
        _reporter.log(message);
      }
      return false;
    }
    final talsec = _talsec ?? Talsec.instance;
    await talsec.attachListener(_listener());
    await talsec.start(
      TalsecConfig(
        watcherMail: _config.watcherMail,
        isProd: _config.isProd,
        androidConfig: target == TargetPlatform.android
            ? AndroidConfig(
                packageName: _config.androidPackageName,
                signingCertHashes: _config.androidSigningCertHashes,
              )
            : null,
        iosConfig: target == TargetPlatform.iOS
            ? IOSConfig(
                bundleIds: [_config.iosBundleId],
                teamId: _config.iosTeamId,
              )
            : null,
      ),
    );
    _started = true;
    _reporter.log('Runtime protection started (observe mode)');
    return true;
  }

  ThreatCallback _listener() {
    void observe(String threat) =>
        _reporter.log('Runtime protection detected: $threat');
    return ThreatCallback(
      onPrivilegedAccess: () => observe('privileged access (root/jailbreak)'),
      onAppIntegrity: () => observe('app integrity (tampering)'),
      onHooks: () => observe('hooking framework'),
      onDebug: () => observe('debugger'),
      onSimulator: () => observe('emulator/simulator'),
      onUnofficialStore: () => observe('unofficial store'),
      onDeviceBinding: () => observe('device binding'),
      onObfuscationIssues: () => observe('obfuscation issues'),
      onDevMode: () => observe('developer mode'),
    );
  }
}
