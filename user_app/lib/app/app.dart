import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/fade_in_on_start.dart';
import 'bindings/initial_binding.dart';
import 'config/app_config.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    required this.config,
    this.initialRoute = AppRoutes.home,
  });

  final AppConfig config;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Event Planner',
      debugShowCheckedModeBanner: !config.isProd,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      initialBinding: InitialBinding(config),
      initialRoute: initialRoute,
      getPages: AppPages.pages(config),
      builder: (context, child) =>
          FadeInOnStart(child: child ?? const SizedBox.shrink()),
    );
  }
}
