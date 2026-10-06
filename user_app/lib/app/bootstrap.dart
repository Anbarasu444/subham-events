import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';

/// Entry point shared by every flavor. Splash, Firebase and FreeRASP are added
/// in M4/M5 (architecture/flutter.md §9).
void bootstrap(Flavor flavor) {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log('Uncaught error', error: error, stackTrace: stack);
    return true;
  };

  runApp(App(config: AppConfig.fromEnvironment(flavor)));
}
