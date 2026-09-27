import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/design/tokens.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/main.dart';

import '../support/prohibited_claims.dart';
import '../support/signed_in.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// The iPhone 16 Pro's safe-area insets.
///
/// Goldens render with no inset at all, which is how a hero sized by a
/// constant once overflowed by 23px on a real handset while every test passed.
const _notch = EdgeInsets.only(top: 59, bottom: 34);

/// The screens §37 names as priorities for the responsive matrix: one per
/// layout archetype, rather than every route at every width.
const _priorityScreens = <String>[
  '/splash',
  '/sign-in',
  '/home',
  '/supervisor',
  '/supervisor/team',
  '/management',
  '/work-context',
  '/active',
  '/result',
  '/read',
  '/safety',
  '/safety/emergency',
  '/hse',
  '/hse/exposures',
  '/hse/record',
  '/reporting',
  '/reporting/register',
  '/reporting/builder',
  '/admin',
  '/admin/integrations',
  '/admin/calibration',
];

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String route, {
    required Size size,
    double textScale = 1,
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          ...routeOverrides(route),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            padding: viewPadding,
            viewPadding: viewPadding,
          ),
          child: DoseBandApp(
            key: ValueKey(route),
            config: _dev,
            initialLocation: route,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  // =====================================================================
  // §37 — responsive matrix
  // =====================================================================

  group('the product holds its layout across phone widths', () {
    for (final width in const [360.0, 390.0, 430.0]) {
      testWidgets('${width.toInt()} px', (tester) async {
        final broken = <String>[];
        for (final route in _priorityScreens) {
          await pumpAt(tester, route, size: Size(width, 9000));
          final error = tester.takeException();
          if (error != null) broken.add('$route -> $error');
        }
        expect(broken, isEmpty, reason: broken.join('\n'));
      });
    }

    testWidgets('wide layout at 900 px', (tester) async {
      final broken = <String>[];
      for (final route in _priorityScreens) {
        await pumpAt(tester, route, size: const Size(900, 1400));
        final error = tester.takeException();
        if (error != null) broken.add('$route -> $error');
      }
      expect(broken, isEmpty, reason: broken.join('\n'));
    });
  });

  // =====================================================================
  // §38 — 200% text
  // =====================================================================

  testWidgets('no priority screen breaks at 200% text', (tester) async {
    final broken = <String>[];
    for (final route in _priorityScreens) {
      await pumpAt(tester, route, size: const Size(360, 20000), textScale: 2);
      final error = tester.takeException();
      if (error != null) broken.add('$route -> $error');
    }
    expect(broken, isEmpty, reason: broken.join('\n'));
  });

  // =====================================================================
  // §39 — safe area / notch
  // =====================================================================

  testWidgets('no priority screen breaks under a notch', (tester) async {
    final broken = <String>[];
    for (final route in _priorityScreens) {
      await pumpAt(
        tester,
        route,
        size: const Size(393, 852),
        viewPadding: _notch,
      );
      final error = tester.takeException();
      if (error != null) broken.add('$route -> $error');
    }
    expect(broken, isEmpty, reason: broken.join('\n'));
  });

  testWidgets('a notch and 200% text together', (tester) async {
    final broken = <String>[];
    for (final route in _priorityScreens) {
      await pumpAt(
        tester,
        route,
        size: const Size(360, 20000),
        textScale: 2,
        viewPadding: _notch,
      );
      final error = tester.takeException();
      if (error != null) broken.add('$route -> $error');
    }
    expect(broken, isEmpty, reason: broken.join('\n'));
  });

  // =====================================================================
  // §40 — accessibility
  // =====================================================================

  group('accessibility', () {
    testWidgets('every route exposes a heading to a screen reader', (
      tester,
    ) async {
      final headless = <String>[];

      // Splash is exempt, and only splash. It carries branding rather than
      // content, advances on its own, and has no title to navigate to; a
      // heading there would be a flag added to satisfy a test.
      for (final route in allRoutes.where((r) => r != '/splash')) {
        await pumpAt(tester, route, size: const Size(390, 9000));
        // A title styled large is a heading only to someone who can see it.
        // The flag is what lets a screen-reader user jump to the top of a
        // screen and tell a title from body text, and both shared scaffolds
        // set it on their title.
        final hasHeader = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .any((s) => s.properties.header ?? false);
        if (!hasHeader) headless.add(route);
      }

      expect(
        headless,
        isEmpty,
        reason: 'no heading on:\n${headless.join('\n')}',
      );
    });

    testWidgets('enabled controls meet the gloved touch target', (
      tester,
    ) async {
      final small = <String>[];

      for (final route in _priorityScreens) {
        await pumpAt(tester, route, size: const Size(390, 9000));
        for (final element in find.byType(FilledButton).evaluate()) {
          final widget = element.widget as FilledButton;
          if (widget.onPressed == null) continue;
          final size = tester.getSize(find.byWidget(widget));
          if (size.height > 0 && size.height < kMinTouchTarget) {
            small.add('$route -> ${size.height.toStringAsFixed(1)}px');
          }
        }
      }

      expect(
        small,
        isEmpty,
        reason:
            'under-sized primary actions:\n'
            '${small.join('\n')}',
      );
    });
  });
}
