import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

import '../../core/util/format.dart';

/// Everything a screen needs to render a [MeasurementResult] through the shared
/// `ResultCard`, plus the what/why/what-to-do copy for every non-plain-valid
/// state.
///
/// The refusal copy lives here, in one exhaustive switch, so the Phase 2 gate —
/// "every refusal state reachable and explained" — is satisfied by construction
/// rather than screen by screen. The `MeasurementReadout` renders `- - -` for a
/// refusal because [value] is null; a refusal never carries a number.
@immutable
final class ResultView {
  const ResultView({
    required this.value,
    required this.prefix,
    required this.uncertainty,
    required this.loq,
    required this.saturation,
    required this.copy,
  });

  final String? value;
  final String? prefix;
  final String? uncertainty;
  final double loq;
  final double saturation;

  /// Null for a plain valid result; present for everything else.
  final ResultCopy? copy;

  // Simulated calibration bounds. Real bounds come from a signed calibration
  // model in Phase 5+; these exist only so the scale can draw its limits in the
  // simulated domain.
  static const double _simLoq = 0.5;
  static const double _simSaturation = 40;

  factory ResultView.of(MeasurementResult result) {
    switch (result) {
      case Valid(:final dose, :final uncertainty, :final status):
        return ResultView(
          value: Fmt.dose(dose.value),
          prefix: null,
          // Without the sign — MeasurementReadout supplies the ± itself.
          uncertainty: Fmt.dose(uncertainty.halfWidth),
          loq: _simLoq,
          saturation: _simSaturation,
          copy: status == ResultStatus.validWithWarning
              ? const ResultCopy(
                  whatHappened: 'The reading is usable, with a caveat.',
                  whyItMatters:
                      'The badge covered less than the assigned monitored '
                      'period, so the true exposure may be higher than shown.',
                  whatToDo:
                      'Record the reading and tell your supervisor the badge '
                      'was not worn for the full period.',
                )
              : null,
        );
      case Censored(:final direction, :final bound):
        final isAbove = direction == CensorDirection.above;
        return ResultView(
          value: bound == null ? null : Fmt.dose(bound.value),
          prefix: isAbove ? '>' : '<',
          uncertainty: null,
          loq: _simLoq,
          saturation: _simSaturation,
          copy: isAbove
              ? const ResultCopy(
                  whatHappened:
                      'The sensing response exceeded the validated range.',
                  whyItMatters:
                      'The exact cumulative exposure cannot be determined from '
                      'this badge — only that it is at least the lower bound '
                      'shown.',
                  whatToDo:
                      'Report to your safety officer and fit a new badge.',
                )
              : const ResultCopy(
                  whatHappened:
                      'The badge response is below the measurable range.',
                  whyItMatters:
                      'A cumulative exposure this low cannot be quantified — '
                      'this is not a reading of zero.',
                  whatToDo:
                      'No action needed. Keep the record and fit a new badge '
                      'for the next period.',
                ),
        );
      case Refused(:final status, :final reasons):
        final detail = reasons.isEmpty ? null : reasons.first.detail;
        final code = reasons.isEmpty ? null : reasons.first.code;
        return ResultView(
          value: null,
          prefix: null,
          uncertainty: null,
          loq: _simLoq,
          saturation: _simSaturation,
          copy: refusalCopy(status, detail: detail, reasonCode: code),
        );
    }
  }
}

@immutable
final class ResultCopy {
  const ResultCopy({
    required this.whatHappened,
    required this.whyItMatters,
    required this.whatToDo,
  });

  final String whatHappened;
  final String whyItMatters;
  final String whatToDo;
}

