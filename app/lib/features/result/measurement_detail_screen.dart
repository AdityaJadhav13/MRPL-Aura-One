import 'package:flutter/material.dart';
import 'package:measurement/measurement.dart';

import '../../core/components/markers.dart';
import '../../core/components/surfaces.dart';
import '../../core/design/status_presentation.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/format.dart';
import '../history/domain/measurement_record.dart';

/// Measurement details.
///
/// Full traceability without overwhelming an ordinary worker: grouped sections,
/// measured/traceable values in mono. Every field an audit record would carry is
/// here, so a result is reproducible (directive §15/§20).
class MeasurementDetailScreen extends StatelessWidget {
  const MeasurementDetailScreen({required this.record, super.key});

  final MeasurementRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final result = record.result;
    final p = result.provenance;
    final presentation = StatusPresentation.of(result.status, c);

    final resultRows = <String, String>{'Result': presentation.label};
    if (result case Valid(:final dose, :final uncertainty, :final coverage)) {
      resultRows['Estimated dose'] = '${Fmt.dose(dose.value)} ${Dose.unit}';
      resultRows['Uncertainty'] = '± ${Fmt.dose(uncertainty.halfWidth)}';
      resultRows['Uncertainty basis'] = uncertainty.basis;
      resultRows['Covered'] = Fmt.duration(coverage);
    } else if (result case Censored(:final bound, :final direction)) {
      if (bound != null) {
        final prefix = direction == CensorDirection.above ? '≥' : '≤';
        resultRows['Bound'] = '$prefix ${Fmt.dose(bound.value)} ${Dose.unit}';
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Measurement details')),
      body: Column(
        children: [
          // Only for simulated data. A real scan's details were shown under
          // this marker unconditionally.
          if (record.domain == DataDomain.simulated && !record.isPresentation)
            const SimulationMarker(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Space.base),
              children: [
                _Section(title: 'Result', rows: resultRows),
                _Section(
                  title: 'Session',
                  rows: {
                    'Started': Fmt.stamp(record.startedAt),
                    'Ended': Fmt.stamp(record.endedAt),
                    'Scanned': Fmt.stamp(record.scannedAt),
                    'Coverage': Fmt.duration(record.coverage),
                  },
                ),
                _Section(
                  title: 'Work context',
                  rows: {
                    'Worker': record.context.worker.displayName,
                    'Site': record.context.site.name,
                    'Work area': record.context.workArea.name,
                    'Shift': record.context.shift.name,
                    'Job': record.context.job.title,
                    // Provenance travels with the reference even in a plain
                    // traceability table: a permit number shown bare, months
                    // later, is a number nobody can weigh.
                    'PTW reference':
                        '${record.context.permit.reference.value} '
                        '[${record.context.permit.reference.source.label}]',
                    'JSA reference':
                        '${record.context.jsa.reference.value} '
                        '[${record.context.jsa.reference.source.label}]',
                  },
                ),
                _Section(
                  title: 'Badge',
                  rows: {
                    'Badge': record.badge.badgeId,
                    'Identity': record.badge.identityProvenance,
                    'Lot': record.badge.batch ?? Fmt.noValue,
                    'Formulation': record.badge.formulation ?? Fmt.noValue,
                    // A physical badge typed by hand has no printed-expiry
                    // record; absence is shown as absence, never as a date.
                    'Expiry': record.badge.expiry == null
                        ? Fmt.noValue
                        : Fmt.date(record.badge.expiry!),
                  },
                ),
                _Section(
                  title: 'Calibration & version',
                  rows: {
                    'Calibration model': p.calibrationModelId ?? '— (no dose)',
                    'Reference profile': p.referenceProfileId ?? '—',
                    'Geometry': p.geometryVersion,
                    'Algorithm': p.algorithmVersion,
                    'App version': p.appVersion,
                    'Device': p.deviceModel,
                  },
                ),
                _Section(
                  title: 'Data domain',
                  rows: {
                    'Domain': record.domain.disclosure,
                    'Origin': record.isPresentation
                        ? 'Presentation — not a validated measurement; kept '
                              'out of registers, statistics and reports'
                        : 'Measured',
                    if (record.originNote != null)
                      'Origin detail': record.originNote!,
                    'Photograph': record.captureId ?? 'None — simulated',
                  },
                ),
                const SizedBox(height: Space.base),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm, left: Space.xs),
            child: Text(
              title,
              style: context.type.label.copyWith(color: c.textSecondary),
            ),
          ),
          DoseBandSurface(
            child: Column(
              children: [
                for (final e in rows.entries)
                  TraceabilityRow(label: e.key, value: e.value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
