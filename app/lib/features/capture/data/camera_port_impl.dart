import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:measurement/measurement.dart';

import '../domain/capture_port.dart';

/// The real camera, behind [CameraPort].
///
/// Everything platform-specific lives here: capability probing, frame format
/// conversion, and the gap between what we ask the camera for and what it
/// agrees to do.
///
/// **Not covered by automated tests.** The iOS Simulator has no camera and CI
/// has no phone, so this class is verified by compiling and by running on a
/// device. That is exactly why [CameraPort] exists — the acquisition rules it
/// feeds are tested through `FakeCameraPort`, so the untested surface is
/// confined to format conversion and plugin calls.
final class CameraPortImpl implements CameraPort {
  CameraPortImpl({
    required this.appVersion,
    this.resolution = ResolutionPreset.veryHigh,
    this.previewDownscale = 4,
  });

  final String appVersion;
  final ResolutionPreset resolution;

  /// Preview frames are downscaled before analysis. Guidance runs several
  /// times a second and a full-resolution pass would heat the phone without
  /// improving the advice; the still is analysed at full resolution.
  final int previewDownscale;

  CameraController? _controller;
  CameraDescription? _description;
  CameraCapabilities? _capabilities;

  /// Read once, when the camera opens. See [_readDevice].
  _DeviceIdentity? _device;
  final Map<String, String> _requested = <String, String>{};
  StreamController<PreviewFrame>? _frames;

