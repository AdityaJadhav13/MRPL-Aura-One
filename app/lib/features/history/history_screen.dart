import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart';

import '../../core/components/pills.dart';
import '../../core/components/states.dart';
import '../../core/design/status_presentation.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/format.dart';
import '../result/result_presentation.dart';
import 'application/history_controller.dart';
import 'domain/measurement_record.dart';

/// Exposure history.
///
/// A restrained timeline of completed measurements. Numeric, below-range,
/// above-range and no-reading records are told apart by icon and label, never by
/// colour alone. Every record is simulated in this phase and marked so; the data
/// domain is never ambiguous (directive §21/§65).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Filter { all, valid, belowRange, aboveRange, noReading }

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _Filter _filter = _Filter.all;

  bool _matches(MeasurementRecord r) {
    final s = r.result.status;
    return switch (_filter) {
      _Filter.all => true,
      _Filter.valid => s.carriesDose,
      _Filter.belowRange => s == ResultStatus.belowQuantificationLimit,
      _Filter.aboveRange =>
        s.isCensored && s != ResultStatus.belowQuantificationLimit,
      _Filter.noReading => s.isRefusal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final all = ref.watch(historyProvider);
    final records = all.where(_matches).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: all.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No measurements yet',
              message:
                  'Completed badge readings appear here. Start a monitored '
                  'period from Home to create one.',
            )
          : Column(
              children: [
                _FilterBar(
                  active: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                Expanded(
                  child: records.isEmpty
                      ? const EmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'Nothing matches',
                          message: 'No records match this filter.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(Space.base),
                          itemCount: records.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: Space.sm),
                          itemBuilder: (_, i) =>
                              _HistoryRow(record: records[i]),
                        ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.base,
                    vertical: Space.sm,
                  ),
                  color: c.surfaceSunken,
                  child: Text(
                    'All records are simulated data.',
                    style: context.type.caption.copyWith(
                      color: c.statusSimulated,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.active, required this.onChanged});

  final _Filter active;
  final ValueChanged<_Filter> onChanged;

  static const _labels = {
    _Filter.all: 'All',
    _Filter.valid: 'Valid',
    _Filter.belowRange: 'Below range',
    _Filter.aboveRange: 'Above range',
    _Filter.noReading: 'No reading',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.base),
        children: [
          for (final entry in _labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm, top: Space.sm),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: active == entry.key,
                showCheckmark: false,
                labelStyle: context.type.label.copyWith(
                  color: active == entry.key ? c.textOnAccent : c.textSecondary,
                ),
                backgroundColor: c.surfaceElevated,
                selectedColor: c.measurementAccent,
                side: BorderSide(color: c.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                onSelected: (_) => onChanged(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final MeasurementRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final status = record.result.status;
    final p = StatusPresentation.of(status, c);
    final view = ResultView.of(record.result);
    final readout = view.value == null
        ? '- - -'
        : '${view.prefix ?? ''}${view.value}';

    return Material(
      color: c.surfaceElevated,
      borderRadius: BorderRadius.circular(Radii.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.control),
        onTap: () => context.push('/measurement', extra: record),
        child: Container(
          padding: const EdgeInsets.all(Space.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusPill(label: p.label, icon: p.icon, colour: p.colour),
                  Text(
                    '$readout ${status.carriesDose ? 'ppm·h' : ''}',
                    style: t.readoutBody.copyWith(color: c.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    record.badge.badgeId,
                    style: t.readoutSmall.copyWith(color: c.textSecondary),
                  ),
                  Text(
                    Fmt.stamp(record.scannedAt),
                    style: t.caption.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
