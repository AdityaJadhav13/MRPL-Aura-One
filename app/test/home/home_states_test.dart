import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/core/util/format.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/home/domain/home_presentation.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/badge_specimen.dart';
import 'package:h2s_doseband/features/workflow/domain/work_context.dart';
import 'package:h2s_doseband/features/workflow/domain/work_context_validator.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

BadgeSpecimen _badge() => SimulationCatalog.specimens().first;

/// A session at [stage], with a complete demo context where one is required.
ShiftSession _session(
  ShiftStage stage, {
  DateTime? startedAt,
  DateTime? endedAt,
}) => ShiftSession(
  stage: stage,
  context: stage.index >= ShiftStage.contextSet.index
      ? SimulationCatalog.demoContext()
      : null,
  badge: stage.index >= ShiftStage.badgeAssigned.index ? _badge() : null,
  startedAt: startedAt,
  endedAt: endedAt,
);

WorkContextReadiness _readiness({bool complete = true}) =>
    WorkContextValidator.assess(
      complete
          ? WorkContextDraft.from(SimulationCatalog.demoContext())
          : WorkContextDraft.empty,
      badge: complete ? _badge() : null,
    );

void main() {
  final start = DateTime(2026, 9, 25, 8, 4);

  group('the projection maps every workflow state', () {
    HomePresentation at(
      ShiftStage stage, {
      DateTime? startedAt,
      DateTime? endedAt,
      DateTime? now,
      bool contextComplete = true,
    }) => HomePresentation.from(
      session: _session(stage, startedAt: startedAt, endedAt: endedAt),
      readiness: _readiness(complete: contextComplete),
      now: now ?? start.add(const Duration(hours: 3, minutes: 42)),
    );

    test('HOME-01 no context', () {
      final p = at(ShiftStage.noShift);
      expect(p.stage, HomeStage.noContext);
      expect(p.actionRoute, '/work-context');
      expect(p.monitoringState, 'Not started');
    });

    test('HOME-02 context incomplete', () {
      final p = at(ShiftStage.contextSet, contextComplete: false);
      expect(p.stage, HomeStage.contextIncomplete);
      expect(p.actionLabel, 'Complete work context');
      expect(p.actionRoute, '/work-context');
    });

    test('HOME-03 context complete, no badge', () {
      final p = at(ShiftStage.contextSet);
      expect(p.stage, HomeStage.awaitingBadge);
      expect(p.actionLabel, 'Assign DoseBand');
      expect(p.actionRoute, '/assign');
    });

    test('HOME-04/05 badge assigned', () {
      final p = at(ShiftStage.badgeAssigned);
      expect(p.stage, HomeStage.badgeAssigned);
      expect(p.actionRoute, '/prework');
    });

    test('HOME-06 ready for dosimetry', () {
      final p = at(ShiftStage.readyForDosimetry);
      expect(p.stage, HomeStage.readyForDosimetry);
      expect(p.actionLabel, 'Start monitoring');
      // The strip must carry the qualification with the phrase.
      expect(p.statusStrip, contains('does not authorise work'));
    });

    test('HOME-07 monitoring active', () {
      final p = at(ShiftStage.monitoring, startedAt: start);
      expect(p.stage, HomeStage.monitoringActive);
      expect(p.isMonitoring, isTrue);
      expect(p.actionLabel, 'End monitoring');
      expect(p.statusStrip, contains('cannot warn you'));
    });

    test('HOME-08 scan required', () {
      final p = at(
        ShiftStage.awaitingScan,
        startedAt: start,
        endedAt: start.add(const Duration(hours: 7)),
      );
      expect(p.stage, HomeStage.scanRequired);
      expect(p.actionLabel, 'Scan DoseBand');
      expect(p.actionRoute, '/read');
    });

    test('HOME-09 result available', () {
      final p = at(ShiftStage.complete);
      expect(p.stage, HomeStage.resultAvailable);
    });

    test('HOME-10 untrusted clock outranks the stage', () {
      // The window runs backwards: the device clock moved while monitoring.
      final p = at(
        ShiftStage.monitoring,
        startedAt: start,
        now: start.subtract(const Duration(hours: 1)),
      );
      expect(p.stage, HomeStage.requiresAttention);
      expect(p.monitoringState, 'Duration not trustworthy');
      expect(p.actionRoute, '/end');
    });

    test('every action route is one the workflow permits', () {
      const permitted = {
        '/work-context',
        '/assign',
        '/prework',
        '/end',
        '/read',
      };
      for (final stage in ShiftStage.values) {
        final p = at(stage, startedAt: start);
        expect(permitted, contains(p.actionRoute), reason: stage.name);
      }
    });

    test('no status strip claims anything about safety', () {
      for (final stage in ShiftStage.values) {
        final strip = at(stage, startedAt: start).statusStrip.toLowerCase();
        for (final claim in [
          'safe to work',
          'is safe',
          'area safe',
          'approved',
          'authorised to',
        ]) {
          expect(
            strip,
            isNot(contains(claim)),
            reason: '${stage.name}: $claim',
          );
        }
      }
    });
  });

  group('Home renders every state', () {
    late WorkflowStore store;

    setUp(() => store = InMemoryWorkflowStore());

    Future<void> pumpHome(
      WidgetTester tester, {
      Size size = const Size(390, 1500),
      double textScale = 1,
      EdgeInsets viewPadding = EdgeInsets.zero,
    }) async {
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      // Tear the previous tree down first. `ShiftSessionController` reads the
      // store once in `build`, so re-pumping over a live tree with a new store
      // override leaves the old session in place — the loop would silently
      // assert against the previous stage.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

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
              key: ValueKey('/home'),
              config: _dev,
              initialLocation: '/home',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the dashboard survives having no data at all', (tester) async {
      await pumpHome(tester);

      // The whole architecture stays put. This is the regression that
      // prompted the rebuild: Home used to collapse to an empty state.
      expect(find.text("TODAY'S SHIFT"), findsOneWidget);
      expect(find.text('WORK CONTEXT'), findsOneWidget);
      expect(find.text('DOSEBAND MONITORING'), findsOneWidget);
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
      expect(find.text('Safe People'), findsOneWidget);

      // Missing data becomes an empty value, not a missing section.
      expect(find.text('Not provided'), findsWidgets);
      expect(find.text('Not selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an active period shows the trusted duration', (tester) async {
      await store.save(
        _session(
          ShiftStage.monitoring,
          startedAt: DateTime.now().subtract(
            const Duration(hours: 3, minutes: 42),
          ),
        ),
      );
      await pumpHome(tester);

      expect(find.text('MONITORING ACTIVE'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('3 h 42 min'), findsOneWidget);
      expect(find.text('End monitoring'), findsOneWidget);
      expect(find.text(_badge().badgeId), findsOneWidget);
    });

    testWidgets('an untrusted window never shows a duration', (tester) async {
      // The period "ended" before it began: the clock moved.
      await store.save(
        _session(
          ShiftStage.monitoring,
          startedAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      await pumpHome(tester);

      expect(find.text(Fmt.noValue), findsWidgets);
      expect(find.text('Duration not trustworthy'), findsOneWidget);
      expect(
        find.textContaining('device clock moved while monitoring'),
        findsOneWidget,
      );
      // And never a zero.
      expect(find.text('0 min'), findsNothing);
      expect(find.text('0 h 0 min'), findsNothing);
    });

    testWidgets('a restored session renders as monitoring, not empty', (
      tester,
    ) async {
      // The cold-start case: persistence handed back an active period, and
      // Home must not reset to "nothing happening".
      await store.save(
        _session(
          ShiftStage.monitoring,
          startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      await pumpHome(tester);

      expect(find.text('MONITORING ACTIVE'), findsOneWidget);
      expect(find.text('Not started'), findsNothing);
    });

    // One case per stage rather than a loop inside a single test: re-pumping
    // a second tree in the same test keeps the previous element tree alive,
    // and the assertion then reads a screen that never rebuilt.
    const ctaByStage = <ShiftStage, String>{
      ShiftStage.noShift: 'Start work context',
      ShiftStage.contextSet: 'Assign DoseBand',
      ShiftStage.badgeAssigned: 'Pre-work check',
      ShiftStage.readyForDosimetry: 'Start monitoring',
      ShiftStage.awaitingScan: 'Scan DoseBand',
    };

    for (final entry in ctaByStage.entries) {
      testWidgets('the CTA at ${entry.key.name} is "${entry.value}"', (
        tester,
      ) async {
        await store.save(
          _session(
            entry.key,
            startedAt: entry.key.index >= ShiftStage.monitoring.index
                ? DateTime.now().subtract(const Duration(hours: 1))
                : null,
            endedAt: entry.key == ShiftStage.awaitingScan
                ? DateTime.now()
                : null,
          ),
        );
        await pumpHome(tester);
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('a populated context fills the shift and context cards', (
      tester,
    ) async {
      await store.save(_session(ShiftStage.badgeAssigned));
      await pumpHome(tester);

      final demo = SimulationCatalog.demoContext();
      expect(find.text(demo.site.name), findsWidgets);
      expect(find.text(demo.department.name), findsOneWidget);
      expect(find.text(demo.worker.displayName), findsOneWidget);
      expect(find.text(demo.permit.reference.value), findsOneWidget);
      // Provenance travels with the reference onto Home.
      expect(find.text('DEMO'), findsWidgets);
      // The toolbox row states what was recorded, not that a talk happened.
      expect(find.text('Acknowledged'), findsOneWidget);
    });

    testWidgets('connectivity is reported honestly', (tester) async {
      await pumpHome(tester);
      // There is no backend, so nothing may claim to be online.
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Not synced'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
    });

    for (final stage in ShiftStage.values) {
      testWidgets('${stage.name} claims nothing about safety', (tester) async {
        await store.save(
          _session(
            stage,
            startedAt: stage.index >= ShiftStage.monitoring.index
                ? DateTime.now().subtract(const Duration(hours: 1))
                : null,
          ),
        );
        await pumpHome(tester);

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

    // A notched device. This is the case the golden tests cannot see: they
    // render with no safe-area inset, so a hero sized by a constant passes
    // there and overflows on a real iPhone — which is exactly what happened
    // during this rebuild.
    testWidgets('no overflow with a notch inset', (tester) async {
      await store.save(
        _session(
          ShiftStage.monitoring,
          startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );
      await pumpHome(
        tester,
        size: const Size(393, 852),
        viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow with a notch inset at 200% text', (tester) async {
      await store.save(_session(ShiftStage.noShift));
      await pumpHome(
        tester,
        size: const Size(393, 852),
        textScale: 2,
        viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
      );
      expect(tester.takeException(), isNull);
    });

    for (final width in <double>[360, 390, 430]) {
      testWidgets('no overflow at ${width.toInt()} wide', (tester) async {
        await store.save(
          _session(
            ShiftStage.monitoring,
            startedAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        );
        await pumpHome(tester, size: Size(width, 1500));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no overflow at 200% text', (tester) async {
      await store.save(
        _session(
          ShiftStage.monitoring,
          startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );
      await pumpHome(tester, size: const Size(390, 844), textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quick actions reach their screens', (tester) async {
      await pumpHome(tester, size: const Size(390, 1600));

      await tester.tap(find.text('Emergency'));
      await tester.pumpAndSettle();
      expect(find.text('Not configured'), findsOneWidget);
    });
  });
}
