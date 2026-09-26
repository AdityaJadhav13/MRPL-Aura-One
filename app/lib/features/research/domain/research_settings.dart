import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

/// What the operator states about the next capture.
///
/// Held between captures so that photographing the same specimen twenty
/// times under one lamp is twenty shutter presses, not twenty forms. The
/// specimen id is the only required field — §40 wants this fast.
@immutable
final class ResearchSettings {
  const ResearchSettings({
    required this.specimenId,
    this.badgeId = '',
    this.batchId = '',
    this.formulationId = '',
    this.seriesLevel = '',
    this.illuminationClass = 'unspecified',
    this.operatorNote = '',
    this.deliberateFailure,
  });

  /// e.g. `P0-X1-01`.
  final String specimenId;
  final String badgeId;
  final String batchId;
  final String formulationId;

  /// `X0`–`X3`, or empty. An intended ordering, never a dose. §42.
  final String seriesLevel;

  /// As the operator describes it: `daylight`, `warm-led`, `cool-led`,
  /// `low-light`, `directional`, `shadow`, `mixed`, `glare`. Recorded, never
  /// inferred from the image — that would derive the independent variable
  /// from the dependent one.
  final String illuminationClass;

  final String operatorNote;

  /// Set when the capture is staged to fail. Keeps refusal tests out of every
  /// acceptance statistic.
  final String? deliberateFailure;

  bool get isComplete => specimenId.trim().isNotEmpty;

  ResearchSpecimen toSpecimen() => ResearchSpecimen(
    specimenId: specimenId.trim(),
    badgeId: _orNull(badgeId),
    batchId: _orNull(batchId),
    formulationId: _orNull(formulationId),
    seriesLevel: _orNull(seriesLevel),
  );

  CaptureConditions toConditions() => CaptureConditions(
    illuminationClass: illuminationClass,
    approximateDistanceMm: null,
    approximateAngleDegrees: null,
    // The physical object photographed. For a coupon or printed specimen
    // that is the specimen itself.
    targetId: specimenId.trim(),
    operatorNote: operatorNote,
    deliberateFailure: deliberateFailure,
  );

  ResearchSettings copyWith({
    String? specimenId,
    String? badgeId,
    String? batchId,
    String? formulationId,
    String? seriesLevel,
    String? illuminationClass,
    String? operatorNote,
    String? deliberateFailure,
    bool clearDeliberateFailure = false,
  }) => ResearchSettings(
    specimenId: specimenId ?? this.specimenId,
    badgeId: badgeId ?? this.badgeId,
    batchId: batchId ?? this.batchId,
    formulationId: formulationId ?? this.formulationId,
    seriesLevel: seriesLevel ?? this.seriesLevel,
    illuminationClass: illuminationClass ?? this.illuminationClass,
    operatorNote: operatorNote ?? this.operatorNote,
    deliberateFailure: clearDeliberateFailure
        ? null
        : (deliberateFailure ?? this.deliberateFailure),
  );

  static String? _orNull(String v) => v.trim().isEmpty ? null : v.trim();
}

/// Illumination classes offered in the form. Free text is still accepted.
const illuminationClasses = <String>[
  'unspecified',
  'daylight',
  'warm-led',
  'cool-led',
  'low-light',
  'directional',
  'shadow',
  'mixed',
  'glare',
];

/// Deliberate failure classes, matching the M0C capture matrix.
const deliberateFailureClasses = <String>[
  'blur',
  'glare',
  'shadow',
  'occluded-marker',
  'cropped',
  'bent',
  'overexposed',
  'underexposed',
  'distractor',
];