/// What happened · why it matters · what to do, for every refusal status.
///
/// Exhaustive over [ResultStatus] so a new status cannot be added without its
/// copy. Censored and valid statuses are handled at the call site above; they
/// return a generic entry here only to keep the switch total.
ResultCopy refusalCopy(
  ResultStatus status, {
  String? detail,
  String? reasonCode,
}) {
  // A clock that moved is not a bad photograph, and telling the worker to
  // scan again would send them round a loop that cannot succeed: the exposure
  // window is unrecoverable regardless of how good the next image is.
  if (reasonCode == 'EXPOSURE_WINDOW_UNTRUSTED') {
    return const ResultCopy(
      whatHappened:
          'The monitored period could not be timed. The device clock moved '
          'while the badge was being worn.',
      whyItMatters:
          'Exposure is a concentration multiplied by a duration. Without a '
          'duration there is no exposure to report, and scanning again will '
          'not recover it.',
      whatToDo:
          'Report this period to your safety officer with the badge. The '
          'badge itself still holds what it absorbed.',
    );
  }

  return switch (status) {
    ResultStatus.poorImage => const ResultCopy(
      whatHappened: 'The image quality was not good enough to measure.',
      whyItMatters:
          'A blurred or poorly lit badge cannot be read reliably, and a wrong '
          'number is worse than none.',
      whatToDo: 'Steady the phone, improve the lighting and scan again.',
    ),
    ResultStatus.referencePatchFailure => ResultCopy(
      whatHappened: 'The reference patches could not be read.',
      whyItMatters:
          'Without the references the badge colour cannot be corrected, so no '
          'reading can be trusted.${detail == 'glare' ? ' Glare is covering the badge.' : ''}',
      whatToDo: 'Tilt the badge away from the light and scan again.',
    ),
    ResultStatus.blankFailure => const ResultCopy(
      whatHappened: 'The unreacted blank region could not be read.',
      whyItMatters:
          'The blank is the baseline the reading is measured against; without '
          'it there is nothing to compare to.',
      whatToDo: 'Scan again with the whole badge in frame.',
    ),
    ResultStatus.sensorBlankDisagreement => const ResultCopy(
      whatHappened: 'The sensor and blank regions disagree.',
      whyItMatters:
          'This points to contamination or damage, so the reading cannot be '
          'relied on.',
      whatToDo: 'Fit a new badge and report this one to your safety officer.',
    ),
    ResultStatus.badgeExpired => const ResultCopy(
      whatHappened: 'This badge is past its validity date.',
      whyItMatters:
          'An expired badge may have reacted with air over time, so any '
          'reading would be misleading.',
      whatToDo: 'Fit a new badge before starting a monitored period.',
    ),
    ResultStatus.badgeDamaged => const ResultCopy(
      whatHappened: 'The badge is physically damaged.',
      whyItMatters:
          'A torn or marked sensor window cannot be measured correctly.',
      whatToDo: 'Fit a new badge and report the damaged one.',
    ),
    ResultStatus.badgeAlreadyUsed => const ResultCopy(
      whatHappened: 'This badge has already been read.',
      whyItMatters:
          'A badge is measured once; a second reading would not reflect a new '
          'period.',
      whatToDo: 'Fit a new badge for this period.',
    ),
    ResultStatus.unsupportedBatch => const ResultCopy(
      whatHappened: 'This badge batch is not supported.',
      whyItMatters:
          'There is no calibration for this batch, so its colour cannot be '
          'turned into an exposure.',
      whatToDo: 'Use a badge from a supported batch and report this one.',
    ),
    ResultStatus.unsupportedCalibration => const ResultCopy(
      whatHappened: 'No calibration is available for this badge.',
      whyItMatters:
          'A reading without a calibration behind it is not a measurement.',
      whatToDo: 'Report to your safety officer; do not rely on this badge.',
    ),
    ResultStatus.partialShift => const ResultCopy(
      whatHappened: 'The badge covered only part of the period.',
      whyItMatters:
          'The exposure outside the covered window is unknown, so a full-shift '
          'figure cannot be given.',
      whatToDo: 'Record the covered time and tell your supervisor.',
    ),
    ResultStatus.environmentOutsideValidatedRange => const ResultCopy(
      whatHappened: 'Conditions were outside the tested range.',
      whyItMatters:
          'The badge has not been validated for these conditions, so a reading '
          'could be wrong in an unknown direction.',
      whatToDo: 'Report to your safety officer; do not rely on this badge.',
    ),
    ResultStatus.contaminationSuspected => const ResultCopy(
      whatHappened: 'Contamination is suspected on the badge.',
      whyItMatters:
          'Something other than H₂S may have reacted with the sensor, so the '
          'reading cannot be trusted.',
      whatToDo: 'Fit a new badge and report this one.',
    ),
    ResultStatus.resultUnreliable => const ResultCopy(
      whatHappened: 'The result did not pass the reliability checks.',
      whyItMatters: 'A reading that fails its own checks must not be reported.',
      whatToDo: 'Scan again; if it fails again, report to your safety officer.',
    ),
    // Handled at the call site; kept for exhaustiveness.
    ResultStatus.valid ||
    ResultStatus.validWithWarning ||
    ResultStatus.belowQuantificationLimit ||
    ResultStatus.aboveRange ||
    ResultStatus.saturated => const ResultCopy(
      whatHappened: 'See the reading above.',
      whyItMatters: '',
      whatToDo: '',
    ),
  };
}
