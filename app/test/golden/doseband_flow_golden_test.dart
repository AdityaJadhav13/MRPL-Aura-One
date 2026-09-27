import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/buttons.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/doseband/application/doseband_providers.dart';
import 'package:h2s_doseband/features/doseband/data/qr_codec.dart';
import 'package:h2s_doseband/features/doseband/domain/doseband_qr.dart';
import 'package:h2s_doseband/features/doseband/domain/pre_use.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
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

/// The DoseBand screens between Home and monitoring (corrective §44): the
/// scanned band, each pre-use outcome and the final-scan identity refusal.
/// The camera is the fake port; nothing here is a camera frame.
void main() {
  final now = DateTime(2026, 9, 27, 10, 30);
  const serial = 'DB-2609-0012';

  late ProviderContainer container;
  late FakeCameraPort camera;

  Finder button(String label) =>
      find.byWidgetPredicate((w) => w is DoseBandButton && w.label == label);

  Future<void> pump(
    WidgetTester tester, {
    OpticalResult optical = const OpticalReadable(),
  }) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final label = QrCodec.render(DoseBandQr.encode(serial), scale: 4);
    camera = FakeCameraPort(
      previewImages: [label],
      stillImage: RgbImage.filled(8, 8, 0, 0, 0),
    );
    final store = InMemoryWorkflowStore();
    await store.save(
      ShiftSession(
        stage: ShiftStage.contextSet,
        context: SimulationCatalog.demoContext(),
      ),
    );
    container = ProviderContainer(
      overrides: [
        environmentConfigProvider.overrideWithValue(_dev),
        ...signedInOverrides(personId: PresentationDataset.aditya, now: now),
        workflowStoreProvider.overrideWithValue(store),
        qrCameraProvider.overrideWithValue(
          () => (port: camera, preview: () => null),
        ),
        qrDecoderProvider.overrideWithValue((i) async => QrCodec.decode(i)),
        opticalCheckProvider.overrideWithValue((_, _) async => optical),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DoseBandApp(config: _dev, initialLocation: '/home'),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls to [label] first: on a 390 × 844 phone Home's action is below
  /// the fold, as a person would find it.
  Future<void> press(WidgetTester tester, String label) async {
    await tester.ensureVisible(button(label).first);
    await tester.pump();
    await tester.tap(button(label).first);
  }

  Future<void> openScanner(WidgetTester tester, String action) async {
    await press(tester, action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> emit(WidgetTester tester, [RgbImage? image]) async {
    await tester.runAsync(() async {
      await camera.emit(1, image: image);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> scanned(WidgetTester tester) async {
    await openScanner(tester, 'Scan new DoseBand');
    await emit(tester);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/doseband-$name.png'),
    );
  }

  testWidgets('scanned, before the photograph', (tester) async {
    await pump(tester);
    await scanned(tester);
    await capture(tester, 'check');
  });

  testWidgets('pre-use: ready', (tester) async {
    await pump(tester);
    await scanned(tester);
    await press(tester, 'Photograph the DoseBand');
    await tester.pumpAndSettle();
    await capture(tester, 'pre-use-ready');
  });

  testWidgets('pre-use: cannot verify', (tester) async {
    await pump(
      tester,
      optical: const OpticalNotReadable(
        reason: 'The photograph is blurred.',
        action: 'Hold the phone steady and try again.',
      ),
    );
    await scanned(tester);
    await press(tester, 'Photograph the DoseBand');
    await tester.pumpAndSettle();
    await capture(tester, 'pre-use-cannot-verify');
  });

  testWidgets('pre-use: replace (held by someone else)', (tester) async {
    await pump(tester);
    await openScanner(tester, 'Scan new DoseBand');
    await container
        .read(dosebandRegistryProvider)
        .claim(dosebandId: serial, workerId: PresentationDataset.lavitra);
    await emit(tester);
    await tester.pumpAndSettle();
    await capture(tester, 'pre-use-replace');
  });

  testWidgets('final scan: not the band worn', (tester) async {
    await pump(tester);
    await scanned(tester);
    await press(tester, 'Photograph the DoseBand');
    await tester.pumpAndSettle();
    await press(tester, 'Assign this DoseBand');
    await tester.pumpAndSettle();
    await container.read(shiftSessionProvider.notifier).endMonitoring();
    // Let the assignment's confirmation expire, as it would have by the end
    // of a shift.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await openScanner(tester, 'Scan assigned DoseBand');
    await emit(tester, QrCodec.render(DoseBandQr.encode('DB-2609-0013')));
    await capture(tester, 'final-scan-wrong-band');
  });
}
