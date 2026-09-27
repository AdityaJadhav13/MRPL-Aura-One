import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/core/util/format.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/home/domain/home_presentation.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/badge_specimen.dart';
import 'package:h2s_doseband/features/workflow/domain/physical_badge.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:h2s_doseband/main.dart';

import '../support/signed_in.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

final DateTime _now = DateTime(2026, 9, 27, 11, 46);
final DateTime _start = _now.subtract(const Duration(hours: 3, minutes: 42));

BadgeSpecimen _specimen() => SimulationCatalog.specimens().first;

final _registered = PhysicalBadge(
  badgeId: 'DB-2609-0010',
  batchId: 'LOT-2609-A',
  identifiedAt: _start,
  source: BadgeIdentitySource.localRegistry,
);

/// A session at [stage]. [registered] gives it a claimed DoseBand with an
/// operations-store session, as the real flow produces; otherwise it carries
/// a simulated specimen, as the development simulation does.
ShiftSession _session(
  ShiftStage stage, {
  DateTime? startedAt,
  DateTime? endedAt,
  bool registered = false,
}) {
  final hasBand = stage.index >= ShiftStage.badgeAssigned.index;
  return ShiftSession(
    stage: stage,
    context: stage.index >= ShiftStage.contextSet.index
        ? SimulationCatalog.demoContext()
        : null,
    badge: hasBand && !registered ? _specimen() : null,
    physicalBadge: hasBand && registered ? _registered : null,
    startedAt: startedAt,
    endedAt: endedAt,
    sessionId: registered ? 'SES-1' : null,
    captureId: stage == ShiftStage.complete ? 'CAP-1' : null,
  );
}

