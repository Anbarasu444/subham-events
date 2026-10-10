import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/crash/crash_reporter.dart';
import '../core/crash/crashlytics_reporter.dart';
import '../core/crash/error_handlers.dart';
import '../core/security/runtime_protection.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'startup/bootstrapper.dart';
import 'startup/startup_failure_app.dart';
import 'startup/startup_router.dart';

/// Entry point shared by every flavor (architecture/flutter.md §9).
/// The native splash stays up until the first Flutter frame is ready.
void bootstrap(Flavor flavor) {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  final reporter = SwitchableCrashReporter(const ConsoleCrashReporter());
  installErrorHandlers(reporter);

  startApp(flavor, reporter);
}

/// Runs the ordered start-up steps and shows either the app or the
/// start-failure screen. Also used by the failure screen's retry.
Future<void> startApp(Flavor flavor, SwitchableCrashReporter reporter) async {
  AppConfig? config;
  PackageInfo? package;

  final result = await Bootstrapper([
    BootstrapStep('config', () async {
      config = AppConfig.fromEnvironment(flavor);
    }, critical: true),
    BootstrapStep('app-version', () async {
      package = await PackageInfo.fromPlatform();
      config = config!.withVersion(package!.version, package!.buildNumber);
    }),
    BootstrapStep('firebase', () async {
      // Uses the per-flavor native config (google-services.json / plist).
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final crashlytics = FirebaseCrashlytics.instance;
      // No crash uploads from debug builds. Not awaited: Crashlytics may
      // fetch its settings over the network and must not delay start-up.
      unawaited(crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode));
      reporter.delegate = CrashlyticsReporter(
        crashlytics,
        const ConsoleCrashReporter(),
      );
    }),
    BootstrapStep('runtime-protection', () async {
      final id = package?.packageName;
      if (id == null) {
        throw StateError(
          'Package info unavailable; runtime protection not started',
        );
      }
      await RuntimeProtection(
        RuntimeProtectionConfig.fromEnvironment(
          androidPackageName: id,
          iosBundleId: id,
          isProd: flavor == Flavor.prod,
        ),
        reporter,
      ).start();
    }),
  ], reporter).run();

  if (result.succeeded) {
    runApp(
      App(
        config: config!,
        reporter: reporter,
        initialRoute: const StartupRouter().initialRoute(),
      ),
    );
  } else {
    runApp(StartupFailureApp(onRetry: () => startApp(flavor, reporter)));
  }
  _removeSplashAfterFirstFrame();
}

void _removeSplashAfterFirstFrame() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
    if (kDebugMode) {
      debugPrint('First frame rendered; native splash removed');
    }
  });
}
