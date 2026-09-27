import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/product_page.dart';
import '../../../core/components/product_states.dart';
import '../../../core/components/product_status.dart';
import '../../../core/components/workspace_components.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../core/util/format.dart';
import '../../account/presentation/workspace_more_screen.dart';
import '../../operations/application/day_status.dart';
import '../../operations/application/management_service.dart';
import '../../operations/application/operations_providers.dart';
import '../../operations/domain/inventory.dart';

const _origin =
    'Aggregated from the operations records on this device. De-identified: '
    'no names, IDs or photographs. Cells under three are withheld.';

/// Why there is no exposure average, total or trend line (§43).
class _ExposureWithheld extends StatelessWidget {
  const _ExposureWithheld();

  @override
  Widget build(BuildContext context) => const StatusBanner(
    tone: StatusTone.info,
    icon: Icons.science_outlined,
    title: 'Exposure statistics are withheld',
    message:
        'No validated H₂S calibration exists, so there are no exposure values '
        'to summarise. Averages and totals are not calculated from '
        'unvalidated readings.',
  );
}

/// Management overview — organisational and de-identified (§42, §43).
class ManagementOverviewScreen extends ConsumerWidget {
  const ManagementOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'Overview',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(managementViewProvider),
          builder: (context, v) {
            final o = v.overview(now);
            final coverage = o.expectedWorkers == 0
                ? Fmt.noValue
                : '${o.startedToday} of ${o.expectedWorkers}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  Fmt.date(now),
                  style: context.type.body.copyWith(
                    color: context.product.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.base),
                CountGrid(
                  tiles: [
                    CountTile(
                      label: 'Monitoring coverage today',
                      value: coverage,
                    ),
                    CountTile(
                      label: 'Completed today',
                      value: '${o.byStatus[WorkerDayStatus.completed] ?? 0}',
                    ),
                    CountTile(
                      label: 'Incomplete or needing attention',
                      value: '${o.byStatus[WorkerDayStatus.exception] ?? 0}',
                    ),
                    CountTile(
                      label: 'HSE review backlog',
                      value: '${o.reviewBacklog}',
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.section),
                const _ExposureWithheld(),
                const SizedBox(height: Gaps.section),
                PageSection(
                  title: 'DoseBand utilisation',
                  children: [_Buckets(counts: o.bandUtilisation)],
                ),
                const DataOriginNote(_origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Buckets extends StatelessWidget {
  const _Buckets({required this.counts});

  final Map<InventoryBucket, int> counts;

  @override
  Widget build(BuildContext context) => SectionCard(
    children: [
      for (final b in InventoryBucket.values)
        FactRow(label: b.label, value: '${counts[b] ?? 0}'),
    ],
  );
}

/// Monitoring completion, state distribution and work areas — every cell
/// de-identified and small cells withheld (§59).
class ManagementMonitoringScreen extends ConsumerWidget {
  const ManagementMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'Monitoring',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(managementViewProvider),
          builder: (context, v) {
            final o = v.overview(now);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageSection(
                  title: 'Today, by monitoring state',
                  children: [
                    SectionCard(
                      children: [
                        for (final s in WorkerDayStatus.values)
                          FactRow(
                            label: s.label,
                            value: '${o.byStatus[s] ?? 0}',
                          ),
                      ],
                    ),
                  ],
                ),
                PageSection(
                  title: 'Records, last 30 days (${o.recordsLast30Days})',
                  children: [
                    if (o.stateDistribution.isEmpty)
                      const StateView(
                        kind: StateKind.empty,
                        message: 'No measurement records in the last 30 days.',
                        compact: true,
                      )
                    else
                      SectionCard(
                        children: [
                          for (final e in o.stateDistribution.entries)
                            FactRow(label: e.key, value: e.value.display),
                        ],
                      ),
                  ],
                ),
                PageSection(
                  title: 'By work area, last 30 days',
                  children: [
                    if (o.workAreas.isEmpty)
                      const StateView(
                        kind: StateKind.empty,
                        message: 'No monitoring periods in the last 30 days.',
                        compact: true,
                      )
                    else
                      RowList(
                        children: [
                          for (final a in o.workAreas) _AreaRow(area: a),
                        ],
                      ),
                  ],
                ),
                const DataOriginNote(_origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({required this.area});

  final WorkAreaSummary area;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            area.workArea,
            style: t.bodyStrong.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Periods ${area.periods.display} · read ${area.completed.display} '
            '· no reading ${area.noReading.display}',
            style: t.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Operational trend — monitoring periods started and completed per day. Not
/// exposure: there are no validated exposure values to trend (§43).
class ManagementTrendsScreen extends ConsumerWidget {
  const ManagementTrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'Trends',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(managementViewProvider),
          builder: (context, v) {
            final days = v.trend(now);
            final max = days.fold<int>(
              1,
              (m, d) =>
                  [m, d.started, d.completed].reduce((a, b) => a > b ? a : b),
            );
            final empty = days.every((d) => d.started == 0 && d.completed == 0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ExposureWithheld(),
                const SizedBox(height: Gaps.section),
                PageSection(
                  title: 'Monitoring activity, last 14 days',
                  children: [
                    if (empty)
                      const StateView(
                        kind: StateKind.empty,
                        message: 'No monitoring activity in this period.',
                        compact: true,
                      )
                    else
                      SectionCard(
                        children: [
                          for (final d in days) _DayBar(day: d, max: max),
                          const SizedBox(height: Space.sm),
                          const _Legend(),
                        ],
                      ),
                  ],
                ),
                const DataOriginNote(_origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.day, required this.max});

  final DayCount day;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    Widget bar(int n, Color colour) => LayoutBuilder(
      builder: (context, c) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: n == 0 ? 2 : c.maxWidth * n / max,
          height: 8,
          color: n == 0 ? p.borderSubtle : colour,
        ),
      ),
    );
    return Semantics(
      label:
          '${Fmt.date(day.day)}: ${day.started} started, '
          '${day.completed} read',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                '${day.day.day}/${day.day.month}',
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  bar(day.started, p.info),
                  const SizedBox(height: 2),
                  bar(day.completed, p.textSecondary),
                ],
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '${day.started}/${day.completed}',
                textAlign: TextAlign.end,
                style: t.readoutSmall.copyWith(color: p.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    Widget key(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 8, color: c),
        const SizedBox(width: Space.xs),
        Text(label, style: t.caption.copyWith(color: p.textSecondary)),
      ],
    );
    return Wrap(
      spacing: Space.base,
      children: [
        key(p.info, 'Periods started'),
        key(p.textSecondary, 'Periods read'),
      ],
    );
  }
}

/// De-identified reports. The one report here is built from the same
/// aggregate the screens show, so it cannot say more than they do.
class ManagementReportsScreen extends ConsumerWidget {
  const ManagementReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'Reports',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(managementViewProvider),
          builder: (context, v) {
            final csv = ManagementReport.coverageCsv(v, now);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageSection(
                  title: 'Monitoring coverage summary',
                  children: [
                    SectionCard(
                      children: [
                        Text(
                          'De-identified. Daily periods started and read, and '
                          'today’s state counts. No names, IDs, DoseBand '
                          'numbers or exposure values.',
                          style: context.type.body.copyWith(
                            color: context.product.textPrimary,
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        SelectableText(
                          csv,
                          style: context.type.readoutSmall.copyWith(
                            color: context.product.textPrimary,
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        DoseBandButton.secondary(
                          label: 'Copy CSV',
                          icon: Icons.copy,
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: csv));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Report copied as CSV.'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const StatusBanner(
                  tone: StatusTone.info,
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'PDF export is not available in this build',
                  message:
                      'Reports can be copied as CSV. No report is sent '
                      'anywhere, and nothing here is an authoritative '
                      'organisational report.',
                ),
                const SizedBox(height: Space.base),
                const DataOriginNote(_origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

abstract final class ManagementReport {
  /// The coverage summary as CSV. Built only from [ManagementView], which
  /// carries no identity, so the CSV cannot contain one.
  static String coverageCsv(ManagementView v, DateTime now) {
    final o = v.overview(now);
    final b = StringBuffer()
      ..writeln('section,key,value')
      ..writeln('today,expected_workers,${o.expectedWorkers}');
    for (final s in WorkerDayStatus.values) {
      b.writeln('today,${s.name},${o.byStatus[s] ?? 0}');
    }
    for (final d in v.trend(now)) {
      final day =
          '${d.day.year}-${d.day.month.toString().padLeft(2, '0')}-'
          '${d.day.day.toString().padLeft(2, '0')}';
      b
        ..writeln('daily,$day.started,${d.started}')
        ..writeln('daily,$day.read,${d.completed}');
    }
    b.writeln('exposure,statistics,withheld — no validated calibration');
    return b.toString();
  }
}

class ManagementMoreScreen extends StatelessWidget {
  const ManagementMoreScreen({super.key});

  @override
  Widget build(BuildContext context) => const WorkspaceMoreScreen();
}