void main() {
  group('the projection maps every workflow state (PRODUCT BUILD v1 §15)', () {
    HomePresentation at(
      ShiftStage stage, {
      DateTime? startedAt,
      DateTime? endedAt,
      DateTime? now,
      bool registered = false,
    }) => HomePresentation.from(
      session: _session(
        stage,
        startedAt: startedAt,
        endedAt: endedAt,
        registered: registered,
      ),
      now: now ?? _now,
    );

    test('A — no DoseBand: scan a new one', () {
      for (final s in [ShiftStage.noShift, ShiftStage.contextSet]) {
        final p = at(s);
        expect(p.stage, HomeStage.noDoseBand);
        expect(p.actionLabel, 'Scan new DoseBand');
        expect(p.actionRoute, '/doseband/scan');
      }
    });

    test('C — monitoring active: complete and scan', () {
      final p = at(ShiftStage.monitoring, startedAt: _start);
      expect(p.stage, HomeStage.monitoringActive);
      expect(p.isMonitoring, isTrue);
      expect(p.actionLabel, 'Complete monitoring & scan');
      expect(p.actionRoute, '/end');
      expect(p.message, contains('cannot warn you'));
    });

    test('D — ready for final read: the assigned band is identified first', () {
      final registered = at(
        ShiftStage.awaitingScan,
        startedAt: _start,
        endedAt: _now,
        registered: true,
      );
      expect(registered.stage, HomeStage.readyForFinalRead);
      expect(registered.actionLabel, 'Scan assigned DoseBand');
      expect(registered.actionRoute, '/doseband/scan?purpose=final');
      // The development simulation has no QR; it goes straight to its scan.
      expect(
        at(
          ShiftStage.awaitingScan,
          startedAt: _start,
          endedAt: _now,
        ).actionRoute,
        '/read',
      );
    });

    test('E — completed today: record, disposal, next band', () {
      final p = at(
        ShiftStage.complete,
        startedAt: _start,
        endedAt: _now,
        registered: true,
      );
      expect(p.stage, HomeStage.completed);
      expect(p.actionRoute, '/history/record/CAP-1');
      expect(p.message, contains('dispose'));
      expect(p.secondaryRoute, '/doseband/scan');
    });

    test('a period completed on an earlier day is today’s state A', () {
      final p = at(
        ShiftStage.complete,
        startedAt: _start.subtract(const Duration(days: 1)),
        endedAt: _now.subtract(const Duration(days: 1)),
      );
      expect(p.stage, HomeStage.noDoseBand);
    });

    test('the development simulation keeps its pre-work step', () {
      expect(at(ShiftStage.badgeAssigned).actionRoute, '/prework');
      expect(at(ShiftStage.readyForDosimetry).actionRoute, '/prework');
    });

    test('an untrusted clock outranks the stage', () {
      final p = at(
        ShiftStage.monitoring,
        startedAt: _now,
        now: _now.subtract(const Duration(hours: 1)),
      );
      expect(p.stage, HomeStage.requiresAttention);
      expect(p.actionRoute, '/end');
      expect(p.message, contains('cannot be stated'));
    });

    test('every action route is one the workflow permits', () {
      const permitted = {
        '/doseband/scan',
        '/doseband/scan?purpose=final',
        '/prework',
        '/end',
        '/read',
        '/history/record/CAP-1',
      };
      for (final registered in [true, false]) {
        for (final stage in ShiftStage.values) {
          final p = at(
            stage,
            startedAt: _start,
            endedAt: stage.index >= ShiftStage.awaitingScan.index ? _now : null,
            registered: registered,
          );
          expect(permitted, contains(p.actionRoute), reason: stage.name);
        }
      }
    });

    test('no state claims anything about safety', () {
      for (final stage in ShiftStage.values) {
        final p = at(stage, startedAt: _start);
        final text = '${p.title} ${p.message}'.toLowerCase();
        for (final claim in [
          'safe to work',
          'is safe',
          'area safe',
          'approved',
          'authorised to',
        ]) {
          expect(text, isNot(contains(claim)), reason: '${stage.name}: $claim');
        }
      }
    });
  });

  group('Home renders every state', () {
    late WorkflowStore store;

    setUp(() => store = InMemoryWorkflowStore());

    Future<void> pumpHome(
      WidgetTester tester, {
      ShiftSession session = ShiftSession.none,
      Size size = const Size(390, 1500),
      double textScale = 1,
      EdgeInsets viewPadding = EdgeInsets.zero,
    }) async {
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      // Tear the previous tree down first, so a new store override is read.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await store.save(session);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentConfigProvider.overrideWithValue(_dev),
            ...signedInOverrides(
              personId: PresentationDataset.aditya,
              now: _now,
              seed: seedForSession(session, _now),
            ),
            workflowStoreProvider.overrideWithValue(store),
          ],
          child: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(textScale),
              padding: viewPadding,
              viewPadding: viewPadding,
            ),
            child: const DoseBandApp(
              key: ValueKey('/home'),
              config: _dev,
              initialLocation: '/home',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('A: who, no band, the scan action, today’s work', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(find.text('Aditya Jadhav'), findsOneWidget);
      expect(find.text('NO DOSEBAND ASSIGNED'), findsOneWidget);
      expect(find.text('Scan new DoseBand'), findsOneWidget);
      expect(find.text('Usual assignment from your company record. Confirm today’s work before a DoseBand is assigned.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('C: the band, the start and the trusted duration', (
      tester,
    ) async {
      await pumpHome(
        tester,
        session: _session(
          ShiftStage.monitoring,
          startedAt: _start,
          registered: true,
        ),
      );
      expect(find.text('MONITORING ACTIVE'), findsOneWidget);
      expect(find.text('DB-2609-0010'), findsOneWidget);
      expect(find.text('3 h 42 min'), findsOneWidget);
      expect(find.text('Complete monitoring & scan'), findsOneWidget);
    });

    testWidgets('an untrusted window never shows a duration', (tester) async {
      await pumpHome(
        tester,
        session: _session(
          ShiftStage.monitoring,
          startedAt: _now.add(const Duration(hours: 2)),
          registered: true,
        ),
      );
      expect(find.text(Fmt.noValue), findsWidgets);
      expect(find.text('MONITORING TIME CANNOT BE TRUSTED'), findsOneWidget);
      expect(find.text('0 min'), findsNothing);
    });

    testWidgets('D: scan the assigned band', (tester) async {
      await pumpHome(
        tester,
        session: _session(
          ShiftStage.awaitingScan,
          startedAt: _start,
          endedAt: _now,
          registered: true,
        ),
      );
      expect(find.text('READY FOR FINAL SCAN'), findsOneWidget);
      expect(find.text('Scan assigned DoseBand'), findsOneWidget);
    });

    testWidgets('E: complete, with the disposal instruction', (tester) async {
      await pumpHome(
        tester,
        session: _session(
          ShiftStage.complete,
          startedAt: _start,
          endedAt: _now,
          registered: true,
        ),
      );
      expect(find.text('TODAY’S MONITORING COMPLETE'), findsOneWidget);
      expect(find.textContaining('dispose'), findsOneWidget);
    });

    testWidgets('a simulated band is marked on Home', (tester) async {
      await pumpHome(
        tester,
        session: _session(ShiftStage.monitoring, startedAt: _start),
      );
      expect(find.textContaining('Simulated'), findsWidgets);
    });

    for (final stage in ShiftStage.values) {
      testWidgets('${stage.name} claims nothing about safety', (tester) async {
        await pumpHome(
          tester,
          session: _session(
            stage,
            startedAt: stage.index >= ShiftStage.monitoring.index
                ? _start
                : null,
            endedAt: stage.index >= ShiftStage.awaitingScan.index ? _now : null,
            registered: true,
          ),
        );
        for (final text
            in tester
                .widgetList<Text>(find.byType(Text))
                .map((t) => (t.data ?? '').toLowerCase())) {
          for (final claim in ['safe to work', 'h₂s safe', 'area safe']) {
            expect(text, isNot(contains(claim)), reason: stage.name);
          }
        }
      });
    }

    testWidgets('no overflow with a notch inset', (tester) async {
      await pumpHome(
        tester,
        session: _session(
          ShiftStage.monitoring,
          startedAt: _start,
          registered: true,
        ),
        size: const Size(393, 852),
        viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow with a notch inset at 200% text', (tester) async {
      await pumpHome(
        tester,
        size: const Size(393, 852),
        textScale: 2,
        viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
      );
      expect(tester.takeException(), isNull);
    });

    for (final width in <double>[320, 360, 390, 430]) {
      testWidgets('no overflow at ${width.toInt()} wide', (tester) async {
        await pumpHome(
          tester,
          session: _session(
            ShiftStage.monitoring,
            startedAt: _start,
            registered: true,
          ),
          size: Size(width, 1500),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no overflow at 200% text while monitoring', (tester) async {
      await pumpHome(
        tester,
        session: _session(
          ShiftStage.monitoring,
          startedAt: _start,
          registered: true,
        ),
        size: const Size(390, 844),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
