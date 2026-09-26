import 'package:flutter/material.dart';

import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/util/format.dart';
import '../../domain/simulated_exposure.dart';

/// The one place a measurement is turned into something on screen.
///
/// ## Why every surface goes through this
///
/// A register cell, a summary row, a chart label and a report preview all
/// have to answer the same question — what does this record's measurement
/// say? If each answers it separately, one of them eventually prints `0` for
/// a state that has no number, and that is the single defect this product
/// most needs to avoid.
///
/// So: `MeasurementCell` resolves the text, this widget renders it, and both
/// refuse to invent a figure. When a quantity is present it is a
/// [SimulatedExposure] and the simulated marker is rendered **beside the
/// number**, not in a legend somewhere — a marker that can be scrolled away
/// from the value it qualifies is not a marker.
class ExposureCell extends StatelessWidget {
  const ExposureCell({
    required this.measurement,
    required this.exposure,
    this.compact = false,
    super.key,
  });

  final ReportedMeasurement measurement;
  final SimulatedExposure? exposure;

  /// Drops the state line, for dense table rows where the state has its own
  /// column.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final c = context.colours;
    final t = context.type;

    final cell = MeasurementCell.of(
      measurement,
      exposure,
      absentPlaceholder: Fmt.noValue,
    );

    return Semantics(
      label: cell.isSimulatedQuantity
          ? 'Simulated exposure ${cell.text}. ${cell.stateLabel}. '
                'Not a measurement — no production calibration exists.'
          : '${cell.text}. ${cell.stateLabel}. No exposure figure is '
                'available, which does not mean the exposure was zero.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  cell.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.readoutSmall.copyWith(
                    color: cell.isSimulatedQuantity
                        ? corporate.textPrimary
                        : corporate.textSecondary,
                  ),
                ),
              ),
              if (cell.isSimulatedQuantity) ...[
                const SizedBox(width: Space.xs),
                // Magenta is reserved for simulated measurements throughout
                // this product. It travels with the number.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: c.statusSimulated.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: c.statusSimulated.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    'SIMULATED',
                    style: t.caption.copyWith(
                      color: c.statusSimulated,
                      fontSize: 8.5,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 1),
            Text(
              cell.stateLabel,
              style: t.caption.copyWith(
                color: corporate.textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The standing note that no production calibration exists.
///
/// Shown once per Reporting screen that displays any quantity. The per-value
/// marker says *this figure is simulated*; this says *and no real figure
/// could exist yet*. Both are needed — a reviewer who sees only the marker
/// may reasonably assume the maths behind it is finished and merely the data
/// is sample.
class NoProductionCalibrationBanner extends StatelessWidget {
  const NoProductionCalibrationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final c = context.colours;
    final t = context.type;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.statusSimulated.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        border: Border.all(color: c.statusSimulated.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 18, color: c.statusSimulated),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Exposure figures are simulated',
                    style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No production H₂S calibration exists, so DoseBand cannot '
                  'yet produce a quantitative exposure from a real badge. '
                  'The figures here illustrate the report layout and are not '
                  'measurements.',
                  style: t.caption.copyWith(color: corporate.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The standing note that an absent figure is not zero.
class NoReadingIsNotZeroNote extends StatelessWidget {
  const NoReadingIsNotZeroNote({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        border: Border.all(color: corporate.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 17, color: corporate.textSecondary),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              '${Fmt.noValue} means no exposure figure is available. It does '
              'not mean the exposure was zero, and these records are not '
              'counted as zero in any total or average.',
              style: t.caption.copyWith(color: corporate.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
