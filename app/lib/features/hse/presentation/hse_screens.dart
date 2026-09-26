import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate.dart';
import '../../../core/demo/ui_demo_catalog.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';

/// HSE overview.
///
/// ## Why none of these tiles is green
///
/// A count of monitored workers is not good news or bad news, and a count of
/// records needing review is work to do rather than a failure. Colouring this
/// dashboard by sentiment would invite an officer to read "all green, nothing
/// to do" — which is precisely the reading a monitoring product must not
/// encourage. Attention is drawn by *ordering* and by the accent rule, not by
/// a traffic-light palette.
class HseDashboardScreen extends StatelessWidget {
  const HseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    final workers = UiDemoCatalog.workers();
    final records = UiDemoCatalog.exposureRecords();
    final review = UiDemoCatalog.requiringReview();
    final active = UiDemoCatalog.activelyMonitored();
    final awaiting = workers
        .where((w) => w.monitoringState == DemoMonitoringState.awaitingScan)
        .length;
    final noReading = records.where((r) => !r.hasReading).length;
    final badgesInUse = UiDemoCatalog.badges()
        .where(
          (b) =>
              b.status == DemoBadgeStatus.assigned ||
              b.status == DemoBadgeStatus.active ||
              b.status == DemoBadgeStatus.awaitingRead,
        )
        .length;

