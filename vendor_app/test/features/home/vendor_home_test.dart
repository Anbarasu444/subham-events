import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vendor_app/app/config/app_config.dart';
import 'package:vendor_app/core/error/failure.dart';
import 'package:vendor_app/core/error/result.dart';
import 'package:vendor_app/core/theme/app_theme.dart';
import 'package:vendor_app/features/diagnostics/domain/entities/backend_health.dart';
import 'package:vendor_app/features/diagnostics/domain/repositories/health_repository.dart';
import 'package:vendor_app/features/home/presentation/controllers/vendor_home_controller.dart';
import 'package:vendor_app/features/home/presentation/views/vendor_home_view.dart';

class _MockRepo extends Mock implements HealthRepository {}

const _config = AppConfig(
  flavor: Flavor.staging,
  apiBaseUrl: 'http://localhost:3000',
  appVersion: '1.0.0',
  buildNumber: '1',
);

const _ok = Ok(
  BackendHealth(
    status: 'ok',
    checks: {'database': 'up'},
    requestId: 'r',
    latency: Duration(milliseconds: 12),
  ),
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());
  tearDown(Get.reset);

  Future<void> pumpHome(WidgetTester tester) async {
    Get.put(VendorHomeController(repo, _config));
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light(), home: const VendorHomeView()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the brand and a connected server', (tester) async {
    when(() => repo.checkReady()).thenAnswer((_) async => _ok);
    await pumpHome(tester);
    expect(find.text('Subam Vendor'), findsOneWidget);
    expect(find.text('Grow your business'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Server ok · 12 ms'), findsOneWidget);
  });

  testWidgets('explains an offline server and recovers on retry', (
    tester,
  ) async {
    when(
      () => repo.checkReady(),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await pumpHome(tester);
    expect(find.text('Connected'), findsNothing);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

    when(() => repo.checkReady()).thenAnswer((_) async => _ok);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('stays readable at 200 % text size', (tester) async {
    when(() => repo.checkReady()).thenAnswer((_) async => _ok);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHome(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Subam Vendor'), findsOneWidget);
  });
}
