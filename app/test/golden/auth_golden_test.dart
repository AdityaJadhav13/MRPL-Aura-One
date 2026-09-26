@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// Goldens for the corporate authentication shell.
///
/// These are the visual review artefact for the flow: four screens that have
/// to read as one product. Rendered at the design target and in both themes.
void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String location, {
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [environmentConfigProvider.overrideWithValue(_dev)],
        child: DoseBandApp(
          key: ValueKey(location),
          config: _dev,
          initialLocation: location,
        ),
      ),
    );
    // Pump rather than settle: the splash holds a repeating progress
    // indicator, and settling would wait for an animation that never ends.
    await tester.pump(const Duration(milliseconds: 700));
  }

  final screens = <String, String>{
    'splash': '/splash',
    'sign-in': '/sign-in',
    'select-site': '/select-site',
    'select-role': '/select-role',
  };

  for (final brightness in Brightness.values) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} · ${brightness.name}', (tester) async {
        await pumpAt(tester, entry.value, brightness: brightness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/auth-${entry.key}-${brightness.name}.png'),
        );
        // The splash schedules its own advance; let it fire so no timer is
        // left pending when the test binding tears down.
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      });
    }
  }

  testWidgets('sign-in · contractor mode', (tester) async {
    await pumpAt(tester, '/sign-in');
    await tester.tap(find.text('Contractor'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-sign-in-contractor.png'),
    );
  });

  testWidgets('select-site · selected', (tester) async {
    await pumpAt(tester, '/select-site');
    await tester.tap(find.text('Mangalore Refinery'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-select-site-selected.png'),
    );
  });

  testWidgets('select-role · selected', (tester) async {
    await pumpAt(tester, '/select-role');
    await tester.tap(find.text('Worker'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-select-role-selected.png'),
    );
  });

  testWidgets('sign-in · compact 360 at 150% text', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 780 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [environmentConfigProvider.overrideWithValue(_dev)],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: DoseBandApp(
            key: ValueKey('/sign-in'),
            config: _dev,
            initialLocation: '/sign-in',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-sign-in-compact-large-text.png'),
    );
  });
}
