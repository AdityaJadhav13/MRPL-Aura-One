import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';
import '../data/reporting_demo_catalog.dart';
import '../domain/report_models.dart';
import '../domain/simulated_exposure.dart';
import 'widgets/exposure_cell.dart';

/// Assembling a report.
///
/// A report is a saved query plus a choice of sections plus a template
/// profile. The builder walks those in order, and every step is the same
/// vocabulary the register already uses — a report should not need a second
/// language for the same things.
class ReportBuilderScreen extends StatefulWidget {
  const ReportBuilderScreen({super.key});

  @override
  State<ReportBuilderScreen> createState() => _ReportBuilderScreenState();
}

class _ReportBuilderScreenState extends State<ReportBuilderScreen> {
  ReportDefinition _definition = ReportDefinition(
    title: 'Occupational exposure register',
    profile: ReportTemplateProfile.internalHse,
    filter: const ReportFilter(),
    sections: ReportSection.values.toSet(),
  );

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final matching = ReportingDemoCatalog.records().length;

    return SafetyScaffold(
      title: 'Report builder',
      subtitle: 'Configure, preview, export',
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),

        _Step(
          number: 1,
          title: 'Report type',
          child: _Choices<String>(
            options: const [
              'Occupational exposure register',
              'Shift exposure register',
              'Daily exposure register',
              'Worker exposure history',
              'Work-area summary',
              'Exception report',
            ],
            selected: _definition.title,
            labelOf: (v) => v,
            onSelected: (v) =>
                setState(() => _definition = _definition.copyWith(title: v)),
          ),
        ),

        _Step(
          number: 2,
          title: 'Reporting period',
          child: _Choices<String>(
            options: const [
              'Today',
              'Last 7 days',
              'Last 30 days',
              'This shift',
            ],
            selected: _definition.filter.periodLabel,
            labelOf: (v) => v,
            onSelected: (v) => setState(
              () => _definition = _definition.copyWith(
                filter: _definition.filter.copyWith(periodLabel: v),
              ),
            ),
          ),
        ),

        _Step(
          number: 3,
          title: 'Scope',
          subtitle: 'Site, department, area, shift, worker type',
          child: _ScopeSummary(filter: _definition.filter),
        ),

        _Step(
          number: 4,
          title: 'Result filters',
          subtitle: 'Measurement state, review state, badge, batch',
          child: _ScopeSummary(filter: _definition.filter, results: true),
        ),

        _Step(
          number: 5,
          title: 'Content',
          subtitle: '${_definition.sections.length} sections included',
          child: Column(
            children: [
              for (final section in ReportSection.values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _definition.sections.contains(section),
                  onChanged: (on) => setState(() {
                    final next = {..._definition.sections};
                    if (on ?? false) {
                      next.add(section);
                    } else {
                      next.remove(section);
                    }
                    _definition = _definition.copyWith(sections: next);
                  }),
                  title: Text(
                    section.label,
                    style: t.body.copyWith(color: corporate.textPrimary),
                  ),
                ),
            ],
          ),
        ),

        _Step(
          number: 6,
          title: 'Template profile',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Choices<ReportTemplateProfile>(
                options: ReportTemplateProfile.values,
                selected: _definition.profile,
                labelOf: (p) => p.label,
                onSelected: (p) => setState(
                  () => _definition = _definition.copyWith(profile: p),
                ),
              ),
              const SizedBox(height: Space.sm),
              // The caveat travels with the profile, always. A profile name
              // without it is the compliance claim this product must not make.
              _ProfileCaveat(profile: _definition.profile),
            ],
          ),
        ),

        _Step(
          number: 7,
          title: 'Preview',
          subtitle: '$matching record(s) in scope',
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  context.push('/reporting/preview', extra: _definition),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Open preview'),
              style: FilledButton.styleFrom(
                backgroundColor: corporate.primary,
                foregroundColor: corporate.textOnPrimary,
                minimumSize: const Size.fromHeight(kMinTouchTarget),
              ),
            ),
          ),
        ),

        _Step(number: 8, title: 'Export', child: const _ExportOptions()),
      ],
    );
  }
}

