import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/buttons.dart';
import 'package:h2s_doseband/core/domain/doseband.dart';
import 'package:h2s_doseband/core/domain/monitoring_session.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/doseband/application/doseband_providers.dart';
import 'package:h2s_doseband/features/doseband/data/qr_codec.dart';
import 'package:h2s_doseband/features/doseband/domain/doseband_qr.dart';
import 'package:h2s_doseband/features/doseband/domain/pre_use.dart';
import 'package:h2s_doseband/features/operations/application/access.dart';
import 'package:h2s_doseband/features/operations/application/day_status.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/application/supervisor_service.dart';
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

/// PRODUCT BUILD v1 §7, §108 steps 1–8 and 18–19: one worker's claim, seen
/// through the UI, reflected in the supervisor's view of the same store.
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
    String person = PresentationDataset.aditya,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final label = QrCodec.render(DoseBandQr.encode(serial), scale: 4);
    camera = FakeCameraPort(
      previewImages: [label],
      stillImage: RgbImage.filled(8, 8, 0, 0, 0),
    );
    final store = InMemoryWorkflowStore();
    // Today's work is recorded; the flow starts at Home state A.
    await store.save(
      ShiftSession(
        stage: ShiftStage.contextSet,
        context: SimulationCatalog.demoContext(),
      ),
    );
    container = ProviderContainer(
      overrides: [
        environmentConfigProvider.overrideWithValue(_dev),
        ...signedInOverrides(personId: person, now: now),
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

  /// The scanner shows an indeterminate progress until the preview arrives,
  /// and the fake camera has no preview widget, so it is pumped by time.
  Future<void> openScanner(WidgetTester tester) async {
    await tester.tap(button('Scan new DoseBand').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> emit(WidgetTester tester, [RgbImage? image]) async {
    // Decoding and the scanner's camera shutdown are real asynchronous work;
    // give them real time before looking at the screen.
    await tester.runAsync(() async {
      await camera.emit(1, image: image);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> scanLabel(WidgetTester tester) async {
    await openScanner(tester);
    await emit(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('scan → check → assign → monitoring, seen by the supervisor', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('No DoseBand assigned'), findsOneWidget);

    await scanLabel(tester);
    expect(find.text('Check DoseBand'), findsOneWidget);
    expect(find.text(serial), findsOneWidget);

    await tester.tap(button('Photograph the DoseBand'));
    await tester.pumpAndSettle();
    expect(find.text('DoseBand ready to use'), findsOneWidget);

    await tester.tap(button('Assign this DoseBand'));
    await tester.pumpAndSettle();

    // Home C.
    expect(find.text('Monitoring active'), findsOneWidget);
    expect(find.text(serial), findsOneWidget);

    // The same store, as Aman sees it.
    final s = await container.read(operationsProvider.future);
    expect(s.bands[serial]!.lifecycle, DoseBandLifecycle.monitoring);
    final day = SupervisorView(s, const Actor0(PresentationDataset.aman).actor)
        .team(now)
        .firstWhere((r) => r.person.personId == PresentationDataset.aditya);
    expect(day.day.status, WorkerDayStatus.monitoring);
    expect(day.band?.dosebandId, serial);
    expect(day.day.session!.state, MonitoringSessionState.active);
  });

  testWidgets('a bad photo is "cannot verify", and nothing is claimed', (
    tester,
  ) async {
    await pump(
      tester,
      optical: const OpticalNotReadable(
        reason: 'Blurred',
        action: 'Hold the phone steady.',
      ),
    );
    await scanLabel(tester);
    await tester.tap(button('Photograph the DoseBand'));
    await tester.pumpAndSettle();
    expect(find.text('Cannot verify — try again'), findsOneWidget);
    expect(find.textContaining('may be fine'), findsOneWidget);
    expect(button('Assign this DoseBand'), findsNothing);
    final s = await container.read(operationsProvider.future);
    expect(s.bands[serial]!.lifecycle, DoseBandLifecycle.available);
  });

  testWidgets('a band someone else holds is "replace" before any photo', (
    tester,
  ) async {
    await pump(tester);
    await openScanner(tester);
    // Lavitra's band in the presentation dataset is quiet here, so claim it
    // for her first, as her own phone would have.
    await container
        .read(dosebandRegistryProvider)
        .claim(dosebandId: serial, workerId: PresentationDataset.lavitra);
    await emit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Replace DoseBand'), findsOneWidget);
    expect(find.textContaining('already assigned'), findsOneWidget);
    expect(find.textContaining('Lavitra'), findsNothing);
    expect(button('Photograph the DoseBand'), findsNothing);
  });

  testWidgets('the final scan refuses a band that is not the one worn', (
    tester,
  ) async {
    await pump(tester);
    await scanLabel(tester);
    await tester.tap(button('Photograph the DoseBand'));
    await tester.pumpAndSettle();
    await tester.tap(button('Assign this DoseBand'));
    await tester.pumpAndSettle();
    await container.read(shiftSessionProvider.notifier).endMonitoring();
    await tester.pumpAndSettle();
    expect(find.text('Scan assigned DoseBand'), findsOneWidget);

    await tester.tap(button('Scan assigned DoseBand'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await emit(tester, QrCodec.render(DoseBandQr.encode('DB-2609-0013')));
    expect(
      find.textContaining('Your assigned DoseBand is $serial'),
      findsOneWidget,
    );
    expect(find.text('Scan your assigned DoseBand'), findsOneWidget);
  });

  testWidgets('a non-DoseBand code is named and scanning continues', (
    tester,
  ) async {
    await pump(tester);
    await openScanner(tester);
    await emit(tester, QrCodec.render('https://example.com'));
    expect(find.textContaining('not a DoseBand'), findsOneWidget);
    expect(find.text('Scan a new DoseBand'), findsOneWidget);
  });
}

/// Builds an actor inline without importing access.dart twice.
class Actor0 {
  const Actor0(this.id);
  final String id;
  Actor get actor => Actor(personId: id, role: AppRole.supervisor);
}
