import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/states.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// Every route that takes its subject through `GoRouterState.extra`.
///
/// These are the routes a deep link, a typed address or a cold-start restore
/// can reach without the record they exist to display. Each one used to write
/// `state.extra! as T` and throw. See [MissingRouteContextScreen].
const _extraRoutes = <String>[
  '/verify',
  '/result',
  '/measurement',
  '/hse/record',
  '/hse/disposition',
  '/hse/handoff',
  '/hse/session',
  '/hse/worker',
  '/hse/batch',
  '/reporting/report',
  '/reporting/record',
  '/reporting/preview',
];

void main() {
  Future<void> pumpAt(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(780, 6000);
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

  group('a detail route reached without its record explains itself', () {
    for (final route in _extraRoutes) {
      testWidgets(route, (tester) async {
        await pumpAt(tester, route);

        // The failure this replaces was an uncaught cast exception.
        expect(
          tester.takeException(),
          isNull,
          reason: '$route threw when opened without extra',
        );
        expect(
          find.byType(MissingRouteContextScreen),
          findsOneWidget,
          reason: '$route should explain the absence, not render blank',
        );
        // And it is not a dead end: there is always a way back to a list.
        expect(find.byType(FilledButton), findsWidgets);
      });
    }
  });

  testWidgets('the recovery action leads somewhere real', (tester) async {
    await pumpAt(tester, '/reporting/record');
    expect(find.byType(MissingRouteContextScreen), findsOneWidget);

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(find.byType(MissingRouteContextScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
