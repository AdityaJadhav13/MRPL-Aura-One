import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/main.dart';

import '../support/prohibited_claims.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// The whole-application sweep behind the UI freeze.
///
/// Every route, against every prohibited claim. Module tests carry their own
/// narrower lists with the reasoning attached; this one exists so that no
/// surface is protected only by the list its own test file happens to have.
void main() {
  Future<void> pumpAt(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(780, 16000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [environmentConfigProvider.overrideWithValue(_dev)],
        child: DoseBandApp(
          key: ValueKey(route),
          config: _dev,
          initialLocation: route,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  String visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join(' \u0000 ')
      .toLowerCase();

  testWidgets('no route makes a prohibited claim', (tester) async {
    final violations = <String>[];

    for (final route in allRoutes) {
      await pumpAt(tester, route);
      final text = visibleText(tester);
      for (final claim in allProhibitedClaims) {
        if (assertsClaim(text, claim)) {
          violations.add('$route -> "$claim"');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'DoseBand may not make these claims anywhere:\n'
          '${violations.join('\n')}',
    );
  });

  testWidgets('every route renders without throwing', (tester) async {
    final broken = <String>[];

    for (final route in allRoutes) {
      await pumpAt(tester, route);
      final error = tester.takeException();
      if (error != null) broken.add('$route -> $error');
    }

    expect(broken, isEmpty, reason: 'routes that threw:\n${broken.join('\n')}');
  });

  // A sweep that matches nothing proves nothing. This confirms the matcher
  // would actually fire, so a future change to how text is collected cannot
  // silently turn the whole suite into a no-op.
  test('the sweep can detect a claim', () {
    const sample = 'This worker is SAFE TO WORK in the unit.';
    expect(allProhibitedClaims.any((c) => assertsClaim(sample, c)), isTrue);

    // ...and that a denial of the same claim is not flagged, which is the
    // failure mode that would quietly push an author to delete the denial.
    const denial = 'This does not mean the worker is safe to work.';
    expect(allProhibitedClaims.any((c) => assertsClaim(denial, c)), isFalse);
  });
}
