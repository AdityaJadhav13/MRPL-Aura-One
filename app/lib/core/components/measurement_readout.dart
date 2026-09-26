import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../util/format.dart';

/// The hero readout.
///
/// When there is no value, this widget renders an em-dash placeholder in the
/// slot where the digits would have been — it does **not** hide itself and it
/// does **not** print a zero. A worker who sees `——` knows something is
/// missing. A worker who sees `0.0` does not.
class MeasurementReadout extends StatelessWidget {
  const MeasurementReadout({
    required this.unit,
    this.value,
    this.prefix,
    this.uncertainty,
    this.colour,
    super.key,
  });

  /// The formatted value, or null for the no-reading state.
  final String? value;

  /// A comparison prefix such as `>` for an above-range bound.
  final String? prefix;

  /// Formatted uncertainty, without the +/- sign.
  final String? uncertainty;

  final String unit;
  final Color? colour;

  /// The empty-slot placeholder.
  ///
  /// Separated hyphens, not em dashes: at hero size an em dash fills its whole
  /// monospace cell, so consecutive ones tile into one solid bar that reads as
  /// a redaction or a progress bar. Separated short dashes are also what a
  /// balance or a multimeter shows when it has no value, so the meaning is
  /// already familiar to anyone who has used one.
  static const String noReading = Fmt.noValue;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final hasValue = value != null;
    final ink = colour ?? c.textPrimary;

    return Semantics(
      label: hasValue
          ? '${prefix ?? ''} $value $unit'
                '${uncertainty != null ? ', plus or minus $uncertainty' : ''}'
          : 'No reading. $unit.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wraps rather than truncating at large text scales.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: Space.sm,
            children: [
              Text(
                '${prefix != null ? '$prefix ' : ''}${value ?? noReading}',
                style: t.readoutHero.copyWith(
                  color: hasValue ? ink : c.textDisabled,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Text(
                  unit,
                  style: t.label.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
          if (uncertainty != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                '± $uncertainty',
                style: t.readoutLarge.copyWith(color: c.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
