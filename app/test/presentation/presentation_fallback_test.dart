import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/buttons.dart';
import 'package:h2s_doseband/core/domain/doseband.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/doseband/application/doseband_providers.dart';
import 'package:h2s_doseband/features/doseband/data/qr_codec.dart';
import 'package:h2s_doseband/features/doseband/domain/doseband_qr.dart';
import 'package:h2s_doseband/features/history/domain/measurement_record.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/presentation/application/presentation_controller.dart';
import 'package:h2s_doseband/features/presentation/domain/presentation_mode.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:h2s_doseband/main.dart';
import 'package:measurement/measurement.dart';

import '../capture/fake_camera.dart';
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

/// Worker directive §53: the presentation fallback runs the product's own
/// workflow for the presentation DoseBand, is off unless deliberately
/// enabled, never applies to a real band, and never lets its records reach
/// organisational data.
void main() {
  final now = DateTime(2026, 9, 27, 10, 30);
  const band = PresentationDataset.presentationBandId;

  ProviderContainer container({EnvironmentConfig config = _dev}) {
    final c = ProviderContainer(
      overrides: [
        environmentConfigProvider.overrideWithValue(config),
        ...signedInOverrides(
          personId: PresentationDataset.aditya,
          now: now,
          seed: datasetWithRecord(now),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('activation', () {
    test('off by default', () {
      final c = container();
      expect(c.read(presentationModeProvider).enabled, isFalse);
      expect(c.read(activeFallbackProvider), isNull);
    });

    test('never in production, even if switched on', () {
      final c = container(config: _prod);
      c.read(presentationModeProvider.notifier)
        ..setEnabled(true)
        ..setLevel(FallbackLevel.fixture);
      expect(c.read(activeFallbackProvider), isNull);
    });

    test('never for a real band', () {
      expect(fallbackFor(FallbackLevel.fixture, 'DB-2609-0011'), isNull);
      expect(fallbackFor(FallbackLevel.fixture, band), FallbackLevel.fixture);
      expect(fallbackFor(null, band), isNull);
    });
  });

  test('the example result is deterministic and names itself', () {
    Valid make() => PresentationResultFixture.result(
      coverage: const Duration(hours: 8),
      geometryVersion: 'g',
      appVersion: 'a',
      deviceModel: 'd',
    );
    final a = make();
    final b = make();
    expect(a.dose.value, b.dose.value);
    expect(a.dose.value, PresentationResultFixture.dosePpmHours);
    expect(a.provenance.calibrationModelId, 'PRESENTATION-EXAMPLE');
    expect(a.uncertainty.basis, contains('not a measured interval'));
  });

  group('the whole workflow at level 3', () {
    late ProviderContainer c;
    late FakeCameraPort camera;

    Finder button(String label) =>
        find.byWidgetPredicate((w) => w is DoseBandButton && w.label == label);

    Future<void> tapButton(WidgetTester tester, String label) async {
      await tester.ensureVisible(button(label).first);
      await tester.pump();
      await tester.tap(button(label).first);
    }

    testWidgets('scan → check → assign → final read → result, all through '
        'the product screens, and nothing reaches organisational data', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      camera = FakeCameraPort(
        previewImages: [QrCodec.render('not a DoseBand', scale: 4)],
        stillImage: RgbImage.filled(8, 8, 0, 0, 0),
      );
      final store = InMemoryWorkflowStore();
      await store.save(
        ShiftSession(
          stage: ShiftStage.contextSet,
          context: SimulationCatalog.demoContext(),
        ),
      );
      c = ProviderContainer(
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          ...signedInOverrides(
            personId: PresentationDataset.aditya,
            now: now,
            seed: datasetWithRecord(now),
          ),
          workflowStoreProvider.overrideWithValue(store),
          qrCameraProvider.overrideWithValue(
            () => (port: camera, preview: () => null),
          ),
          qrDecoderProvider.overrideWithValue((i) async => QrCodec.decode(i)),
        ],
      );
      addTearDown(c.dispose);
      c.read(presentationModeProvider.notifier)
        ..setEnabled(true)
        ..setLevel(FallbackLevel.fixture);
      final reviewsBefore = (await c.read(operationsProvider.future)).reviews;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const DoseBandApp(config: _dev, initialLocation: '/home'),
        ),
      );
      await tester.pumpAndSettle();

      // Scan new DoseBand → the QR fallback.
      await tapButton(tester, 'Scan new DoseBand');
      await tester.pump(const Duration(milliseconds: 500));
      await tapButton(tester, 'Use Presentation DoseBand');
      await tester.pumpAndSettle();
      expect(find.text('Check DoseBand'), findsOneWidget);
      expect(find.text(band), findsOneWidget);

      // Pre-use: the fixture's deterministic READY, in the product's UI.
      await tapButton(tester, 'Photograph the DoseBand');
      await tester.pumpAndSettle();
      expect(find.text('DoseBand ready to use'), findsOneWidget);
      await tapButton(tester, 'Assign this DoseBand');
      await tester.pumpAndSettle();
      expect(find.text('MONITORING ACTIVE'), findsOneWidget);

      // Time compression: a real transition, no measurement.
      expect(
        await c.read(presentationWorkflowProvider).advanceToFinalRead(),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Scan assigned DoseBand'), findsOneWidget);

      // Final read: the same identity check, then the analysing state.
      await tapButton(tester, 'Scan assigned DoseBand');
      await tester.pump(const Duration(milliseconds: 500));
      await tapButton(tester, 'Use Presentation DoseBand');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Analysing DoseBand…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // The product's result screen, with the example and its one line.
      expect(find.text('Exposure result'), findsOneWidget);
      expect(
        find.textContaining('Presentation example — not a calibrated'),
        findsOneWidget,
      );
      expect(find.textContaining('Simulated — not a real'), findsNothing);

      final s = await c.read(operationsProvider.future);
      final record = s.measurements.singleWhere((m) => m.isPresentation);
      expect(record.origin, RecordOrigin.presentation);
      expect(record.domain, DataDomain.simulated);
      expect(record.badge.badgeId, band);
      expect(record.originNote, contains('level 3'));
      // Kept out of every organisational view, and HSE has nothing to review.
      expect(s.registerMeasurements.where((m) => m.isPresentation), isEmpty);
      expect(s.reviews.length, reviewsBefore.length);
      // The real record in the dataset is untouched.
      expect(s.measurement('CAP-TEST-1'), isNotNull);

      // Reset for the next take: presentation data only.
      final removed = await c.read(presentationWorkflowProvider).reset();
      expect(removed, 1);
      final after = await c.read(operationsProvider.future);
      expect(after.measurements.where((m) => m.isPresentation), isEmpty);
      expect(after.measurement('CAP-TEST-1'), isNotNull);
      expect(after.bands[band]!.lifecycle, DoseBandLifecycle.available);
      expect(c.read(shiftSessionProvider).value, ShiftSession.none);
    });
  });

  testWidgets('the QR fallback is absent unless presentation mode is on', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final camera = FakeCameraPort(
      previewImages: [QrCodec.render(DoseBandQr.encode('DB-2609-0011'))],
      stillImage: RgbImage.filled(8, 8, 0, 0, 0),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          ...signedInOverrides(personId: PresentationDataset.aditya, now: now),
          qrCameraProvider.overrideWithValue(
            () => (port: camera, preview: () => null),
          ),
        ],
        child: const DoseBandApp(
          config: _dev,
          initialLocation: '/doseband/scan',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Use Presentation DoseBand'), findsNothing);
  });
}
