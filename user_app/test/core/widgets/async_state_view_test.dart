import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/error/failure.dart';
import 'package:user_app/core/state/view_state.dart';
import 'package:user_app/core/widgets/async_state_view.dart';

Widget _host(ViewState<String> state, {VoidCallback? onRetry}) => MaterialApp(
  home: Scaffold(
    body: AsyncStateView<String>(
      state: state,
      onRetry: onRetry,
      emptyTitle: 'No events yet',
      builder: (_, data) => Text('content: $data'),
    ),
  ),
);

void main() {
  testWidgets('loading shows the skeleton', (tester) async {
    await tester.pumpWidget(_host(const Loading()));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('content renders the builder', (tester) async {
    await tester.pumpWidget(_host(const Content('hello')));
    expect(find.text('content: hello'), findsOneWidget);
    expect(find.textContaining('offline'), findsNothing);
  });

  testWidgets('stale content shows the offline banner', (tester) async {
    await tester.pumpWidget(_host(const Content('hello', isStale: true)));
    expect(find.textContaining('may be offline'), findsOneWidget);
  });

  testWidgets('empty shows the empty title', (tester) async {
    await tester.pumpWidget(_host(const Empty()));
    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('retryable error shows a working retry button', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(const Failed(NetworkFailure()), onRetry: () => retries++),
    );
    expect(find.text('You are offline'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('non-retryable error has no retry button', (tester) async {
    await tester.pumpWidget(
      _host(const Failed(ForbiddenFailure()), onRetry: () {}),
    );
    expect(find.text('Try again'), findsNothing);
  });
}
