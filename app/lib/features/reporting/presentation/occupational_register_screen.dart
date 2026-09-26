import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate.dart';
import '../../../core/demo/ui_demo_catalog.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';
import '../data/reporting_demo_catalog.dart';
import '../domain/report_models.dart';
import '../domain/simulated_exposure.dart';
import 'widgets/exposure_cell.dart';

/// The occupational exposure register.
///
/// ## The backbone of the reporting subsystem
///
/// Everything else in Reporting is a view onto this: a shift register is this
/// filtered by shift, an exception report is this filtered by state, an audit
/// package is this plus its provenance. So this screen carries the full
/// occupational field set, and every record leads to a detail view that walks
/// the whole chain — worker, shift, area, job, PTW/JSA, badge, monitoring
/// window, read, measurement, validity, calibration, review, disposition,
/// audit.
///
/// ## Phone and wide layouts
///
/// A twelve-column occupational table on a 390-pixel phone is unreadable, so
/// the phone gets record cards and the wide layout gets a table. Same records,
/// same cells, same refusal to print a number where there is none.
class OccupationalRegisterScreen extends StatefulWidget {
  const OccupationalRegisterScreen({super.key});

  @override
  State<OccupationalRegisterScreen> createState() =>
      _OccupationalRegisterScreenState();
}

