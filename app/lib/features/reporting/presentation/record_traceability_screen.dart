import 'package:flutter/material.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';
import '../data/reporting_demo_catalog.dart';
import '../domain/simulated_exposure.dart';
import 'widgets/exposure_cell.dart';

/// One occupational record, end to end.
///
/// ## The phase's exit criterion
///
/// A reviewer must be able to start at a name and follow the whole chain:
/// worker → shift → work area → job → PTW/JSA → badge → monitoring window →
/// badge read → measurement or refusal → validity → calibration version →
/// HSE review → disposition → audit.
///
/// The sections below are that chain, in that order, with nothing between
/// them. Where a link is missing the screen says so rather than skipping it,
/// because a gap a reviewer cannot see is a gap they will assume is filled.
///
/// This screen is **read-only**. Reporting consumes records; the HSE module
/// owns review and disposition, and offering a second disposition control
/// here would create two places where a record's state can diverge.
class RecordTraceabilityScreen extends StatelessWidget {
  const RecordTraceabilityScreen({required this.record, super.key});

  final OccupationalRecord record;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final w = record.worker;

    return SafetyScaffold(
      title: 'Exposure record',
      subtitle: record.recordId,
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.sm),
        const NoProductionCalibrationBanner(),
        const SizedBox(height: Space.base),

        _Step(
          index: 1,
          title: 'Worker',
          rows: [
            ('Name', w.name, false),
            ('Worker ID', w.workerId, true),
            ('Employment', w.typeLabel, false),
            if (w.contractorCompany case final company?)
              ('Contractor', company, false),
            ('Department', w.department, false),
          ],
        ),
        _Step(
          index: 2,
          title: 'Shift',
          rows: [
            ('Shift', w.shift, false),
            ('Date', Fmt.date(record.startedAt), false),
          ],
        ),
        _Step(
          index: 3,
          title: 'Work area',
          rows: [
            ('Site', 'Mangalore Refinery', false),
            ('Work area', w.workArea, false),
          ],
        ),
        _Step(index: 4, title: 'Job', rows: [('Activity', record.job, false)]),
        _Step(
          index: 5,
          title: 'Permit and JSA',
          rows: [
            ('PTW reference', record.permitReference, true),
            ('JSA reference', record.jsaReference, true),
          ],
          // These are references to someone else's process. The register
          // records which ones a reading sat beside; it confirms nothing.
          note:
              'References recorded by the worker. DoseBand does not verify '
              'a permit or a JSA against any system.',
          origin: DataOrigin.uiDemo,
        ),
        _Step(
          index: 6,
          title: 'Badge',
          rows: [
            ('Badge ID', record.badgeId, true),
            ('Batch', record.batchId, true),
            ('Formulation', 'Bi-based colorimetric (sim)', false),
            ('Geometry', 'badge-v1-research', true),
          ],
        ),
        _Step(
          index: 7,
          title: 'Monitoring window',
          rows: [
            ('Started', Fmt.stamp(record.startedAt), true),
            ('Ended', Fmt.stamp(record.endedAt), true),
            ('Covered', Fmt.duration(record.coverage), true),
            (
              'Completeness',
              record.monitoringComplete ? 'Complete' : 'Partial',
              false,
            ),
            (
              'Clock',
              record.clockTrusted ? 'Trusted' : 'Not trustworthy',
              false,
            ),
          ],
          note: record.clockTrusted
              ? null
              : 'The device clock moved during this period, so its duration '
                    'cannot be established. The window is reported as '
                    'unknown rather than computed.',
        ),
        _Step(
          index: 8,
          title: 'Badge read',
          rows: [('Read at', Fmt.stamp(record.endedAt), true)],
        ),

