import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:measurement/measurement.dart';

import '../../../core/components/buttons.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/env/app_version.dart';
import '../../../core/geometry/geometry_assets.dart';
import '../../capture/application/capture_controller.dart';
import '../../capture/data/camera_port_impl.dart';
import '../../capture/domain/badge_v1_references.dart';
import '../../capture/presentation/capture_screen.dart';
import '../../operations/application/operations_repository.dart';
import '../domain/pre_use.dart';

/// The optical half of the pre-use check (PRODUCT BUILD v1 §10).
///
/// The same real camera and the same engine as the final scan, asking a
/// narrower question: can this DoseBand be *read* — target, fiducials,
/// geometry, reference and sensor regions? It pops an [OpticalResult]; the
/// check screen decides what that means. No measurement is recorded: a
/// pre-use photograph of an unexposed band is not an exposure record.
class PreUseCaptureScreen extends ConsumerStatefulWidget {
  const PreUseCaptureScreen({required this.dosebandId, super.key});

  final String dosebandId;

  @override
  ConsumerState<PreUseCaptureScreen> createState() =>
      _PreUseCaptureScreenState();
}

class _PreUseCaptureScreenState extends ConsumerState<PreUseCaptureScreen>
    with WidgetsBindingObserver {
  CameraPortImpl? _port;
  CaptureController? _controller;
  String? _error;
  bool _handled = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setPreferredOrientations(const []));
    unawaited(_stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_stop());
      case AppLifecycleState.resumed:
        if (_controller == null && !_handled) unawaited(_start());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      final snapshot = await ref.read(operationsProvider.future);
      final band = snapshot.bands[widget.dosebandId];
      final geometry = await GeometryAssets().load(
        band?.geometryVersion ?? 'badge-v1-research',
      );
      final port = CameraPortImpl(appVersion: appVersion);
      final controller = CaptureController(
        port: port,
        geometry: geometry,
        referenceTargets: badgeV1ReferenceTargets(geometry),
        fitPatchIds: badgeV1FitPatchIds,
        holdoutPatchIds: badgeV1HoldoutPatchIds,
        appVersion: appVersion,
        previewDownscale: port.previewDownscale,
        dataDomain: DataDomain.field,
        autoCapture: false,
        context: () => MeasurementContext(
          batchId: band?.lotId,
          formulationId: band?.formulationId,
        ),
      );
      await controller.start();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onController);
      setState(() {
        _port = port;
        _controller = controller;
        _error = controller.state.error;
      });
    } on GeometryAssetException catch (e) {
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

  void _onController() {
    final outcome = _controller?.state.outcome;
    if (outcome == null || _handled) return;
    _handled = true;
    Navigator.of(context).pop(PreUseAssessment.fromCapture(outcome));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera unavailable')),
        body: ListView(
          padding: const EdgeInsets.all(Gaps.screenGutter),
          children: [
            Text(
              'The DoseBand cannot be checked without a photograph. If camera '
              'access was refused, allow it in the phone’s settings for '
              'DoseBand.',
              style: context.type.body.copyWith(
                color: context.product.textPrimary,
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              error,
              style: context.type.caption.copyWith(
                color: context.product.textSecondary,
              ),
            ),
            const SizedBox(height: Space.base),
            DoseBandButton.primary(
              label: 'Try again',
              onPressed: () {
                setState(() => _error = null);
                unawaited(_start());
              },
            ),
            const SizedBox(height: Space.sm),
            DoseBandButton.secondary(
              label: 'Back',
              onPressed: () =>
                  Navigator.of(context).pop(OpticalCameraUnavailable(error)),
            ),
          ],
        ),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return CaptureScreen(
      controller: controller,
      preview: _port?.controller,
      requireReady: true,
    );
  }
}
