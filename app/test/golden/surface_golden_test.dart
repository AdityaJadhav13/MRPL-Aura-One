@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/design/brand_assets.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/core/components/product_navigation.dart';
import 'package:h2s_doseband/main.dart';

import '../support/signed_in.dart';

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
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          ...routeOverrides(location),
        ],
        child: DoseBandApp(
          key: ValueKey(location),
          config: _dev,
          initialLocation: location,
        ),
      ),
    );
    // Profile and More screens carry the refinery header: decode it for
    // real so the capture does not depend on how far decoding had got.
    final context = tester.element(find.byType(Scaffold).first);
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(BrandAssets.refineryBackdrop),
        context,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  final surfaces = <String, String>{
    'worker-monitoring': '/active',
    'worker-history': '/history',
    'worker-profile': '/profile',
    'worker-settings': '/profile/settings',
    'safety-hub': '/safety',
    'safety-h2s': '/safety/h2s',
    'safety-sds': '/safety/sds',
    'safety-emergency': '/safety/emergency',
    'supervisor-overview': '/supervisor',
    'supervisor-team': '/supervisor/team',
    'supervisor-monitoring': '/supervisor/monitoring',
    'supervisor-exceptions': '/supervisor/exceptions',
    'supervisor-worker': '/supervisor/worker/E-10231',
    'hse-overview': '/hse',
    'hse-exposures': '/hse/exposures',
    'hse-record': '/hse/record/CAP-TEST-1',
    'hse-reports': '/hse/reports',
    'management-overview': '/management',
    'management-monitoring': '/management/monitoring',
    'management-trends': '/management/trends',
    'admin-overview': '/admin',
    'admin-people': '/admin/people',
    'admin-doseband': '/admin/doseband',
    'admin-band': '/admin/doseband/band/DB-2609-0010',
    'admin-system-hub': '/admin/system',
    'admin-integrations': '/admin/integrations',
    'admin-retention': '/admin/retention',
    'admin-calibration': '/admin/calibration',
    'admin-versions': '/admin/versions',
    'admin-more': '/admin/more',
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
    for (final width in <double>[320, 360, 390, 430]) {
      testWidgets('HSE overview at ${width.toInt()} wide', (tester) async {
        await pumpAt(tester, '/hse', size: Size(width, 900));
        expect(tester.takeException(), isNull);
      });
    }

    for (final route in ['/supervisor', '/hse', '/management', '/admin']) {
      testWidgets('$route uses a rail on a wide layout', (tester) async {
        await pumpAt(tester, route, size: const Size(1000, 800));
        expect(tester.takeException(), isNull);
        expect(find.byType(ProductNavigationRail), findsOneWidget);
        expect(find.byType(FloatingNavigationBar), findsNothing);
      });

      testWidgets('$route uses the floating bar on a phone', (tester) async {
        await pumpAt(tester, route, size: const Size(390, 844));
        expect(find.byType(FloatingNavigationBar), findsOneWidget);
        expect(find.byType(ProductNavigationRail), findsNothing);
      });
    }

    for (final route in <String>[
      '/safety',
      '/supervisor',
      '/supervisor/team',
      '/hse',
      '/hse/record/CAP-TEST-1',
      '/hse/reports',
      '/management',
      '/admin',
      '/admin/doseband',
      '/admin/integrations',
    ]) {
      testWidgets('$route at 200% text', (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              environmentConfigProvider.overrideWithValue(_dev),
              ...routeOverrides(route),
            ],
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
