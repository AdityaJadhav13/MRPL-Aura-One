import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart' show Refused;

import '../../core/components/markers.dart';
import '../../core/components/product_page.dart';
import '../../core/components/product_states.dart';
import '../../core/components/workspace_components.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/format.dart';
import '../operations/application/operations_providers.dart';
import '../operations/domain/measurement_state.dart';
import '../operations/domain/review.dart';
import '../operations/presentation/ops_chips.dart';
import '../workflow/application/workflow_controller.dart';
import 'application/history_controller.dart';
import 'domain/measurement_record.dart';

enum HistoryPeriod {
  week('7 days'),
  month('30 days'),
  custom('Custom');

  const HistoryPeriod(this.label);

  final String label;
}

/// Worker History (PRODUCT BUILD v1 §27, §28).
///
/// One row per monitoring period's record. Values appear only where a
/// validated result exists; every other state is a word. There is no total,
/// no average and no "lifetime" figure: individual records are kept so that a
/// validated occupational summary can be computed properly later — summing
/// unvalidated records into a dose would be a number nobody can defend.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryPeriod _period = HistoryPeriod.month;
  DateTimeRange? _custom;

  Future<void> _pickRange(DateTime now) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange:
          _custom ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked != null) {
      setState(() {
        _custom = picked;
        _period = HistoryPeriod.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final all = ref.watch(historyProvider);
    final (DateTime from, DateTime to) = switch (_period) {
      HistoryPeriod.week => (
        today.subtract(const Duration(days: 6)),
        today.add(const Duration(days: 1)),
      ),
      HistoryPeriod.month => (
        today.subtract(const Duration(days: 29)),
        today.add(const Duration(days: 1)),
      ),
      HistoryPeriod.custom => (
        _custom?.start ?? today,
        (_custom?.end ?? today).add(const Duration(days: 1)),
      ),
    };
    final records = all
        .where((r) => !r.scannedAt.isBefore(from) && r.scannedAt.isBefore(to))
        .toList();
    final view = ref.watch(workerViewProvider).value;

    return ProductPage(
      title: 'History',
      showBack: false,
      children: [
        ChoiceChips<HistoryPeriod>(
          options: HistoryPeriod.values,
          selected: _period,
          labelOf: (p) => p == HistoryPeriod.custom && _custom != null
              ? '${Fmt.date(_custom!.start)} – ${Fmt.date(_custom!.end)}'
              : p.label,
          onSelected: (p) {
            if (p == HistoryPeriod.custom) {
              _pickRange(now);
            } else {
              setState(() => _period = p);
            }
          },
        ),
        const SizedBox(height: Space.base),
        if (all.isEmpty)
          const StateView(
            kind: StateKind.empty,
            title: 'No records yet',
            message:
                'Each completed monitoring period adds one record here, after '
                'its final scan.',
          )
        else if (records.isEmpty)
          const StateView(
            kind: StateKind.noResults,
            message: 'No records in this period.',
          )
        else
          RowList(
            children: [
              for (final r in records)
                _HistoryRow(record: r, reviewed: view?.reviewOf(r)),
            ],
          ),
        const SizedBox(height: Space.base),
        Text(
          '${records.length} record${records.length == 1 ? '' : 's'} shown. '
          'Records are kept individually; no totals are calculated.',
          style: context.type.caption.copyWith(
            color: context.product.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, required this.reviewed});

  final MeasurementRecord record;
  final HseReview? reviewed;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final r = record;
    final review = reviewed;
    return InkWell(
      onTap: () => context.push('/history/record/${r.id}', extra: r),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTouchTarget),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Fmt.date(r.scannedAt)} · ${r.context.shift.name}',
                      style: t.bodyStrong.copyWith(color: p.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.badge.badgeId} · ${Fmt.duration(r.endedAt.isBefore(r.startedAt) ? null : r.coverage)}',
                      style: t.readoutSmall.copyWith(color: p.textSecondary),
                    ),
                    // The value (or censoring bound) only where one exists;
                    // otherwise the state chip below says everything.
                    if (r.result is! Refused) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        MeasurementStateText.exposureCell(r.result),
                        style: t.body.copyWith(color: p.textPrimary),
                      ),
                    ],
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        MeasurementStateChip(r.result),
                        if (review != null) ReviewStateChip(review.state),
                        if (r.badge.isSimulated) const SimulationMarker(),
                        if (r.isPresentation) const PresentationTag(),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
