// MEASUREMENT-INTEGRATION-02 — the worker's real scan path.
//
// Everything here runs the production workflow, codec, recorder and screens.
// Only the camera hardware is replaced, and only where a camera is needed.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/capture/application/capture_controller.dart';
import 'package:h2s_doseband/features/capture/data/capture_archive.dart';
import 'package:h2s_doseband/features/capture/domain/badge_v1_references.dart';
import 'package:h2s_doseband/features/capture/domain/capture_outcome.dart';
import 'package:h2s_doseband/features/capture/presentation/capture_screen.dart';
import 'package:h2s_doseband/features/research/application/research_recorder.dart';
import 'package:h2s_doseband/features/scan/worker_capture_screen.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/session_codec.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/physical_badge.dart';
import 'package:h2s_doseband/features/workflow/domain/work_context.dart';
import 'package:h2s_doseband/features/workflow/domain/work_context_validator.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

import '../capture/fake_camera.dart';

final _badge = PhysicalBadge(
  badgeId: 'DB-PHYS-0001',
  batchId: 'B-1',
  formulationId: 'F-1',
  identifiedAt: DateTime.utc(2026, 9, 26, 8),
);

/// A store that survives "process death": decode(encode(x)), as the file store
/// does across a cold start.
final class _RoundTripStore implements WorkflowStore {
  Object? _saved;

  @override
  Future<ShiftSession> load() async =>
      SessionCodec.decode(_saved) ?? ShiftSession.none;

  @override
  Future<void> save(ShiftSession session) async =>
      _saved = SessionCodec.encode(session);

  @override
  Future<void> clear() async => _saved = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===================================================================
  // Workflow: a physical badge is never a simulated one
  // ===================================================================

  group('a physical badge in the workflow', () {
    late ProviderContainer container;
    late _RoundTripStore store;

    Future<ShiftSessionController> controller() async {
      await container.read(shiftSessionProvider.future);
      return container.read(shiftSessionProvider.notifier);
    }

    setUp(() {
      store = _RoundTripStore();
      container = ProviderContainer(
        overrides: [workflowStoreProvider.overrideWithValue(store)],
      );
    });
    tearDown(() => container.dispose());

    test('replaces any simulated specimen, and vice versa', () async {
      final c = await controller();
      await c.setContext(SimulationCatalog.demoContext());
      await c.assignBadge(SimulationCatalog.specimens().first);
      await c.assignPhysicalBadge(_badge);
      var s = container.read(shiftSessionProvider).value!;
      expect(s.badge, isNull);
      expect(s.physicalBadge?.badgeId, 'DB-PHYS-0001');
      expect(s.isPhysical, isTrue);

      await c.assignBadge(SimulationCatalog.specimens().first);
      s = container.read(shiftSessionProvider).value!;
      expect(s.physicalBadge, isNull);
      expect(s.isPhysical, isFalse);
    });

    test(
      'is accepted by the validator, as not verifiable rather than failed',
      () {
        final readiness = WorkContextValidator.assess(
          const WorkContextDraft(),
          badge: _badge,
        );
        expect(
          readiness.missingRequirements,
          isNot(contains(WorkContextRequirement.badgeAssigned)),
        );
        expect(
          readiness.missingRequirements,
          isNot(contains(WorkContextRequirement.badgeUsable)),
        );
      },
    );

    test('survives a restart mid-monitoring', () async {
      // §83: begin a monitored period, kill the app, relaunch, resume.
      final c = await controller();
      await c.setContext(SimulationCatalog.demoContext());
      await c.assignPhysicalBadge(_badge);
      await c.confirmPreWork();
      await c.startMonitoring();

      final relaunched = ProviderContainer(
        overrides: [workflowStoreProvider.overrideWithValue(store)],
      );
      addTearDown(relaunched.dispose);
      final restored = await relaunched.read(shiftSessionProvider.future);
      expect(restored.stage, ShiftStage.monitoring);
      expect(restored.physicalBadge?.badgeId, 'DB-PHYS-0001');
      expect(restored.physicalBadge?.batchId, 'B-1');
      expect(restored.physicalBadge?.source, BadgeIdentitySource.manualEntry);
      expect(restored.badge, isNull);
    });

    test('can never be completed by the simulation path', () async {
      final c = await controller();
      await c.setContext(SimulationCatalog.demoContext());
      await c.assignPhysicalBadge(_badge);
      await c.confirmPreWork();
      await c.startMonitoring();
      await c.endMonitoring();
      // Playing back a declared outcome for a real badge is the provenance
      // error §8 forbids.
      await expectLater(c.completeScan(), throwsStateError);
    });

    test('completes only after monitoring ends, with a real result', () async {
      final c = await controller();
      await c.setContext(SimulationCatalog.demoContext());
      await c.assignPhysicalBadge(_badge);
      await c.confirmPreWork();
      await c.startMonitoring();

      final refusal = const NoCalibration().interpret(
        _observe(),
        appVersion: 't',
        deviceModel: 't',
      );
      await expectLater(
        c.completePhysicalScan(result: refusal, captureId: 'cap-1'),
        throwsStateError,
        reason: 'monitoring has not ended',
      );

      await c.endMonitoring();
      await c.completePhysicalScan(result: refusal, captureId: 'cap-1');
      final s = container.read(shiftSessionProvider).value!;
      expect(s.stage, ShiftStage.complete);
      expect(s.captureId, 'cap-1');
      expect(s.result?.status, ResultStatus.unsupportedCalibration);
    });

    test('codec rejects a session claiming both kinds of badge', () {
      final encoded = SessionCodec.encode(
        ShiftSession(
          stage: ShiftStage.badgeAssigned,
          context: SimulationCatalog.demoContext(),
          physicalBadge: _badge,
        ),
      );
      encoded['badge_id'] = SimulationCatalog.specimens().first.badgeId;
      expect(SessionCodec.decode(encoded), isNull);
    });

    test('codec still reads a schema-2 session', () {
      final encoded = SessionCodec.encode(
        ShiftSession(
          stage: ShiftStage.badgeAssigned,
          context: SimulationCatalog.demoContext(),
          badge: SimulationCatalog.specimens().first,
        ),
      )..['schema'] = 2;
      expect(SessionCodec.decode(encoded)?.badge, isNotNull);
    });
  });

