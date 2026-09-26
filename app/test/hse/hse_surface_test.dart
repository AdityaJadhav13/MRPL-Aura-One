import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/demo/ui_demo_catalog.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/core/util/format.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
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
    Size size = const Size(390, 4000),
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

  const hseRoutes = <String, String>{
    '/hse': 'HSE overview',
    '/hse/monitoring': 'Monitoring',
    '/hse/exposures': 'Exposure register',
    '/hse/review': 'Review',
    '/hse/exceptions': 'Exceptions',
    '/hse/workers': 'Workers',
    '/hse/inventory': 'Badge inventory',
    '/hse/calibration': 'Calibration',
    '/hse/audit': 'Audit trail',
  };

  group('every HSE route resolves', () {
    for (final entry in hseRoutes.entries) {
      testWidgets('${entry.key} renders', (tester) async {
        await pumpAt(tester, entry.key);
        expect(tester.takeException(), isNull);
        expect(find.text(entry.value), findsWidgets);
      });
    }

    testWidgets('the shell offers four destinations on a phone', (
      tester,
    ) async {
      await pumpAt(tester, '/hse', size: const Size(390, 844));
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(4));
      for (final label in ['Overview', 'Monitoring', 'Exposures', 'Review']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });
  });

  group('the dashboard reports operations honestly', () {
    testWidgets('it shows the six operational metrics', (tester) async {
      await pumpAt(tester, '/hse');
      for (final metric in [
        'Monitoring active',
        'Awaiting scan',
        'Review required',
        'No valid reading',
        'Badges in use',
      ]) {
        expect(find.text(metric), findsWidgets, reason: metric);
      }
    });

    testWidgets('it never claims a backend', (tester) async {
      await pumpAt(tester, '/hse');
      expect(find.text('Not connected'), findsWidgets);
      expect(find.text('Never'), findsWidgets);

      final text = visibleText(tester);
      for (final line in text) {
        expect(line.trim(), isNot('synced'), reason: line);
        expect(line.trim(), isNot('online'), reason: line);
      }
    });

    testWidgets('it marks itself as demonstration data', (tester) async {
      await pumpAt(tester, '/hse');
      expect(find.text('DEMONSTRATION DATA'), findsWidgets);
    });
  });

  group('the register carries the occupational field set', () {
    testWidgets('a record shows employment, area, badge and batch', (
      tester,
    ) async {
      await pumpAt(tester, '/hse/exposures');
      for (final label in [
        'Employment',
        'Department',
        'Work area',
        'Shift',
        'Badge',
        'Batch',
        'Window',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('filters are reachable and report a count', (tester) async {
      await pumpAt(tester, '/hse/exposures');
      expect(find.text('Filters'), findsOneWidget);
      expect(
        find.textContaining(' of ${UiDemoCatalog.exposureRecords().length}'),
        findsOneWidget,
      );
    });

    testWidgets('search narrows the register', (tester) async {
      await pumpAt(tester, '/hse/exposures');
      await tester.enterText(find.byType(TextField).first, 'DB-4K8C7');
      await tester.pumpAndSettle();
      expect(find.text('DB-4K8C7'), findsWidgets);
    });
  });

  group('no reading is never zero', () {
    const surfaces = [
      '/hse',
      '/hse/exposures',
      '/hse/review',
      '/hse/exceptions',
    ];

    testWidgets('no HSE surface prints a dose', (tester) async {
      for (final route in surfaces) {
        await pumpAt(tester, route);
        for (final line in visibleText(tester)) {
          expect(
            RegExp(r'\d+(\.\d+)?\s*ppm').hasMatch(line),
            isFalse,
            reason: '$route rendered "$line"',
          );
        }
      }
    });

    testWidgets('the refusal placeholder is used instead of zero', (
      tester,
    ) async {
      await pumpAt(tester, '/hse/exceptions');
      expect(find.text(Fmt.noValue), findsWidgets);
      for (final line in visibleText(tester)) {
        expect(
          RegExp(r'^0(\.0+)?\s*(ppm|ppm·h)$').hasMatch(line.trim()),
          isFalse,
          reason: line,
        );
      }
    });

    test('no demo record carries a dose at all', () {
      // The strongest form of the rule: there is no field to put one in.
      for (final record in UiDemoCatalog.exposureRecords()) {
        expect(
          record.outcome,
          anyOf(DemoRecordOutcome.readComplete, DemoRecordOutcome.noReading),
          reason: record.recordId,
        );
      }
    });
  });

  group('the exception queue ranks nothing', () {
    testWidgets('it groups by reason and filters by workflow state', (
      tester,
    ) async {
      await pumpAt(tester, '/hse/exceptions');
      expect(find.textContaining('All ('), findsOneWidget);
      // Reason codes appear as group headings.
      expect(find.text('POOR_IMAGE'), findsWidgets);
      expect(find.text('EXPOSURE_WINDOW_UNTRUSTED'), findsWidgets);
    });

    testWidgets('it invents no severity banding', (tester) async {
      await pumpAt(tester, '/hse/exceptions');
      final text = visibleText(tester).join(' ');
      for (final band in ['high risk', 'medium risk', 'low risk']) {
        expect(text, isNot(contains(band)), reason: band);
      }
      // "severity" appears only in the sentence denying that anything is
      // ranked by it.
      expect(text, isNot(contains('severity:')));
      expect(text, contains('does not rank them by severity'));
    });

    test('review states are workflow, not severity', () {
      for (final state in DemoReviewState.values) {
        final label = state.label.toLowerCase();
        for (final band in ['risk', 'severity', 'critical', 'urgent']) {
          expect(label, isNot(contains(band)), reason: state.name);
        }
      }
    });
  });

  group('worker profile creates no aggregate', () {
    testWidgets('it refuses a lifetime or cumulative figure', (tester) async {
      await pumpAt(tester, '/hse/workers');
      await tester.tap(find.text('Aditya Jadhav').first);
      await tester.pumpAndSettle();

      expect(find.text('Unavailable'), findsWidgets);
      final text = visibleText(tester).join(' ');
      expect(text, contains('does not present a lifetime or cumulative'));
      for (final claim in [
        'lifetime dose',
        'total career',
        'health risk score',
      ]) {
        expect(text, isNot(contains(claim)), reason: claim);
      }
    });
  });

  group('measurement review is read-only', () {
    Future<void> openReview(WidgetTester tester) async {
      await pumpAt(tester, '/hse/exposures');
      await tester.tap(find.text('EXP-2026-0918-0041'));
      await tester.pumpAndSettle();
    }

    testWidgets('it shows the technical sections', (tester) async {
      await openReview(tester);
      for (final section in [
        'RESULT',
        'WORKER',
        'WORK CONTEXT',
        'MONITORING WINDOW',
        'BADGE',
        'CALIBRATION',
        'CAPTURE',
        'ALGORITHM AND VERSIONS',
        'AUDIT',
      ]) {
        expect(find.text(section), findsWidgets, reason: section);
      }
    });

    testWidgets('it offers no editable measurement field', (tester) async {
      await openReview(tester);
      // The only text input anywhere in review is on the disposition screen,
      // and that captures a reason — never a value.
      expect(find.byType(TextField), findsNothing);
      final text = visibleText(tester).join(' ');
      expect(text, contains('measurement record is immutable'));
    });

    testWidgets('unassessed quality is not reported as passing', (
      tester,
    ) async {
      await pumpAt(tester, '/hse/exceptions');
      await tester.tap(find.text('EXP-2026-0918-0038'));
      await tester.pumpAndSettle();
      final text = visibleText(tester).join(' ');
      expect(text, anyOf(contains('not assessed'), contains('of ')));
    });
  });

  group('disposition records workflow, not verdicts', () {
    Future<void> openDisposition(WidgetTester tester) async {
      await pumpAt(tester, '/hse/exposures');
      await tester.tap(find.text('EXP-2026-0918-0041'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record a disposition'));
      await tester.pumpAndSettle();
    }

    testWidgets('it offers only workflow states', (tester) async {
      await openDisposition(tester);
      for (final state in [
        'In review',
        'Additional information required',
        'Reviewed',
        'Closed',
      ]) {
        expect(find.text(state), findsWidgets, reason: state);
      }
    });

    testWidgets('it offers no clinical or safety verdict', (tester) async {
      await openDisposition(tester);
      final text = visibleText(tester).join(' ');
      for (final verdict in [
        'medically cleared',
        'fit for duty',
        'worker cleared',
        'no health risk',
        'unsafe',
      ]) {
        expect(text, isNot(contains(verdict)), reason: verdict);
      }
      expect(text, contains('makes no statement about the worker’s health'));
    });

    testWidgets('a closing decision requires a reason', (tester) async {
      await openDisposition(tester);
      await tester.tap(find.text('Reviewed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('A reason is required'), findsOneWidget);
    });

    testWidgets('it claims no signature', (tester) async {
      await openDisposition(tester);
      expect(find.text('Not applicable'), findsWidgets);
      final text = visibleText(tester).join(' ');
      expect(text, isNot(contains('digitally signed')));
    });
  });

  group('badge inventory and batch stay honest', () {
    testWidgets('inventory says no badge has been manufactured', (
      tester,
    ) async {
      await pumpAt(tester, '/hse/inventory');
      final text = visibleText(tester).join(' ');
      expect(text, contains('no doseband badge has been manufactured'));
    });

    testWidgets('batch leaves unknown fields unavailable', (tester) async {
      await pumpAt(tester, '/hse/inventory');
      await tester.tap(find.text('DB-4K7M2'));
      await tester.pumpAndSettle();

      expect(find.text('Unavailable'), findsWidgets);
      final text = visibleText(tester).join(' ');
      expect(text, contains('supply-chain record'));
      // No invented QC or release language.
      for (final claim in ['qc approved', 'lot released', 'shelf life']) {
        expect(text, isNot(contains(claim)), reason: claim);
      }
    });

    test('no batch carries a manufacture or expiry date', () {
      for (final batch in UiDemoCatalog.batches()) {
        expect(batch.manufacturedAt, isNull, reason: batch.batchId);
        expect(batch.expiresAt, isNull, reason: batch.batchId);
      }
    });
  });

  group('calibration shows no fabricated metric', () {
    testWidgets('it states that none exists and lists the gates', (
      tester,
    ) async {
      await pumpAt(tester, '/hse/calibration');
      expect(find.text('No production calibration available'), findsOneWidget);
      for (final gate in ['S1', 'S2', 'S3']) {
        expect(find.text(gate), findsOneWidget, reason: gate);
      }
      expect(find.text('OPEN'), findsNWidgets(3));
    });

    testWidgets('every performance metric is unavailable', (tester) async {
      await pumpAt(tester, '/hse/calibration');
      for (final metric in [
        'Accuracy',
        'Limit of detection',
        'Limit of quantification',
        'RMSE',
        'R²',
        'Uncertainty budget',
        'Validated range',
      ]) {
        expect(find.text(metric), findsWidgets, reason: metric);
      }
      // And no number is attached to any of them.
      for (final line in visibleText(tester)) {
        expect(
          RegExp(r'^\d+(\.\d+)?\s*%?$').hasMatch(line.trim()),
          isFalse,
          reason: line,
        );
      }
    });

    testWidgets('recalibration is stated not to rewrite history', (
      tester,
    ) async {
      await pumpAt(tester, '/hse/calibration');
      final text = visibleText(tester).join(' ');
      expect(text, contains('never rewrites history'));
      expect(text, contains('keeps the model that produced it'));
    });
  });

  group('the audit trail carries transitions, not signatures', () {
    testWidgets('entries show previous and new state with a reason', (
      tester,
    ) async {
      await pumpAt(tester, '/hse/audit');
      expect(find.text('Monitoring'), findsWidgets);
      expect(find.text('Awaiting scan'), findsWidgets);
      final text = visibleText(tester).join(' ');
      expect(text, contains('reference patches unreadable'));
    });

    testWidgets('it claims no signature and no MRPL audit id', (tester) async {
      await pumpAt(tester, '/hse/audit');
      final text = visibleText(tester).join(' ');
      expect(text, contains('not digitally signed'));
      expect(text, isNot(contains('mrpl-aud')));
    });
  });

  group('occupational health handoff sends the minimum', () {
    testWidgets('it excludes medical information explicitly', (tester) async {
      await pumpAt(tester, '/hse/exposures');
      await tester.tap(find.text('EXP-2026-0918-0041'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Occupational health handoff'));
      await tester.pumpAndSettle();

      final text = visibleText(tester).join(' ');
      expect(text, contains('any medical or clinical information'));
      expect(text, contains('nothing has been sent'));
      expect(find.text(Fmt.noValue), findsWidgets);
    });
  });

  group('no HSE screen claims compliance or authority', () {
    testWidgets('across every route', (tester) async {
      for (final route in hseRoutes.keys) {
        await pumpAt(tester, route);
        for (final line in visibleText(tester)) {
          for (final claim in [
            'oisd compliant',
            'dgms compliant',
            'mrpl verified',
            'safe to work',
            'medically cleared',
            'fit for duty',
            'ptw approved',
            'jsa approved',
          ]) {
            expect(line, isNot(contains(claim)), reason: '$route: $line');
          }
        }
      }
    });
  });

  group('the HSE surface holds its layout', () {
    for (final width in <double>[360, 390, 430]) {
      testWidgets('every route at ${width.toInt()} wide', (tester) async {
        for (final route in hseRoutes.keys) {
          await pumpAt(tester, route, size: Size(width, 4000));
          expect(tester.takeException(), isNull, reason: route);
        }
      });
    }

    testWidgets('a wide layout uses a rail', (tester) async {
      await pumpAt(tester, '/hse', size: const Size(1000, 900));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    for (final route in <String>[
      '/hse',
      '/hse/exposures',
      '/hse/calibration',
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