    return SafetyScaffold(
      title: 'HSE overview',
      subtitle: 'Mangalore Refinery · Demo site',
      showHero: true,
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Today', origin: DataOrigin.uiDemo),
        _MetricGrid(
          children: [
            MetricCard(
              label: 'Workers monitored',
              value: '${workers.length}',
              icon: Icons.groups_outlined,
            ),
            MetricCard(
              label: 'Monitoring active',
              value: '${active.length}',
              icon: Icons.monitor_heart_outlined,
              onTap: () => context.go('/hse/monitoring'),
            ),
            MetricCard(
              label: 'Awaiting scan',
              value: '$awaiting',
              icon: Icons.qr_code_scanner_outlined,
            ),
            MetricCard(
              label: 'Records complete',
              value: '${records.length}',
              icon: Icons.task_alt_outlined,
              onTap: () => context.go('/hse/exposures'),
            ),
            MetricCard(
              label: 'Review required',
              value: '${review.length}',
              icon: Icons.rule_outlined,
              emphasis: review.isNotEmpty,
              onTap: () => context.go('/hse/review'),
            ),
            MetricCard(
              label: 'No valid reading',
              value: '$noReading',
              icon: Icons.do_not_disturb_on_outlined,
              caption: 'Not an exposure of zero',
              onTap: () => context.push('/hse/exceptions'),
            ),
            MetricCard(
              label: 'Badges in use',
              value: '$badgesInUse',
              icon: Icons.badge_outlined,
              onTap: () => context.push('/hse/inventory'),
            ),
          ],
        ),

        const SectionHeader(
          title: 'Needs attention',
          subtitle: 'Records that cannot be closed as they stand',
        ),
        if (review.isEmpty)
          const InfoCard(child: Text('No records require review.'))
        else
          for (final record in review.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: ExposureRecordCard(record: record),
            ),

        const SectionHeader(
          title: 'Active monitoring',
          subtitle: 'Badges currently in the field',
        ),
        if (active.isEmpty)
          const InfoCard(child: Text('No monitored periods are active.'))
        else
          InfoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < active.length; i++) ...[
                  if (i > 0) _Sep(),
                  NavigationRow(
                    icon: Icons.person_outline,
                    title: active[i].name,
                    subtitle:
                        '${active[i].workArea} · '
                        '${Fmt.duration(active[i].coverageAt(DateTime.now()))}',
                    onTap: () => context.push('/hse/session', extra: active[i]),
                  ),
                ],
              ],
            ),
          ),

        const SectionHeader(title: 'System'),
        InfoCard(
          child: Column(
            children: [
              // Never "synced" or "online": the app is local-only, and a
              // green connectivity line is the easiest thing on a dashboard
              // to believe without checking.
              const RecordRow(label: 'Records', value: 'Stored on this device'),
              const RecordRow(
                label: 'Backend',
                value: 'Not connected',
                origin: DataOrigin.notConnected,
              ),
              const RecordRow(label: 'Last synchronisation', value: 'Never'),
              RecordRow(
                label: 'Pending upload',
                value: Fmt.noValue,
                mono: true,
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Calibration'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_outlined,
                    size: 19,
                    color: corporate.textSecondary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'No production calibration available',
                      style: t.bodyStrong.copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                'No validated calibration model exists, so no quantitative '
                'H₂S figure is produced anywhere in this application. Badge '
                'readings complete, but the exposure quantity is unavailable.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
              const SizedBox(height: Space.sm),
              TextButton(
                onPressed: () => context.push('/hse/calibration'),
                child: const Text('Calibration detail'),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'More'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              NavigationRow(
                icon: Icons.person_search_outlined,
                title: 'Worker search',
                origin: DataOrigin.uiDemo,
                onTap: () => context.push('/hse/workers'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.inventory_2_outlined,
                title: 'Badge inventory',
                origin: DataOrigin.uiDemo,
                onTap: () => context.push('/hse/inventory'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.warning_amber_outlined,
                title: 'Exception queue',
                origin: DataOrigin.uiDemo,
                onTap: () => context.push('/hse/exceptions'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.history_toggle_off_outlined,
                title: 'Audit trail',
                origin: DataOrigin.uiDemo,
                onTap: () => context.push('/hse/audit'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.assessment_outlined,
                title: 'Reporting',
                onTap: () => context.push('/reporting'),
              ),
            ],
          ),
        ),
      ],
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

/// A responsive metric grid: two columns on a phone, more when there is room.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
            ? 3
            : 2;
        final spacing = Space.sm;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// HSE active monitoring.
class HseActiveMonitoringScreen extends StatefulWidget {
  const HseActiveMonitoringScreen({super.key});

  @override
  State<HseActiveMonitoringScreen> createState() =>
      _HseActiveMonitoringScreenState();
}

class _HseActiveMonitoringScreenState extends State<HseActiveMonitoringScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final matches = UiDemoCatalog.workers()
        .where((w) => w.monitoringState != DemoMonitoringState.notStarted)
        .where(
          (w) =>
              _query.isEmpty ||
              w.name.toLowerCase().contains(_query.toLowerCase()) ||
              w.workerId.toLowerCase().contains(_query.toLowerCase()) ||
              w.workArea.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return SafetyScaffold(
      title: 'Monitoring',
      subtitle: 'Badges currently in the field',
      bottom: CorporateSearchField(
        hint: 'Search worker, ID or area',
        onChanged: (v) => setState(() => _query = v),
      ),
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),
        if (matches.isEmpty)
          const InfoCard(child: Text('No monitored periods match this search.'))
        else
          for (final worker in matches)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: _MonitoringCard(worker: worker, now: now),
            ),
      ],
    );
  }
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({required this.worker, required this.now});

  final DemoWorker worker;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final coverage = worker.coverageAt(now);

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Both children flexible: a rigid chip beside an Expanded name has
          // no width to give back, and at 200% text it drove the row past the
          // card edge. The label wraps rather than truncating, because a
          // half-shown monitoring state is worse than a two-line one.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  worker.name,
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
              ),
              const SizedBox(width: Space.sm),
              Flexible(child: _StateChip(label: worker.monitoringState.label)),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            '${worker.workerId} · ${worker.typeLabel}'
            '${worker.contractorCompany == null ? '' : ' · ${worker.contractorCompany}'}',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
          const SizedBox(height: Space.sm),
          RecordRow(label: 'Department', value: worker.department),
          RecordRow(label: 'Work area', value: worker.workArea),
          RecordRow(label: 'Shift', value: worker.shift),
          RecordRow(
            label: 'Started',
            value: worker.startedAt == null
                ? Fmt.noValue
                : Fmt.stamp(worker.startedAt!),
            mono: true,
          ),
          // Unknown stays unknown: the same rule the real workflow follows.
          RecordRow(
            label: 'Duration',
            value: Fmt.duration(coverage),
            mono: true,
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

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
        style: t.caption.copyWith(color: corporate.textSecondary),
      ),
    );
  }
}

/// A single exposure record, as a card.
class ExposureRecordCard extends StatelessWidget {
  const ExposureRecordCard({
    required this.record,
    this.detailed = false,
    super.key,
  });

  final DemoExposureRecord record;