  // ===================================================================
  // Routing: the badge decides, not a flag
  // ===================================================================

  group('/read', () {
    Future<void> pump(WidgetTester tester, ShiftSession session) async {
      final store = InMemoryWorkflowStore();
      await store.save(session);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [workflowStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: ReadBadgeScreen(simulated: Text('SIMULATED SCAN')),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a physical badge opens the real camera path', (tester) async {
      await pump(
        tester,
        ShiftSession(
          stage: ShiftStage.awaitingScan,
          context: SimulationCatalog.demoContext(),
          physicalBadge: _badge,
          startedAt: DateTime.utc(2026, 9, 26, 8),
          endedAt: DateTime.utc(2026, 9, 26, 16),
        ),
      );
      expect(find.byType(WorkerCaptureScreen), findsOneWidget);
      expect(find.text('SIMULATED SCAN'), findsNothing);
    });

    testWidgets('a simulated specimen never reaches the camera', (
      tester,
    ) async {
      await pump(
        tester,
        ShiftSession(
          stage: ShiftStage.awaitingScan,
          context: SimulationCatalog.demoContext(),
          badge: SimulationCatalog.specimens().first,
          startedAt: DateTime.utc(2026, 9, 26, 8),
          endedAt: DateTime.utc(2026, 9, 26, 16),
        ),
      );
      expect(find.byType(WorkerCaptureScreen), findsNothing);
      expect(find.text('SIMULATED SCAN'), findsOneWidget);
    });
  });

  // ===================================================================
  // The worker's capture button
  // ===================================================================

