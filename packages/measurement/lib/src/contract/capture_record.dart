import 'package:meta/meta.dart';

import '../capture/capture_metadata.dart';
import '../capture/guidance.dart';
import '../geometry/geometry_validation.dart';
import '../quality/image_quality.dart';
import 'data_domain.dart';
import 'feature_vector.dart';
import 'research_pipeline.dart';

/// Where a capture was taken, as the operator described it.
///
/// Free-form-ish on purpose: these are experimental conditions recorded by a
/// person, not measured by the phone. Pretending otherwise — inferring the
/// illuminant from the image, say — would mean the dataset's independent
/// variable was derived from its dependent one.
@immutable
final class CaptureConditions {
  const CaptureConditions({
    required this.illuminationClass,
    required this.approximateDistanceMm,
    required this.approximateAngleDegrees,
    required this.targetId,
    required this.operatorNote,
    this.deliberateFailure,
  });

  /// e.g. `daylight`, `warm-led`, `cool-led`, `mixed`, `low-light`,
  /// `strong-directional`.
  final String illuminationClass;

  final int? approximateDistanceMm;
  final int? approximateAngleDegrees;

  /// Which physical printed target this is — a specific sheet, not a design.
  /// Two prints of the same file are two targets.
  final String targetId;

  final String operatorNote;

  /// Set when the capture was staged to fail: `glare`, `blur`, `shadow`,
  /// `occluded-marker`, `bent`, `overexposed`, `underexposed`, `cropped`.
  ///
  /// **Deliberate failures must not be pooled with valid acquisitions in any
  /// statistic.** They exist to test refusal, and averaging them into a
  /// detection rate would understate it while telling us nothing about
  /// refusal. This field is what keeps the two populations apart.
  final String? deliberateFailure;

  bool get isDeliberateFailure => deliberateFailure != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'illumination_class': illuminationClass,
    'approximate_distance_mm': approximateDistanceMm,
    'approximate_angle_degrees': approximateAngleDegrees,
    'target_id': targetId,
    'operator_note': operatorNote,
    'deliberate_failure': deliberateFailure,
    'is_deliberate_failure': isDeliberateFailure,
  };
}

/// Which physical research specimen a capture photographed.
///
/// ## Why this is separate from a badge id
///
/// `badge_id` is product identity: the badge a worker wears, assigned through
/// the workflow. `specimen_id` is laboratory identity: one piece of printed
/// target, coupon or prototype on a bench. They answer different questions and
/// are owned by different processes, and overloading one to carry the other is
/// how a laboratory coupon ends up looking like an issued badge in a report.
/// Directive APP-INTEGRATION-01 §12.
///
/// ## Why the series level carries no dose
///
/// [seriesLevel] is an intended *ordering* — `X0` unexposed, `X1` < `X2` <
/// `X3` — and nothing more. It deliberately has no numeric exposure attached.
/// Until a reference instrument measures the integrated concentration at the
/// badge plane, there is no dose to attach, and deriving one from the badge's
/// own colour would be circular calibration. §42, §47.
@immutable
final class ResearchSpecimen {
  const ResearchSpecimen({
    required this.specimenId,
    this.badgeId,
    this.batchId,
    this.formulationId,
    this.seriesLevel,
  }) : assert(specimenId != '', 'a specimen must be identified');

  /// e.g. `P0-X1-01`. The one required field: a capture with no specimen is a
  /// photograph of something, and nobody can later say what.
  final String specimenId;

  /// Product badge identity, when the specimen is also an issued badge.
  final String? badgeId;

  final String? batchId;
  final String? formulationId;

  /// Intended order in a series, e.g. `X0`–`X3`. Ordinal, never a dose.
  final String? seriesLevel;

  Map<String, Object?> toJson() => <String, Object?>{
    'specimen_id': specimenId,
    'badge_id': badgeId,
    'batch_id': batchId,
    'formulation_id': formulationId,
    'series_level': seriesLevel,
  };

  static ResearchSpecimen fromJson(Map<String, Object?> json) =>
      ResearchSpecimen(
        specimenId: json['specimen_id']! as String,
        badgeId: json['badge_id'] as String?,
        batchId: json['batch_id'] as String?,
        formulationId: json['formulation_id'] as String?,
        seriesLevel: json['series_level'] as String?,
      );
}

