import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/buttons.dart';
import 'package:h2s_doseband/core/design/theme.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/presentation/badge_verification_screen.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/badge_specimen.dart';
import 'package:h2s_doseband/features/workflow/domain/worker_identity.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:h2s_doseband/main.dart';

import '../support/signed_in.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

BadgeSpecimen _badge() => SimulationCatalog.specimens().first;

/// The enabled state of a [DoseBandButton] by its label.
///
/// The design system's button is a custom widget, not an [ElevatedButton], so
/// reaching for a Material type here would silently find nothing.
VoidCallback? _onPressedOf(WidgetTester tester, String label) {
  final button = tester.widget<DoseBandButton>(
    find.byWidgetPredicate((w) => w is DoseBandButton && w.label == label),
  );
  return button.onPressed;
}

void main() {
  late WorkflowStore store;

  setUp(() => store = InMemoryWorkflowStore());

  /// Pumps a route.
  ///
  /// The default viewport is deliberately taller than any phone. These screens
  /// are long scrollables, and a `ListView` does not build children that are
  /// off-screen — so a content-presence assertion on a realistic viewport would
  /// fail for a reason that has nothing to do with the content. The tests that
  /// are actually about layout pass a real phone size explicitly.
  Future<void> pumpAt(
    WidgetTester tester,
    String location, {
    String personId = PresentationDataset.lavitra,
    Size size = const Size(390, 5000),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(size.width * 3, size.height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          workflowStoreProvider.overrideWithValue(store),
          ...signedInOverrides(personId: personId),
        ],
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: DoseBandApp(
            key: ValueKey(location),
            config: _dev,
            initialLocation: location,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('the work-context form', () {
    testWidgets('inherits the site chosen at sign-in', (tester) async {
      await pumpAt(tester, '/work-context');
      expect(find.text('Mangalore Refinery'), findsWidgets);
    });

    testWidgets('shows the signed-in worker', (tester) async {
      await pumpAt(tester, '/work-context');
      expect(find.text('Lavitra Satam'), findsOneWidget);
      expect(find.text('E-10231'), findsOneWidget);
      expect(find.text('Employee'), findsOneWidget);
    });

    testWidgets('asks an employee for no contractor company', (tester) async {
      await pumpAt(tester, '/work-context');
      expect(find.text('Contractor company'), findsNothing);
    });

    testWidgets('asks a contractor for a contractor company', (tester) async {
      await pumpAt(
        tester,
        '/work-context',
        personId: PresentationDataset.aditya,
      );
      expect(find.text('Contractor company'), findsOneWidget);
    });

    testWidgets('offers departments, areas, shifts and permit types', (
      tester,
    ) async {
      await pumpAt(tester, '/work-context');
      expect(find.text('Operations'), findsOneWidget);
      expect(find.text('Health, Safety & Environment'), findsOneWidget);

      expect(find.text('Sulphur Recovery Unit — Demo area'), findsOneWidget);
      expect(find.text('Shift A · 06:00–14:00'), findsOneWidget);
    });

    testWidgets('lists what is still needed', (tester) async {
      await pumpAt(tester, '/work-context');
      expect(find.text('Still needed'), findsOneWidget);
      expect(find.text('PTW reference recorded'), findsOneWidget);
      expect(find.text('Toolbox talk acknowledged'), findsOneWidget);
    });

    testWidgets('records a typed permit as manual, never verified', (
      tester,
    ) async {
      await pumpAt(tester, '/work-context');
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. PTW-24-11873'),
        'PTW-24-11873',
      );
      await tester.pump();

      expect(find.text('PTW-24-11873'), findsWidgets);
      // The provenance chip follows the value onto the screen.
      expect(find.text('Manual'), findsWidgets);
      expect(find.text('Verified'), findsNothing);
    });

    testWidgets('the toolbox acknowledgement says what it is not', (
      tester,
    ) async {
      await pumpAt(tester, '/work-context');
      expect(
        find.textContaining('does not replace the organisation'),
        findsOneWidget,
      );
    });

    testWidgets('continue is disabled until the context is complete', (
      tester,
    ) async {
      await pumpAt(tester, '/work-context');
      expect(_onPressedOf(tester, 'Continue to badge'), isNull);
    });
  });

  group('the pre-work check', () {
    Future<void> seed(ShiftStage stage) async {
      await store.save(
        ShiftSession(
          stage: stage,
          context: SimulationCatalog.demoContext(),
          badge: _badge(),
          startedAt: stage.index >= ShiftStage.monitoring.index
              ? DateTime(2026, 9, 25, 6)
              : null,
        ),
      );
    }

    testWidgets('start is disabled while requirements are missing', (
      tester,
    ) async {
      await pumpAt(tester, '/prework');
      expect(_onPressedOf(tester, 'Start monitoring'), isNull);
      expect(find.text('Not ready'), findsOneWidget);
      expect(find.text('Ready for dosimetry'), findsNothing);
    });

    testWidgets('"Ready for dosimetry" appears only when requirements pass', (
      tester,
    ) async {
      await seed(ShiftStage.badgeAssigned);
      await pumpAt(tester, '/prework');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Ready for dosimetry'), findsOneWidget);
      expect(_onPressedOf(tester, 'Start monitoring'), isNotNull);
    });

    testWidgets('says what ready for dosimetry does not mean', (tester) async {
      await seed(ShiftStage.badgeAssigned);
      await pumpAt(tester, '/prework');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('does not authorise work'), findsOneWidget);
      expect(find.textContaining('does not replace PTW'), findsOneWidget);
    });

    testWidgets('warns that nothing was checked externally', (tester) async {
      await seed(ShiftStage.badgeAssigned);
      await pumpAt(tester, '/prework');
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.textContaining('has been checked against an MRPL system'),
        findsOneWidget,
      );
    });

    testWidgets('no screen in the flow says "safe to work"', (tester) async {
      for (final route in ['/work-context', '/prework', '/active']) {
        await seed(ShiftStage.monitoring);
        await pumpAt(tester, route);
        await tester.pump(const Duration(milliseconds: 200));

        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => (t.data ?? '').toLowerCase());
        for (final text in texts) {
          expect(
            text.contains('safe to work'),
            isFalse,
            reason: '$route rendered: $text',
          );
          expect(
            text.contains('ptw approved'),
            isFalse,
            reason: '$route rendered: $text',
          );
        }
      }
    });
  });

  group('an active period locks its context', () {
    testWidgets('the work-context screen becomes a read-only record', (
      tester,
    ) async {
      await store.save(
        ShiftSession(
          stage: ShiftStage.monitoring,
          context: SimulationCatalog.demoContext(),
          badge: _badge(),
          startedAt: DateTime(2026, 9, 25, 6),
        ),
      );
      await pumpAt(tester, '/work-context');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('cannot be changed'), findsOneWidget);
      // No way to edit anything.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Continue to badge'), findsNothing);
    });

    testWidgets('the badge cannot be reassigned from a stale route', (
      tester,
    ) async {
      // A back stack or a deep link can land on /verify during monitoring.
      // The controller throws there, so the screen has to refuse first —
      // otherwise the worker meets a crash instead of an explanation.
      await store.save(
        ShiftSession(
          stage: ShiftStage.monitoring,
          context: SimulationCatalog.demoContext(),
          badge: _badge(),
          startedAt: DateTime(2026, 9, 25, 6),
        ),
      );
      // Pumped directly: the route takes its specimen as `extra`, so the
      // realistic way to arrive here mid-monitoring is the back button from
      // pre-work, which re-renders this screen with the specimen it already
      // had.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentConfigProvider.overrideWithValue(_dev),
            workflowStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            theme: buildDoseBandTheme(brightness: Brightness.light),
            home: BadgeVerificationScreen(specimen: _badge()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('cannot be changed'), findsOneWidget);
      expect(find.text('Assign this badge'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a restored context renders on home', (tester) async {
      await store.save(
        ShiftSession(
          stage: ShiftStage.monitoring,
          context: SimulationCatalog.demoContext(),
          badge: _badge(),
          startedAt: DateTime(2026, 9, 25, 6),
        ),
      );
      await pumpAt(tester, '/home');
      await tester.pump(const Duration(milliseconds: 200));

      // Home was rebuilt in UI-SURFACE-01: it renders its own dashboard
      // sections rather than the WorkContextSummary group headers.
      expect(find.text("TODAY'S SHIFT"), findsOneWidget);
      expect(find.text('WORK CONTEXT'), findsOneWidget);
      expect(find.text('MONITORING ACTIVE'), findsOneWidget);
      // The restored context's own values are on screen.
      expect(
        find.text(SimulationCatalog.demoContext().site.name),
        findsWidgets,
      );
    });

    testWidgets('a contractor row appears only for a contractor', (
      tester,
    ) async {
      await store.save(
        ShiftSession(
          stage: ShiftStage.monitoring,
          context: SimulationCatalog.demoContext(
            workerType: WorkerType.contractor,
          ),
          badge: _badge(),
          startedAt: DateTime(2026, 9, 25, 6),
        ),
      );
      await pumpAt(tester, '/home');
      await tester.pump(const Duration(milliseconds: 200));
      // The rebuilt identity card puts the employment type and the worker ID
      // on one line, and the employing contractor on the next.
      expect(find.textContaining('Contractor · ID'), findsOneWidget);
      expect(find.text('XYZ Engineering'), findsOneWidget);
    });
  });

  group('the layout holds up', () {
    testWidgets('a small screen does not overflow', (tester) async {
      await pumpAt(tester, '/work-context', size: const Size(320, 568));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% text does not break the form', (tester) async {
      await pumpAt(
        tester,
        '/work-context',
        textScale: 2,
        size: const Size(390, 844),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% text does not break the pre-work check', (tester) async {
      await store.save(
        ShiftSession(
          stage: ShiftStage.badgeAssigned,
          context: SimulationCatalog.demoContext(),
          badge: _badge(),
        ),
      );
      await pumpAt(
        tester,
        '/prework',
        textScale: 2,
        size: const Size(390, 844),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}
