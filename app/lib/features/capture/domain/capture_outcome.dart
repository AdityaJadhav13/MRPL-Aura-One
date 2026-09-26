import 'dart:typed_data';

import 'package:measurement/measurement.dart';

/// The raw material of one capture, kept whether it was accepted or refused.
///
/// A refused capture is still evidence — often the most useful kind in M0C,
/// because it shows what the reader rejects and why. So both outcomes carry
/// this, and the archive writes both. APP-INTEGRATION-01 §10, §27.
final class CaptureEvidence {
  const CaptureEvidence({
    required this.originalBytes,
    required this.still,
    required this.previewAssessment,
    required this.stillAssessment,
    required this.stillQuality,
    this.homography,
  });

  /// Exactly what the camera produced. Never re-encoded.
  final Uint8List originalBytes;

  /// The decoded still, for diagnostics overlays. Not persisted: it is
  /// recomputable from [originalBytes], and storing it would double the size
  /// of every capture for nothing.
  final RgbImage still;

  /// The last preview assessment before the shutter. Null when the shutter
  /// was pressed before any preview frame had been assessed.
  final GuidanceAssessment? previewAssessment;

  /// The authoritative assessment, of the still itself.
  final GuidanceAssessment? stillAssessment;

  final ImageQuality stillQuality;

  /// Badge-to-image mapping, where fiducials were found. Used to draw ROI
  /// outlines on the original in diagnostics.
  final Homography? homography;
}

/// How a capture attempt ended.
///
/// There is no "captured successfully" state carrying a dose, and there will
/// not be one in M0B. A capture produces either an observation — optical
/// features, with the conditions they were measured under — or a refusal.
sealed class CaptureOutcome {
  const CaptureOutcome({required this.evidence});

  final CaptureEvidence evidence;
}

/// The still passed every acquisition check and features were extracted.
///
/// Still not a measurement: there is no calibration model, so
/// [MeasurementResult] for this observation is a refusal. See
/// `refuseForLackOfCalibration`.
final class CaptureObserved extends CaptureOutcome {
  const CaptureObserved({
    required this.observation,
    required this.metadata,
    required this.geometryValidation,
    required this.result,
    required super.evidence,
  });

  final ResearchObservation observation;
  final CaptureMetadata metadata;

  /// Null when the geometry carries no withheld control points, in which case
  /// deformation simply cannot be assessed and must not be claimed.
  final GeometryValidation? geometryValidation;

  /// Whatever the configured [Calibration] made of the observation. With
  /// [NoCalibration] — the only one that exists — always a refusal.
  final MeasurementResult result;
}

/// The still did not pass, so no features were extracted.
///
/// Reached by manual capture as readily as by auto-capture. A manual shutter
/// is a usability affordance, not a measurement override — directive §10.
final class CaptureRefused extends CaptureOutcome {
  const CaptureRefused({
    required this.result,
    required this.metadata,
    required super.evidence,
    this.assessment,
  });

  final MeasurementResult result;
  final CaptureMetadata metadata;

  /// What the final still looked like, where that could be assessed.
  final GuidanceAssessment? assessment;
}