/// Everything recorded about one capture, for dossier V0.
///
/// One record per capture, carrying its own conditions and provenance, so a
/// file never has to be interpreted by its name. Renaming files by hand, with
/// the metadata left behind, is how a dataset stops meaning anything.
@immutable
final class CaptureRecord {
  const CaptureRecord({
    required this.captureId,
    required this.dataDomain,
    required this.geometryVersion,
    required this.featureDefinitionVersion,
    required this.algorithmVersion,
    required this.conditions,
    required this.metadata,
    required this.previewAssessment,
    required this.stillAssessment,
    required this.outcome,
    required this.originalImageFile,
    this.featureVector,
    this.geometryValidation,
    this.stillQuality,
    this.refusalCode,
    this.refusalDetail,
    this.specimen,
    this.observation,
    this.correctionMethod,
    this.homography,
    this.measurementStatus,
  });

  final String captureId;

  /// `lab` for dossier V0: printed targets are controlled and traceable. Not
  /// `simulated` — these are real photographs — and not `field`, which is
  /// reserved for a badge worn by a worker.
  final DataDomain dataDomain;

  final String geometryVersion;
  final String featureDefinitionVersion;
  final String algorithmVersion;

  final CaptureConditions conditions;
  final CaptureMetadata metadata;

  /// The last preview assessment before the shutter, and the assessment of the
  /// still itself.
  ///
  /// Both are kept because they are the raw material for the preview-versus-
  /// still question: can a preview metric safely gate a still capture, or must
  /// every metric be recomputed? The authoritative one is always the still.
  final GuidanceAssessment? previewAssessment;
  final GuidanceAssessment? stillAssessment;

  /// `observed` or `refused`.
  final String outcome;

  /// Path of the ORIGINAL captured bytes, relative to the archive root. Never
  /// re-encoded: features can be recomputed, an original cannot.
  final String originalImageFile;

  final FeatureVector? featureVector;
  final GeometryValidation? geometryValidation;
  final ImageQuality? stillQuality;
  final String? refusalCode;
  final String? refusalDetail;

  /// Which physical specimen was photographed. See [ResearchSpecimen].
  final ResearchSpecimen? specimen;

  /// The full observation — every ROI sample, the fitted correction and its
  /// holdout validation — not just the feature vector derived from it.
  ///
  /// §50: calibration will evolve, and a record that kept only "ΔE = 12.3"
  /// could never be recomputed under a later method. The ROI statistics are
  /// the near-raw data a future method would start from.
  final ResearchObservation? observation;

  /// Which correction method the capture was processed under, e.g.
  /// `affine3x4` or `linear3x3`, or null if none fitted. §49.
  final String? correctionMethod;

  /// The badge-to-image homography, row-major 3×3, in millimetres to pixels.
  ///
  /// Recomputable from the original by re-running detection, but storing it
  /// means a later reader can check an ROI's placement without re-running
  /// anything — and can tell if a later detector disagrees.
  final List<List<double>>? homography;

  /// The `ResultStatus` the calibration produced, e.g.
  /// `unsupportedCalibration` for an observation with no calibration.
  ///
  /// Read together with [outcome], this is the typed state §17 asks for:
  /// `outcome == observed` and `unsupportedCalibration` means the optical
  /// acquisition was valid and there was no evidence-backed way to turn it
  /// into an exposure. It is never a number, and never zero.
  final String? measurementStatus;

  Map<String, Object?> toJson() => <String, Object?>{
    // Version 2 adds the specimen, the full observation and the correction
    // method. Version 1 records remain readable: every new field is optional.
    'schema': 'doseband-capture-record/2',
    'capture_id': captureId,
    'data_domain': dataDomain.name,
    'disclosure': dataDomain.disclosure,
    'geometry_version': geometryVersion,
    'feature_definition_version': featureDefinitionVersion,
    'algorithm_version': algorithmVersion,
    'conditions': conditions.toJson(),
    'device': metadata.toJson(),
    'preview_assessment': previewAssessment?.toJson(),
    'still_assessment': stillAssessment?.toJson(),
    'still_quality': stillQuality?.toJson(),
    'outcome': outcome,
    'measurement_status': measurementStatus,
    'refusal_code': refusalCode,
    'refusal_detail': refusalDetail,
    'original_image_file': originalImageFile,
    'geometry_validation': geometryValidation?.toJson(),
    'feature_vector': featureVector?.toJson(),
    'specimen': specimen?.toJson(),
    'correction_method': correctionMethod,
    'homography_badge_mm_to_image_px': homography,
    'observation': observation?.toJson(),
  };
}
