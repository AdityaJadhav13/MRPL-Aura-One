import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/checklist.dart';
import '../../../core/components/info_note.dart';
import '../../../core/components/step_scaffold.dart';
import '../../../core/components/surfaces.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../application/workflow_controller.dart';
import '../../../core/util/async_value_x.dart';
import '../domain/badge_specimen.dart';
import '../domain/workflow_state.dart';

/// Badge verification.
///
/// Shows the badge's identity and the pre-assignment checks. Assignment is
/// gated on eligibility: an ineligible badge (expired, unsupported) cannot be
/// carried into a monitored period. The block is stated plainly, not alarmed —
/// a refused badge is the system working correctly.
class BadgeVerificationScreen extends ConsumerWidget {
  const BadgeVerificationScreen({required this.specimen, super.key});

  final BadgeSpecimen specimen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colours;
    final t = context.type;
    final validity = specimen.validity;
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;

    // Reaching this screen during monitoring means a stale route or a back
    // stack, not a decision. The controller would throw on assignment; the
    // worker should be told why instead of meeting a crash.
    final locked = session.contextIsLocked;

    return StepScaffold(
      title: 'Verify badge',
      primaryAction: locked
          ? null
          : validity.eligible
          ? DoseBandButton.primary(
              label: 'Assign this badge',
              icon: Icons.check,
              onPressed: () async {
                await ref
                    .read(shiftSessionProvider.notifier)
                    .assignBadge(specimen);
                if (context.mounted) context.push('/prework');
              },
            )
          : DoseBandButton.secondary(
              label: 'Choose another badge',
              icon: Icons.arrow_back,
              onPressed: () => context.pop(),
            ),
      children: [
        if (locked) ...[
          DoseBandSurface(
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: c.textSecondary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'Monitoring is in progress, so the assigned badge is part '
                    'of the exposure record and cannot be changed. End the '
                    'monitored period to assign a different badge.',
                    style: t.body.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
        ],
        DoseBandSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TraceabilityRow(label: 'Badge', value: specimen.badgeId),
              TraceabilityRow(label: 'Lot', value: specimen.lot),
              TraceabilityRow(
                label: 'Formulation',
                value: specimen.formulation,
              ),
              TraceabilityRow(
                label: 'Calibration',
                value: specimen.calibrationModelId,
              ),
              TraceabilityRow(
                label: 'Expiry',
                value: Fmt.date(specimen.expiry),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(
          'Verification checks',
          style: t.label.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: Space.sm),
        DoseBandSurface(
          child: ValidationChecklist(
            items: [
              for (final check in validity.checks)
                ChecklistItem(
                  label: check.label,
                  passed: check.passed,
                  detail: check.detail,
                ),
            ],
          ),
        ),
        if (!validity.eligible) ...[
          const SizedBox(height: Space.lg),
          InfoNote(
            icon: Icons.block,
            text:
                'This badge cannot be assigned. Fit a badge that passes every '
                'check before starting a monitored period.',
          ),
        ],
      ],
    );
  }
}
