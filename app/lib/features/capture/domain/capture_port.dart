import 'dart:typed_data';

import 'package:measurement/measurement.dart';

/// One preview frame, already converted to the engine's image type.
typedef PreviewFrame = ({RgbImage image, DateTime at});

/// A captured still, with everything known about how it was taken.
typedef CapturedStill = ({
  RgbImage image,
  Uint8List originalBytes,
  CaptureMetadata metadata,
});

/// The boundary between the app and the camera hardware.
///
/// This exists so the acquisition logic — guidance, arming, refusal — can be
/// exercised without a device. That is not a convenience: the iOS Simulator
/// has no camera at all, and CI has no phone, so an untestable camera layer
/// would mean the acquisition rules were never tested anywhere.
///
/// Implementations report what the platform **actually** supports rather than
/// what the plugin nominally offers. Android camera2 support varies widely
/// between handsets at the same OS level.
abstract interface class CameraPort {
  /// Opens the camera and reports what it can do.
  Future<CameraCapabilities> open();

  /// Requests the locks that make two photographs of the same badge
  /// comparable. Returns what was actually applied, which may be less than
  /// what was asked for — and the difference is recorded, not hidden.
  Future<Map<String, String>> applyMeasurementSettings();

  /// Downscaled preview frames for guidance. Never the measurement path.
  Stream<PreviewFrame> previewFrames();

  /// Takes the full-resolution still that the measurement is made from.
  Future<CapturedStill> captureStill();

  Future<void> close();
}

/// Raised when the camera cannot be used at all.
final class CameraUnavailable implements Exception {
  const CameraUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'CameraUnavailable: $reason';
}
