import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/buttons.dart';
import 'package:h2s_doseband/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:h2s_doseband/core/components/product_navigation.dart';
import 'package:h2s_doseband/core/design/tokens.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/main.dart';

import '../support/signed_in.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// PRODUCT BUILD v1 §70, §78, §128 — the controls a gloved worker and a
/// supervisor rely on are large enough to hit, on the smallest phone in the
/// matrix and at 200% text.
void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String route, {
    Size size = const Size(320, 568),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(size.width * 3, size.height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          ...routeOverrides(route),
        ],
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: DoseBandApp(
            key: ValueKey('$route$textScale'),
            config: _dev,
            initialLocation: route,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  void expectTarget(WidgetTester tester, Finder f, double min, String what) {
    expect(f, findsWidgets, reason: what);
    for (final e in f.evaluate()) {
      final size = (e.renderObject! as RenderBox).size;
      expect(size.height, greaterThanOrEqualTo(min), reason: '$what height');
      expect(size.width, greaterThanOrEqualTo(min), reason: '$what width');
    }
  }

  Finder primary(String label) =>
      find.byWidgetPredicate(
        (w) =>
            (w is DoseBandButton && w.label == label) ||
            (w is AuthPrimaryButton && w.label == label),
      );

  for (final scale in [1.0, 2.0]) {
    testWidgets('worker navigation and central Scan at ${scale}x', (
      tester,
    ) async {
      await pumpAt(tester, '/home', textScale: scale);
      final items = find.descendant(
        of: find.byType(FloatingNavigationBar),
        matching: find.byType(InkWell),
      );
      expectTarget(tester, items, kMinInteractive, 'navigation destination');
    });

    testWidgets('Home primary action at ${scale}x', (tester) async {
      await pumpAt(tester, '/home', textScale: scale);
      // At 200 % on a 320 phone the card is tall; the action is one scroll
      // below it, never hidden behind the navigation.
      await tester.scrollUntilVisible(primary('Scan new DoseBand'), 120);
      expectTarget(
        tester,
        primary('Scan new DoseBand'),
        kMinTouchTarget,
        'Scan new DoseBand',
      );
    });

    testWidgets('sign-in action at ${scale}x', (tester) async {
      await pumpAt(tester, '/sign-in', textScale: scale);
      expectTarget(tester, primary('Sign In'), kMinTouchTarget, 'Sign In');
    });

    testWidgets('pre-use check action at ${scale}x', (tester) async {
      await pumpAt(tester, '/doseband/check/DB-2609-0011', textScale: scale);
      await tester.pump(const Duration(milliseconds: 300));
      expectTarget(
        tester,
        primary('Photograph the DoseBand'),
        kMinTouchTarget,
        'Photograph the DoseBand',
      );
    });

    testWidgets('supervisor navigation at ${scale}x', (tester) async {
      await pumpAt(tester, '/supervisor', textScale: scale);
      final items = find.descendant(
        of: find.byType(FloatingNavigationBar),
        matching: find.byType(InkWell),
      );
      expectTarget(tester, items, kMinInteractive, 'supervisor destination');
    });
  }
}
