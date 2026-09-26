import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/info_note.dart';
import '../../../core/components/markers.dart';
import '../../../core/components/pills.dart';
import '../../../core/components/step_scaffold.dart';
import '../../../core/components/surfaces.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/async_value_x.dart';
import '../../../core/util/format.dart';
import '../application/workflow_controller.dart';
import '../domain/workflow_state.dart';
import 'widgets/provenance.dart';

/// Active monitoring — the detail view.
///
/// Shows how long the badge has been active and the full context it is attached
/// to. It shows **elapsed time only** — never a live exposure figure, because a
/// passive badge cannot produce one. The elapsed clock ticks so the screen is
/// visibly live without implying a live measurement.
class ActiveMonitoringScreen extends ConsumerStatefulWidget {
  const ActiveMonitoringScreen({super.key});

  @override
  ConsumerState<ActiveMonitoringScreen> createState() =>
      _ActiveMonitoringScreenState();
}

class _ActiveMonitoringScreenState
    extends ConsumerState<ActiveMonitoringScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;
    final ctx = session.context;
    final badge = session.assignedBadge;
    final start = session.startedAt;
    final elapsed = session.coverageAt(DateTime.now());

    return StepScaffold(
      title: 'Active monitoring',
      primaryAction: DoseBandButton.primary(
        label: 'End monitoring and read badge',
        icon: Icons.stop_circle_outlined,
        onPressed: () => context.push('/end'),
      ),
      children: [
        Row(
          children: [
            StatusPill(
              label: 'Dosimetry active',
              icon: Icons.radio_button_checked,
              colour: c.statusValid,
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        DoseBandSurface(
          measurement: true,
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elapsed',
                style: t.caption.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: Space.xs),
              Text(
                Fmt.duration(elapsed),
                style: t.readoutLarge.copyWith(color: c.textPrimary),
              ),
              if (start != null) ...[
                const SizedBox(height: Space.xs),
                Text(
                  'Since ${Fmt.clock(start)}',
                  style: t.readoutSmall.copyWith(color: c.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        DoseBandSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badge != null)
                TraceabilityRow(label: 'Badge', value: badge.badgeId),
              if (ctx != null) ...[
                TraceabilityRow(label: 'Worker', value: ctx.worker.displayName),
                TraceabilityRow(label: 'Work area', value: ctx.workArea.name),
                TraceabilityRow(label: 'Job', value: ctx.job.title),
                TraceabilityRow(label: 'Shift', value: ctx.shift.name),
                ProvenanceRow.of(
                  label: 'PTW reference',
                  value: ctx.permit.reference,
                  secondary: ctx.permit.type?.name,
                ),
                ProvenanceRow.of(
                  label: 'JSA reference',
                  value: ctx.jsa.reference,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        const OfflineMarker(pendingCount: 0),
        const SizedBox(height: Space.lg),
        const InfoNote.notAnAlarm(),
      ],
    );
  }
}
