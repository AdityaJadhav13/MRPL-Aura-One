import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import 'widgets/exposure_cell.dart';
import '../data/reporting_demo_catalog.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';

/// A report this product can produce, or intends to.
enum ReportKind {
  shiftExposure(
    'Shift exposure register',
    'Exposure records for one shift',
    ReportCategory.occupationalExposure,
  ),
  dailyExposure(
    'Daily exposure register',
    'Exposure records for one day, grouped by shift',
    ReportCategory.occupationalExposure,
  ),
  occupationalExposureRegister(
    'Occupational exposure register',
    'The full occupational record, with work context and provenance',
    ReportCategory.occupationalExposure,
  ),
  workerHistory(
    'Worker exposure history',
    'One worker over a period',
    ReportCategory.occupationalExposure,
  ),
  workAreaSummary(
    'Work-area exposure summary',
    'Monitoring counts by area',
    ReportCategory.operations,
  ),
  exceptionReport(
    'Exception report',
    'Records that could not be closed, by reason',
    ReportCategory.exceptions,
  ),
  invalidMeasurement(
    'Invalid measurement report',
    'Refusals and what caused them',
    ReportCategory.exceptions,
  ),
  aboveRangeSaturated(
    'Above-range and saturated',
    'Readings outside the quantifiable interval, kept apart',
    ReportCategory.exceptions,
  ),
  incompleteMonitoring(
    'Incomplete monitoring report',
    'Periods that did not cover what was asked of them',
    ReportCategory.exceptions,
  ),
  badgeUtilization(
    'Badge utilisation',
    'Badge lifecycle and usage',
    ReportCategory.badgeAndBatch,
  ),
  batchReport(
    'Batch report',
    'Badge usage and outcomes by batch',
    ReportCategory.badgeAndBatch,
  ),
  calibrationReport(
    'Calibration report',
    'Calibration package metadata and usage',
    ReportCategory.calibration,
  ),
  auditPackage(
    'Audit package',
    'A bundle assembled for an auditor',
    ReportCategory.audit,
  );

  const ReportKind(this.title, this.description, this.category);

  final String title;
  final String description;
  final ReportCategory category;
}

enum ReportCategory {
  occupationalExposure('Occupational exposure'),
  operations('Operations'),
  exceptions('Exceptions'),
  badgeAndBatch('Badge and batch'),
  calibration('Calibration'),
  audit('Audit');

  const ReportCategory(this.label);

  final String label;
}

/// The reporting centre.
///
/// ## Why nothing here says "compliant"
///
/// A report labelled OISD, DGMS or MRPL compliant asserts that its contents
/// satisfy a specific regulatory schema. No such mapping has been done, and
/// the underlying records do not yet carry a measured quantity. Every template
/// here is therefore marked as internal, and it stays that way until somebody
/// does the regulatory mapping properly.
class ReportingCentreScreen extends StatelessWidget {
  const ReportingCentreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    final byCategory = <ReportCategory, List<ReportKind>>{};
    for (final kind in ReportKind.values) {
      byCategory.putIfAbsent(kind.category, () => []).add(kind);
    }

