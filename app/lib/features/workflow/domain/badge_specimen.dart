import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

import 'physical_badge.dart';

/// A simulated badge.
///
/// In production a badge is a physical object whose reacted sensor window is
/// photographed and measured. Here there is no photograph and no chemistry: a
/// specimen carries a *declared* outcome, and scanning it plays that outcome
/// through the real [MeasurementResult] state machine. Nothing is computed from
/// an image — that is Phase 3+. This keeps the simulation honest: it exercises
/// the UI's handling of every result state without inventing a measurement.
///
/// Every specimen lives in the `simulated` data domain and is rendered with the
/// magenta simulation marker. It can never become a production record.
@immutable
final class BadgeSpecimen implements BadgeIdentity {
  const BadgeSpecimen({
    required this.badgeId,
    required this.lot,
    required this.formulation,
    required this.calibrationModelId,
    required this.geometryVersion,
    required this.expiry,
    required this.validity,
    required this.outcome,
    required this.label,
    required this.description,
  });

  @override
  final String badgeId;
  final String lot;
  @override
  final String formulation;
  final String calibrationModelId;
  final String geometryVersion;
  @override
  final DateTime expiry;

  /// The result of the pre-scan validation checks (batch supported, calibration
  /// available, not previously used, within validity, QR integrity). A specimen
  /// that fails verification never reaches monitoring.
  final BadgeValidity validity;

  /// What this specimen reports when it is finally scanned.
  final SpecimenOutcome outcome;

  /// Short name for the simulation picker, e.g. "Mid response".
  final String label;

  /// One line explaining what this specimen demonstrates.
  final String description;

  @override
  String? get batch => lot;

  @override
  bool get isSimulated => true;

  @override
  String get identityProvenance => 'Simulated specimen';
}

/// The verification verdict for a specimen, and why.
@immutable
final class BadgeValidity {
  const BadgeValidity({required this.checks, required this.eligible});

  /// Ordered checks shown on the verification screen.
  final List<BadgeCheck> checks;

  /// Whether assignment may proceed. False if any blocking check failed.
  final bool eligible;

  static const List<String> checkOrder = [
    'Batch supported',
    'Calibration available',
    'Not previously read',
    'Within validity period',
    'QR integrity',
  ];
}

@immutable
final class BadgeCheck {
  const BadgeCheck({required this.label, required this.passed, this.detail});

  final String label;
  final bool passed;
  final String? detail;
}

/// A declared scan outcome. Deliberately mirrors the shape of
/// [MeasurementResult] so the mapping in `simulation.dart` is total and
/// obvious, but carries no calibration mathematics.
sealed class SpecimenOutcome {
  const SpecimenOutcome();
}

final class ValidOutcome extends SpecimenOutcome {
  const ValidOutcome({
    required this.dosePpmHours,
    required this.uncertaintyHalfWidth,
    required this.uncertaintyBasis,
    this.warning,
  });

  final double dosePpmHours;
  final double uncertaintyHalfWidth;
  final String uncertaintyBasis;

  /// When present, the result is Valid-with-a-caveat rather than plain Valid.
  final String? warning;
}

final class CensoredOutcome extends SpecimenOutcome {
  const CensoredOutcome({
    required this.status,
    required this.direction,
    this.boundPpmHours,
  });

  final ResultStatus status;
  final CensorDirection direction;
  final double? boundPpmHours;
}

final class RefusedOutcome extends SpecimenOutcome {
  const RefusedOutcome({required this.status, required this.reason});

  final ResultStatus status;
  final ReasonCode reason;
}
