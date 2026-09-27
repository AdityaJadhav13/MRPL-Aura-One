import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/admin/data/admin_demo_catalog.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/main.dart';

import '../support/signed_in.dart';

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

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String route, {
    Size size = const Size(390, 6000),
    double textScale = 1,
    EnvironmentConfig config = _dev,
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(config),
          ...routeOverrides(route),
        ],
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: DoseBandApp(
            key: ValueKey(route),
            config: config,
            initialLocation: route,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  List<String> visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').toLowerCase())
      .where((t) => t.isNotEmpty)
      .toList();

  const adminRoutes = <String, String>{
    '/admin': 'Administration',
    '/admin/people': 'People',
    '/admin/people/CT-45832': 'Roles and scopes',
    '/admin/doseband': 'DoseBand inventory',
    '/admin/doseband/lot/LOT-2609-A': 'Lot LOT-2609-A',
    '/admin/doseband/band/DB-2609-0010': 'QR label',
    '/admin/system': 'System',
    '/admin/audit': 'Audit log',
    '/admin/integrations': 'Integration status',
    '/admin/sites': 'Sites',
    '/admin/departments': 'Departments',
    '/admin/work-areas': 'Work areas',
    '/admin/organisation': 'Organisation',
    '/admin/integrations/ptw': 'Permit to Work',
    '/admin/retention': 'Retention',
    '/admin/versions': 'Versions',
    '/admin/sync': 'Sync health',
    '/admin/calibration': 'Calibration',
    '/admin/badges': 'Badge configuration',
    '/admin/demo-data': 'Presentation data',
    '/admin/system/info': 'System information',
  };

  // ===================================================================
  // Reachability
  // ===================================================================

  group('every admin route renders', () {
    for (final entry in adminRoutes.entries) {
      testWidgets(entry.key, (tester) async {
        await pumpAt(tester, entry.key);
        expect(
          find.text(entry.value),
          findsWidgets,
          reason: '${entry.key} should show "${entry.value}"',
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('admin screens survive 200% text scale', (tester) async {
    for (final route in adminRoutes.keys) {
      await pumpAt(tester, route, textScale: 2, size: const Size(390, 12000));
      expect(
        tester.takeException(),
        isNull,
        reason: '$route overflowed at 200% text',
      );
    }
  });

  // ===================================================================
  // §46 — no integration may claim to be connected
  // ===================================================================

  group('nothing claims to be connected', () {
    test('the catalog has no connected state to render', () {
      // If someone adds one, this fails before any screen can show it.
      expect(
        IntegrationState.values.map((s) => s.name),
        isNot(contains('connected')),
      );
      for (final integration in AdminDemoCatalog.integrations()) {
        expect(integration.state, IntegrationState.notConnected);
        expect(integration.lastSuccess, isNull);
        expect(integration.lastAttempt, isNull);
      }
    });

    testWidgets('integration status says so for every entry', (tester) async {
      await pumpAt(tester, '/admin/integrations');
      final text = visibleText(tester);
      expect(text.where((t) => t.contains('not connected')), isNotEmpty);
      expect(
        text.any((t) => t == 'connected' || t.contains('· connected')),
        isFalse,
        reason: 'no integration may render as connected',
      );
      // A last-success timestamp would be a fabricated event.
      expect(text.where((t) => t.contains('last attempt')), isNotEmpty);
      expect(text.where((t) => t == 'never'), isNotEmpty);
    });

    testWidgets('an integration detail shows never, not a date', (
      tester,
    ) async {
      await pumpAt(tester, '/admin/integrations/backend');
      final text = visibleText(tester);
      expect(text, contains('never'));
      expect(
        text.any((t) => t.contains('last success') && t.contains('20')),
        isFalse,
      );
    });
  });

  // ===================================================================
  // §47 — no fabricated MRPL enterprise identity
  // ===================================================================

  group('administration is not exposure access (§45, §149)', () {
    testWidgets('an account shows roles and scopes, never exposure', (
      tester,
    ) async {
      await pumpAt(tester, '/admin/people/CT-45832');
      final text = visibleText(tester).join(' ');
      expect(text, contains('roles and scopes'));
      for (final forbidden in const [
        'no reading',
        'ppm',
        'exposure record',
        'monitoring active',
        'db-2609',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    testWidgets('an in-use band shows its state, not who holds it', (
      tester,
    ) async {
      // DB-2609-0001 is being worn by Lavitra in the presentation dataset.
      await pumpAt(tester, '/admin/doseband/band/DB-2609-0001');
      final text = visibleText(tester).join(' ');
      expect(text, contains('doseband in use'));
      expect(text, isNot(contains('lavitra')));
      expect(text, contains('not while it is in use'));
    });

    testWidgets('no enterprise directory is claimed', (tester) async {
      await pumpAt(tester, '/admin/people');
      final text = visibleText(tester).join(' ');
      expect(text, contains('no organisation directory is connected'));
      for (final forbidden in const ['sso enabled', 'ldap connected', 'sap']) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  // ===================================================================
  // §48 — retention states no period it cannot justify
  // ===================================================================

  group('retention claims no period', () {
    test('every profile is unconfigured', () {
      for (final profile in AdminDemoCatalog.retentionProfiles()) {
        expect(profile.duration, isNull);
        expect(profile.authority, isNull);
      }
    });

    testWidgets('retention screen shows not configured, not a number', (
      tester,
    ) async {
      await pumpAt(tester, '/admin/retention');
      final text = visibleText(tester);
      expect(text.where((t) => t.contains('not configured')), isNotEmpty);
      for (final forbidden in const [
        '30 years',
        '40 years',
        '7 years',
        '5 years',
        'as per oisd',
        'as per dgms',
      ]) {
        expect(
          text.any((t) => t.contains(forbidden)),
          isFalse,
          reason: 'retention must not assert "$forbidden"',
        );
      }
    });
  });

  // ===================================================================
  // §50 — calibration administration offers no route around validation
  // ===================================================================

  group('calibration administration cannot activate anything', () {
    testWidgets('no calibration exists and no metric is stated', (
      tester,
    ) async {
      await pumpAt(tester, '/admin/calibration');
      final text = visibleText(tester);
      expect(
        text.any((t) => t.contains('no production h₂s calibration')),
        isTrue,
      );
      // No fabricated performance figure anywhere on the screen.
      expect(
        text.any((t) => RegExp(r'\d+(\.\d+)?\s*(ppm|ppm·h|%|r²)').hasMatch(t)),
        isFalse,
        reason: 'calibration admin must state no accuracy, LOD, LOQ or range',
      );
      expect(text.where((t) => t.contains('unavailable')), isNotEmpty);
    });

    testWidgets('the activate control is disabled', (tester) async {
      await pumpAt(tester, '/admin/calibration');
      final buttons = tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(buttons, isNotEmpty);
      for (final button in buttons) {
        expect(
          button.onPressed,
          isNull,
          reason: 'no admin control may activate a calibration',
        );
      }
    });
  });

  // ===================================================================
  // §51 — security language claims nothing
  // ===================================================================

  group('security and sync language', () {
    testWidgets('no encryption or compliance guarantee is asserted', (
      tester,
    ) async {
      for (final route in adminRoutes.keys) {
        await pumpAt(tester, route);
        final text = visibleText(tester);
        for (final forbidden in const [
          'end-to-end encrypted',
          'encrypted at rest',
          'iso 27001',
          'gdpr compliant',
          'soc 2',
          'audit ready',
          'production ready',
          'fully compliant',
          'secure by design',
        ]) {
          expect(
            text.any((t) => t.contains(forbidden)),
            isFalse,
            reason: '$route must not assert "$forbidden"',
          );
        }
      }
    });

    testWidgets('sync health reports local-only, not healthy', (tester) async {
      await pumpAt(tester, '/admin/sync');
      final text = visibleText(tester);
      expect(
        text.any((t) => t.contains('healthy') || t.contains('all systems')),
        isFalse,
      );
    });
  });

  // ===================================================================
  // Demo data controls are development-only
  // ===================================================================

  testWidgets('demo data controls do not exist in production', (tester) async {
    await pumpAt(tester, '/admin/more', config: _prod);
    expect(find.text('Presentation data'), findsNothing);
  });

  // ===================================================================
  // Unknown identifiers
  // ===================================================================

  group('unknown identifiers do not render an empty record', () {
    for (final route in const ['/admin/integrations/nonexistent']) {
      testWidgets(route, (tester) async {
        await pumpAt(tester, route);
        expect(find.text('Not found'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });

  for (final route in const [
    '/admin/people/EMP-00000',
    '/admin/doseband/band/DB-0000-0000',
  ]) {
    testWidgets('$route explains itself', (tester) async {
      await pumpAt(tester, route);
      expect(find.textContaining('No '), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
