import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Makes the test view a phone: [width] × [height] logical pixels at [dpr],
/// with a status bar ([top]) and a navigation bar ([bottom]) the app must
/// keep clear of, and the system font size at [textScale].
void usePhone(
  WidgetTester tester,
  double width,
  double height, {
  double dpr = 3,
  double textScale = 1,
  double top = 24,
  double bottom = 48,
}) {
  tester.view.physicalSize = Size(width * dpr, height * dpr);
  tester.view.devicePixelRatio = dpr;
  final insets = FakeViewPadding(top: top * dpr, bottom: bottom * dpr);
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Whether [finder]'s widget lies fully inside the screen, clear of the
/// system bars.
bool clearOfSystemBars(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  final top = view.padding.top / view.devicePixelRatio;
  final bottom = view.padding.bottom / view.devicePixelRatio;
  return rect.top >= top - 0.5 && rect.bottom <= size.height - bottom + 0.5 && rect.left >= -0.5 && rect.right <= size.width + 0.5;
}
