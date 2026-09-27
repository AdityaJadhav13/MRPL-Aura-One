import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/step_scaffold.dart';
import '../../../core/components/surfaces.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/async_value_x.dart';
import '../../../core/util/format.dart';
import '../application/workflow_controller.dart';
import '../domain/workflow_state.dart';

/// End monitoring confirmation.
///
/// Ending the period is a one-way step: the badge stops accruing and must be
/// read. It is not destructive (no data is lost), so it is a primary action, not
/// a red one — but it is confirmed because the next thing is the final scan.
class EndMonitoringScreen extends ConsumerWidget {
  const EndMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colours;
    final t = context.type;
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;
    final badge = session.assignedBadge;
    final elapsed = session.coverageAt(DateTime.now());

    return StepScaffold(
      title: 'End monitoring',
      primaryAction: DoseBandButton.primary(
        label: 'End monitoring and scan',
        icon: Icons.arrow_forward,
        onPressed: () async {
          try {
            await ref.read(shiftSessionProvider.notifier).endMonitoring();
          } on Object catch (e) {
            // The period changed elsewhere (closed by a supervisor, or the
            // band was reported). Reload from the store rather than guess.
            ref.invalidate(shiftSessionProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Monitoring could not be ended: $e')),
              );
              context.go('/home');
            }
            return;
          }
          if (!context.mounted) return;
          // A registered DoseBand is identified by its QR before the final
          // photograph, so the reading is attached to the band actually worn.
          final registered = session.sessionId != null;
          context.push(registered ? '/doseband/scan?purpose=final' : '/read');
        },
      ),
      secondaryAction: DoseBandButton.secondary(
        label: 'Keep monitoring',
        onPressed: () => context.pop(),
      ),
      children: [
        Text(
          'This ends the monitored period. The badge stops accruing exposure and '
          'is read next.',
          style: t.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.lg),
        DoseBandSurface(
          child: Column(
            children: [
              if (badge != null)
                TraceabilityRow(label: 'Badge', value: badge.badgeId),
              if (session.startedAt != null)
                TraceabilityRow(
                  label: 'Started',
                  value: Fmt.clock(session.startedAt!),
                ),
              TraceabilityRow(label: 'Coverage', value: Fmt.duration(elapsed)),
            ],
          ),
        ),
      ],
    );
  }
}