class _OccupationalRegisterScreenState
    extends State<OccupationalRegisterScreen> {
  ReportFilter _filter = const ReportFilter();
  String _query = '';

  /// The width at which a table becomes more readable than cards.
  static const double _tableBreakpoint = 840;

  bool _matches(OccupationalRecord r) {
    final f = _filter;
    if (f.department != null && r.worker.department != f.department) {
      return false;
    }
    if (f.workArea != null && r.worker.workArea != f.workArea) return false;
    if (f.shift != null && r.worker.shift != f.shift) return false;
    if (f.isContractor != null && r.worker.isContractor != f.isContractor) {
      return false;
    }
    if (f.measurement != null && r.measurement.label != f.measurement) {
      return false;
    }
    if (f.reviewState != null && r.reviewState.label != f.reviewState) {
      return false;
    }
    if (f.badgeId != null && r.badgeId != f.badgeId) return false;
    if (f.batchId != null && r.batchId != f.batchId) return false;
    if (_query.isEmpty) return true;

    final q = _query.toLowerCase();
    return r.worker.name.toLowerCase().contains(q) ||
        r.worker.workerId.toLowerCase().contains(q) ||
        r.recordId.toLowerCase().contains(q) ||
        r.badgeId.toLowerCase().contains(q) ||
        r.batchId.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final all = ReportingDemoCatalog.records();
    final records = all.where(_matches).toList();

    return SafetyScaffold(
      title: 'Occupational exposure register',
      subtitle: '${_filter.periodLabel} · ${records.length} of ${all.length}',
      bottom: CorporateSearchField(
        hint: 'Search worker, ID, record, badge or batch',
        onChanged: (v) => setState(() => _query = v),
      ),
      children: [
        const DemoDataBanner(
          message:
              'Demonstration records. They describe no real worker, badge, '
              'permit or measurement.',
        ),
        const SizedBox(height: Space.sm),
        const NoProductionCalibrationBanner(),
        const SizedBox(height: Space.sm),
        const NoReadingIsNotZeroNote(),
        const SizedBox(height: Space.base),

        InfoCard(
          padding: EdgeInsets.zero,
          child: NavigationRow(
            icon: Icons.filter_list,
            title: 'Filters',
            subtitle: _filter.activeCount == 0
                ? 'Period, department, area, shift, state, badge, batch'
                : '${_filter.activeCount} active',
            trailingText: '${records.length}',
            onTap: () => _openFilters(context, all),
          ),
        ),
        const SizedBox(height: Space.base),

        if (records.isEmpty)
          const InfoCard(
            child: Text(
              'No records match these filters. Nothing has been hidden — the '
              'register simply holds nothing for this selection.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= _tableBreakpoint
                ? _RegisterTable(records: records)
                : Column(
                    children: [
                      for (final record in records)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: _RegisterCard(record: record),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }

  Future<void> _openFilters(
    BuildContext context,
    List<OccupationalRecord> all,
  ) async {
    final corporate = context.corporate;
    List<String> distinct(String Function(OccupationalRecord) of) =>
        all.map(of).toSet().toList()..sort();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: corporate.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CorporateRadii.xl),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Filters',
                  style: context.type.heading.copyWith(
                    color: corporate.textPrimary,
                  ),
                ),
                const SizedBox(height: Space.base),
                _Group(
                  label: 'Period',
                  options: const [
                    'Today',
                    'Last 7 days',
                    'Last 30 days',
                    'This shift',
                  ],
                  selected: _filter.periodLabel,
                  onSelected: (v) => setSheet(() {
                    _filter = _filter.copyWith(periodLabel: v ?? 'Last 7 days');
                    setState(() {});
                  }),
                ),
                _Group(
                  label: 'Department',
                  options: distinct((r) => r.worker.department),
                  selected: _filter.department,
                  onSelected: (v) => setSheet(() {
                    _filter = _filter.copyWith(department: v);
                    setState(() {});
                  }),
                ),
                _Group(
                  label: 'Work area',
                  options: distinct((r) => r.worker.workArea),
                  selected: _filter.workArea,
                  onSelected: (v) => setSheet(() {
                    _filter = _filter.copyWith(workArea: v);
                    setState(() {});
                  }),
                ),
                _Group(
                  label: 'Shift',
                  options: distinct((r) => r.worker.shift),
                  selected: _filter.shift,
                  onSelected: (v) => setSheet(() {
                    _filter = _filter.copyWith(shift: v);
                    setState(() {});
                  }),
                ),
                _Group(
                  label: 'Worker type',
                  options: const ['Employee', 'Contractor'],
                  selected: _filter.isContractor == null
                      ? null
                      : (_filter.isContractor! ? 'Contractor' : 'Employee'),
                  onSelected: (v) => setSheet(() {
                    _filter = _filter.copyWith(
                      isContractor: v == null ? null : v == 'Contractor',
                    );
                    setState(() {});
                  }),
                ),
                _Group(
                  label: 'Measurement state',
                  options: ReportedMeasurement.values
                      .map((m) => m.label)
                      .toList(),
                  selected: _filter.measurement,
                  onSelected: (v) => setSheet(() {
                    _filter = _filter.copyWith(measurement: v);
                    setState(() {});
                  }),
                ),
                _Group(
                  label: 'Review state',
                  options: DemoReviewState.values.map((s) => s.label).toList(),
                  selected: _filter.reviewState,
                  onSelected: (v) => setSheet(() {
                    _filter = _filter.copyWith(reviewState: v);
                    setState(() {});
                  }),
                ),
                _Group(
                  label: 'Badge',
                  options: distinct((r) => r.badgeId),
                  selected: _filter.badgeId,
                  onSelected: (v) => setSheet(() {
                    _filter = _filter.copyWith(badgeId: v);
                    setState(() {});
                  }),
                ),
                _Group(
                  label: 'Batch',
                  options: distinct((r) => r.batchId),
                  selected: _filter.batchId,
                  onSelected: (v) => setSheet(() {
                    _filter = _filter.copyWith(batchId: v);
                    setState(() {});
                  }),
                ),
                const SizedBox(height: Space.base),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheet(() {
                          _filter = const ReportFilter();
                          setState(() {});
                        }),
                        child: const Text('Clear all'),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: corporate.primary,
                          foregroundColor: corporate.textOnPrimary,
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One filter dimension. Tapping the active value clears it.
class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: t.caption.copyWith(
              color: corporate.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(option),
                  selected: option == selected,
                  showCheckmark: true,
                  onSelected: (isSelected) =>
                      onSelected(isSelected ? option : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A register record on a phone.
class _RegisterCard extends StatelessWidget {
  const _RegisterCard({required this.record});

  final OccupationalRecord record;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final w = record.worker;

    return InfoCard(
      onTap: () => context.push('/reporting/record', extra: record),
      emphasis: record.reviewState.isOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Both children are flexible. A bare pill beside an Expanded name
          // has no width to give back, so at 200% text it drove the row 99
          // pixels past the card edge. Letting the pill's label wrap keeps
          // the review state fully readable, which truncating it would not.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  w.name,
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
              ),
              const SizedBox(width: Space.sm),
              Flexible(child: _Pill(label: record.reviewState.label)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            record.recordId,
            style: t.readoutSmall.copyWith(color: corporate.textSecondary),
          ),
          const SizedBox(height: Space.sm),
          RecordRow(label: 'Worker ID', value: w.workerId, mono: true),
          RecordRow(label: 'Employment', value: w.typeLabel),
          if (w.contractorCompany case final company?)
            RecordRow(label: 'Contractor', value: company),
          RecordRow(label: 'Department', value: w.department),
          RecordRow(label: 'Work area', value: w.workArea),
          RecordRow(label: 'Shift', value: w.shift),
          RecordRow(label: 'Job', value: record.job),
          RecordRow(
            label: 'PTW',
            value: record.permitReference,
            mono: true,
            origin: DataOrigin.uiDemo,
          ),
          RecordRow(
            label: 'JSA',
            value: record.jsaReference,
            mono: true,
            origin: DataOrigin.uiDemo,
          ),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Space.sm),
            decoration: BoxDecoration(
              color: corporate.surfaceMuted,
              borderRadius: BorderRadius.circular(CorporateRadii.sm),
              border: Border.all(color: corporate.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated cumulative exposure',
                  style: t.caption.copyWith(
                    color: corporate.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 2),
                ExposureCell(
                  measurement: record.measurement,
                  exposure: record.exposure,
                ),
                if (record.refusalReason case final reason?) ...[
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: t.caption.copyWith(
                      color: corporate.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The register as a table, on a layout wide enough to read one.
class _RegisterTable extends StatelessWidget {
  const _RegisterTable({required this.records});

  final List<OccupationalRecord> records;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: t.caption.copyWith(
            color: corporate.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          dataTextStyle: t.caption.copyWith(color: corporate.textPrimary),
          columns: const [
            DataColumn(label: Text('Record')),
            DataColumn(label: Text('Worker')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Area')),
            DataColumn(label: Text('Shift')),
            DataColumn(label: Text('Badge')),
            DataColumn(label: Text('Monitored')),
            DataColumn(label: Text('Exposure')),
            DataColumn(label: Text('State')),
            DataColumn(label: Text('Review')),
          ],
          rows: [
            for (final r in records)
              DataRow(
                onSelectChanged: (_) =>
                    context.push('/reporting/record', extra: r),
                cells: [
                  DataCell(Text(r.recordId)),
                  DataCell(Text(r.worker.name)),
                  DataCell(Text(r.worker.typeLabel)),
                  DataCell(Text(r.worker.workArea)),
                  DataCell(Text(r.worker.shift)),
                  DataCell(Text(r.badgeId)),
                  DataCell(Text(Fmt.duration(r.coverage))),
                  // Same cell widget as the phone card: a table must not get
                  // its own idea of how to render an absent measurement.
                  DataCell(
                    ExposureCell(
                      measurement: r.measurement,
                      exposure: r.exposure,
                      compact: true,
                    ),
                  ),
                  DataCell(Text(r.measurement.label)),
                  DataCell(Text(r.reviewState.label)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.sm),
        border: Border.all(color: corporate.border),
      ),
      child: Text(
        label,
        style: context.type.caption.copyWith(color: corporate.textSecondary),
      ),
    );
  }
}
