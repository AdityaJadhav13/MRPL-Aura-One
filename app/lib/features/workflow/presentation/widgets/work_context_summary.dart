import 'package:flutter/material.dart';

import '../../../../core/components/surfaces.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/util/format.dart';
import '../../domain/badge_specimen.dart';
import '../../domain/work_context.dart';
import '../../domain/worker_identity.dart';
import '../../domain/workflow_state.dart';
import 'provenance.dart';

/// The work context as the worker sees it on Home.
///
/// Grouped the way the question is actually asked on a refinery floor:
///
/// > Who am I? Where am I working? What job context? Which badge? What next?
///
/// Each group is a heading with a few rows under it, rather than one long list
/// of labelled values — a worker glancing at this between tasks needs to land
/// on the right group first and read the value second.
///
/// Referenced values keep their provenance chip. On a screen summarising the
/// context, a bare permit number would be the easiest place of all to forget
/// that nothing checked it.
class WorkContextSummary extends StatelessWidget {
  const WorkContextSummary({
    required this.session,
    this.showMonitoring = true,
    super.key,
  });

  final ShiftSession session;

  /// Whether to include the monitoring group. Suppressed where the calling
  /// screen already states the monitoring state more prominently.
  final bool showMonitoring;

  @override
  Widget build(BuildContext context) {
    final ctx = session.context;
    final badge = session.assignedBadge;
    if (ctx == null && badge == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ctx != null) ...[
          _Group(
            title: 'Worker',
            children: [
              TraceabilityRow(label: 'Name', value: ctx.worker.displayName),
              TraceabilityRow(label: 'Worker ID', value: ctx.worker.workerId),
              TraceabilityRow(
                label: 'Type',
                value: ctx.worker.workerType.label,
              ),
              // Shown only for a contractor: an employee has no employing
              // contractor, and an empty row invites someone to fill it in.
              if (ctx.worker.workerType == WorkerType.contractor &&
                  ctx.worker.contractorCompany != null)
                TraceabilityRow(
                  label: 'Contractor',
                  value: ctx.worker.contractorCompany!,
                ),
              if (ctx.worker.gatePass case final g?)
                ProvenanceRow.of(label: 'Gate pass', value: g),
            ],
          ),
          _Group(
            title: "Today's work",
            children: [
              TraceabilityRow(label: 'Site', value: ctx.site.name),
              TraceabilityRow(label: 'Department', value: ctx.department.name),
              TraceabilityRow(label: 'Work area', value: ctx.workArea.name),
              TraceabilityRow(label: 'Shift', value: ctx.shift.name),
            ],
          ),
          _Group(
            title: 'Work context',
            children: [
              TraceabilityRow(label: 'Job / activity', value: ctx.job.title),
              if (ctx.job.workOrder case final w?)
                TraceabilityRow(label: 'Work order', value: w),
              ProvenanceRow.of(
                label: 'PTW reference',
                value: ctx.permit.reference,
                secondary: ctx.permit.type?.name,
              ),
              ProvenanceRow.of(
                label: 'JSA reference',
                value: ctx.jsa.reference,
              ),
              _ToolboxRow(workContext: ctx),
            ],
          ),
        ],
        if (badge != null)
          _Group(
            title: 'DoseBand',
            children: [
              TraceabilityRow(label: 'Badge', value: badge.badgeId),
              TraceabilityRow(label: 'Lot', value: badge.batch ?? Fmt.noValue),
              TraceabilityRow(
                label: 'Status',
                value: switch (badge) {
                  BadgeSpecimen(:final validity) =>
                    validity.eligible
                        ? 'Assigned'
                        : 'Not usable — see verification',
                  _ => 'Assigned · ${badge.identityProvenance}',
                },
              ),
            ],
          ),
        if (showMonitoring)
          _Group(
            title: 'Monitoring',
            children: [
              TraceabilityRow(
                label: 'State',
                value: _monitoringLabel(session.stage),
              ),
            ],
          ),
      ],
    );
  }

  /// Plain descriptions of where the workflow has reached.
  ///
  /// None of these may read as a verdict on the work. "Ready for dosimetry"
  /// is the strongest thing said here and it is a statement about DoseBand's
  /// own readiness, not about the job or the atmosphere.
  static String _monitoringLabel(ShiftStage stage) =>
      WorkContextSummaryLabels.forStage(stage);
}

class _ToolboxRow extends StatelessWidget {
  const _ToolboxRow({required this.workContext});

  final WorkContext workContext;

  @override
  Widget build(BuildContext context) {
    final tb = workContext.toolboxTalk;
    return ProvenanceRow(
      label: 'Toolbox talk',
      // Deliberately describes what happened — a worker acknowledged something
      // on a phone — rather than asserting that the talk occurred.
      value: 'Acknowledged',
      source: tb.source,
      secondary: tb.reference,
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: t.caption.copyWith(
              color: c.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: Space.sm),
          DoseBandSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// The monitoring-state vocabulary, exposed so it can be asserted on.
///
/// These strings are a safety boundary: none of them may read as a verdict on
/// the work, the permit or the atmosphere. `test/workflow/safety_language_test.dart`
/// checks every one of them, which only works if they are reachable from a
/// test — hence a named surface rather than a private method.
abstract final class WorkContextSummaryLabels {
  static String forStage(ShiftStage stage) => switch (stage) {
    ShiftStage.noShift => 'Not started',
    ShiftStage.contextSet => 'Work context recorded',
    ShiftStage.badgeAssigned => 'Badge assigned',
    ShiftStage.readyForDosimetry => 'Ready for dosimetry',
    ShiftStage.monitoring => 'Monitoring active',
    ShiftStage.awaitingScan => 'Awaiting badge scan',
    ShiftStage.complete => 'Reading complete',
  };

  /// Every label a worker can be shown.
  static List<String> get all =>
      ShiftStage.values.map(forStage).toList(growable: false);
}
