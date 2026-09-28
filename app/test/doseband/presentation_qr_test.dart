import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/buttons.dart';
import 'package:h2s_doseband/core/domain/doseband.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/doseband/application/doseband_providers.dart';
import 'package:h2s_doseband/features/doseband/data/qr_codec.dart';
import 'package:h2s_doseband/features/doseband/domain/pre_use.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/operations_codec.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/operations/domain/assignment.dart';
import 'package:h2s_doseband/features/presentation/application/presentation_controller.dart';
import 'package:h2s_doseband/features/presentation/domain/presentation_mode.dart';
import 'package:h2s_doseband/features/scan/worker_capture_screen.dart';
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

/// Directive §53O: today's printed prototype QR → the presentation DoseBand
/// serial → assigned to the signed-in worker → the same band verified at the
/// final read. The identity chain stays visible and survives a restart.
void main() {
  final now = DateTime(2026, 9, 27, 10, 30);
  const printed = 'SIH-2026-DOSEBAND-PROTOTYPE';
  const band = PresentationDataset.presentationBandId;

  late InMemoryOperationsStore ops;
  late InMemoryWorkflowStore device;
  late FakeCameraPort camera;

  Finder button(String label) =>
      find.byWidgetPredicate((w) => w is DoseBandButton && w.label == label);

  Future<void> press(WidgetTester tester, String label) async {
    await tester.ensureVisible(button(label).first);
    await tester.pump();
    await tester.tap(button(label).first);
  }

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String person = PresentationDataset.aditya,
    FallbackLevel? level = FallbackLevel.qr,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    camera = FakeCameraPort(
      previewImages: [QrCodec.render(printed, scale: 4)],
      stillImage: RgbImage.filled(8, 8, 0, 0, 0),
    );
    final c = ProviderContainer(
      overrides: [
        environmentConfigProvider.overrideWithValue(_dev),
        ...signedInOverrides(personId: person, now: now, store: ops),
        workflowStoreProvider.overrideWithValue(device),
        // A fresh camera per scanner, as the real provider gives: closing
        // the claim scanner's camera must not end the final scanner's.
        qrCameraProvider.overrideWithValue(() {
          camera = FakeCameraPort(
            previewImages: [QrCodec.render(printed, scale: 4)],
            stillImage: RgbImage.filled(8, 8, 0, 0, 0),
          );
          return (port: camera, preview: () => null);
        }),
        qrDecoderProvider.overrideWithValue((i) async => QrCodec.decode(i)),
        // Level 1: the pre-use optical check stays real; here, readable.
        opticalCheckProvider.overrideWithValue(
          (_, _) async => const OpticalReadable(),
        ),
      ],
    );
    addTearDown(c.dispose);
    if (level != null) {
      c.read(presentationModeProvider.notifier)
        ..setEnabled(true)
        ..setLevel(level);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const DoseBandApp(config: _dev, initialLocation: '/home'),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> emit(WidgetTester tester, String payload) async {
    await tester.runAsync(() async {
      await camera.emit(1, image: QrCodec.render(payload, scale: 4));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openScanner(WidgetTester tester, String action) async {
    await press(tester, action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUp(() {
    ops = InMemoryOperationsStore(quietDataset(now));
    device = InMemoryWorkflowStore();
  });

  Future<void> seedContext() => device.save(
    ShiftSession(
      stage: ShiftStage.contextSet,
      context: SimulationCatalog.demoContext(),
    ),
  );

  testWidgets('printed prototype QR → identified → assign to me → '
      'monitoring, recorded with its payload, and it survives a restart', (
    tester,
  ) async {
    await seedContext();
    final c = await pump(tester);

    await openScanner(tester, 'Scan new DoseBand');
    await emit(tester, printed);
    await tester.pumpAndSettle();
    expect(find.text('DoseBand identified'), findsOneWidget);
    expect(find.text(band), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);

    await press(tester, 'Photograph the DoseBand');
    await tester.pumpAndSettle();
    expect(find.text('DoseBand ready to use'), findsOneWidget);
    await press(tester, 'Assign to me');
    await tester.pumpAndSettle();

    // Home, at once: the band, whose it is, and no "no DoseBand".
    expect(find.text('MONITORING ACTIVE'), findsOneWidget);
    expect(find.text(band), findsOneWidget);
    expect(find.text('Assigned to you'), findsOneWidget);
    expect(find.text('NO DOSEBAND ASSIGNED'), findsNothing);

    final s = await c.read(operationsProvider.future);
    final a = s.assignments.singleWhere((x) => x.dosebandId == band);
    expect(a.workerId, PresentationDataset.aditya);
    expect(a.identifiedBy, BandIdentification.presentationQrMapping);
    expect(a.isPresentation, isTrue);
    expect(a.qrPayload, printed);
    expect(s.session(a.sessionId)!.dosebandId, band);
    expect(s.bands[band]!.lifecycle, DoseBandLifecycle.monitoring);

    // A restart: the stores are read afresh by a new container.
    final restarted = ProviderContainer(
      overrides: [
        environmentConfigProvider.overrideWithValue(_dev),
        ...signedInOverrides(
          personId: PresentationDataset.aditya,
          now: now,
          store: ops,
        ),
        workflowStoreProvider.overrideWithValue(device),
      ],
    );
    addTearDown(restarted.dispose);
    final session = await restarted.read(shiftSessionProvider.future);
    expect(session.stage, ShiftStage.monitoring);
    expect(session.physicalBadge?.badgeId, band);
    final again = await restarted.read(operationsProvider.future);
    expect(again.assignment(a.assignmentId)!.qrPayload, printed);
  });

  testWidgets('final read: another code is the wrong DoseBand; the same '
      'printed code opens the camera', (tester) async {
    await seedContext();
    final c = await pump(tester);
    await openScanner(tester, 'Scan new DoseBand');
    await emit(tester, printed);
    await tester.pumpAndSettle();
    await press(tester, 'Photograph the DoseBand');
    await tester.pumpAndSettle();
    await press(tester, 'Assign to me');
    await tester.pumpAndSettle();

    await c.read(shiftSessionProvider.notifier).endMonitoring();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await openScanner(tester, 'Scan assigned DoseBand');

    await emit(tester, 'SOME-OTHER-LABEL');
    expect(find.textContaining('Wrong DoseBand'), findsOneWidget);
    expect(find.byType(WorkerCaptureScreen), findsNothing);

    await emit(tester, printed);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(WorkerCaptureScreen), findsOneWidget);
  });

  testWidgets('another worker cannot claim the band', (tester) async {
    await seedContext();
    // Aditya holds it already, as his phone recorded.
    final first = ProviderContainer(
      overrides: [
        environmentConfigProvider.overrideWithValue(_dev),
        ...signedInOverrides(
          personId: PresentationDataset.aditya,
          now: now,
          store: ops,
        ),
      ],
    );
    addTearDown(first.dispose);
    await first
        .read(dosebandRegistryProvider)
        .claimWith(
          dosebandId: band,
          workerId: PresentationDataset.aditya,
          identifiedBy: BandIdentification.presentationQrMapping,
          qrPayload: printed,
        );

    await pump(tester, person: PresentationDataset.lavitra);
    await openScanner(tester, 'Scan new DoseBand');
    await emit(tester, printed);
    await tester.pumpAndSettle();
    expect(find.text('DoseBand already assigned'), findsOneWidget);
    expect(button('Assign to me'), findsNothing);
  });

  testWidgets('without presentation mode the placeholder is not a DoseBand', (
    tester,
  ) async {
    await seedContext();
    await pump(tester, level: null);
    await openScanner(tester, 'Scan new DoseBand');
    await emit(tester, printed);
    expect(find.textContaining('not a DoseBand'), findsOneWidget);
    expect(find.text('DoseBand identified'), findsNothing);
  });

  test('the codec keeps identification and payload; older records read as '
      'printed QR', () {
    final base = PresentationDataset.build(now);
    final a = DoseBandAssignment(
      assignmentId: 'ASG-X',
      dosebandId: band,
      workerId: PresentationDataset.aditya,
      sessionId: 'SES-X',
      claimedAt: now,
      state: AssignmentState.active,
      identifiedBy: BandIdentification.presentationQrMapping,
      qrPayload: printed,
    );
    final json = OperationsCodec.encode(
      base.copyWith(assignments: [...base.assignments, a]),
    );
    final back = OperationsCodec.decode(json)!;
    final decoded = back.assignment('ASG-X')!;
    expect(decoded.identifiedBy, BandIdentification.presentationQrMapping);
    expect(decoded.qrPayload, printed);
    // Seeded assignments were encoded without the new fields' values set.
    expect(
      back.assignments
          .where((x) => x.assignmentId != 'ASG-X')
          .every((x) => x.identifiedBy == BandIdentification.qrCode),
      isTrue,
    );
  });
}
