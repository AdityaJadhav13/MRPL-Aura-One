import 'package:measurement/measurement.dart';

import '../../../core/util/format.dart';

/// Measurement-state words for lists, registers and exports (§24, §61).
///
/// One vocabulary for every non-visual surface, so a CSV, a register row and
/// a supervisor's exception list cannot disagree about what a record says.
/// Every non-valued state is a **word**, never a number: nothing in this file
/// can produce "0".
abstract final class MeasurementStateText {
  static String label(ResultStatus s) => switch (s) {
    ResultStatus.valid => 'Valid',
    ResultStatus.validWithWarning => 'Valid with warning',
    ResultStatus.belowQuantificationLimit => 'Below Quantification',
    ResultStatus.aboveRange => 'Above Range',
    ResultStatus.saturated => 'Saturated',
    ResultStatus.poorImage => 'No Reading — poor image',
    ResultStatus.badgeExpired => 'No Reading — DoseBand expired',
    ResultStatus.badgeDamaged => 'No Reading — DoseBand damaged',
    ResultStatus.badgeAlreadyUsed => 'No Reading — DoseBand already used',
    ResultStatus.unsupportedBatch => 'No Reading — unsupported lot',
    ResultStatus.unsupportedCalibration => 'No Reading — no calibration',
    ResultStatus.referencePatchFailure => 'No Reading — reference failure',
    ResultStatus.blankFailure => 'No Reading — blank failure',
    ResultStatus.sensorBlankDisagreement =>
      'No Reading — sensor/blank disagreement',
    ResultStatus.partialShift => 'No Reading — partial coverage',
    ResultStatus.environmentOutsideValidatedRange =>
      'No Reading — outside validated conditions',
    ResultStatus.contaminationSuspected =>
      'No Reading — contamination suspected',
    ResultStatus.resultUnreliable => 'No Reading — result unreliable',
  };

  /// The exposure cell of a register or export.
  ///
  /// * Valid: the calibrated cumulative exposure in ppm·h.
  /// * Censored: the state, with the calibrated bound where one exists —
  ///   never an invented exact value.
  /// * Refusal: "No Reading" and why.
  static String exposureCell(MeasurementResult r) => switch (r) {
    Valid(:final dose) => '${Fmt.dose(dose.value)} ppm·h',
    Censored(:final status, :final bound) => switch (status) {
      ResultStatus.belowQuantificationLimit =>
        bound == null
            ? 'Below Quantification'
            : 'Below Quantification (< ${Fmt.dose(bound.value)} ppm·h)',
      ResultStatus.aboveRange =>
        bound == null
            ? 'Above Range'
            : 'Above Range (> ${Fmt.dose(bound.value)} ppm·h)',
      _ => label(status),
    },
    Refused(:final status) => label(status),
  };

  /// Whether the record needs a person to look at it for a reason other than
  /// routine review: anything that is not a value.
  static bool isException(MeasurementResult r) => r is! Valid;

  /// Whether taking another photograph of the same band could change the
  /// outcome. A missing calibration, an expired band or an untrusted window
  /// cannot be fixed by a better picture (§26).
  static bool retakeCouldHelp(MeasurementResult r) {
    if (r is! Refused) return false;
    return switch (r.status) {
      ResultStatus.poorImage || ResultStatus.referencePatchFailure => true,
      _ => false,
    };
  }
}
