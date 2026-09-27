import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/buttons.dart';
import 'package:h2s_doseband/core/components/product_navigation.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/operations/application/hse_service.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/operations/domain/review.dart';
import 'package:h2s_doseband/features/reporting/domain/register_export.dart';
import 'package:h2s_doseband/main.dart';
import 'package:measurement/measurement.dart';

import '../operations/operations_fixtures.dart';
import '../support/signed_in.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// PRODUCT BUILD v1 §38–§41, §122, §125.
void main() {
  final now = DateTime(2026, 9, 27, 10, 30);

  Finder button(String label) =>
      find.byWidgetPredicate((w) => w is DoseBandButton && w.label == label);

  Future<ProviderContainer> pumpAt(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(390 * 2, 2600 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(
      overrides: [
        environmentConfigProvider.overrideWithValue(_dev),
        ...signedInOverrides(
          personId: PresentationDataset.samhita,
          seed: datasetWithRecord(now),
          now: now,
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: DoseBandApp(
          key: ValueKey(route),
          config: _dev,
          initialLocation: route,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  List<String> texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();

  testWidgets('the shell has the five approved destinations', (tester) async {
    await pumpAt(tester, '/hse');
    for (final d in ['Overview', 'Exposures', 'Reviews', 'Reports', 'More']) {
      expect(
        find.descendant(
          of: find.byType(FloatingNavigationBar),
          matching: find.text(d),
        ),
        findsOneWidget,
        reason: d,
      );
    }
  });

  testWidgets('the register lists the record with its separate states', (
    tester,
  ) async {
    await pumpAt(tester, '/hse/exposures');
    expect(find.text('Aditya Jadhav'), findsOneWidget);
    expect(find.text('No Reading — no calibration'), findsOneWidget);
    expect(find.text('Awaiting review'), findsWidgets);
  });

  testWidgets('search narrows the register and says when nothing matches', (
    tester,
  ) async {
    await pumpAt(tester, '/hse/exposures');
    await tester.enterText(find.byType(TextField), 'Lavitra');
    await tester.pumpAndSettle();
    expect(find.text('Aditya Jadhav'), findsNothing);
    expect(find.textContaining('No records match'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'DB-2609-0010');
    await tester.pumpAndSettle();
    expect(find.text('Aditya Jadhav'), findsOneWidget);
  });

  testWidgets('traceability shows the whole chain and nothing editable', (
    tester,
  ) async {
    await pumpAt(tester, '/hse/record/CAP-TEST-1');
    for (final step in [
      '1 · Worker',
      '2 · Work context',
      '3 · DoseBand',
      '4 · Monitoring session',
      '5 · Capture and quality',
      '6 · Algorithm and calibration',
      '7 · Measurement result',
      '8 · HSE review',
    ]) {
      expect(find.text(step), findsOneWidget, reason: step);
    }
    expect(find.text('None applies'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'nothing to edit');
    for (final line in texts(tester)) {
      expect(
        RegExp(r'\d+(\.\d+)?\s*ppm').hasMatch(line),
        isFalse,
        reason: line,
      );
    }
  });

  testWidgets('a review moves on; the record stays the same object', (
    tester,
  ) async {
    final c = await pumpAt(tester, '/hse/record/CAP-TEST-1');
    final before = (await c.read(operationsProvider.future))
        .measurement('CAP-TEST-1');
    await tester.tap(button('Move to in review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    final s = await c.read(operationsProvider.future);
    expect(s.reviewFor('CAP-TEST-1')!.state, ReviewState.inReview);
    expect(identical(s.measurement('CAP-TEST-1'), before), isTrue);
  });

  testWidgets('an id outside scope is refused, not shown', (tester) async {
    await pumpAt(tester, '/hse/record/NOT-A-RECORD');
    expect(find.textContaining('outside your access'), findsOneWidget);
  });

  testWidgets('the copied register keeps "No Reading" a word', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpAt(tester, '/hse/reports');
    await tester.tap(button('Copy CSV'));
    await tester.pumpAndSettle();
    expect(copied, isNotNull);
    final row = copied!.split('\n')[1];
    expect(row, contains('No Reading — no calibration'));
    expect(row, isNot(contains(',0,')));
    expect(row, contains(',none,'), reason: 'calibration model: none');
  });

  group('export semantics (§61, §125)', () {
    HseView view() => HseView(datasetWithRecord(now), samhita);

    test('the register header names every traceability column', () {
      final rows = RegisterExport.register(view().register());
      expect(rows.first, RegisterExport.registerColumns);
      expect(rows, hasLength(2));
    });

    String exposureOf(MeasurementResult r) {
      final s = datasetWithRecord(now);
      final m = s.measurement('CAP-TEST-1')!;
      final replaced = s.copyWith(measurements: [m.copyWithResult(r)]);
      return RegisterExport.register(
        HseView(replaced, samhita).register(),
      )[1][12];
    }

    const prov = Provenance(
      algorithmVersion: 'a',
      geometryVersion: 'g',
      calibrationModelId: 'cal-x',
      referenceProfileId: null,
      appVersion: 't',
      deviceModel: 't',
    );

    test('No Reading is a word', () {
      expect(exposureOf(view().register().first.record.result), isNot('0'));
      expect(
        exposureOf(
          Refused(
            status: ResultStatus.poorImage,
            reasons: const [ReasonCode('TEST')],
            provenance: prov,
          ),
        ),
        'No Reading — poor image',
      );
    });

    test('below quantification, above range and saturated are words', () {
      expect(
        exposureOf(
          Censored(
            status: ResultStatus.belowQuantificationLimit,
            direction: CensorDirection.below,
            bound: Dose.ppmHours(0.5),
            reasons: const [ReasonCode('TEST')],
            provenance: prov,
          ),
        ),
        'Below Quantification (< 0.5 ppm·h)',
      );
      expect(
        exposureOf(
          Censored(
            status: ResultStatus.aboveRange,
            direction: CensorDirection.above,
            bound: Dose.ppmHours(40),
            reasons: const [ReasonCode('TEST')],
            provenance: prov,
          ),
        ),
        'Above Range (> 40.0 ppm·h)',
      );
      expect(
        exposureOf(
          Censored(
            status: ResultStatus.saturated,
            direction: CensorDirection.above,
            reasons: const [ReasonCode('TEST')],
            provenance: prov,
          ),
        ),
        'Saturated',
      );
    });

    test('an admin or a supervisor cannot build the HSE register', () {
      final s = datasetWithRecord(now);
      expect(() => HseView(s, yashviAdmin), throwsA(anything));
      expect(() => HseView(s, aman), throwsA(anything));
    });

    test('an aligned profile says it is not a compliance claim', () {
      expect(ReportProfile.oisdAligned.caveat, contains('not a statement'));
      expect(ReportProfile.dgmsAligned.caveat, contains('not a statement'));
    });
  });
}
