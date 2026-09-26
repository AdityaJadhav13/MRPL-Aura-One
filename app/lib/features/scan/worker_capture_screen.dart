import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart';

import '../../core/env/app_version.dart';
import '../../core/geometry/geometry_assets.dart';
import '../capture/application/capture_controller.dart';
import '../capture/data/camera_port_impl.dart';
import '../capture/domain/badge_v1_references.dart';
import '../capture/domain/capture_outcome.dart';
import '../capture/presentation/capture_screen.dart';
import '../history/application/history_controller.dart';
import '../history/domain/measurement_record.dart';
import '../research/application/research_providers.dart';
import '../research/application/research_recorder.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/domain/physical_badge.dart';
import '../workflow/domain/workflow_state.dart';

/// The worker reading their physical badge. MEASUREMENT-INTEGRATION-02 §8.
///
/// ## Everything here is real
///
/// The camera is the phone's camera. The still is the photograph it took. The
/// badge is located, rectified, colour-corrected and measured by the engine
/// on those pixels, and the result is whatever the calibration makes of them —
/// today always a refusal, because no H₂S calibration exists. There is no
/// fixture, no simulated specimen and no declared outcome anywhere in this
/// path; a session reaches this screen only with a [PhysicalBadge].
///
/// ## What the worker can and cannot do
///
/// They press **Capture** once the preview is in position and steady. They
/// cannot force a failed photograph into a result: if the still fails a
/// measurement-critical check, they are told the one thing to fix and the
/// camera comes back. Every attempt, accepted or refused, is archived.
class WorkerCaptureScreen extends ConsumerStatefulWidget {
  const WorkerCaptureScreen({super.key});

  @override
  ConsumerState<WorkerCaptureScreen> createState() =>
      _WorkerCaptureScreenState();
}

