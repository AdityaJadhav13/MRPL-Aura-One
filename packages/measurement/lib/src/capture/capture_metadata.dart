import 'package:meta/meta.dart';

/// Whether a piece of capture metadata is known, and if not, why not.
///
/// Three states, not two. "We asked the platform and it said 400" and "this
/// phone has no API for ISO" and "the API exists but returned nothing" are
/// different facts, and collapsing them into a nullable number loses the only
/// thing that distinguishes a device limitation from a bug.
///
/// Directive §7: never fabricate metadata.
enum MetadataAvailability {
  /// The value was read from the platform.
  known,

  /// The platform exposes this control, but no value was available for this
  /// capture — not yet converged, not reported, or not applicable.
  unavailable,

  /// This platform or device does not expose the control at all.
  unsupported,
}

/// One metadata field and the reason it does or does not have a value.
@immutable
final class CaptureField<T> {
  const CaptureField.known(T this.value)
    : availability = MetadataAvailability.known;

  const CaptureField.unavailable()
    : value = null,
      availability = MetadataAvailability.unavailable;

  const CaptureField.unsupported()
    : value = null,
      availability = MetadataAvailability.unsupported;

  /// Non-null exactly when [availability] is [MetadataAvailability.known].
  final T? value;
  final MetadataAvailability availability;

  bool get isKnown => availability == MetadataAvailability.known;

  Map<String, Object?> toJson() => <String, Object?>{
    'availability': availability.name,
    if (value != null) 'value': value,
  };

  @override
  String toString() => isKnown ? '$value' : availability.name;
}

/// What the platform said it could do, as opposed to what we asked for.
///
/// Recorded per capture rather than assumed per platform. Android's camera2
/// support varies enormously between devices at the same OS level, and a
/// hardware level that nominally exposes a control does not guarantee this
/// handset honours it.
///
/// **A phone that lacks a control is not thereby rejected.** Whether manual
/// white balance is actually needed is an experimental question — the whole
/// point of the printed reference patches is to make the illuminant
/// recoverable without it — and dossier V0 (Q9) exists to answer it. Until it
/// does, capability is recorded, not gated on.
@immutable
final class CameraCapabilities {
  const CameraCapabilities({
    required this.focusLockSupported,
    required this.exposureLockSupported,
    required this.whiteBalanceLockSupported,
    required this.exposureCompensationSupported,
    required this.manualIsoSupported,
    required this.manualExposureDurationSupported,
    required this.torchSupported,
    required this.sensorMetadataAvailable,
    this.lensDescription,
    this.maximumResolution,
  });

  /// Nothing known yet — the state before a camera has been opened.
  const CameraCapabilities.unknown()
    : focusLockSupported = false,
      exposureLockSupported = false,
      whiteBalanceLockSupported = false,
      exposureCompensationSupported = false,
      manualIsoSupported = false,
      manualExposureDurationSupported = false,
      torchSupported = false,
      sensorMetadataAvailable = false,
      lensDescription = null,
      maximumResolution = null;

  final bool focusLockSupported;
  final bool exposureLockSupported;
  final bool whiteBalanceLockSupported;
  final bool exposureCompensationSupported;
  final bool manualIsoSupported;
  final bool manualExposureDurationSupported;
  final bool torchSupported;

  /// Whether per-frame sensor values (ISO, exposure time) can be read back.
  /// Distinct from being able to *set* them: some platforms report without
  /// allowing control, and that is still useful, because a recorded value is
  /// measurement metadata even when it was chosen by the phone.
  final bool sensorMetadataAvailable;

  final String? lensDescription;
  final String? maximumResolution;

  /// The controls that most directly affect reproducibility between two
  /// photographs of the same badge.
  int get lockScore =>
      (focusLockSupported ? 1 : 0) +
      (exposureLockSupported ? 1 : 0) +
      (whiteBalanceLockSupported ? 1 : 0);

  Map<String, Object?> toJson() => <String, Object?>{
    'focus_lock_supported': focusLockSupported,
    'exposure_lock_supported': exposureLockSupported,
    'white_balance_lock_supported': whiteBalanceLockSupported,
    'exposure_compensation_supported': exposureCompensationSupported,
    'manual_iso_supported': manualIsoSupported,
    'manual_exposure_duration_supported': manualExposureDurationSupported,
    'torch_supported': torchSupported,
    'sensor_metadata_available': sensorMetadataAvailable,
    'lens_description': lensDescription,
    'maximum_resolution': maximumResolution,
    'lock_score': lockScore,
  };
}

/// Everything recorded about how a photograph was taken.
///
/// The camera is part of the instrument, so this is measurement metadata, not
/// diagnostics. Directive §11 and §7.
@immutable
final class CaptureMetadata {
  const CaptureMetadata({
    required this.capturedAt,
    required this.deviceManufacturer,
    required this.deviceModel,
    required this.operatingSystem,
    required this.appVersion,
    required this.capabilities,
    required this.cameraId,
    required this.imageWidth,
    required this.imageHeight,
    required this.orientationDegrees,
    required this.torchOn,
    required this.focusLocked,
    required this.exposureLocked,
    required this.whiteBalanceLocked,
    required this.exposureCompensation,
    required this.isoSensitivity,
    required this.exposureTimeSeconds,
    required this.requestedSettings,
  });

  final DateTime capturedAt;
  final String deviceManufacturer;
  final String deviceModel;
  final String operatingSystem;
  final String appVersion;
  final CameraCapabilities capabilities;

  final CaptureField<String> cameraId;
  final CaptureField<int> imageWidth;
  final CaptureField<int> imageHeight;
  final CaptureField<int> orientationDegrees;
  final CaptureField<bool> torchOn;
  final CaptureField<bool> focusLocked;
  final CaptureField<bool> exposureLocked;
  final CaptureField<bool> whiteBalanceLocked;
  final CaptureField<double> exposureCompensation;
  final CaptureField<int> isoSensitivity;
  final CaptureField<double> exposureTimeSeconds;

  /// What the app asked the platform for, regardless of what it got.
  ///
  /// Kept separately from the applied values on purpose: "we requested an
  /// exposure lock and the device ignored it" is a different measurement
  /// condition from "we never asked", and only the pair distinguishes them.
  final Map<String, String> requestedSettings;

  Map<String, Object?> toJson() => <String, Object?>{
    'captured_at': capturedAt.toIso8601String(),
    'device_manufacturer': deviceManufacturer,
    'device_model': deviceModel,
    'operating_system': operatingSystem,
    'app_version': appVersion,
    'capabilities': capabilities.toJson(),
    'camera_id': cameraId.toJson(),
    'image_width': imageWidth.toJson(),
    'image_height': imageHeight.toJson(),
    'orientation_degrees': orientationDegrees.toJson(),
    'torch_on': torchOn.toJson(),
    'focus_locked': focusLocked.toJson(),
    'exposure_locked': exposureLocked.toJson(),
    'white_balance_locked': whiteBalanceLocked.toJson(),
    'exposure_compensation': exposureCompensation.toJson(),
    'iso_sensitivity': isoSensitivity.toJson(),
    'exposure_time_seconds': exposureTimeSeconds.toJson(),
    'requested_settings': requestedSettings,
  };
}
