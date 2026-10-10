import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_app/app/startup/startup_failure_app.dart';

void main() {
  testWidgets('shows the failure message and retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      StartupFailureApp(
        onRetry: () async {
          retries++;
        },
      ),
    );
    expect(find.text('Couldn’t start the app'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(retries, 1);
  });
}
