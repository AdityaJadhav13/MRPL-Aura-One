import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/product_navigation.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/core/util/format.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

const _prod = EnvironmentConfig(
  environment: AppEnvironment.prod,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// Journeys through the role surfaces, and the honesty rules that must hold on
/// every one of them.
void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String location, {
    EnvironmentConfig config = _dev,
    Size size = const Size(390, 2200),
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [environmentConfigProvider.overrideWithValue(config)],
        child: DoseBandApp(
          key: ValueKey(location),
          config: config,
          initialLocation: location,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Every visible string on the current screen, lower-cased.
  List<String> visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').toLowerCase())
      .where((t) => t.isNotEmpty)
      .toList();

  group('every role lands somewhere real', () {
    test('each role declares a landing route', () {
      for (final role in AppRole.values) {
        expect(role.landingRoute, isNotEmpty, reason: role.name);
      }
    });

    test('built roles land on their own shell, not the worker journey', () {
      expect(AppRole.worker.landingRoute, '/home');
      expect(AppRole.hseOfficer.landingRoute, '/hse');
      expect(AppRole.administrator.landingRoute, '/admin');
      expect(AppRole.supervisor.landingRoute, '/supervisor');
      expect(AppRole.management.landingRoute, '/management');
    });
  });

  group('worker navigation is the approved five destinations', () {
    // APP-PRODUCT-01 §6 superseded UI-SURFACE-01's four-tab rule: Profile is
    // now a destination, and Scan is the centre, primary action.
    testWidgets('Home, History, Scan, Safety, Profile — and nothing else', (
      tester,
    ) async {
      await pumpAt(tester, '/home', size: const Size(390, 844));
      final bar = tester.widget<FloatingNavigationBar>(
        find.byType(FloatingNavigationBar),
      );
      expect(bar.destinations.map((d) => d.label), [
        'Home',
        'History',
        'Scan',
        'Safety',
        'Profile',
      ]);
      // Scan, and only Scan, is the primary action — and it is the centre.
      expect(
        bar.destinations.where((d) => d.isPrimaryAction).map((d) => d.label),
        ['Scan'],
      );
      expect(bar.destinations[2].isPrimaryAction, isTrue);
      // These are reached from the work they belong to, never promoted to
      // a tab.
      for (final absent in ['PTW', 'JSA', 'Badge', 'Reports']) {
        expect(
          find.descendant(
            of: find.byType(FloatingNavigationBar),
            matching: find.text(absent),
          ),
          findsNothing,
          reason: absent,
        );
      }
    });

    testWidgets('account is reachable from the worker identity card', (
      tester,
    ) async {
      // The semantics tree is not built unless something asks for it, and
      // this assertion is specifically about what a screen-reader user can
      // reach.
      // Disposed explicitly rather than in a tearDown: the framework verifies
      // that no handle outlives the test body, and a tearDown runs after that
      // check.
      final semantics = tester.ensureSemantics();

      await pumpAt(tester, '/home', size: const Size(390, 844));
      // A substring match: the card's own label merges with the worker
      // details beneath it, which is what a screen reader should read out.
      expect(
        find.bySemanticsLabel(RegExp('Account and profile')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('safety surface', () {
    testWidgets('the hub says DoseBand is not a real-time gas alarm', (
      tester,
    ) async {
      await pumpAt(tester, '/safety');
      expect(
        find.text('DoseBand is not a real-time gas alarm'),
        findsOneWidget,
      );
      // And that it does not replace a detector, which is the belief the
      // sentence exists to prevent.
      expect(
        find.textContaining('does not replace portable or fixed gas'),
        findsOneWidget,
      );
    });

    for (final route in <String, String>{
      '/safety/h2s': 'Hydrogen sulphide',
      '/safety/emergency': 'Emergency',
      '/safety/hazard': 'Near miss or hazard',
      '/safety/occupational-health': 'Occupational health',
      '/safety/ptw': 'Permit to Work',
      '/safety/jsa': 'Job Safety Analysis',
      '/safety/ppe': 'PPE',
      '/safety/toolbox': 'Toolbox resources',
      '/safety/sds': 'Safety data sheets',
      '/safety/offline': 'Offline documents',
    }.entries) {
      testWidgets('${route.key} renders', (tester) async {
        await pumpAt(tester, route.key);
        expect(tester.takeException(), isNull);
        expect(find.text(route.value), findsWidgets);
      });
    }

    testWidgets('emergency invents no contact details', (tester) async {
      await pumpAt(tester, '/safety/emergency');
      final text = visibleText(tester).join(' ');

      expect(find.text('Not configured'), findsOneWidget);
      // No phone number, however formatted.
      expect(RegExp(r'\b\d{3,}\s?\d{3,}\b').hasMatch(text), isFalse);
      expect(text, isNot(contains('assembly point is')));
      expect(text, contains('follow site alarms'));
    });

    testWidgets('the hazard handoff cannot be submitted', (tester) async {
      await pumpAt(tester, '/safety/hazard');
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue to organisation reporting'),
      );
      // A button that looks like it files a hazard report and does nothing is
      // the most dangerous control this product could ship.
      expect(button.onPressed, isNull);
    });
  });

  group('HSE surface', () {
    testWidgets('the dashboard reaches its destinations', (tester) async {
      await pumpAt(tester, '/hse', size: const Size(390, 844));
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(4));
      for (final label in ['Overview', 'Monitoring', 'Exposures', 'Review']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    for (final route in <String, String>{
      '/hse/monitoring': 'Monitoring',
      '/hse/exposures': 'Exposure register',
      '/hse/review': 'Review',
      '/hse/workers': 'Workers',
      '/hse/exceptions': 'Exceptions',
      '/hse/inventory': 'Badge inventory',
      '/hse/calibration': 'Calibration',
      '/hse/audit': 'Audit trail',
    }.entries) {
      testWidgets('${route.key} renders', (tester) async {
        await pumpAt(tester, route.key);
        expect(tester.takeException(), isNull);
        expect(find.text(route.value), findsWidgets);
      });
    }

    testWidgets('calibration says no production model exists', (tester) async {
      await pumpAt(tester, '/hse/calibration');
      expect(find.text('No production calibration available'), findsOneWidget);
      // The three gates stay visible; UI progress must not hide them.
      for (final gate in ['S1', 'S2', 'S3']) {
        expect(find.text(gate), findsOneWidget, reason: gate);
      }
      expect(find.text('OPEN'), findsNWidgets(3));
    });

    testWidgets('demo screens say they are demo', (tester) async {
      for (final route in ['/hse', '/hse/exposures', '/hse/monitoring']) {
        await pumpAt(tester, route);
        expect(find.text('DEMONSTRATION DATA'), findsWidgets, reason: route);
      }
    });
  });

  group('reporting surface', () {
    testWidgets('the centre lists report templates', (tester) async {
      await pumpAt(tester, '/reporting');
      expect(find.text('Internal templates'), findsOneWidget);
      // Listed twice on purpose: once as a shortcut under "Start here",
      // once in its category. It is the backbone screen of the subsystem.
      expect(find.text('Occupational exposure register'), findsWidgets);
    });

    testWidgets('no report claims regulatory compliance', (tester) async {
      await pumpAt(tester, '/reporting');
      final text = visibleText(tester).join(' ');
      for (final claim in ['oisd', 'dgms', 'compliant', 'certified']) {
        expect(text, isNot(contains(claim)), reason: claim);
      }
    });
  });

  group('admin surface', () {
    for (final route in <String, String>{
      '/admin': 'Administration',
      '/admin/integrations': 'Integration status',
      '/admin/users': 'Users and roles',
      '/admin/sites': 'Sites',
      '/admin/departments': 'Departments',
      '/admin/work-areas': 'Work areas',
      '/admin/devices': 'Devices',
      '/admin/retention': 'Retention',
      '/admin/sync': 'Sync health',
      '/admin/system': 'System information',
    }.entries) {
      testWidgets('${route.key} renders', (tester) async {
        await pumpAt(tester, route.key);
        expect(tester.takeException(), isNull);
        expect(find.text(route.value), findsWidgets);
      });
    }

    testWidgets('no integration is shown as connected', (tester) async {
      await pumpAt(tester, '/admin/integrations');
      expect(find.text('Nothing is connected'), findsOneWidget);
      expect(find.text('Not connected'), findsWidgets);
      // There is no code path that renders "Connected", and this is what
      // keeps it that way.
      final text = visibleText(tester);
      expect(text.where((t) => t.trim() == 'connected'), isEmpty);
    });

    testWidgets('system information keeps the limitations visible', (
      tester,
    ) async {
      await pumpAt(tester, '/admin/system');
      final text = visibleText(tester).join(' ');
      expect(text, contains('no quantitative h₂s calibration exists'));
      expect(text, contains('s1'));
      expect(text, contains('are open'));
      expect(text, contains('forward device-clock jumps cannot be detected'));
    });
  });

  group('measurement honesty holds across every surface', () {
    const surfaces = [
      '/hse',
      '/hse/exposures',
      '/hse/review',
      '/hse/exceptions',
      '/reporting',
      '/admin/system',
    ];

    testWidgets('no surface prints a fabricated dose', (tester) async {
      for (final route in surfaces) {
        await pumpAt(tester, route);
        final text = visibleText(tester);
        for (final line in text) {
          // No calibration exists, so no ppm or ppm·h figure may appear
          // anywhere. Prose mentioning the unit is fine; a number attached to
          // it is not.
          expect(
            RegExp(r'\d+(\.\d+)?\s*ppm').hasMatch(line),
            isFalse,
            reason: '$route rendered "$line"',
          );
        }
      }
    });

    testWidgets('a refusal never becomes zero', (tester) async {
      await pumpAt(tester, '/hse/exceptions');
      final text = visibleText(tester);

      // The refusal placeholder is present...
      expect(text, contains(Fmt.noValue));
      // ...and no record shows a zero exposure.
      for (final line in text) {
        expect(
          RegExp(r'^0(\.0+)?\s*(ppm|ppm·h)$').hasMatch(line.trim()),
          isFalse,
          reason: 'rendered "$line"',
        );
      }
    });

    testWidgets('no surface calls an exposure safe or normal', (tester) async {
      for (final route in surfaces) {
        await pumpAt(tester, route);
        for (final line in visibleText(tester)) {
          for (final word in [
            'exposure is safe',
            'within safe',
            'normal exposure',
          ]) {
            expect(line, isNot(contains(word)), reason: '$route: $line');
          }
        }
      }
    });

    testWidgets('a worker profile shows no cumulative total', (tester) async {
      await pumpAt(tester, '/hse/workers');
      await tester.tap(find.text('Aditya Jadhav').first);
      await tester.pumpAndSettle();

      expect(find.text('Cumulative exposure'.toUpperCase()), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        find.textContaining('does not present a lifetime or cumulative'),
        findsOneWidget,
      );
    });
  });

  group('production guards', () {
    testWidgets('presentation accounts are absent from a production build', (
      tester,
    ) async {
      await pumpAt(tester, '/sign-in', config: _prod);
      expect(find.text('Presentation accounts'), findsNothing);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('presentation accounts exist in a development build', (
      tester,
    ) async {
      await pumpAt(tester, '/sign-in');
      expect(find.text('Presentation accounts'), findsOneWidget);
    });
  });
}
