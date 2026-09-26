import 'dart:async';
import 'dart:typed_data';

import 'package:h2s_doseband/features/capture/domain/capture_port.dart';
import 'package:measurement/measurement.dart';

/// A camera that emits images we constructed.
///
/// The iOS Simulator has no camera and CI has no phone, so without this the
/// acquisition rules — guidance, arming, refusal — would be untested
/// everywhere. It also lets the preview and the still differ, which is the
/// case directive §11 is about and which a real device makes hard to stage.
final class FakeCameraPort implements CameraPort {
  FakeCameraPort({
    required this.previewImages,
    required this.stillImage,
    this.capabilities = const CameraCapabilities(
      focusLockSupported: true,
      exposureLockSupported: true,
      whiteBalanceLockSupported: true,
      exposureCompensationSupported: true,
      manualIsoSupported: false,
      manualExposureDurationSupported: false,
      torchSupported: true,
      sensorMetadataAvailable: true,
    ),
    this.appliedSettings = const <String, String>{},
    this.frameInterval = const Duration(milliseconds: 150),
  });

  final List<RgbImage> previewImages;
  final RgbImage stillImage;
  final CameraCapabilities capabilities;
  final Map<String, String> appliedSettings;
  final Duration frameInterval;

  int captureCount = 0;
  bool opened = false;
  bool closed = false;

  final _controller = StreamController<PreviewFrame>.broadcast();
  DateTime _clock = DateTime.utc(2026, 9, 24, 12);

  @override
  Future<CameraCapabilities> open() async {
    opened = true;
    return capabilities;
  }

  @override
  Future<Map<String, String>> applyMeasurementSettings() async =>
      appliedSettings;

  @override
  Stream<PreviewFrame> previewFrames() => _controller.stream;

  /// Pushes [count] preview frames, advancing a deterministic clock.
  Future<void> emit(int count, {RgbImage? image}) async {
    for (var i = 0; i < count; i++) {
      _clock = _clock.add(frameInterval);
      _controller.add((
        image: image ?? previewImages[i % previewImages.length],
        at: _clock,
      ));
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<CapturedStill> captureStill() async {
    captureCount++;
    return (
      image: stillImage,
      originalBytes: Uint8List(0),
      metadata: CaptureMetadata(
        capturedAt: _clock,
        deviceManufacturer: 'Fake',
        deviceModel: 'FakePhone 1',
        operatingSystem: 'test',
        appVersion: '0.1.0',
        capabilities: capabilities,
        cameraId: const CaptureField<String>.known('0'),
        imageWidth: CaptureField<int>.known(stillImage.width),
        imageHeight: CaptureField<int>.known(stillImage.height),
        orientationDegrees: const CaptureField<int>.known(0),
        torchOn: const CaptureField<bool>.known(false),
        focusLocked: const CaptureField<bool>.known(true),
        exposureLocked: const CaptureField<bool>.known(true),
        whiteBalanceLocked: const CaptureField<bool>.known(true),
        exposureCompensation: const CaptureField<double>.known(0),
        isoSensitivity: const CaptureField<int>.unsupported(),
        exposureTimeSeconds: const CaptureField<double>.unavailable(),
        requestedSettings: appliedSettings,
      ),
    );
  }

  @override
  Future<void> close() async {
    closed = true;
    await _controller.close();
  }
}
