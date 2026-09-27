import 'dart:async';

import 'package:flutter/material.dart';
import 'package:measurement/measurement.dart';

import '../../../core/geometry/geometry_assets.dart';
import '../application/capture_controller.dart';
import '../data/camera_port_impl.dart';
import '../domain/badge_v1_references.dart';
import 'capture_screen.dart';

/// Wires a real camera to the capture pipeline.
///
/// **Development only.** It is reachable only where simulation is available,
/// which is compiled out of production builds — the same guard the design
/// gallery uses. It produces no dose and no worker-facing record; its purpose
/// is to collect dossier V0 images.
///
/// The geometry comes from the packaged asset, checksum-verified against the
/// canonical definition in `measurement-engine/geometry/`. It is not
/// hard-coded here, and there is no fallback: if the geometry cannot be
/// trusted, capture does not start.
class CaptureHostScreen extends StatefulWidget {
  const CaptureHostScreen({
    required this.appVersion,
    this.geometryVersion = 'badge-v1-research',
    super.key,
  });

  final String appVersion;
  final String geometryVersion;

  @override
  State<CaptureHostScreen> createState() => _CaptureHostScreenState();
}

class _CaptureHostScreenState extends State<CaptureHostScreen> {
  CaptureController? _controller;
  CameraPortImpl? _port;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaitedStart();
  }

  void unawaitedStart() {
    _start().catchError((Object e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  Future<void> _start() async {
    final BadgeGeometry geometry;
    try {
      geometry = await GeometryAssets().load(widget.geometryVersion);
    } on GeometryAssetException catch (e) {
      // No fallback geometry. A measurement made against the wrong ROI
      // coordinates is undetectable downstream, so not starting is the only
      // safe response.
      if (mounted) setState(() => _error = e.detail);
      return;
    }

    final port = CameraPortImpl(appVersion: widget.appVersion);
    final controller = CaptureController(
      port: port,
      geometry: geometry,
      referenceTargets: badgeV1ReferenceTargets(geometry),
      fitPatchIds: badgeV1FitPatchIds,
      holdoutPatchIds: badgeV1HoldoutPatchIds,
      appVersion: widget.appVersion,
      // The worker presses the shutter. Auto-capture stays off while the
      // arming thresholds are provisional: an automatic shutter firing on an
      // unvalidated rule would make the thresholds harder to study, not
      // easier.
      autoCapture: false,
    );
    await controller.start();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _port = port;
      _controller = controller;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capture unavailable')),
        body: Padding(padding: const EdgeInsets.all(24), child: Text(error)),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return CaptureScreen(controller: controller, preview: _port?.controller);
  }
}
