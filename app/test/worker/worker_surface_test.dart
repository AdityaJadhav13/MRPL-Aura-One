import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/core/util/format.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/result/result_presentation.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:h2s_doseband/main.dart';
import 'package:measurement/measurement.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

ShiftSession _session(ShiftStage stage, {DateTime? startedAt}) => ShiftSession(
  stage: stage,
  context: stage.index >= ShiftStage.contextSet.index
      ? SimulationCatalog.demoContext()
      : null,
  badge: stage.index >= ShiftStage.badgeAssigned.index
      ? SimulationCatalog.specimens().first
      : null,
  startedAt: startedAt,
);

void main() {
  late WorkflowStore store;

  setUp(() => store = InMemoryWorkflowStore());

  Future<void> pumpAt(
    WidgetTester tester,
    String route, {
    Size size = const Size(390, 1600),
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

  const workerRoutes = <String, String>{
    '/shift': 'Shift',
    '/worker-identity': 'Worker identity',
    '/work-area': 'Work area',
    '/ptw': 'Permit to Work',
    '/jsa': 'Job Safety Analysis',
    '/toolbox': 'Toolbox talk',
    '/scan-badge': 'Scan badge QR',
    '/traceability': 'Badge traceability',
  };

  group('every worker route resolves', () {
    for (final entry in workerRoutes.entries) {
      testWidgets('${entry.key} renders with a context', (tester) async {
        await store.save(_session(ShiftStage.badgeAssigned));
        await pumpAt(tester, entry.key);
        expect(tester.takeException(), isNull);
        expect(find.text(entry.value), findsWidgets);
      });

      testWidgets('${entry.key} renders with no context', (tester) async {
        // The empty case must be a designed state, not a crash or a blank.
        await pumpAt(tester, entry.key);
        expect(tester.takeException(), isNull);
        expect(find.text(entry.value), findsWidgets);
      });
    }
  });

  group('context detail reads the committed context', () {
    testWidgets('worker identity shows the real identity', (tester) async {
      await store.save(_session(ShiftStage.badgeAssigned));
      await pumpAt(tester, '/worker-identity');

      final demo = SimulationCatalog.demoContext();
      expect(find.text(demo.worker.displayName), findsOneWidget);
      expect(find.text(demo.worker.workerId), findsOneWidget);
    });

    testWidgets('PTW shows the reference with its provenance', (tester) async {
      await store.save(_session(ShiftStage.badgeAssigned));
      await pumpAt(tester, '/ptw');

      final demo = SimulationCatalog.demoContext();
      expect(find.text(demo.permit.reference.value), findsWidgets);
      expect(find.text('Demo'), findsWidgets);
      // Never a claim of approval.
      final text = visibleText(tester).join(' ');
      expect(text, isNot(contains('ptw approved')));
      expect(text, contains('does not issue a permit'));
    });

    testWidgets('JSA states what DoseBand does not do', (tester) async {
      await store.save(_session(ShiftStage.badgeAssigned));
      await pumpAt(tester, '/jsa');

      final text = visibleText(tester).join(' ');
      expect(text, contains('does not create a jsa'));
      expect(text, isNot(contains('jsa approved')));
    });

    testWidgets('toolbox records an acknowledgement, not a completion', (
      tester,
    ) async {
      await store.save(_session(ShiftStage.badgeAssigned));
      await pumpAt(tester, '/toolbox');

      expect(find.text('Acknowledged'), findsWidgets);
      final text = visibleText(tester).join(' ');
      expect(text, contains('not evidence that the talk took place'));
      expect(text, isNot(contains('training complete')));
    });

    testWidgets('work area carries no hazard classification', (tester) async {
      await store.save(_session(ShiftStage.badgeAssigned));
      await pumpAt(tester, '/work-area');

      final text = visibleText(tester).join(' ');
      expect(text, contains('no hazard classification'));
      // No concentration or risk band anywhere.
      expect(RegExp(r'\d+\s*ppm').hasMatch(text), isFalse);
    });

    testWidgets('shift shows an unknown duration as a refusal', (tester) async {
      await store.save(_session(ShiftStage.badgeAssigned));
      await pumpAt(tester, '/shift');

      // Monitoring has not started, so there is no window.
      expect(find.text(Fmt.noValue), findsWidgets);
      expect(find.text('0 min'), findsNothing);
    });
  });

  group('the QR screen does not fake a scanner', () {
    testWidgets('it says the camera is unavailable and why', (tester) async {
      await pumpAt(tester, '/scan-badge');

      expect(find.text('Camera not available'), findsOneWidget);
      final text = visibleText(tester).join(' ');
      expect(text, contains('no doseband has been manufactured'));
      // No claim that anything was detected or resolved.
      expect(text, isNot(contains('badge found')));
      expect(text, isNot(contains('scanning')));
    });

    testWidgets('it offers the honest manual path', (tester) async {
      await pumpAt(tester, '/scan-badge');
      expect(find.text('Choose a badge manually'), findsOneWidget);
    });
  });

  group('traceability distinguishes evidence from absence', () {
    testWidgets('supply-chain stages report no record', (tester) async {
      await store.save(
        _session(
          ShiftStage.monitoring,
          startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );
      await pumpAt(tester, '/traceability');

      for (final stage in [
        'Manufactured',
        'Batch released',
        'Inventory',
        'Issued',
      ]) {
        expect(find.text(stage), findsOneWidget, reason: stage);
      }
      // Marked absent, not pending — nothing is on its way.
      expect(find.text('No record exists'), findsWidgets);

      final text = visibleText(tester).join(' ');
      expect(text, contains('supply chain that does not exist'));
    });

    testWidgets('observed stages carry the real workflow values', (
      tester,
    ) async {
      final started = DateTime(2026, 9, 25, 8, 4);
      await store.save(
        ShiftSession(
          stage: ShiftStage.monitoring,
          context: SimulationCatalog.demoContext(),
          badge: SimulationCatalog.specimens().first,
          startedAt: started,
        ),
      );
      await pumpAt(tester, '/traceability');

      expect(find.text('Assigned'), findsOneWidget);
      expect(find.text('Activated'), findsOneWidget);
      expect(
        find.text(SimulationCatalog.specimens().first.badgeId),
        findsWidgets,
      );
      expect(find.text(Fmt.stamp(started)), findsWidgets);
    });
  });

  group('the result screen keeps the calibration boundary', () {
    test('every refusal status has copy', () {
      // Exhaustive by construction; this pins that the switch stays total.
      for (final status in ResultStatus.values.where((s) => s.isRefusal)) {
        final copy = refusalCopy(status);
        expect(copy.whatHappened, isNotEmpty, reason: status.name);
        expect(copy.whyItMatters, isNotEmpty, reason: status.name);
        expect(copy.whatToDo, isNotEmpty, reason: status.name);
      }
    });

    test('an untrusted window does not tell the worker to scan again', () {
      // Scanning again cannot recover a lost duration, and sending them round
      // that loop wastes the one chance to report it while the badge is to
      // hand.
      final copy = refusalCopy(
        ResultStatus.resultUnreliable,
        reasonCode: 'EXPOSURE_WINDOW_UNTRUSTED',
      );
      expect(copy.whatHappened.toLowerCase(), contains('device clock'));
      expect(copy.whatToDo.toLowerCase(), isNot(contains('scan again')));
      expect(copy.whatToDo.toLowerCase(), contains('safety officer'));
    });

    test('a generic unreliable result still suggests a retry', () {
      final copy = refusalCopy(ResultStatus.resultUnreliable);
      expect(copy.whatToDo.toLowerCase(), contains('scan again'));
    });
  });

  group('the worker surface holds its layout', () {
    for (final width in <double>[360, 390, 430]) {
      testWidgets('all worker routes at ${width.toInt()} wide', (tester) async {
        for (final route in workerRoutes.keys) {
          await store.save(_session(ShiftStage.badgeAssigned));
          await pumpAt(tester, route, size: Size(width, 1600));
          expect(tester.takeException(), isNull, reason: route);
        }
      });
    }

    testWidgets('complex worker screens at 200% text with a notch', (
      tester,
    ) async {
      for (final route in ['/shift', '/traceability', '/ptw']) {
        await store.save(
          _session(
            ShiftStage.monitoring,
            startedAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        );
        await pumpAt(
          tester,
          route,
          size: const Size(393, 852),
          textScale: 2,
          viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
        );
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  });

  group('no worker screen claims authority', () {
    testWidgets('across every new route', (tester) async {
      for (final route in workerRoutes.keys) {
        await store.save(_session(ShiftStage.badgeAssigned));
        await pumpAt(tester, route);

        for (final line in visibleText(tester)) {
          for (final claim in [
            'safe to work',
            'ptw approved',
            'jsa approved',
            'area safe',
            'mrpl verified',
          ]) {
            expect(line, isNot(contains(claim)), reason: '$route: $line');
          }
        }
      }
    });
  });
}
