import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/app/startup/startup_failure_app.dart';

void main() {
  testWidgets(
    'start-failure screen does not overflow at 200% text on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(StartupFailureApp(onRetry: () async {}));
      expect(tester.takeException(), isNull);
      expect(find.text('Try again'), findsOneWidget);
    },
  );
}
