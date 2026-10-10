import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 390×844 phone (logical pixels) for screen tests, unless the test has
/// already chosen a size (e.g. a small phone for 200 % text).
void usePhoneSize(WidgetTester tester) {
  final logical = tester.view.physicalSize / tester.view.devicePixelRatio;
  if (logical != const Size(800, 600)) return; // test chose its own size
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