/// The caveat attached to a template profile.
class _ProfileCaveat extends StatelessWidget {
  const _ProfileCaveat({required this.profile});

  final ReportTemplateProfile profile;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final heavier = profile.referencesRegulator;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: heavier ? corporate.accentMuted : corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        border: Border.all(
          color: heavier
              ? corporate.accent.withValues(alpha: 0.45)
              : corporate.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            heavier ? Icons.gavel_outlined : Icons.info_outline,
            size: 17,
            color: heavier ? corporate.accent : corporate.textSecondary,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              profile.caveat,
              style: t.caption.copyWith(
                color: heavier
                    ? corporate.textPrimary
                    : corporate.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The export formats, all unavailable.
class _ExportOptions extends StatelessWidget {
  const _ExportOptions();

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final format in ExportFormat.values) ...[
              Expanded(
                child: OutlinedButton(
                  // No exporter exists. A control that produced an empty or
                  // partial file would be worse than one that says it cannot.
                  onPressed: null,
                  child: Text(format.label),
                ),
              ),
              if (format != ExportFormat.values.last)
                const SizedBox(width: Space.sm),
            ],
          ],
        ),
        const SizedBox(height: Space.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.sm),
          decoration: BoxDecoration(
            color: corporate.surfaceMuted,
            borderRadius: BorderRadius.circular(CorporateRadii.sm),
            border: Border.all(color: corporate.border),
          ),
          child: Row(
            children: [
              Icon(Icons.link_off, size: 15, color: corporate.textSecondary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  'Export is not connected. A preview shows what a report '
                  'would contain; nothing has been generated, downloaded or '
                  'submitted anywhere.',
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScopeSummary extends StatelessWidget {
  const _ScopeSummary({required this.filter, this.results = false});

  final ReportFilter filter;
  final bool results;

  @override
  Widget build(BuildContext context) {
    final rows = results
        ? <(String, String)>[
            ('Measurement state', filter.measurement ?? 'All'),
            ('Review state', filter.reviewState ?? 'All'),
            ('Badge', filter.badgeId ?? 'All'),
            ('Batch', filter.batchId ?? 'All'),
          ]
        : <(String, String)>[
            ('Site', filter.site ?? 'Mangalore Refinery'),
            ('Department', filter.department ?? 'All'),
            ('Work area', filter.workArea ?? 'All'),
            ('Shift', filter.shift ?? 'All'),
            (
              'Worker type',
              filter.isContractor == null
                  ? 'All'
                  : (filter.isContractor! ? 'Contractor' : 'Employee'),
            ),
          ];

    return Column(
      children: [
        for (final row in rows) RecordRow(label: row.$1, value: row.$2),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final int number;
  final String title;
  final String? subtitle;
  final Widget child;

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
                    '$number',
                    style: t.caption.copyWith(
                      color: corporate.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: t.bodyStrong.copyWith(
                            color: corporate.textPrimary,
                          ),
                        ),
                      ),
                      if (subtitle case final s?)
                        Text(
                          s,
                          style: t.caption.copyWith(
                            color: corporate.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _Choices<T extends Object> extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(labelOf(option)),
            selected: option == selected,
            showCheckmark: true,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}

/// An audit-quality preview of the configured report.
///
/// A preview, and it says so. Nothing has been generated: the distinction
/// between *this is what it would contain* and *a report exists* is the whole
/// honesty of the export story.
class ReportPreviewScreen extends StatelessWidget {
  const ReportPreviewScreen({required this.definition, super.key});

  final ReportDefinition definition;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final records = ReportingDemoCatalog.records();
    final withFigures = records.where((r) => r.exposure != null).length;
    final noReading = records
        .where((r) => r.measurement == ReportedMeasurement.noReading)
        .length;

    return SafetyScaffold(
      title: 'Report preview',
      subtitle: definition.title,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: corporate.surfaceMuted,
            borderRadius: BorderRadius.circular(CorporateRadii.md),
            border: Border.all(color: corporate.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 17,
                color: corporate.textSecondary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  'Preview only. No report has been generated, and nothing '
                  'has been exported or submitted.',
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        const NoProductionCalibrationBanner(),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Report identification'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Title', value: definition.title),
              RecordRow(
                label: 'Template profile',
                value: definition.profile.label,
              ),
              RecordRow(label: 'Period', value: definition.filter.periodLabel),
              RecordRow(
                label: 'Prepared',
                value: Fmt.stamp(DateTime.now()),
                mono: true,
              ),
              const RecordRow(
                label: 'Report ID',
                value: 'Not assigned — no report service exists',
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        _ProfileCaveat(profile: definition.profile),

        const SectionHeader(title: 'Organisation and site'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(
                label: 'Organisation',
                value: 'Mangalore Refinery and Petrochemicals Limited',
                origin: DataOrigin.uiDemo,
              ),
              RecordRow(label: 'Site', value: 'Mangalore Refinery'),
              RecordRow(label: 'Prepared by', value: 'DoseBand prototype'),
            ],
          ),
        ),

        const SectionHeader(title: 'Methodology'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RecordRow(
                label: 'Measurement target',
                value: 'Estimated cumulative external H₂S exposure',
              ),
              const RecordRow(label: 'Unit', value: 'ppm·h'),
              const RecordRow(
                label: 'Approach',
                value:
                    'Passive colorimetric dosimeter, read by smartphone '
                    'photograph',
              ),
              const RecordRow(
                label: 'Calibration',
                value: 'None — no production calibration exists',
              ),
              const SizedBox(height: Space.xs),
              Text(
                'DoseBand measures external exposure around the badge. It '
                'does not measure absorbed dose, blood concentration, '
                'biological dose or health status.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Summary'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Records', value: '${records.length}'),
              RecordRow(
                label: 'With a simulated figure',
                value: '$withFigures',
              ),
              RecordRow(label: 'No valid reading', value: '$noReading'),
              // Deliberately absent: there is no mean, because averaging a
              // set containing unknowns would require treating them as
              // something, and the only honest something is "leave out".
              const RecordRow(label: 'Mean exposure', value: 'Not reported'),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        InfoCard(
          child: Text(
            'No mean or total is reported. Records without a figure cannot be '
            'included in an average, and excluding them silently would '
            'describe a different population than the one monitored.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),

        const SectionHeader(title: 'Records', subtitle: 'Extract'),
        for (final record in records.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${record.worker.name} · ${record.recordId}',
                    style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                  ),
                  const SizedBox(height: Space.xs),
                  RecordRow(label: 'Work area', value: record.worker.workArea),
                  RecordRow(
                    label: 'Monitored',
                    value: Fmt.duration(record.coverage),
                    mono: true,
                  ),
                  const SizedBox(height: Space.xs),
                  ExposureCell(
                    measurement: record.measurement,
                    exposure: record.exposure,
                  ),
                ],
              ),
            ),
          ),

        const SectionHeader(title: 'Limitations'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final limitation in const <String>[
                'DoseBand does not replace approved real-time gas detection '
                    'and is not an alarm.',
                'The intended quantitative result is estimated cumulative '
                    'external exposure, not absorbed medical dose.',
                'No valid reading must not be interpreted as zero exposure.',
                'Measurements outside validated conditions require review.',
                'No production quantitative calibration is available, so the '
                    'figures in this preview are simulated.',
                'Scientific gates S1, S2 and S3 remain open.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.circle,
                          size: 5,
                          color: corporate.textSecondary,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          limitation,
                          style: t.caption.copyWith(
                            color: corporate.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SectionHeader(title: 'Export'),
        const InfoCard(child: _ExportOptions()),
      ],
    );
  }
}
