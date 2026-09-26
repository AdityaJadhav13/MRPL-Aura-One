import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/core/util/format.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/reporting/data/reporting_demo_catalog.dart';
import 'package:h2s_doseband/features/reporting/domain/report_models.dart';
import 'package:h2s_doseband/features/reporting/domain/simulated_exposure.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String route, {
    Size size = const Size(390, 6000),
    double textScale = 1,
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [environmentConfigProvider.overrideWithValue(_dev)],
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

  const reportingRoutes = <String, String>{
    '/reporting': 'Reporting',
    '/reporting/register': 'Occupational exposure register',
    '/reporting/builder': 'Report builder',
    '/reporting/audit-package': 'Audit package',
    '/reporting/history': 'Report history',
  };

  // ===================================================================
  // §55 — null semantics. The rule this whole phase turns on.
  // ===================================================================

  group('a missing measurement is never zero', () {
    test('only simulated-valid states may carry a quantity', () {
      for (final state in ReportedMeasurement.values) {
        final mayCarry =
            state == ReportedMeasurement.simulatedValid ||
            state == ReportedMeasurement.simulatedValidWithWarning;
        expect(state.carriesQuantity, mayCarry, reason: state.name);
      }
    });

    test('a state without a quantity formats as the placeholder, not 0', () {
      for (final state in ReportedMeasurement.values.where(
        (s) => !s.carriesQuantity,
      )) {
        final cell = MeasurementCell.of(
          state,
          null,
          absentPlaceholder: Fmt.noValue,
        );
        expect(cell.text, Fmt.noValue, reason: state.name);
        expect(cell.text, isNot('0'), reason: state.name);
        expect(cell.text, isNot('0.0'), reason: state.name);
        expect(cell.isSimulatedQuantity, isFalse, reason: state.name);
      }
    });

    test('formatting refuses a quantity a state is not entitled to', () {
      // The strongest form of the rule: a defect in the data is a thrown
      // error, not a silently printed number or a silently dropped one.
      expect(
        () => MeasurementCell.of(
          ReportedMeasurement.noReading,
          const SimulatedExposure.ppmHours(4.2),
          absentPlaceholder: Fmt.noValue,
        ),
        throwsArgumentError,
      );
    });

    test('no record in the catalogue violates the rule', () {
      for (final r in ReportingDemoCatalog.records()) {
        if (r.exposure != null) {
          expect(r.measurement.carriesQuantity, isTrue, reason: r.recordId);
        }
      }
    });

    test('the distinct states stay distinct', () {
      // Each of these is a different fact about the world, and collapsing any
      // pair of them loses information a reviewer needs.
      expect(
        ReportedMeasurement.aboveValidatedRange,
        isNot(ReportedMeasurement.saturated),
      );
      expect(
        ReportedMeasurement.belowQuantificationLimit,
        isNot(ReportedMeasurement.noReading),
      );
      expect(
        ReportedMeasurement.unsupportedCalibration,
        isNot(ReportedMeasurement.noReading),
      );
      expect(ReportedMeasurement.partialMonitoring.carriesQuantity, isFalse);
    });

    test('above-range and saturated are separate records', () {
      final both = ReportingDemoCatalog.aboveRangeOrSaturated();
      expect(
        both.any(
          (r) => r.measurement == ReportedMeasurement.aboveValidatedRange,
        ),
        isTrue,
      );
      expect(
        both.any((r) => r.measurement == ReportedMeasurement.saturated),
        isTrue,
      );
    });

    test('partial monitoring is distinct from complete', () {
      final partial = ReportingDemoCatalog.incompleteMonitoring();
      expect(partial, isNotEmpty);
      for (final r in partial) {
        expect(r.monitoringComplete, isFalse, reason: r.recordId);
        // And no figure has been scaled up to a full period.
        expect(r.exposure, isNull, reason: r.recordId);
      }
    });

    testWidgets('the register prints no zero exposure', (tester) async {
      await pumpAt(tester, '/reporting/register');
      for (final line in visibleText(tester)) {
        expect(
          RegExp(r'^0(\.0+)?\s*ppm').hasMatch(line.trim()),
          isFalse,
          reason: line,
        );
      }
      expect(find.text(Fmt.noValue), findsWidgets);
    });

    testWidgets('no average or total is reported', (tester) async {
      await pumpAt(tester, '/reporting/builder');
      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();

      expect(find.text('Not reported'), findsWidgets);
      final text = visibleText(tester).join(' ');
      expect(text, contains('cannot be included in an average'));
    });
  });

  // ===================================================================
  // §20, §42 — simulated figures must stay unmistakable.
  // ===================================================================

  group('quantitative figures are unmistakably simulated', () {
    test('the exposure type has no non-simulated constructor', () {
      const value = SimulatedExposure.ppmHours(4.2);
      expect(value.isSimulated, isTrue);
      expect(value.value, 4.2);
    });

    testWidgets('a figure carries the marker beside it', (tester) async {
      await pumpAt(tester, '/reporting/register');
      // Every rendered figure has a SIMULATED chip next to it.
      expect(find.text('SIMULATED'), findsWidgets);
    });

    // Every screen that puts a quantity on the page, and only those. The
    // builder chooses sections and report types and shows no figures, so a
    // banner there would be noise; this list previously included it and
    // passed only because the loop never actually left the first route.
    testWidgets('the standing calibration banner is shown', (tester) async {
      await pumpAt(tester, '/reporting/register');
      expect(find.text('Exposure figures are simulated'), findsWidgets);

      // The record and the preview carry their subject in `extra`, so they
      // are reached the way a user reaches them rather than by URL.
      await tester.tap(find.text('OER-2026-0924-0102'));
      await tester.pumpAndSettle();
      expect(
        find.text('Exposure figures are simulated'),
        findsWidgets,
        reason: 'the traceability view shows a quantity',
      );
    });

    testWidgets('the register says no production calibration exists', (
      tester,
    ) async {
      await pumpAt(tester, '/reporting/register');
      final text = visibleText(tester).join(' ');
      expect(text, contains('no production h₂s calibration exists'));
    });
  });

  // ===================================================================
  // §56 — regulatory language.
  // ===================================================================

  group('no regulatory claim is made', () {
    test('no template profile name claims compliance', () {
      for (final profile in ReportTemplateProfile.values) {
        final label = profile.label.toLowerCase();
        for (final claim in [
          'compliant',
          'approved',
          'certified',
          'verified',
        ]) {
          expect(label, isNot(contains(claim)), reason: profile.name);
        }
      }
    });

    test('profiles naming a regulator carry a caveat', () {
      for (final profile in ReportTemplateProfile.values) {
        expect(profile.caveat, isNotEmpty, reason: profile.name);
      }
      expect(
        ReportTemplateProfile.oisdAligned.caveat.toLowerCase(),
        contains('not yet verified'),
      );
      expect(
        ReportTemplateProfile.dgmsAligned.caveat.toLowerCase(),
        contains('has not been established'),
      );
      expect(ReportTemplateProfile.oisdAligned.referencesRegulator, isTrue);
    });

    testWidgets('no reporting screen claims compliance', (tester) async {
      for (final route in reportingRoutes.keys) {
        await pumpAt(tester, route);
        for (final line in visibleText(tester)) {
          for (final claim in [
            'oisd compliant',
            'oisd approved',
            'oisd certified',
            'dgms compliant',
            'dgms approved',
            'dgms certified',
            'mrpl approved',
            'mrpl certified',
            'mrpl verified',
            'regulatory compliant',
          ]) {
            expect(line, isNot(contains(claim)), reason: '$route: $line');
          }
        }
      }
    });

    testWidgets('an aligned profile shows its caveat when selected', (
      tester,
    ) async {
      await pumpAt(tester, '/reporting/builder');
      await tester.tap(find.text('OISD-aligned'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Not yet verified against applicable OISD'),
        findsOneWidget,
      );
    });
  });

  // ===================================================================
  // §57 — export honesty.
  // ===================================================================

  group('nothing claims an export happened', () {
    testWidgets('export controls are disabled everywhere', (tester) async {
      for (final route in ['/reporting/builder', '/reporting/audit-package']) {
        await pumpAt(tester, route);
        for (final button in tester.widgetList<OutlinedButton>(
          find.byType(OutlinedButton),
        )) {
          expect(button.onPressed, isNull, reason: route);
        }
        for (final button in tester.widgetList<FilledButton>(
          find.byType(FilledButton),
        )) {
          // The only enabled FilledButton in reporting is "Open preview".
          final enabled = button.onPressed != null;
          if (enabled) {
            expect(
              find.descendant(
                of: find.byWidget(button),
                matching: find.text('Open preview'),
              ),
              findsOneWidget,
              reason: route,
            );
          }
        }
      }
    });

    testWidgets('no success language appears', (tester) async {
      for (final route in reportingRoutes.keys) {
        await pumpAt(tester, route);
        final text = visibleText(tester).join(' ');
        for (final claim in [
          'report generated',
          'export successful',
          'download complete',
          'official report created',
          'submitted to oisd',
          'submitted to dgms',
          'submitted to mrpl',
        ]) {
          expect(text, isNot(contains(claim)), reason: '$route: $claim');
        }
      }
    });

    test('no export format reports itself as available', () {
      for (final format in ExportFormat.values) {
        expect(
          format.availability,
          ExportAvailability.notConnected,
          reason: format.name,
        );
      }
    });

    testWidgets('report history is empty rather than invented', (tester) async {
      await pumpAt(tester, '/reporting/history');
      expect(find.text('No reports have been generated'), findsOneWidget);
      expect(find.text('Unavailable'), findsWidgets);
      expect(ReportingDemoCatalog.reportHistory(), isEmpty);
    });

    testWidgets('the preview says it is a preview', (tester) async {
      await pumpAt(tester, '/reporting/builder');
      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();
      final text = visibleText(tester).join(' ');
      expect(text, contains('preview only'));
      expect(text, contains('no report has been generated'));
      expect(find.textContaining('Not assigned'), findsWidgets);
    });

    testWidgets('the audit package claims no signature', (tester) async {
      await pumpAt(tester, '/reporting/audit-package');
      final text = visibleText(tester).join(' ');
      expect(text, contains('not applicable'));
      expect(text, contains('holds no signing keys'));
      expect(text, isNot(contains('digitally signed')));
    });
  });

  // ===================================================================
  // §54 — the traceability chain. The phase exit criterion.
  // ===================================================================

  group('a record can be traced end to end', () {
    testWidgets('the chain is complete and in order', (tester) async {
      await pumpAt(tester, '/reporting/register');
      await tester.tap(find.text('OER-2026-0924-0102'));
      await tester.pumpAndSettle();

      // Every link, named.
      for (final step in [
        'Worker',
        'Shift',
        'Work area',
        'Job',
        'Permit and JSA',
        'Badge',
        'Monitoring window',
        'Badge read',
        'MEASUREMENT',
        'Validity and quality',
        'Calibration and software',
        'HSE review',
        'Audit',
      ]) {
        expect(find.text(step), findsWidgets, reason: step);
      }
    });

    testWidgets('it carries the actual values, not placeholders', (
      tester,
    ) async {
      await pumpAt(tester, '/reporting/register');
      await tester.tap(find.text('OER-2026-0924-0102'));
      await tester.pumpAndSettle();

      expect(find.text('PTW-DEMO-4471'), findsWidgets);
      expect(find.text('JSA-DEMO-2048'), findsWidgets);
      expect(find.text('DB-4K7Q9'), findsWidgets);
      expect(find.text('L26-0912-A'), findsWidgets);
      expect(find.text('EMP-21003'), findsWidgets);
    });

    testWidgets('it is read-only', (tester) async {
      await pumpAt(tester, '/reporting/register');
      await tester.tap(find.text('OER-2026-0924-0102'));
      await tester.pumpAndSettle();

      // No control that edits a measurement, a window or a disposition.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      final text = visibleText(tester).join(' ');
      expect(text, contains('read-only here'));
      expect(text, contains('does not rewrite a measurement'));
    });

    testWidgets('an untrusted window shows no duration', (tester) async {
      await pumpAt(tester, '/reporting/register');
      await tester.tap(find.text('OER-2026-0920-0039'));
      await tester.pumpAndSettle();

      expect(find.text('Not trustworthy'), findsOneWidget);
      final text = visibleText(tester).join(' ');
      expect(text, contains('cannot be established'));
      expect(find.text('0 min'), findsNothing);
    });

    testWidgets('quality evidence reads not recorded, not passed', (
      tester,
    ) async {
      await pumpAt(tester, '/reporting/register');
      await tester.tap(find.text('OER-2026-0924-0102'));
      await tester.pumpAndSettle();

      expect(find.text('Not recorded'), findsWidgets);
      final text = visibleText(tester).join(' ');
      expect(text, contains('not the same as "passed"'));
    });
  });

  // ===================================================================
  // Navigation, methodology, layout.
  // ===================================================================

  group('every reporting route resolves', () {
    for (final entry in reportingRoutes.entries) {
      testWidgets('${entry.key} renders', (tester) async {
        await pumpAt(tester, entry.key);
        expect(tester.takeException(), isNull);
        expect(find.text(entry.value), findsWidgets);
      });
    }

    testWidgets('the centre reaches the register and builder', (tester) async {
      await pumpAt(tester, '/reporting');
      expect(find.text('Occupational exposure register'), findsWidgets);
      expect(find.text('Report builder'), findsWidgets);
      expect(find.text('Audit package'), findsWidgets);
      expect(find.text('Report history'), findsWidgets);
    });
  });

  group('methodology stays within what DoseBand measures', () {
    testWidgets('the preview describes external exposure only', (tester) async {
      await pumpAt(tester, '/reporting/builder');
      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();

      final text = visibleText(tester).join(' ');
      expect(text, contains('estimated cumulative external h₂s exposure'));
      expect(text, contains('does not measure absorbed dose'));
      for (final claim in [
        'blood concentration',
        'biological dose',
        'health status',
      ]) {
        expect(text, contains(claim), reason: 'denial of $claim');
      }
    });

    testWidgets('limitations are present and current', (tester) async {
      await pumpAt(tester, '/reporting/builder');
      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();

      final text = visibleText(tester).join(' ');
      expect(text, contains('must not be interpreted as zero exposure'));
      expect(text, contains('does not replace approved real-time gas'));
      expect(text, contains('s1, s2 and s3 remain open'));
    });
  });

  group('the reporting surface holds its layout', () {
    for (final width in <double>[360, 390, 430]) {
      testWidgets('every route at ${width.toInt()} wide', (tester) async {
        for (final route in reportingRoutes.keys) {
          await pumpAt(tester, route, size: Size(width, 6000));
          expect(tester.takeException(), isNull, reason: route);
        }
      });
    }

    testWidgets('a wide layout uses a table', (tester) async {
      await pumpAt(tester, '/reporting/register', size: const Size(1100, 2000));
      expect(find.byType(DataTable), findsOneWidget);
    });

    testWidgets('a phone uses cards, not a table', (tester) async {
      await pumpAt(tester, '/reporting/register', size: const Size(390, 6000));
      expect(find.byType(DataTable), findsNothing);
    });

    for (final route in <String>[
      '/reporting',
      '/reporting/register',
      '/reporting/builder',
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
}