  group('capture button', () {
    Future<CaptureController> pumpScreen(
      WidgetTester tester, {
      required bool requireReady,
      required RgbImage preview,
    }) async {
      final geometry = BadgeGeometry.parse(
        File('../packages/measurement/geometry/badge-v1.geometry.json')
            .readAsStringSync(),
      );
      final port = FakeCameraPort(
        previewImages: <RgbImage>[preview],
        stillImage: preview,
      );
      final controller = CaptureController(
        port: port,
        geometry: geometry,
        referenceTargets: badgeV1ReferenceTargets(geometry),
        fitPatchIds: badgeV1FitPatchIds,
        holdoutPatchIds: badgeV1HoldoutPatchIds,
        appVersion: 't',
        autoCapture: false,
      );
      await tester.runAsync(controller.start);
      addTearDown(() => tester.runAsync(controller.dispose));
      await tester.pumpWidget(
        MaterialApp(
          home: CaptureScreen(
            controller: controller,
            requireReady: requireReady,
          ),
        ),
      );
      return controller;
    }

    FilledButton button(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('is disabled in worker mode until the badge is ready', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        requireReady: true,
        preview: RgbImage.filled(400, 300, 60, 60, 60),
      );
      expect(button(tester).onPressed, isNull);
      expect(find.text('Capture'), findsOneWidget);
    });

    testWidgets('is always available in research mode', (tester) async {
      // The M0C dataset needs deliberately bad captures.
      await pumpScreen(
        tester,
        requireReady: false,
        preview: RgbImage.filled(400, 300, 60, 60, 60),
      );
      expect(button(tester).onPressed, isNotNull);
    });
  });

  // ===================================================================
  // The archived worker scan
  // ===================================================================

  test(
    'a worker scan is archived with badge and context, not a specimen',
    () async {
      // Read from the canonical file. Loading through the asset bundle from
      // a plain test() after widget tests hangs on the test binding.
      final geometry = BadgeGeometry.parse(
        File('../packages/measurement/geometry/badge-v1.geometry.json')
            .readAsStringSync(),
      );
      final tmp = Directory.systemTemp.createTempSync('doseband-worker-');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final session = ShiftSession(
        stage: ShiftStage.awaitingScan,
        context: SimulationCatalog.demoContext(),
        physicalBadge: _badge,
        startedAt: DateTime.utc(2026, 9, 26, 8),
        endedAt: DateTime.utc(2026, 9, 26, 16),
      );
      final outcome = await _captureWith(
        geometry,
        dataDomain: DataDomain.field,
      );
      final saved =
          await ResearchRecorder(
            archive: CaptureArchive(root: tmp),
            geometry: geometry,
          ).saveWorkerScan(
            outcome,
            badge: _badge,
            session: session,
            context: session.context!,
          );

      final json = saved.record.toJson();
      expect(json['specimen'], isNull, reason: 'a worn badge is not a coupon');
      expect(json['data_domain'], 'field');
      expect(saved.captureId, startsWith('DB-PHYS-0001__'));
      final ctx = json['operational_context']! as Map<String, Object?>;
      expect((ctx['badge']! as Map)['badge_id'], 'DB-PHYS-0001');
      expect(ctx['badge_identity_provenance'], contains('Manual entry'));
      expect(ctx['worker_id'], isNotNull);
      expect(ctx['monitored_seconds'], 8 * 3600);
      expect(ctx['permit_reference'], isNotNull);
    },
  );

  test('an untrusted monitoring window is recorded as unknown, not zero', () {
    final ctx = workerScanContext(
      badge: _badge,
      session: ShiftSession(
        stage: ShiftStage.awaitingScan,
        context: SimulationCatalog.demoContext(),
        physicalBadge: _badge,
        // End before start: a clock moved backwards.
        startedAt: DateTime.utc(2026, 9, 26, 16),
        endedAt: DateTime.utc(2026, 9, 26, 8),
      ),
      context: SimulationCatalog.demoContext(),
    );
    expect(ctx['monitored_seconds'], isNull);
  });

  // ===================================================================
  // §18 · preview scaling across resolutions
  // ===================================================================

  group('preview guidance is scale-independent', () {
    // 1/2 and 1/4 (the app's setting) must read ready. At 1/8 the 4 mm
    // fiducials are ~8 px across, below what the detector resolves — a
    // detection floor, asserted separately below, not the scale bug.
    for (final downscale in const <int>[2, 4]) {
      test('ready on a 1/$downscale preview', () async {
        final geometry = BadgeGeometry.parse(
          File('../packages/measurement/geometry/badge-v1.geometry.json')
              .readAsStringSync(),
        );
        const stillPxPerMm = 16.0;
        const w = 1600, h = 1200;
        final preview = renderBadge(
          geometry: geometry,
          badgeToImage: placeBadge(
            pixelsPerMm: stillPxPerMm / downscale,
            translateX: (w / downscale - geometry.widthMm * 16 / downscale) / 2,
            translateY:
                (h / downscale - geometry.heightMm * 16 / downscale) / 2,
          ),
          width: w ~/ downscale,
          height: h ~/ downscale,
          colours: badgeV1Colours,
        );
        final port = FakeCameraPort(
          previewImages: <RgbImage>[preview],
          stillImage: preview,
        );
        final controller = CaptureController(
          port: port,
          geometry: geometry,
          referenceTargets: badgeV1ReferenceTargets(geometry),
          fitPatchIds: badgeV1FitPatchIds,
          holdoutPatchIds: badgeV1HoldoutPatchIds,
          appVersion: 't',
          autoCapture: false,
          previewDownscale: downscale,
        );
        await controller.start();
        await port.emit(3);
        expect(
          controller.state.guidance?.state,
          GuidanceState.ready,
          reason:
              'a badge at ${stillPxPerMm.toStringAsFixed(0)} px/mm on the '
              'still must read as in range on a 1/$downscale preview',
        );
        await controller.dispose();
      });
    }

    test('at 1/8 the preview fails on detection, never on scale', () async {
      // G-03 showed up as `moveCloser` for a badge that was the right size.
      // A badge too small to *detect* is a different, honest failure.
      final geometry = BadgeGeometry.parse(
        File('../packages/measurement/geometry/badge-v1.geometry.json')
            .readAsStringSync(),
      );
      const d = 8;
      final preview = renderBadge(
        geometry: geometry,
        badgeToImage: placeBadge(
          pixelsPerMm: 16 / d,
          translateX: (1600 / d - geometry.widthMm * 2) / 2,
          translateY: (1200 / d - geometry.heightMm * 2) / 2,
        ),
        width: 1600 ~/ d,
        height: 1200 ~/ d,
        colours: badgeV1Colours,
      );
      final port = FakeCameraPort(
        previewImages: <RgbImage>[preview],
        stillImage: preview,
      );
      final controller = CaptureController(
        port: port,
        geometry: geometry,
        referenceTargets: badgeV1ReferenceTargets(geometry),
        fitPatchIds: badgeV1FitPatchIds,
        holdoutPatchIds: badgeV1HoldoutPatchIds,
        appVersion: 't',
        autoCapture: false,
        previewDownscale: d,
      );
      await controller.start();
      await port.emit(3);
      expect(controller.state.guidance?.state, isNot(GuidanceState.moveCloser));
      await controller.dispose();
    });
  });
}