class _WorkerCaptureScreenState extends ConsumerState<WorkerCaptureScreen>
    with WidgetsBindingObserver {
  BadgeGeometry? _geometry;
  CameraPortImpl? _port;
  CaptureController? _controller;
  String? _error;
  bool _handling = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // One orientation, so preview, still and guidance share a frame of
    // reference. §84.
    unawaited(
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setPreferredOrientations(<DeviceOrientation>[]));
    unawaited(_stop());
    super.dispose();
  }

  /// The camera is released when the app leaves the foreground and reopened
  /// when it returns. Holding it through a lock screen leaves a dead preview
  /// on most Android devices, and another app may need it meanwhile. §81.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_stop());
      case AppLifecycleState.resumed:
        if (_controller == null && !_handling) unawaited(_start());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      final session = ref.read(shiftSessionProvider).value;
      final badge = session?.physicalBadge;
      if (badge == null) {
        setState(() => _error = 'No physical badge is assigned.');
        return;
      }

      final geometry =
          _geometry ?? await GeometryAssets().load('badge-v1-research');
      final port = CameraPortImpl(appVersion: appVersion);
      final controller = CaptureController(
        port: port,
        geometry: geometry,
        referenceTargets: badgeV1ReferenceTargets(geometry),
        fitPatchIds: badgeV1FitPatchIds,
        holdoutPatchIds: badgeV1HoldoutPatchIds,
        appVersion: appVersion,
        previewDownscale: port.previewDownscale,
        // A worker reading a worn badge in the operational workflow.
        dataDomain: DataDomain.field,
        // The worker presses Capture; nothing fires by itself. §16.
        autoCapture: false,
        context: () => MeasurementContext(
          batchId: badge.batchId,
          formulationId: badge.formulationId,
        ),
      );
      await controller.start();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onController);
      setState(() {
        _geometry = geometry;
        _port = port;
        _controller = controller;
        _error = controller.state.error;
      });
    } on GeometryAssetException catch (e) {
      // No fallback geometry: a measurement against the wrong ROI coordinates
      // is undetectable downstream.
      if (mounted) setState(() => _error = e.detail);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop() async {
    final controller = _controller;
    if (controller == null) return;
    controller.removeListener(_onController);
    _controller = null;
    _port = null;
    await controller.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _onController() async {
    final controller = _controller;
    final outcome = controller?.state.outcome;
    if (controller == null || outcome == null || _handling) return;
    _handling = true;
    try {
      await _handle(controller, outcome);
    } finally {
      _handling = false;
    }
  }

  Future<void> _handle(
    CaptureController controller,
    CaptureOutcome outcome,
  ) async {
    final session = ref.read(shiftSessionProvider).value;
    final badge = session?.physicalBadge;
    final ctx = session?.context;
    if (session == null || badge == null || ctx == null) return;

    // Archive first, whatever the verdict. A refused attempt is the evidence
    // that measures false rejection on real hardware.
    final SavedCapture saved;
    try {
      saved = await ResearchRecorder(
        archive: ref.read(captureArchiveProvider),
        geometry: _geometry!,
      ).saveWorkerScan(outcome, badge: badge, session: session, context: ctx);
    } on Object catch (e) {
      if (!mounted) return;
      await _tell(
        'The photo could not be saved',
        'Nothing was recorded. Try again.\n\n$e',
      );
      await controller.resume();
      return;
    }

    final failure = outcome.quality.primaryFailure;
    final correctionFailed =
        outcome is CaptureObserved &&
        (failure?.id == 'reference_fit' ||
            failure?.id == 'withheld_references');

    if (outcome is! CaptureObserved ||
        (!outcome.quality.acceptable && !correctionFailed)) {
      // An acquisition failure — focus, glare, framing, exposure. The worker
      // can fix it, so the only way forward is a retake. No bypass. §51, §52.
      if (!mounted) return;
      final action = failure?.workerAction;
      await _tell(
        'Please retake the photo',
        (action == null || action.isEmpty)
            ? 'The photo could not be used. Show the whole badge, flat, in '
                  'even light, and hold steady.'
            : action,
      );
      await controller.resume();
      return;
    }

    if (correctionFailed) {
      // The photograph was acquired, but the colour references could not be
      // trusted. A retake in even light may fix it — but the failure can also
      // be systematic (the withheld black patch is an extrapolation of the
      // fitted correction, and exceeds the provisional limit under ordinary
      // JPEG compression). So the worker may retake, or record the scan as
      // what it is: a reference failure. Either way no number is produced;
      // recording a typed refusal is not a bypass into a measurement. §38.
      if (!mounted) return;
      final record = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Colour references could not be verified'),
          content: Text(
            '${failure!.workerAction}\n\nYou can retake the photo, or record '
            'this scan as a reference failure. A reference failure gives no '
            'exposure value.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Record as reference failure'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Retake'),
            ),
          ],
        ),
      );
      if (record != true) {
        await controller.resume();
        return;
      }
    }

    final observed = outcome;
    await ref
        .read(shiftSessionProvider.notifier)
        .completePhysicalScan(
          result: observed.result,
          captureId: saved.captureId,
        );

    final scannedAt = ref.read(clockProvider)();
    final record = MeasurementRecord(
      id: saved.captureId,
      result: observed.result,
      badge: badge,
      context: ctx,
      startedAt: session.startedAt ?? scannedAt,
      endedAt: session.endedAt ?? scannedAt,
      scannedAt: scannedAt,
      domain: observed.observation.dataDomain,
      captureId: saved.captureId,
    );
    ref.read(historyProvider.notifier).add(record);
    if (mounted) context.pushReplacement('/result', extra: record);
  }

  Future<void> _tell(String title, String body) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera unavailable')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(error),
              const SizedBox(height: 16),
              const Text(
                'If camera access was refused, allow it in the phone’s '
                'settings for DoseBand, then try again.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() => _error = null);
                  unawaited(_start());
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return CaptureScreen(
      controller: controller,
      preview: _port?.controller,
      requireReady: true,
    );
  }
}

/// `/read`: the real camera for a physical badge, the labelled simulation for
/// a presentation specimen.
///
/// Decided by the badge the session holds, not by a mode flag. A session with
/// a physical badge can only reach the real camera; a simulated specimen can
/// only reach the simulation. §73.
class ReadBadgeScreen extends ConsumerWidget {
  const ReadBadgeScreen({required this.simulated, super.key});

  /// The simulated guided scan, for a presentation specimen.
  final Widget simulated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(shiftSessionProvider).value ?? ShiftSession.none;
    return session.isPhysical ? const WorkerCaptureScreen() : simulated;
  }
}
