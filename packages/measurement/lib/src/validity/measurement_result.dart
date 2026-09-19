import 'package:meta/meta.dart';

import 'result_status.dart';

/// Cumulative external H2S exposure: concentration integrated over time.
///
/// Not absorbed dose. Not a health outcome. Not a probability of harm.
@immutable
final class Dose {
  const Dose.ppmHours(this.value)
    : assert(value >= 0, 'dose cannot be negative');

  final double value;

  static const String unit = 'ppm·h';

  @override
  String toString() => '$value $unit';

  @override
  bool operator ==(Object other) => other is Dose && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// An uncertainty interval and, crucially, the basis on which it is claimed.
///
/// The dossier is explicit: do not label an interval 95% unless independent
/// data support that coverage. [basis] is required so that a coverage claim
/// cannot be made by omission.
@immutable
final class Uncertainty {
  const Uncertainty({required this.halfWidth, required this.basis});

  final double halfWidth;

  /// Free text describing where this interval comes from, carried from the
  /// calibration model. Never synthesised at the call site.
  final String basis;
}

@immutable
final class ReasonCode {
  const ReasonCode(this.code, {this.detail});

  final String code;
  final String? detail;

  @override
  String toString() => detail == null ? code : '$code ($detail)';
}

/// Which versions produced this result. Directive section 15: every
/// measurement must be reproducible.
@immutable
final class Provenance {
  const Provenance({
    required this.algorithmVersion,
    required this.geometryVersion,
    required this.calibrationModelId,
    required this.referenceProfileId,
    required this.appVersion,
    required this.deviceModel,
  });

  final String algorithmVersion;
  final String geometryVersion;

  /// Null whenever no calibration model was applied — which is every status
  /// that does not carry a dose.
  final String? calibrationModelId;
  final String? referenceProfileId;
  final String appVersion;
  final String deviceModel;
}

/// The outcome of a scan.
///
/// This type is the reason "convert a failure into 0 ppm·h" cannot be written:
/// [Refused] and [Censored] have no field to put a dose in. The database
/// mirrors this with the `dose_only_when_valid` CHECK constraint.
@immutable
sealed class MeasurementResult {
  const MeasurementResult({required this.reasons, required this.provenance});

  ResultStatus get status;

  /// Why this result is what it is. Never empty for a non-valid status: the
  /// user is owed an explanation, and directive section 30 requires it to say
  /// what happened, why it matters and what to do next.
  final List<ReasonCode> reasons;

  final Provenance provenance;
}

final class Valid extends MeasurementResult {
  Valid({
    required this.dose,
    required this.uncertainty,
    required this.coverage,
    required super.provenance,
    List<ReasonCode> warnings = const [],
  }) : _warnings = warnings,
       assert(
         // A dose without a model behind it is not a measurement.
         provenance.calibrationModelId != null,
         'a valid result requires the calibration model that produced it',
       ),
       super(reasons: warnings);

  final Dose dose;
  final Uncertainty uncertainty;

  /// The exposure window this dose actually covers. Never extrapolated to a
  /// full shift, and never normalised to an 8-hour TWA here.
  final Duration coverage;

  final List<ReasonCode> _warnings;

  @override
  ResultStatus get status =>
      _warnings.isEmpty ? ResultStatus.valid : ResultStatus.validWithWarning;
}

enum CensorDirection { below, above }

/// The true value is outside the quantifiable interval.
///
/// [bound] is the defensible one-sided bound where the calibration supports
/// one — the dossier requires that an above-range result retain a lower bound
/// rather than discard the information entirely.
final class Censored extends MeasurementResult {
  Censored({
    required this.status,
    required this.direction,
    required super.reasons,
    required super.provenance,
    this.bound,
  }) : assert(reasons.isNotEmpty, 'a censored result must explain itself'),
       assert(status.isCensored, 'Censored may only carry a censored status');

  @override
  final ResultStatus status;

  final CensorDirection direction;
  final Dose? bound;
}

/// No number may be reported. There is no dose field, by design.
final class Refused extends MeasurementResult {
  Refused({
    required this.status,
    required super.reasons,
    required super.provenance,
  }) : assert(reasons.isNotEmpty, 'a refusal must explain itself'),
       assert(status.isRefusal, 'Refused may only carry a refusal status');

  @override
  final ResultStatus status;
}
