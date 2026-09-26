import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/checklist.dart';
import '../../../core/components/info_note.dart';
import '../../../core/components/pills.dart';
import '../../../core/components/step_scaffold.dart';
import '../../../core/components/surfaces.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/async_value_x.dart';
import '../../../core/util/format.dart';
import '../application/workflow_controller.dart';
import '../domain/badge_specimen.dart';
import '../domain/physical_badge.dart';
import '../application/work_context_controller.dart';
import '../domain/work_context_validator.dart';
import '../domain/worker_identity.dart';
import '../domain/workflow_state.dart';

/// Pre-work dosimetry check.
///
/// Confirms the DoseBand workflow is ready — and only that. The final state is
/// "Ready for dosimetry", never "Safe to work": this screen says nothing about
/// whether the environment or the worker is safe. That distinction is the whole
/// product (directive §11).
class PreWorkCheckScreen extends ConsumerWidget {
  const PreWorkCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colours;
    final t = context.type;
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;

    final readiness = ref.watch(workContextReadinessProvider);
    final badge = session.assignedBadge;

    // The checklist is rendered from the single validation policy, not from
    // its own null checks. A requirement added to WorkContextValidator appears
    // here automatically; one removed cannot linger here pretending to be
    // enforced.
    final checks = [
      for (final requirement in WorkContextRequirement.values)
        if (_isApplicable(requirement, ref))
          ChecklistItem(
            label: requirement.label,
            passed: !readiness.isMissing(requirement),
            detail: _detailFor(requirement, ref),
          ),
    ];
    final ready = readiness.isReady;

    return StepScaffold(
      title: 'Pre-work check',
      primaryAction: DoseBandButton.primary(
        label: 'Start monitoring',
        icon: Icons.play_arrow,
        onPressed: ready ? () => _confirmStart(context, ref, badge) : null,
      ),
      children: [
        DoseBandSurface(child: ValidationChecklist(items: checks)),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            if (ready)
              const StatusPill(
                label: 'Ready for dosimetry',
                icon: Icons.verified_outlined,
                colour: Color(0xFF0E6E7D),
              )
            else
              StatusPill(
                label: 'Not ready',
                icon: Icons.pending_outlined,
                colour: c.textSecondary,
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(
          'Ready for dosimetry confirms that DoseBand monitoring information is '
          'complete. It does not authorise work and does not replace PTW, JSA '
          'or site safety requirements. It says nothing about whether the area '
          'or the work is safe.',
          style: t.body.copyWith(color: c.textSecondary),
        ),
        if (readiness.warnings.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          for (final w in readiness.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: c.textSecondary),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      w.message,
                      style: t.caption.copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: Space.lg),
        const InfoNote.notAnAlarm(),
      ],
    );
  }

  /// Contractor company is only a requirement for a contractor, so showing it
  /// to an employee as a permanently-passing tick would be noise.
  static bool _isApplicable(WorkContextRequirement r, WidgetRef ref) {
    if (r != WorkContextRequirement.contractorCompany) return true;
    final worker = ref.read(workContextDraftProvider).worker;
    return worker?.workerType == WorkerType.contractor;
  }

  /// The value that satisfied a requirement, so a worker can see *what* was
  /// recorded rather than only that something was.
  static String? _detailFor(WorkContextRequirement r, WidgetRef ref) {
    final draft = ref.read(workContextDraftProvider);
    final badge = ref.read(shiftSessionProvider).dataOrNull?.assignedBadge;
    return switch (r) {
      WorkContextRequirement.workerIdentity => draft.worker?.displayName,
      WorkContextRequirement.contractorCompany =>
        draft.worker?.contractorCompany,
      WorkContextRequirement.site => draft.site?.name,
      WorkContextRequirement.department => draft.department?.name,
      WorkContextRequirement.workArea => draft.workArea?.name,
      WorkContextRequirement.shift => draft.shift?.name,
      WorkContextRequirement.job => draft.job?.title,
      WorkContextRequirement.permitReference => draft.permit?.reference.value,
      WorkContextRequirement.jsaReference => draft.jsa?.reference.value,
      WorkContextRequirement.toolboxTalk =>
        draft.toolboxTalk == null ? null : 'Acknowledged on this device',
      WorkContextRequirement.badgeAssigned => badge?.badgeId,
      WorkContextRequirement.badgeUsable => switch (badge) {
        BadgeSpecimen(:final calibrationModelId) => calibrationModelId,
        // Said plainly: nothing about a hand-typed badge could be checked.
        PhysicalBadge() =>
          'Not verified — manual entry. Batch, calibration, prior use and '
              'expiry cannot be checked without an inventory.',
        _ => null,
      },
    };
  }

  Future<void> _confirmStart(
    BuildContext context,
    WidgetRef ref,
    BadgeIdentity? badge,
  ) async {
    final c = context.colours;
    final t = context.type;
    final now = DateTime.now();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start monitored period',
                style: t.heading.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: Space.sm),
              Text(
                'The badge becomes active now. Wear it for the whole period, then '
                'end and read it.',
                style: t.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: Space.base),
              DoseBandSurface(
                child: Column(
                  children: [
                    TraceabilityRow(
                      label: 'Badge',
                      value: badge?.badgeId ?? '—',
                    ),
                    TraceabilityRow(label: 'Start', value: Fmt.clock(now)),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              DoseBandButton.primary(
                label: 'Start now',
                icon: Icons.play_arrow,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: Space.sm),
              DoseBandButton.secondary(
                label: 'Not yet',
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    final notifier = ref.read(shiftSessionProvider.notifier);
    await notifier.confirmPreWork();
    await notifier.startMonitoring();
    if (context.mounted) context.go('/home');
  }
}