// ------------------------------------------------------------ helpers

ResearchObservation _observe() {
  final geometry = BadgeGeometry.parse(
    File('../packages/measurement/geometry/badge-v1.geometry.json')
        .readAsStringSync(),
  );
  final h = placeBadge(pixelsPerMm: 14, translateX: 70, translateY: 60);
  return observe(
    image: renderBadge(
      geometry: geometry,
      badgeToImage: h,
      width: 1000,
      height: 700,
      colours: badgeV1Colours,
    ),
    geometry: geometry,
    correspondences: fiducialCorrespondences(geometry, h),
    dataDomain: DataDomain.field,
    referenceTargets: badgeV1ReferenceTargets(geometry),
    fitPatchIds: badgeV1FitPatchIds,
    holdoutPatchIds: badgeV1HoldoutPatchIds,
  );
}

Future<CaptureOutcome> _captureWith(
  BadgeGeometry geometry, {
  required DataDomain dataDomain,
}) async {
  final h = placeBadge(pixelsPerMm: 16, translateX: 320, translateY: 280);
  final still = renderBadge(
    geometry: geometry,
    badgeToImage: h,
    width: 1600,
    height: 1200,
    colours: badgeV1Colours,
  );
  final port = FakeCameraPort(
    previewImages: <RgbImage>[still],
    stillImage: still,
  );
  final controller = CaptureController(
    port: port,
    geometry: geometry,
    referenceTargets: badgeV1ReferenceTargets(geometry),
    fitPatchIds: badgeV1FitPatchIds,
    holdoutPatchIds: badgeV1HoldoutPatchIds,
    appVersion: 't',
    autoCapture: false,
    dataDomain: dataDomain,
  );
  await controller.start();
  await controller.capture();
  final outcome = controller.state.outcome!;
  await controller.dispose();
  // FakeCameraPort returns empty original bytes; give the archive something
  // real to write.
  return switch (outcome) {
    CaptureObserved o => CaptureObserved(
      observation: o.observation,
      metadata: o.metadata,
      geometryValidation: o.geometryValidation,
      result: o.result,
      quality: o.quality,
      evidence: CaptureEvidence(
        originalBytes: Uint8List.fromList(encodePng(still)),
        still: o.evidence.still,
        previewAssessment: o.evidence.previewAssessment,
        stillAssessment: o.evidence.stillAssessment,
        stillQuality: o.evidence.stillQuality,
        homography: o.evidence.homography,
      ),
    ),
    CaptureRefused r => r,
  };
}
