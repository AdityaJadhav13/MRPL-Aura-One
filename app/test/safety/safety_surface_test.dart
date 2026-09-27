import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/safety/data/safety_demo_catalog.dart';
import 'package:h2s_doseband/features/safety/domain/safety_content.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

void main() {
  late WorkflowStore store;

  setUp(() => store = InMemoryWorkflowStore());

  Future<void> pumpAt(
    WidgetTester tester,
    String route, {
    Size size = const Size(390, 5200),
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
          workflowStoreProvider.overrideWithValue(store),
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

  List<String> visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').toLowerCase())
      .where((t) => t.isNotEmpty)
      .toList();

  const safetyRoutes = <String, String>{
    '/safety': 'Safety',
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
  };

  group('every safety route resolves', () {
    for (final entry in safetyRoutes.entries) {
      testWidgets('${entry.key} renders', (tester) async {
        await pumpAt(tester, entry.key);
        expect(tester.takeException(), isNull);
        expect(find.text(entry.value), findsWidgets);
      });
    }

    testWidgets('the hub reaches every sub-screen', (tester) async {
      await pumpAt(tester, '/safety');
      for (final label in [
        'Emergency',
        'Hydrogen sulphide',
        'Near miss or hazard',
        'Occupational health',
        'Permit to Work',
        'Job Safety Analysis',
        'PPE',
        'Toolbox resources',
        'Safety data sheets',
        'Offline documents',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });
  });

  group('emergency invents nothing', () {
    testWidgets('it says the site information is not configured', (
      tester,
    ) async {
      await pumpAt(tester, '/safety/emergency');
      expect(find.text('Site emergency information'), findsOneWidget);
      expect(find.text('Not configured'), findsWidgets);
      expect(find.text('Unavailable'), findsWidgets);
    });

    testWidgets('it contains no phone number in any format', (tester) async {
      await pumpAt(tester, '/safety/emergency');
      final text = visibleText(tester).join(' ');

      // Anything that could be dialled. A wrong number here is dialled in the
      // one situation where being wrong costs the most.
      expect(RegExp(r'\d{3,}').hasMatch(text), isFalse, reason: text);
      expect(text, isNot(contains('call ')));
      expect(text, isNot(contains('dial')));
    });

    testWidgets('no control appears to place a call', (tester) async {
      await pumpAt(tester, '/safety/emergency');
      // No enabled button at all on this screen.
      for (final button in tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(find.byIcon(Icons.call), findsNothing);
    });

    testWidgets('it gives safe general guidance instead', (tester) async {
      await pumpAt(tester, '/safety/emergency');
      final text = visibleText(tester).join(' ');
      expect(text, contains('follow site alarms and approved procedures'));
      expect(text, contains('not an emergency gas alarm'));
    });
  });

  group('the hazard handoff cannot pretend to submit', () {
    testWidgets('the continue control is disabled', (tester) async {
      await pumpAt(tester, '/safety/hazard');
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue to organisation reporting'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('nothing claims a report was sent', (tester) async {
      await pumpAt(tester, '/safety/hazard');
      final text = visibleText(tester).join(' ');
      for (final claim in [
        'report submitted',
        'reference number',
        'successfully',
        'we have received',
      ]) {
        expect(text, isNot(contains(claim)), reason: claim);
      }
      expect(text, contains('nothing you select here has been sent'));
    });

    testWidgets('all four categories are offered', (tester) async {
      await pumpAt(tester, '/safety/hazard');
      for (final kind in [
        'Near miss',
        'Unsafe condition',
        'Unsafe act',
        'Other hazard',
      ]) {
        expect(find.text(kind), findsWidgets, reason: kind);
      }
    });
  });

  group('occupational health stays out of medicine', () {
    testWidgets('it makes no clinical claim', (tester) async {
      await store.save(
        ShiftSession(
          stage: ShiftStage.monitoring,
          context: SimulationCatalog.demoContext(),
          badge: SimulationCatalog.specimens().first,
          startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );
      await pumpAt(tester, '/safety/occupational-health');

      final text = visibleText(tester).join(' ');
      for (final claim in [
        'medically cleared',
        'fit for duty',
        'fit for work',
        'health score',
        'diagnos',
      ]) {
        expect(
          text.contains(claim) && !text.contains('no diagnosis'),
          isFalse,
          reason: claim,
        );
      }
      expect(text, contains('no health score is calculated'));
      expect(text, contains('no judgement about fitness for work'));
    });

    testWidgets('it shows the real record and claims no referral', (
      tester,
    ) async {
      await store.save(
        ShiftSession(
          stage: ShiftStage.monitoring,
          context: SimulationCatalog.demoContext(),
          badge: SimulationCatalog.specimens().first,
          startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );
      await pumpAt(tester, '/safety/occupational-health');

      expect(
        find.text(SimulationCatalog.demoContext().worker.displayName),
        findsWidgets,
      );
      final text = visibleText(tester).join(' ');
      expect(text, contains('nothing has been referred'));
    });
  });

  group('PTW and JSA guidance keep the boundary', () {
    testWidgets('PTW states what DoseBand does not do', (tester) async {
      await pumpAt(tester, '/safety/ptw');
      final text = visibleText(tester).join(' ');
      expect(text, contains('does not issue a permit'));
      expect(text, contains('not permission to start work'));
      expect(text, isNot(contains('ptw approved')));
    });

    testWidgets('JSA states what DoseBand does not do', (tester) async {
      await pumpAt(tester, '/safety/jsa');
      final text = visibleText(tester).join(' ');
      expect(text, contains('does not create a jsa'));
      expect(text, contains('does not replace a jsa'));
      expect(text, isNot(contains('jsa approved')));
    });

    testWidgets('PTW shows the current reference with provenance', (
      tester,
    ) async {
      await store.save(
        ShiftSession(
          stage: ShiftStage.badgeAssigned,
          context: SimulationCatalog.demoContext(),
          badge: SimulationCatalog.specimens().first,
        ),
      );
      await pumpAt(tester, '/safety/ptw');

      final demo = SimulationCatalog.demoContext();
      expect(find.text(demo.permit.reference.value), findsWidgets);
      expect(find.text('Demo'), findsWidgets);
    });
  });

  group('PPE recommends nothing', () {
    testWidgets('requirements are not configured', (tester) async {
      await pumpAt(tester, '/safety/ppe');
      expect(
        find.text('Organisation-specific PPE requirements'),
        findsOneWidget,
      );
      expect(find.text('Not configured'), findsWidgets);
    });

    testWidgets('it never derives PPE from a measurement', (tester) async {
      await pumpAt(tester, '/safety/ppe');
      final text = visibleText(tester).join(' ');
      expect(text, contains('does not recommend ppe from its own readings'));
      // No specific equipment is named as required.
      for (final item in ['respirator required', 'you must wear', 'scba']) {
        expect(text, isNot(contains(item)), reason: item);
      }
    });

    testWidgets('all seven categories are listed', (tester) async {
      await pumpAt(tester, '/safety/ppe');
      for (final category in SafetyDemoCatalog.ppeCategories()) {
        expect(find.text(category), findsWidgets, reason: category);
      }
    });
  });

  group('document libraries stay honest', () {
    testWidgets('toolbox viewing does not acknowledge a talk', (tester) async {
      await pumpAt(tester, '/safety/toolbox');
      final text = visibleText(tester).join(' ');
      expect(text, contains('no document library is connected'));
      expect(text, contains('not a record of training or competence'));
      expect(text, isNot(contains('training complete')));
      expect(text, isNot(contains('demo-')));
    });

    testWidgets('SDS opens no placeholder sheet; it points at the site '
        'register', (tester) async {
      await pumpAt(tester, '/safety/sds');
      final text = visibleText(tester).join(' ');
      // Worker directive §42: a resource must not open a fake document.
      expect(text, contains('does not hold safety data sheets'));
      expect(text, contains('approved sds register'));
      expect(text, isNot(contains('demo-')));
      expect(find.text('DEMONSTRATION DATA'), findsNothing);
    });

    test('no demo document uses a realistic organisation number', () {
      for (final document in SafetyDemoCatalog.allDocuments()) {
        expect(document.id, startsWith('DEMO-'), reason: document.id);
        expect(document.revision, isNull, reason: document.id);
      }
    });

    test('nothing demo is marked as organisational', () {
      // The one thing that must never happen: generated placeholder text
      // wearing the authority of a site procedure.
      for (final document in SafetyDemoCatalog.allDocuments()) {
        expect(document.source.isOrganisational, isFalse, reason: document.id);
      }
    });

    testWidgets('offline shows nothing downloaded', (tester) async {
      await pumpAt(tester, '/safety/offline');
      expect(find.text('Nothing is downloaded'), findsOneWidget);
      final text = visibleText(tester).join(' ');
      expect(text, contains('storage used is not shown'));
      expect(text, isNot(contains('mb')));
    });

    testWidgets('offline is presented as normal, not broken', (tester) async {
      await pumpAt(tester, '/safety/offline');
      final text = visibleText(tester).join(' ');
      expect(text, contains('working offline is normal'));
    });
  });

  group('H₂S information overstates nothing', () {
    testWidgets('it publishes no exposure limit or threshold', (tester) async {
      await pumpAt(tester, '/safety/h2s');
      final text = visibleText(tester).join(' ');

      // No concentration figure of any kind.
      expect(RegExp(r'\d+\s*(ppm|mg/m)').hasMatch(text), isFalse);
      expect(text, isNot(contains('threshold limit')));
      expect(text, isNot(contains('alarm set at')));
    });

    testWidgets('it separates general, product and organisation content', (
      tester,
    ) async {
      await pumpAt(tester, '/safety/h2s');
      expect(find.text('General information'), findsWidgets);
      expect(find.text('DoseBand'), findsWidgets);
      expect(find.text('Not configured'), findsWidgets);
    });

    testWidgets('it says a refusal is not zero', (tester) async {
      await pumpAt(tester, '/safety/h2s');
      final text = visibleText(tester).join(' ');
      expect(text, contains('not an exposure of zero'));
      expect(text, contains('does not replace'));
    });

    testWidgets('it does not claim the chemistry is validated', (tester) async {
      await pumpAt(tester, '/safety/h2s');
      final text = visibleText(tester).join(' ');
      expect(text, contains('calibration is not yet available'));
      expect(text, isNot(contains('validated chemistry')));
      expect(text, isNot(contains('clinically')));
    });
  });

  group('no safety screen claims authority it lacks', () {
    testWidgets('across every safety route', (tester) async {
      for (final route in safetyRoutes.keys) {
        await pumpAt(tester, route);
        for (final line in visibleText(tester)) {
          for (final claim in [
            'safe to work',
            'h₂s safe',
            'area safe',
            'medically cleared',
            'fit for duty',
            'ptw approved',
            'jsa approved',
            'mrpl verified',
            'emergency cleared',
            // Worker directive §37: honest about integrations without
            // calling the product a prototype on every screen.
            'prototype',
          ]) {
            expect(line, isNot(contains(claim)), reason: '$route: $line');
          }
        }
      }
    });
  });

  group('the DoseBand limitation (Worker directive §39)', () {
    testWidgets('names everything DoseBand does not replace', (tester) async {
      await pumpAt(tester, '/safety');
      final text = visibleText(tester).join(' ');
      for (final control in [
        'passive, cumulative',
        'portable h₂s detectors',
        'fixed gas detection',
        'site alarms',
        'approved ppe',
        'permit-to-work',
        'site emergency procedures',
      ]) {
        expect(text, contains(control), reason: control);
      }
    });
  });

  group('the safety surface holds its layout', () {
    for (final width in <double>[360, 390, 430]) {
      testWidgets('every route at ${width.toInt()} wide', (tester) async {
        for (final route in safetyRoutes.keys) {
          await pumpAt(tester, route, size: Size(width, 5200));
          expect(tester.takeException(), isNull, reason: route);
        }
      });
    }

    for (final route in <String>[
      '/safety',
      '/safety/emergency',
      '/safety/h2s',
      '/safety/sds',
    ]) {
      testWidgets('$route at 200% text with a notch', (tester) async {
        await pumpAt(
          tester,
          route,
          size: const Size(393, 852),
          textScale: 2,
          viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('content sources behave', () {
    test('only organisation content is organisational', () {
      for (final source in SafetyContentSource.values) {
        expect(
          source.isOrganisational,
          source == SafetyContentSource.organisation,
          reason: source.name,
        );
      }
    });

    test('every source explains itself', () {
      for (final source in SafetyContentSource.values) {
        expect(source.label, isNotEmpty, reason: source.name);
        expect(source.explanation, isNotEmpty, reason: source.name);
      }
    });
  });
}
