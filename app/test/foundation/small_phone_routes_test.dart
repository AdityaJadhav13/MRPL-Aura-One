import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/main.dart';

import '../support/prohibited_claims.dart';
import '../support/responsive.dart';
import '../support/signed_in.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// Every parameterless route on the smallest phone in the matrix, at 100% and
/// 200% text (APP-PRODUCT-01 §68, §109).
///
/// The earlier route sweeps start at 360 wide. This one found three overflows
/// at 320 / 200% that nothing else covered — processing, the guided scan and
/// the QR viewfinder — which were fixed in Phase 0.
void main() {
  for (final scale in const [1.0, 2.0]) {
    for (final route in allRoutes) {
      testWidgets('$route at 320x568, ${(scale * 100).round()}% text', (
        tester,
      ) async {
        setView(tester, const Size(320, 568), topInset: 24, bottomInset: 16);
        setTextScale(tester, scale);
        final errors = await collectLayoutErrors(() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                environmentConfigProvider.overrideWithValue(_dev),
                ...routeOverrides(route, now: DateTime(2026, 9, 27, 8, 4)),
              ],
              child: DoseBandApp(
                key: ValueKey('$route@$scale'),
                config: _dev,
                initialLocation: route,
              ),
            ),
          );
          // Fixed frames: several screens hold indeterminate progress.
          await tester.pump(const Duration(milliseconds: 500));
          // Let the splash's own timer fire so none is left pending.
          await tester.pump(const Duration(seconds: 2));
          await tester.pump(const Duration(milliseconds: 500));
        });
        expectNoLayoutErrors(errors, '$route ×$scale');
      });
    }
  }
}