  @override
  Future<CameraCapabilities> open() async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      throw CameraUnavailable('${e.code}: ${e.description ?? ''}');
    }
    if (cameras.isEmpty) {
      throw const CameraUnavailable('no cameras are available on this device');
    }

    _device = await _readDevice();

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _description = back;

    final controller = CameraController(
      back,
      resolution,
      // The badge is a colour measurement; audio is irrelevant and asking for
      // it would request a permission we do not need.
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      throw CameraUnavailable('${e.code}: ${e.description ?? ''}');
    }
    _controller = controller;

    // Probe rather than assume. Support varies between handsets at the same
    // OS level, so the only honest source is this device, now.
    Future<bool> supports(Future<void> Function() attempt) async {
      try {
        await attempt();
        return true;
      } on CameraException {
        return false;
      } on UnsupportedError {
        return false;
      } on MissingPluginException {
        return false;
      }
    }

    final focus = await supports(
      () => controller.setFocusMode(FocusMode.locked),
    );
    final exposure = await supports(
      () => controller.setExposureMode(ExposureMode.locked),
    );
    final compensation = await supports(
      () async => controller.getMinExposureOffset(),
    );
    final torch = await supports(() => controller.setFlashMode(FlashMode.off));

    return _capabilities = CameraCapabilities(
      focusLockSupported: focus,
      exposureLockSupported: exposure,
      // The plugin exposes no white-balance lock on either platform today.
      // Recorded as unsupported rather than silently assumed either way; a
      // phone lacking it is NOT rejected, because whether it matters is what
      // dossier V0 Q9 exists to answer.
      whiteBalanceLockSupported: false,
      exposureCompensationSupported: compensation,
      manualIsoSupported: false,
      manualExposureDurationSupported: false,
      torchSupported: torch,
      sensorMetadataAvailable: false,
      lensDescription: '${back.name} (${back.lensDirection.name})',
      maximumResolution: resolution.name,
    );
  }

  @override
  Future<Map<String, String>> applyMeasurementSettings() async {
    final controller = _controller;
    if (controller == null) {
      throw const CameraUnavailable('camera is not open');
    }
    _requested
      ..clear()
      ..addAll(<String, String>{
        'focus_mode': 'locked',
        'exposure_mode': 'locked',
        'flash_mode': 'off',
        'image_format': Platform.isAndroid ? 'yuv420' : 'bgra8888',
        'resolution_preset': resolution.name,
      });

    final applied = <String, String>{};
    Future<void> attempt(String key, Future<void> Function() action) async {
      try {
        await action();
        applied[key] = _requested[key]!;
      } on CameraException catch (e) {
        // The difference between "we asked and were refused" and "we never
        // asked" is measurement metadata, so the failure is recorded rather
        // than swallowed.
        applied[key] = 'refused:${e.code}';
      }
    }

    await attempt('flash_mode', () => controller.setFlashMode(FlashMode.off));
    await attempt(
      'focus_mode',
      () => controller.setFocusMode(FocusMode.locked),
    );
    await attempt(
      'exposure_mode',
      () => controller.setExposureMode(ExposureMode.locked),
    );
    applied['image_format'] = _requested['image_format']!;
    applied['resolution_preset'] = _requested['resolution_preset']!;
    return applied;
  }

  @override
  Stream<PreviewFrame> previewFrames() {
    final controller = _controller;
    if (controller == null) {
      throw const CameraUnavailable('camera is not open');
    }
    final frames = StreamController<PreviewFrame>.broadcast(
      onCancel: () async {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      },
    );
    _frames = frames;

    controller.startImageStream((CameraImage image) {
      if (frames.isClosed) return;
      final converted = _toRgb(image, downscale: previewDownscale);
      if (converted != null) {
        frames.add((image: converted, at: DateTime.now()));
      }
    });
    return frames.stream;
  }

  @override
  Future<CapturedStill> captureStill() async {
    final controller = _controller;
    if (controller == null) {
      throw const CameraUnavailable('camera is not open');
    }
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    final XFile file;
    try {
      file = await controller.takePicture();
    } on CameraException catch (e) {
      throw CameraUnavailable('${e.code}: ${e.description ?? ''}');
    }
    final bytes = await file.readAsBytes();

    // Decode for analysis, but keep the ORIGINAL bytes. The analytical image
    // is never re-encoded: repeated JPEG compression is the kind of quiet
    // degradation directive §11 forbids, and the stored original is what a
    // future algorithm version would be re-run against.
    final RgbImage image;
    try {
      image = decodeStill(bytes);
    } on FormatException catch (e) {
      throw CameraUnavailable('captured image could not be decoded: $e');
    }

    final controllerValue = controller.value;
    return (
      image: image,
      originalBytes: bytes,
      metadata: CaptureMetadata(
        capturedAt: DateTime.now(),
        // Read from the platform, not inferred. This previously recorded
        // the camera id as the device model ("0" on Android) and the
        // platform as the manufacturer — every capture would have been
        // untraceable by device. APP-INTEGRATION-01 G-02.
        deviceManufacturer: _device?.manufacturer ?? 'unavailable',
        deviceModel: _device?.model ?? 'unavailable',
        operatingSystem:
            _device?.operatingSystem ?? Platform.operatingSystemVersion,
        appVersion: appVersion,
        capabilities: _capabilities ?? const CameraCapabilities.unknown(),
        cameraId: CaptureField<String>.known(_description?.name ?? 'unknown'),
        imageWidth: CaptureField<int>.known(image.width),
        imageHeight: CaptureField<int>.known(image.height),
        orientationDegrees: CaptureField<int>.known(
          _description?.sensorOrientation ?? 0,
        ),
        torchOn: CaptureField<bool>.known(
          controllerValue.flashMode == FlashMode.torch,
        ),
        focusLocked: CaptureField<bool>.known(
          controllerValue.focusMode == FocusMode.locked,
        ),
        exposureLocked: CaptureField<bool>.known(
          controllerValue.exposureMode == ExposureMode.locked,
        ),
        // The plugin exposes no white-balance state on either platform, so
        // this is UNSUPPORTED rather than false. Never fabricate metadata.
        whiteBalanceLocked: const CaptureField<bool>.unsupported(),
        exposureCompensation: const CaptureField<double>.unavailable(),
        isoSensitivity: const CaptureField<int>.unsupported(),
        exposureTimeSeconds: const CaptureField<double>.unsupported(),
        requestedSettings: Map<String, String>.of(_requested),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _frames?.close();
    await _controller?.dispose();
    _controller = null;
  }

  /// Converts a platform frame to the engine's image type.
  ///
  /// Preview frames only. Nothing analytical depends on this conversion being
  /// colour-accurate — guidance needs geometry and gross exposure, and the
  /// authoritative colour work happens on the still.
  static RgbImage? _toRgb(CameraImage image, {int downscale = 1}) {
    final step = downscale < 1 ? 1 : downscale;
    final width = image.width ~/ step;
    final height = image.height ~/ step;
    if (width < 8 || height < 8) return null;

    final out = RgbImage.filled(width, height, 0, 0, 0);

    switch (image.format.group) {
      case ImageFormatGroup.bgra8888:
        final plane = image.planes.first;
        final rowStride = plane.bytesPerRow;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final i = (y * step) * rowStride + (x * step) * 4;
            if (i + 3 >= plane.bytes.length) continue;
            out.setPixel(
              x,
              y,
              plane.bytes[i + 2],
              plane.bytes[i + 1],
              plane.bytes[i],
            );
          }
        }
      case ImageFormatGroup.yuv420:
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];
        final uvRowStride = uPlane.bytesPerRow;
        final uvPixelStride = uPlane.bytesPerPixel ?? 1;
        for (var y = 0; y < height; y++) {
          final sy = y * step;
          for (var x = 0; x < width; x++) {
            final sx = x * step;
            final yIndex = sy * yPlane.bytesPerRow + sx;
            final uvIndex = (sy ~/ 2) * uvRowStride + (sx ~/ 2) * uvPixelStride;
            if (yIndex >= yPlane.bytes.length ||
                uvIndex >= uPlane.bytes.length ||
                uvIndex >= vPlane.bytes.length) {
              continue;
            }
            final yy = yPlane.bytes[yIndex];
            final uu = uPlane.bytes[uvIndex] - 128;
            final vv = vPlane.bytes[uvIndex] - 128;
            int clamp(num v) => v < 0 ? 0 : (v > 255 ? 255 : v.toInt());
            out.setPixel(
              x,
              y,
              clamp(yy + 1.402 * vv),
              clamp(yy - 0.344136 * uu - 0.714136 * vv),
              clamp(yy + 1.772 * uu),
            );
          }
        }
      case ImageFormatGroup.jpeg:
      case ImageFormatGroup.nv21:
      case ImageFormatGroup.unknown:
        return null;
    }
    return out;
  }

  /// Exposed for a device-side smoke check.
  @visibleForTesting
  static RgbImage? convertForTest(CameraImage image, {int downscale = 1}) =>
      _toRgb(image, downscale: downscale);

  /// The live controller, for the preview widget. Null until [open] succeeds.
  CameraController? get controller => _controller;
}

/// The phone itself, as the platform reports it.
typedef _DeviceIdentity = ({
  String manufacturer,
  String model,
  String operatingSystem,
});

/// Reads manufacturer, model and OS from the platform.
///
/// Returns null rather than guessing when the platform will not say. A
/// fabricated model is worse than an absent one: it would silently merge two
/// phones' data into one population in every cross-device comparison.
Future<_DeviceIdentity?> _readDevice() async {
  final info = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      return (
        manufacturer: a.manufacturer,
        model: a.model,
        operatingSystem:
            'Android ${a.version.release} (SDK ${a.version.sdkInt})',
      );
    }
    if (Platform.isIOS) {
      final i = await info.iosInfo;
      return (
        manufacturer: 'Apple',
        model: i.utsname.machine,
        operatingSystem: '${i.systemName} ${i.systemVersion}',
      );
    }
  } on Object {
    return null;
  }
  return null;
}
