import 'package:flutter/foundation.dart';

/// A cumulative exposure figure shown in the Reporting surfaces.
///
/// ## Why this type exists at all
///
/// Until this phase, no number resembling a dose appeared anywhere in the
/// product, because none could be earned: there is no production H₂S
/// calibration. Reporting needs *some* quantitative example to show what a
/// register, a summary and an audit package will look like — otherwise the
/// most important screens in the product cannot be reviewed.
///
/// So the type is deliberately lopsided. There is exactly one constructor,
/// [SimulatedExposure.ppmHours], and it produces a value that is **always**
/// marked simulated. There is no `SimulatedExposure.measured`, no `.real`, no
/// flag to flip. A production reading will not use this class at all — it will
/// carry the measurement package's `Dose`, which is a different type with
/// different rules.
///
/// That asymmetry is the point. When calibration arrives, the compiler will
/// not let a real result quietly inherit the simulated presentation, and a
/// reviewer looking at a register today cannot mistake these figures for
/// measurements.
@immutable
final class SimulatedExposure {
  /// The only way to obtain one.
  const SimulatedExposure.ppmHours(this.value)
    : assert(value >= 0, 'exposure cannot be negative');

  final double value;

  static const String unit = 'ppm·h';

  /// Always true. Present so call sites read as a question about the value
  /// rather than as knowledge about the type, and so the rendering path is
  /// the same one a future real/simulated split would use.
  bool get isSimulated => true;

  @override
  bool operator ==(Object other) =>
      other is SimulatedExposure && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// What a reporting record's measurement actually is.
///
/// ## The rule this enum enforces
///
/// A record either carries a simulated quantity or it carries a **state**.
/// There is no third option where a state gets coerced into `0` so a table,
/// a chart or an export has something numeric to put in a cell.
///
/// These are all distinct, and none of them is zero exposure:
///
/// * `noReading` — the measurement was refused; the exposure is unknown.
/// * `belowQuantificationLimit` — there was exposure, below what the method
///   can quantify. Not zero, and not nothing.
/// * `aboveValidatedRange` — above what the calibration was validated for.
///   The reading exists; the model does not cover it.
/// * `saturated` — the chemistry itself has stopped responding. **Not the
///   same as above-range**: one is a limit of the model, the other a limit of
///   the sensor, and conflating them would hide which.
/// * `partialMonitoring` — the badge covered only part of the intended
///   period. The number, if any, describes less than was asked for.
/// * `unsupportedCalibration` — no model applies to that batch at all.
enum ReportedMeasurement {
  simulatedValid('Valid', true),
  simulatedValidWithWarning('Valid, with a caveat', true),
  belowQuantificationLimit('Below quantification limit', false),
  aboveValidatedRange('Above validated range', false),
  saturated('Saturated', false),
  partialMonitoring('Partial monitoring', false),
  unsupportedCalibration('Unsupported calibration', false),
  noReading('No valid reading', false);

  const ReportedMeasurement(this.label, this.carriesQuantity);

  final String label;

  /// Whether a record in this state may carry a figure at all.
  ///
  /// Only the two simulated-valid states may. Everything else has no number,
  /// and asking for one is a bug rather than a formatting problem.
  final bool carriesQuantity;

  /// Whether this state means the measurement could not be produced.
  bool get isRefusal => this == ReportedMeasurement.noReading;

  /// Whether the true value lies outside what can be quantified, rather than
  /// the measurement having failed.
  bool get isCensored =>
      this == ReportedMeasurement.belowQuantificationLimit ||
      this == ReportedMeasurement.aboveValidatedRange ||
      this == ReportedMeasurement.saturated;
}

/// How a record's measurement should be rendered, resolved once.
///
/// Every table cell, card, summary and preview row goes through this, so a
/// state cannot be formatted one way in the register and another in a chart.
@immutable
final class MeasurementCell {
  const MeasurementCell._({
    required this.text,
    required this.isSimulatedQuantity,
    required this.stateLabel,
  });

  /// Builds the cell for a record.
  ///
  /// Throws if a record claims a quantity its state is not entitled to. That
  /// is deliberate: silently dropping the figure would hide a data defect,
  /// and silently showing it would publish a number the state says does not
  /// exist.
  factory MeasurementCell.of(
    ReportedMeasurement state,
    SimulatedExposure? exposure, {
    required String absentPlaceholder,
  }) {
    if (exposure != null && !state.carriesQuantity) {
      throw ArgumentError(
        'A record in state ${state.name} carries a quantity. Only the '
        'simulated-valid states may. Fix the record, not the formatter.',
      );
    }

    if (exposure == null) {
      return MeasurementCell._(
        text: absentPlaceholder,
        isSimulatedQuantity: false,
        stateLabel: state.label,
      );
    }

    return MeasurementCell._(
      text: '${exposure.value.toStringAsFixed(1)} ${SimulatedExposure.unit}',
      isSimulatedQuantity: true,
      stateLabel: state.label,
    );
  }

  /// The figure, or the absent placeholder. **Never `0`** for an absent
  /// value — zero is a measurement, absence is not.
  final String text;

  /// Whether [text] holds a simulated figure. When true, the caller must
  /// render the simulated marker beside it; a widget test asserts this.
  final bool isSimulatedQuantity;

  final String stateLabel;
}