  /// The register shows the full occupational field set; the dashboard and
  /// queues show the short form. Same card, so a record reads the same way
  /// wherever an officer meets it.
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      onTap: () => context.push('/hse/record', extra: record),
      emphasis: record.reviewState != DemoReviewState.reviewed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  record.worker.name,
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
              ),
              const SizedBox(width: Space.sm),
              Flexible(child: _StateChip(label: record.reviewState.label)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            record.recordId,
            style: t.readoutSmall.copyWith(color: corporate.textSecondary),
          ),
          const SizedBox(height: Space.sm),
          if (detailed) ...[
            RecordRow(label: 'Employment', value: record.worker.typeLabel),
            if (record.worker.contractorCompany case final company?)
              RecordRow(label: 'Contractor', value: company),
            RecordRow(label: 'Department', value: record.worker.department),
          ],
          RecordRow(label: 'Work area', value: record.worker.workArea),
          if (detailed) RecordRow(label: 'Shift', value: record.worker.shift),
          RecordRow(label: 'Badge', value: record.badgeId, mono: true),
          if (detailed)
            RecordRow(label: 'Batch', value: record.batchId, mono: true),
          RecordRow(
            label: 'Monitored',
            value: Fmt.duration(record.coverage),
            mono: true,
          ),
          if (detailed)
            RecordRow(
              label: 'Window',
              value:
                  '${Fmt.stamp(record.startedAt)} → '
                  '${Fmt.stamp(record.endedAt)}',
              mono: true,
            ),
          const SizedBox(height: Space.sm),
          _OutcomeLine(record: record),
        ],
      ),
    );
  }
}

/// The result line for a record.
///
/// There is no dose here, and there is no `0`. `readComplete` says the badge
/// was read and that the quantity is unavailable because no calibration
/// exists; `noReading` names the reason. Both print the refusal placeholder in
/// the value slot, so the slot never carries a number that was not measured.
class _OutcomeLine extends StatelessWidget {
  const _OutcomeLine({required this.record});

