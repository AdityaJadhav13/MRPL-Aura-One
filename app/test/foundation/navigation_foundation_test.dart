import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:h2s_doseband/core/components/product_navigation.dart';
import 'package:h2s_doseband/core/components/states.dart';
import 'package:h2s_doseband/core/design/tokens.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/history/history_screen.dart';
import 'package:h2s_doseband/features/profile/profile_screen.dart';
import 'package:h2s_doseband/features/safety/presentation/safety_hub_screen.dart';
import 'package:h2s_doseband/features/scan/scan_screen.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/main.dart';

import '../support/responsive.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

Future<void> _pump(WidgetTester tester, {String at = '/home'}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 27, 8, 4)),
      ],
      child: DoseBandApp(key: ValueKey(at), config: _dev, initialLocation: at),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _barItem(String label) => find.descendant(
  of: find.byType(FloatingNavigationBar),
  matching: find.text(label),
);

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('worker navigation (§31, §84)', () {
    testWidgets('five destinations in the approved order, Scan in the centre', (
      tester,
    ) async {
      setView(tester, const Size(390, 844));
      await _pump(tester);
      final bar = tester.widget<FloatingNavigationBar>(
        find.byType(FloatingNavigationBar),
      );
      expect(bar.destinations.map((d) => d.label).toList(), [
        'Home',
        'History',
        'Scan',
        'Safety',
        'Profile',
      ]);
      expect(bar.destinations[2].isPrimaryAction, isTrue);

      // Scan is visibly centred in the bar.
      final barRect = tester.getRect(find.byType(FloatingNavigationBar));
      final scanRect = tester.getRect(_barItem('Scan'));
      expect((scanRect.center.dx - barRect.center.dx).abs(), lessThan(2));
    });

    testWidgets('every destination opens its own screen, and the URL follows', (
      tester,
    ) async {
      setView(tester, const Size(390, 844));
      await _pump(tester);
      final expected = <String, (Type, String)>{
        'History': (HistoryScreen, '/history'),
        'Scan': (ScanScreen, '/scan'),
        'Safety': (SafetyHubScreen, '/safety'),
        'Profile': (ProfileScreen, '/profile'),
      };
      final visited = <String>{};
      for (final e in expected.entries) {
        await tester.tap(_barItem(e.key));
        await tester.pumpAndSettle();
        expect(find.byType(e.value.$1), findsOneWidget, reason: e.key);
        final here = _location(tester);
        expect(here, e.value.$2);
        visited.add(here);
      }
      // Route-sweep integrity (§34): the test really moved.
      expect(visited, hasLength(expected.length));
    });

    testWidgets('selected state is announced, not only coloured', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      setView(tester, const Size(390, 844));
      await _pump(tester, at: '/safety');

      final safety = tester.getSemantics(
        find
            .ancestor(of: _barItem('Safety'), matching: find.byType(Semantics))
            .first,
      );
      expect(
        safety,
        isSemantics(isSelected: true, isButton: true, label: 'Safety'),
      );

      final home = tester.getSemantics(
        find
            .ancestor(of: _barItem('Home'), matching: find.byType(Semantics))
            .first,
      );
      expect(home, isSemantics(isSelected: false, label: 'Home'));
      handle.dispose();
    });

    testWidgets('every destination is at least a gloved-thumb target', (
      tester,
    ) async {
      setView(tester, const Size(320, 568));
      await _pump(tester);
      for (final label in ['Home', 'History', 'Scan', 'Safety', 'Profile']) {
        final item = find
            .ancestor(of: _barItem(label), matching: find.byType(InkWell))
            .first;
        final size = tester.getSize(item);
        expect(
          size.width,
          greaterThanOrEqualTo(kMinTouchTarget),
          reason: label,
        );
        expect(
          size.height,
          greaterThanOrEqualTo(kMinTouchTarget),
          reason: label,
        );
      }
    });

    testWidgets('the bar clears the gesture bar and the status bar', (
      tester,
    ) async {
      // A gesture-navigation phone: 24-point status bar, 34-point home
      // indicator.
      setView(tester, const Size(390, 844), topInset: 24, bottomInset: 34);
      await _pump(tester);
      final bar = tester.getRect(find.byType(FloatingNavigationBar));
      // The bar's own surface, not its safe-area padding, must end above
      // the system inset.
      final surface = tester.getRect(
        find
            .descendant(
              of: find.byType(FloatingNavigationBar),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(surface.bottom, lessThanOrEqualTo(844 - 34));
      expect(bar.bottom, 844);
    });

    testWidgets('the last item of a long screen is never under the bar', (
      tester,
    ) async {
      setView(tester, const Size(360, 640), bottomInset: 24);
      await _pump(tester, at: '/safety');
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -20000));
      await tester.pumpAndSettle();

      final barTop = tester
          .getRect(
            find
                .descendant(
                  of: find.byType(FloatingNavigationBar),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .top;
      final body = tester.renderObject<RenderBox>(scrollable);
      final bodyBottom = body.localToGlobal(Offset(0, body.size.height)).dy;
      expect(bodyBottom, lessThanOrEqualTo(barTop));
    });

    testWidgets('the bar steps aside for the keyboard', (tester) async {
      setView(tester, const Size(360, 640), keyboard: 300);
      await _pump(tester);
      expect(find.byType(FloatingNavigationBar), findsNothing);
    });

    testWidgets('nav labels stop growing at 130%, and nothing overflows', (
      tester,
    ) async {
      setView(tester, const Size(320, 568));
      setTextScale(tester, 2.0);
      final errors = await collectLayoutErrors(() => _pump(tester));
      expectNoLayoutErrors(errors, '320 at 200%');
      final label = tester.widget<Text>(_barItem('History'));
      final scaler = MediaQuery.textScalerOf(
        tester.element(_barItem('History')),
      );
      expect(scaler.scale(10), closeTo(13, 0.01));
      expect(label.data, 'History');
    });
  });

  group('adaptive navigation (§32)', () {
    testWidgets('a rail at 720 and wider, a bar below', (tester) async {
      setView(tester, const Size(719, 1000));
      await _pump(tester);
      expect(find.byType(FloatingNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      setView(tester, const Size(720, 1000));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingNavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('the selection survives crossing the breakpoint', (
      tester,
    ) async {
      setView(tester, const Size(390, 844));
      await _pump(tester);
      await tester.tap(_barItem('Safety'));
      await tester.pumpAndSettle();

      // Rotate to a landscape tablet.
      setView(tester, const Size(1280, 800));
      await tester.pumpAndSettle();
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 3);
      expect(find.byType(SafetyHubScreen), findsOneWidget);

      // And back.
      setView(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      final bar = tester.widget<FloatingNavigationBar>(
        find.byType(FloatingNavigationBar),
      );
      expect(bar.selectedIndex, 3);
    });
  });

  group('back and deep links (§33, §84)', () {
    testWidgets('back from a pushed detail returns to the tab it came from', (
      tester,
    ) async {
      setView(tester, const Size(390, 844));
      await _pump(tester, at: '/safety');
      _router(tester).push('/safety/h2s');
      await tester.pumpAndSettle();
      expect(find.byType(FloatingNavigationBar), findsNothing);

      // The Android back button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SafetyHubScreen), findsOneWidget);
      expect(find.byType(FloatingNavigationBar), findsOneWidget);
    });

    for (final route in ['/result', '/measurement', '/verify', '/hse/record']) {
      testWidgets('$route without its record explains itself, never throws', (
        tester,
      ) async {
        setView(tester, const Size(360, 640));
        await _pump(tester, at: route);
        expect(tester.takeException(), isNull);
        expect(find.byType(MissingRouteContextScreen), findsOneWidget);
      });
    }
  });

  group('the worker shell across the device matrix (§69, §109)', () {
    for (final device in kDeviceMatrix.entries) {
      for (final scale in kTextScales) {
        testWidgets('${device.key} at ${(scale * 100).round()}%', (
          tester,
        ) async {
          setView(tester, device.value, bottomInset: 16, topInset: 24);
          setTextScale(tester, scale);
          final errors = await collectLayoutErrors(() async {
            await _pump(tester);
            for (final label in ['History', 'Scan', 'Safety', 'Profile']) {
              final target =
                  find.byType(FloatingNavigationBar).evaluate().isEmpty
                  ? find.descendant(
                      of: find.byType(NavigationRail),
                      matching: find.text(label),
                    )
                  : _barItem(label);
              await tester.tap(target);
              await tester.pumpAndSettle();
            }
          });
          expectNoLayoutErrors(errors, '${device.key} ×$scale');
        });
      }
    }
  });
}
