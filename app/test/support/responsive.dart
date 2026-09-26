import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The representative device matrix (APP-PRODUCT-01 §69, §110), in logical
/// pixels. Phones first, then the wider layouts, then landscape.
///
/// This is the *tested* matrix. It is not a claim about every device.
const Map<String, Size> kDeviceMatrix = {
  '320x568 small phone': Size(320, 568),
  '360x640 compact phone': Size(360, 640),
  '390x844 standard phone': Size(390, 844),
  '412x915 large phone': Size(412, 915),
  '430x932 max phone': Size(430, 932),
  '600x960 small tablet': Size(600, 960),
  '800x1280 tablet': Size(800, 1280),
  '844x390 phone landscape': Size(844, 390),
  '1280x800 tablet landscape': Size(1280, 800),
};

/// Text scales tested (§25).
const List<double> kTextScales = [1.0, 1.3, 1.5, 2.0];

/// Sets the test view to [size] logical pixels, optionally with a bottom
/// system inset (a gesture bar) and a top inset (a status bar / cutout).
void setView(
  WidgetTester tester,
  Size size, {
  double bottomInset = 0,
  double topInset = 0,
  double keyboard = 0,
}) {
  const dpr = 3.0;
  tester.view.physicalSize = Size(size.width * dpr, size.height * dpr);
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = FakeViewPadding(
    top: topInset * dpr,
    bottom: bottomInset * dpr,
  );
  tester.view.viewPadding = FakeViewPadding(
    top: topInset * dpr,
    bottom: bottomInset * dpr,
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * dpr);
  addTearDown(tester.view.reset);
}

/// Sets the platform text scale.
void setTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Collects every Flutter error raised while [body] runs — overflow stripes,
/// layout assertions — instead of letting the first one abort the test, so a
/// failure reports all of them at once (§68, §109).
Future<List<FlutterErrorDetails>> collectLayoutErrors(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// Fails with a readable list if any layout error was collected.
void expectNoLayoutErrors(List<FlutterErrorDetails> errors, String where) {
  expect(
    errors.map((e) => e.exceptionAsString().split('\n').first).toList(),
    isEmpty,
    reason: 'layout errors at $where',
  );
}