  final DemoExposureRecord record;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.sm),
        border: Border.all(color: corporate.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Fmt.noValue,
            style: t.readoutBody.copyWith(color: corporate.textSecondary),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.outcome.label,
                  style: t.caption.copyWith(color: corporate.textPrimary),
                ),
                Text(
                  record.refusalReason ??
                      'Quantitative H₂S calibration not available',
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The exposure register.
class HseExposureRegisterScreen extends StatefulWidget {
  const HseExposureRegisterScreen({super.key});

  @override
  State<HseExposureRegisterScreen> createState() =>
      _HseExposureRegisterScreenState();
}

enum _ResultFilter {
  all('All'),
  read('Badge read'),
  noReading('No reading'),
  reviewRequired('Review required');

  const _ResultFilter(this.label);

  final String label;
}

class _HseExposureRegisterScreenState extends State<HseExposureRegisterScreen> {
  _ResultFilter _filter = _ResultFilter.all;
  String _query = '';
  String? _department;
  String? _workArea;
  String? _shift;
  bool? _contractor;
  DemoReviewState? _reviewState;

  bool _matchesResult(DemoExposureRecord r) => switch (_filter) {
    _ResultFilter.all => true,
    _ResultFilter.read => r.hasReading,
    _ResultFilter.noReading => !r.hasReading,
    _ResultFilter.reviewRequired => r.reviewState.isOpen,
  };

  bool _matches(DemoExposureRecord r) {
    if (!_matchesResult(r)) return false;
    if (_department != null && r.worker.department != _department) return false;
    if (_workArea != null && r.worker.workArea != _workArea) return false;
    if (_shift != null && r.worker.shift != _shift) return false;
    if (_contractor != null && r.worker.isContractor != _contractor) {
      return false;
    }
    if (_reviewState != null && r.reviewState != _reviewState) return false;
    if (_query.isEmpty) return true;

    final q = _query.toLowerCase();
    return r.worker.name.toLowerCase().contains(q) ||
        r.worker.workerId.toLowerCase().contains(q) ||
        r.recordId.toLowerCase().contains(q) ||
        r.badgeId.toLowerCase().contains(q) ||
        r.batchId.toLowerCase().contains(q);
  }

  int get _activeFilters => [
    _department,
    _workArea,
    _shift,
    _contractor,
    _reviewState,
  ].where((f) => f != null).length;

  @override
  Widget build(BuildContext context) {
    final all = UiDemoCatalog.exposureRecords();
    final records = all.where(_matches).toList();

    return SafetyScaffold(
      title: 'Exposure register',
      subtitle: 'Occupational exposure records',
      bottom: Column(
        children: [
          CorporateSearchField(
            hint: 'Search worker, ID, record, badge or batch',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: Space.sm),
          FilterChipRow<_ResultFilter>(
            options: _ResultFilter.values,
            selected: _filter,
            labelOf: (f) => f.label,
            countOf: (f) {
              final previous = _filter;
              _filter = f;
              final n = all.where(_matchesResult).length;
              _filter = previous;
              return n;
            },
            onSelected: (f) => setState(() => _filter = f),
          ),
        ],
      ),
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),

        // Secondary filters live behind a sheet rather than stacking six chip
        // rows above a list. An officer filtering a register is doing one
        // deliberate thing; the register itself should stay readable.
        InfoCard(
          padding: EdgeInsets.zero,
          child: NavigationRow(
            icon: Icons.filter_list,
            title: 'Filters',
            subtitle: _activeFilters == 0
                ? 'Department, area, shift, worker type, review state'
                : '$_activeFilters active',
            trailingText: '${records.length} of ${all.length}',
            onTap: () => _openFilters(context, all),
          ),
        ),
        const SizedBox(height: Space.base),

        if (records.isEmpty)
          const InfoCard(child: Text('No records match these filters.'))
        else
          for (final record in records)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: ExposureRecordCard(record: record, detailed: true),
            ),
      ],
    );
  }

  Future<void> _openFilters(
    BuildContext context,
    List<DemoExposureRecord> all,
  ) async {
    final corporate = context.corporate;

    List<String> distinct(String Function(DemoExposureRecord) of) =>
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
        builder: (sheetContext, setSheetState) => SafeArea(
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
                _FilterGroup<String>(
                  label: 'Department',
                  options: distinct((r) => r.worker.department),
                  selected: _department,
                  labelOf: (v) => v,
                  onSelected: (v) => setSheetState(() {
                    _department = v;
                    setState(() {});
                  }),
                ),
                _FilterGroup<String>(
                  label: 'Work area',
                  options: distinct((r) => r.worker.workArea),
                  selected: _workArea,
                  labelOf: (v) => v,
                  onSelected: (v) => setSheetState(() {
                    _workArea = v;
                    setState(() {});
                  }),
                ),
                _FilterGroup<String>(
                  label: 'Shift',
                  options: distinct((r) => r.worker.shift),
                  selected: _shift,
                  labelOf: (v) => v,
                  onSelected: (v) => setSheetState(() {
                    _shift = v;
                    setState(() {});
                  }),
                ),
                _FilterGroup<bool>(
                  label: 'Worker type',
                  options: const [false, true],
                  selected: _contractor,
                  labelOf: (v) => v ? 'Contractor' : 'Employee',
                  onSelected: (v) => setSheetState(() {
                    _contractor = v;
                    setState(() {});
                  }),
                ),
                _FilterGroup<DemoReviewState>(
                  label: 'Review state',
                  options: DemoReviewState.values,
                  selected: _reviewState,
                  labelOf: (v) => v.label,
                  onSelected: (v) => setSheetState(() {
                    _reviewState = v;
                    setState(() {});
                  }),
                ),
                const SizedBox(height: Space.base),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheetState(() {
                          _department = null;
                          _workArea = null;
                          _shift = null;
                          _contractor = null;
                          _reviewState = null;
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

/// One filter dimension. Selecting the active value again clears it.
class _FilterGroup<T extends Object> extends StatelessWidget {
  const _FilterGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T?> onSelected;

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
                  label: Text(labelOf(option)),
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

/// The review queue.
class HseReviewQueueScreen extends StatelessWidget {
  const HseReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = UiDemoCatalog.requiringReview();

    return SafetyScaffold(
      title: 'Review',
      subtitle: 'Records awaiting a decision',
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),
        if (pending.isEmpty)
          const InfoCard(child: Text('No records require review.'))
        else ...[
          SectionHeader(
            title: '${pending.length} awaiting review',
            origin: DataOrigin.uiDemo,
          ),
          for (final record in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: ExposureRecordCard(record: record),
            ),
        ],
      ],
    );
  }
}
