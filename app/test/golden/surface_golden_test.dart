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

/// Goldens for the Safety, HSE, Reporting and Admin surfaces.
///
/// These are the visual review artefact for UI-SURFACE-01. The point is not
/// pixel regression — it is that a reviewer can look at every role's landing
/// screen side by side and see one product rather than four.
void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String location, {
    Size size = const Size(390, 900),
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

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
    await tester.pump(const Duration(milliseconds: 400));
  }

  final surfaces = <String, String>{
    'worker-monitoring': '/active',
    'safety-hub': '/safety',
    'safety-h2s': '/safety/h2s',
    'safety-emergency': '/safety/emergency',
    'hse-dashboard': '/hse',
    'hse-exposures': '/hse/exposures',
    'hse-calibration': '/hse/calibration',
    'reporting-centre': '/reporting',
    'reporting-register': '/reporting/register',
    'admin-home': '/admin',
    'admin-integrations': '/admin/integrations',
    'admin-users': '/admin/users',
    'admin-user-detail': '/admin/users/CT-45832',
    'admin-retention': '/admin/retention',
    'admin-calibration': '/admin/calibration',
    'admin-versions': '/admin/versions',
    'admin-system': '/admin/system',
  };

  for (final entry in surfaces.entries) {
    testWidgets('${entry.key} renders', (tester) async {
      await pumpAt(tester, entry.value);

      // No overflow, no thrown layout exception.
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${entry.key}.png'),
      );
    });
  }

  group('the surfaces survive real constraints', () {
    testWidgets('HSE active monitoring renders', (tester) async {
      // No pixel golden for this one. It shows elapsed time against the wall
      // clock, so its image changes every minute — a golden here would fail
      // on a schedule rather than on a regression, and the usual fix for that
      // is to stop trusting goldens. The assertion that matters is that it
      // lays out and shows a duration slot.
      await pumpAt(tester, '/hse/monitoring');
      expect(tester.takeException(), isNull);
      expect(find.text('Monitoring'), findsWidgets);
    });

    for (final width in <double>[360, 390, 430]) {
      testWidgets('HSE dashboard at ${width.toInt()} wide', (tester) async {
        await pumpAt(tester, '/hse', size: Size(width, 900));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('HSE uses a rail on a wide layout', (tester) async {
      await pumpAt(tester, '/hse', size: const Size(1000, 800));
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('HSE uses a bottom bar on a phone', (tester) async {
      await pumpAt(tester, '/hse', size: const Size(390, 844));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    for (final route in <String>[
      '/safety',
      '/hse',
      '/reporting',
      '/admin',
      '/admin/integrations',
    ]) {
      testWidgets('$route at 200% text', (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [environmentConfigProvider.overrideWithValue(_dev)],
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: DoseBandApp(
                key: ValueKey(route),
                config: _dev,
                initialLocation: route,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
