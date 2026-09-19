@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// Goldens for the navigation shell and its four destinations, in both themes.
void main() {
  for (final brightness in Brightness.values) {
    final mode = brightness.name;

    for (final destination in ['Home', 'Scan', 'History', 'Profile']) {
      testWidgets('$destination · $mode', (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await tester.pumpWidget(const DoseBandApp(config: _dev));
        await tester.pumpAndSettle();

        if (destination != 'Home') {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(destination),
            ),
          );
          await tester.pumpAndSettle();
        }

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/shell-${destination.toLowerCase()}-$mode.png',
          ),
        );
      });
    }
  }
}