    return SafetyScaffold(
      title: 'Reporting',
      subtitle: 'Registers, exceptions and audit',
      showHero: true,
      children: [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 19,
                    color: corporate.textSecondary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'Internal templates',
                      style: t.bodyStrong.copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                'These are internal report templates. None of them is mapped '
                'to a regulatory schema, and no report produced here should '
                'be described as satisfying one. Export is not implemented.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        const SectionHeader(title: 'Start here'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              NavigationRow(
                icon: Icons.table_chart_outlined,
                title: 'Occupational exposure register',
                subtitle: 'The full record, with traceability',
                origin: DataOrigin.uiDemo,
                onTap: () => context.push('/reporting/register'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.tune,
                title: 'Report builder',
                subtitle: 'Configure, preview, export',
                onTap: () => context.push('/reporting/builder'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.inventory_2_outlined,
                title: 'Audit package',
                subtitle: 'Assemble evidence for review',
                onTap: () => context.push('/reporting/audit-package'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.history_toggle_off,
                title: 'Report history',
                subtitle: 'Nothing generated yet',
                origin: DataOrigin.notConnected,
                onTap: () => context.push('/reporting/history'),
              ),
            ],
          ),
        ),

        for (final entry in byCategory.entries) ...[
          SectionHeader(title: entry.key.label),
          InfoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      child: Divider(height: 1, color: corporate.border),
                    ),
                  NavigationRow(
                    icon: Icons.summarize_outlined,
                    title: entry.value[i].title,
                    subtitle: entry.value[i].description,
                    onTap: () => switch (entry.value[i]) {
                      // Two kinds have screens of their own; the rest share
                      // the generic detail, which is the architecture this
                      // phase was asked to preserve.
                      ReportKind.occupationalExposureRegister => context.push(
                        '/reporting/register',
                      ),
                      ReportKind.auditPackage => context.push(
                        '/reporting/audit-package',
                      ),
                      _ => context.push(
                        '/reporting/report',
                        extra: entry.value[i],
                      ),
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A report's detail: filters, preview and output options.
///
/// The preview is built from demonstration records. The export controls are
/// present and disabled — there is no exporter, and a button that appears to
/// produce a PDF and silently does nothing is worse than one that says it
/// cannot.
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({required this.kind, super.key});

  final ReportKind kind;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final records = _recordsFor(kind);

    return SafetyScaffold(
      title: kind.title,
      subtitle: kind.category.label,
      children: [
        const DemoDataBanner(
          message:
              'This preview is built from demonstration records. It '
              'describes no real worker and no real measurement.',
        ),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Filters'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(label: 'Site', value: 'Mangalore Refinery'),
              RecordRow(label: 'Period', value: 'Last 7 days'),
              RecordRow(label: 'Department', value: 'All'),
              RecordRow(label: 'Work area', value: 'All'),
              RecordRow(label: 'Shift', value: 'All'),
            ],
          ),
        ),

        SectionHeader(
          title: 'Preview',
          subtitle: '${records.length} record(s)',
          origin: DataOrigin.uiDemo,
        ),
        if (kind == ReportKind.calibrationReport)
          const _CalibrationReportBody()
        else if (records.isEmpty)
          const InfoCard(child: Text('No records for these filters.'))
        else
          for (final record in records)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: _ReportRowCard(record: record),
            ),

        const SectionHeader(title: 'Output'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.table_view_outlined),
                      label: const Text('CSV'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                'Export is not implemented. No exporter exists, so these '
                'controls are disabled rather than producing an empty or '
                'partial file.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        if (kind == ReportKind.auditPackage) ...[
          const SectionHeader(title: 'Package contents'),
          InfoCard(
            child: Column(
              children: const [
                RecordRow(label: 'Exposure register', value: 'Included'),
                RecordRow(label: 'Worker records', value: 'Included'),
                RecordRow(label: 'Badge traceability', value: 'Included'),
                RecordRow(label: 'Calibration information', value: 'Included'),
                RecordRow(label: 'Invalid measurements', value: 'Included'),
                RecordRow(label: 'HSE reviews', value: 'Included'),
                RecordRow(label: 'Methodology', value: 'Included'),
                RecordRow(label: 'Audit trail', value: 'Included'),
                RecordRow(label: 'Referenced documents', value: 'Unavailable'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Reporting reads its own catalogue, not the HSE one.
  ///
  /// The distinction matters: these records carry the measurement states the
  /// reports are *about* — above-range separately from saturated, partial
  /// separately from complete — which the HSE dataset does not model.
  static List<OccupationalRecord> _recordsFor(ReportKind kind) =>
      switch (kind) {
        // Everything that is not a simulated-valid reading.
        ReportKind.exceptionReport => ReportingDemoCatalog.exceptions(),
        // Acquisition and measurement failures only.
        ReportKind.invalidMeasurement =>
          ReportingDemoCatalog.invalidMeasurements(),
        // Outside the quantifiable interval — the measurement succeeded.
        ReportKind.aboveRangeSaturated =>
          ReportingDemoCatalog.aboveRangeOrSaturated(),
        // The period itself was short.
        ReportKind.incompleteMonitoring =>
          ReportingDemoCatalog.incompleteMonitoring(),
        ReportKind.calibrationReport => const [],
        _ => ReportingDemoCatalog.records(),
      };
}

/// One row of a report preview.
class _ReportRowCard extends StatelessWidget {
  const _ReportRowCard({required this.record});

  final OccupationalRecord record;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final w = record.worker;

    return InfoCard(
      onTap: () => context.push('/reporting/record', extra: record),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  w.name,
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
              ),
              Text(
                record.recordId,
                style: t.readoutSmall.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          RecordRow(label: 'Employment', value: w.typeLabel),
          if (w.contractorCompany case final company?)
            RecordRow(label: 'Contractor', value: company),
          RecordRow(label: 'Department', value: w.department),
          RecordRow(label: 'Work area', value: w.workArea),
          RecordRow(label: 'Shift', value: w.shift),
          RecordRow(label: 'Badge', value: record.badgeId, mono: true),
          RecordRow(label: 'Batch', value: record.batchId, mono: true),
          RecordRow(
            label: 'Monitored',
            value: Fmt.duration(record.coverage),
            mono: true,
          ),
          RecordRow(
            label: 'Completeness',
            value: record.monitoringComplete ? 'Complete' : 'Partial',
          ),
          const SizedBox(height: Space.sm),
          // The same cell every other reporting surface uses, so a state
          // cannot be formatted one way here and another in the register.
          ExposureCell(
            measurement: record.measurement,
            exposure: record.exposure,
          ),
          if (record.refusalReason case final reason?)
            RecordRow(label: 'Reason', value: reason),
          RecordRow(label: 'Review', value: record.reviewState.label),
        ],
      ),
    );
  }
}

/// The calibration report body.
class _CalibrationReportBody extends StatelessWidget {
  const _CalibrationReportBody();

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No calibration package exists',
            style: t.bodyStrong.copyWith(color: corporate.textPrimary),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'There is no calibration identifier, version, validated domain, '
            'model type or evidence summary to report, because no calibration '
            'has been produced.',
            style: t.body.copyWith(color: corporate.textSecondary),
          ),
          const SizedBox(height: Space.base),
          Text(
            'No accuracy figure, limit of detection, limit of quantification '
            'or coefficient of determination appears in this report. Those '
            'values come from experiments, and none have been run.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.md),
    child: Divider(height: 1, color: context.corporate.border),
  );
}
