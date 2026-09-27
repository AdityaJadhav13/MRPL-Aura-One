import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/main.dart';

import '../support/responsive.dart';
import '../support/signed_in.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// Worker directive §60: the worker flow at every size in the matrix, at
/// 100 % and 200 % text, with a notch and gesture insets. A layout error
/// anywhere fails with the full list.
void main() {
  const sizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
    Size(600, 960),
    Size(800, 1280),
    Size(844, 390), // landscape
  ];
  const routes = <String>[
    '/sign-in',
    '/select-site',
    '/select-role',
    '/home',
    '/profile',
    '/profile/settings',
    '/safety',
    '/history',
  ];

  for (final scale in const [1.0, 2.0]) {
    for (final size in sizes) {
      testWidgets(
        'worker flow at ${size.width.toInt()}x${size.height.toInt()}, '
        '${(scale * 100).round()}% text',
        (tester) async {
          setView(tester, size, topInset: 24, bottomInset: 16);
          setTextScale(tester, scale);
          final errors = await collectLayoutErrors(() async {
            for (final route in routes) {
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    environmentConfigProvider.overrideWithValue(_dev),
                    ...routeOverrides(route, now: DateTime(2026, 9, 27, 8, 4)),
                  ],
                  child: DoseBandApp(
                    key: ValueKey('$route@$size@$scale'),
                    config: _dev,
                    initialLocation: route,
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 400));
            }
          });
          expectNoLayoutErrors(
            errors,
            '${size.width.toInt()}x${size.height.toInt()} ×$scale',
          );
        },
      );
    }
  }
}