        // --- the measurement, with its own treatment ----------------------
        const SectionHeader(title: 'Measurement'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated cumulative external H₂S exposure',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
              const SizedBox(height: Space.xs),
              ExposureCell(
                measurement: record.measurement,
                exposure: record.exposure,
              ),
              const SizedBox(height: Space.sm),
              if (record.warning case final warning?)
                RecordRow(label: 'Caveat', value: warning),
              if (record.refusalReason case final reason?)
                RecordRow(label: 'Reason', value: reason),
              const SizedBox(height: Space.xs),
              Text(
                _measurementNote(record.measurement),
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        _Step(
          index: 10,
          title: 'Validity and quality',
          rows: const [
            ('Image quality', 'Not recorded', false),
            ('Reference patches', 'Not recorded', false),
            ('Blank region', 'Not recorded', false),
            ('Environment', 'Not recorded', false),
          ],
          note:
              'This prototype does not retain capture quality evidence per '
              'record. "Not recorded" is not the same as "passed".',
        ),
        _Step(
          index: 11,
          title: 'Calibration and software',
          rows: [
            for (final entry in record.versions.entries)
              (entry.key, entry.value, true),
          ],
          note:
              'A record keeps the versions that produced it. A future '
              'recalibration supersedes for new readings and never restates '
              'this one.',
        ),
        _Step(
          index: 12,
          title: 'HSE review',
          rows: [
            ('Review state', record.reviewState.label, false),
            ('Disposition', record.disposition ?? 'Not yet recorded', false),
            ('Reviewer', record.reviewer ?? Fmt.noValue, true),
            (
              'Reviewed at',
              record.reviewedAt == null
                  ? Fmt.noValue
                  : Fmt.stamp(record.reviewedAt!),
              true,
            ),
          ],
          note:
              'Review and disposition belong to the HSE module. This report '
              'shows them; it does not change them.',
        ),
        _Step(
          index: 13,
          title: 'Audit',
          rows: [
            ('Created', Fmt.stamp(record.endedAt), true),
            ('Modified', 'Never', false),
            ('Recalculated', 'Never', false),
            ('Superseded by', 'Not superseded', false),
            ('Exported', 'Never — no exporter exists', false),
            ('Signature', 'Not applicable', false),
          ],
        ),

        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'This record is read-only here. Reporting queries and organises '
            'records; it does not rewrite a measurement, a monitoring window '
            'or an HSE decision.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }

  /// What each state means, in the one place a reviewer will look for it.
  static String _measurementNote(ReportedMeasurement m) => switch (m) {
    ReportedMeasurement.simulatedValid ||
    ReportedMeasurement.simulatedValidWithWarning =>
      'A simulated figure. No production calibration exists, so a real badge '
          'read through this application would report that the badge was '
          'read and that the quantity is unavailable.',
    ReportedMeasurement.belowQuantificationLimit =>
      'There was exposure, below what the method can quantify. This is not '
          'an exposure of zero.',
    ReportedMeasurement.aboveValidatedRange =>
      'The reading is above the interval the calibration was validated for. '
          'The measurement succeeded; the model does not cover it. This is '
          'not the same as saturation.',
    ReportedMeasurement.saturated =>
      'The sensor chemistry stopped responding, so the true value cannot be '
          'recovered from it. This is a limit of the badge, not of the '
          'model.',
    ReportedMeasurement.partialMonitoring =>
      'The badge covered only part of the intended period. No figure is '
          'reported, and none has been scaled up to a full period.',
    ReportedMeasurement.unsupportedCalibration =>
      'No calibration model applies to this batch, so no quantity can be '
          'produced from it.',
    ReportedMeasurement.noReading =>
      'No number may be reported for this record. The exposure over this '
          'period is unknown, which is not the same as zero.',
  };
}

/// One link in the traceability chain.
class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.title,
    required this.rows,
    this.note,
    this.origin,
  });

  final int index;
  final String title;

  /// (label, value, monospace)
  final List<(String, String, bool)> rows;

  final String? note;
  final DataOrigin? origin;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: corporate.primaryMuted,
                    borderRadius: BorderRadius.circular(CorporateRadii.sm),
                  ),
                  child: Text(
                    '$index',
                    style: t.caption.copyWith(
                      color: corporate.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: t.bodyStrong.copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (origin?.showsRowChip ?? false)
                  OriginChip(origin!, compact: true),
              ],
            ),
            const SizedBox(height: Space.sm),
            for (final row in rows)
              RecordRow(label: row.$1, value: row.$2, mono: row.$3),
            if (note case final n?) ...[
              const SizedBox(height: Space.xs),
              Text(
                n,
                style: t.caption.copyWith(
                  color: corporate.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
