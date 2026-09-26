import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/corporate.dart';
import '../../../core/components/step_scaffold.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/async_value_x.dart';
import '../../../core/util/format.dart';
import '../application/workflow_controller.dart';
import '../domain/work_context.dart';
import '../domain/worker_identity.dart';
import '../domain/workflow_state.dart';
import 'widgets/provenance.dart';

/// The read-only detail screens behind Home's context cards.
///
/// Each one answers a single question — who am I, where am I working, which
/// permit — and every one of them reads the **committed** work context from
/// the session. None of them edits: editing happens in the work-context form,
/// which is the only writer and which locks itself once monitoring starts.
///
/// They exist because Home has to stay glanceable. A worker who wants the full
/// permit record should be able to reach it without the dashboard trying to
/// show everything at once.

/// Shared frame: a corporate step with an empty state when no context exists.
class _ContextDetail extends ConsumerWidget {
  const _ContextDetail({
    required this.title,
    required this.emptyMessage,
    required this.builder,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> Function(BuildContext, WorkContext) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;
    final workContext = session.context;

    return StepScaffold(
      title: title,
      simulated: false,
      children: workContext == null
          ? [
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nothing recorded yet',
                      style: context.type.bodyStrong.copyWith(
                        color: context.corporate.textPrimary,
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      emptyMessage,
                      style: context.type.body.copyWith(
                        color: context.corporate.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Space.base),
                    DoseBandButton.secondary(
                      label: 'Open work context',
                      icon: Icons.arrow_forward,
                      onPressed: () => context.push('/work-context'),
                    ),
                  ],
                ),
              ),
            ]
          : builder(context, workContext),
    );
  }
}

/// Everything about this monitored period, in one place.
class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;
    final c = session.context;
    final now = DateTime.now();

    return StepScaffold(
      title: 'Shift',
      simulated: false,
      primaryAction: session.isActive
          ? DoseBandButton.primary(
              label: 'End monitoring',
              icon: Icons.stop_circle_outlined,
              onPressed: () => context.push('/end'),
            )
          : null,
      children: [
        if (c == null)
          const InfoCard(
            child: Text(
              'No monitored period has been started. Record a work context to '
              'begin.',
            ),
          )
        else ...[
          const SectionHeader(title: 'Worker'),
          InfoCard(
            onTap: () => context.push('/worker-identity'),
            child: Column(
              children: [
                RecordRow(label: 'Name', value: c.worker.displayName),
                RecordRow(
                  label: 'Worker ID',
                  value: c.worker.workerId,
                  mono: true,
                ),
                RecordRow(label: 'Type', value: c.worker.workerType.label),
                if (c.worker.contractorCompany case final company?)
                  RecordRow(label: 'Contractor', value: company),
              ],
            ),
          ),

          const SectionHeader(title: 'Location'),
          InfoCard(
            onTap: () => context.push('/work-area'),
            child: Column(
              children: [
                RecordRow(label: 'Site', value: c.site.name),
                RecordRow(label: 'Department', value: c.department.name),
                RecordRow(label: 'Work area', value: c.workArea.name),
                RecordRow(
                  label: 'Shift',
                  value: c.shift.window == null
                      ? c.shift.name
                      : '${c.shift.name} · ${c.shift.window}',
                ),
              ],
            ),
          ),

          const SectionHeader(title: 'Job'),
          InfoCard(
            child: Column(
              children: [
                RecordRow(label: 'Activity', value: c.job.title),
                if (c.job.workOrder case final order?)
                  RecordRow(label: 'Work order', value: order, mono: true),
                if (c.job.supervisor case final supervisor?)
                  RecordRow(label: 'Supervisor', value: supervisor),
              ],
            ),
          ),

          const SectionHeader(title: 'External references'),
          InfoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                NavigationRow(
                  icon: Icons.assignment_outlined,
                  title: 'Permit to Work',
                  subtitle: c.permit.reference.value,
                  onTap: () => context.push('/ptw'),
                ),
                _Sep(),
                NavigationRow(
                  icon: Icons.fact_check_outlined,
                  title: 'Job Safety Analysis',
                  subtitle: c.jsa.reference.value,
                  onTap: () => context.push('/jsa'),
                ),
                _Sep(),
                NavigationRow(
                  icon: Icons.groups_outlined,
                  title: 'Toolbox talk',
                  subtitle: 'Acknowledged',
                  onTap: () => context.push('/toolbox'),
                ),
              ],
            ),
          ),

          const SectionHeader(title: 'DoseBand'),
          InfoCard(
            // The traceability screen describes a simulated specimen's
            // supply chain, so only a specimen links to it.
            onTap: session.badge == null
                ? null
                : () => context.push('/traceability'),
            child: Column(
              children: [
                RecordRow(
                  label: 'Badge',
                  value: session.assignedBadge?.badgeId ?? 'Not assigned',
                  mono: session.assignedBadge != null,
                ),
                RecordRow(
                  label: 'Lot',
                  value: session.assignedBadge?.batch ?? Fmt.noValue,
                  mono: session.assignedBadge?.batch != null,
                ),
                if (session.physicalBadge case final physical?)
                  RecordRow(
                    label: 'Identity',
                    value: physical.identityProvenance,
                  ),
              ],
            ),
          ),

          const SectionHeader(title: 'Monitoring window'),
          InfoCard(
            child: Column(
              children: [
                RecordRow(
                  label: 'Started',
                  value: session.startedAt == null
                      ? 'Not started'
                      : Fmt.stamp(session.startedAt!),
                  mono: session.startedAt != null,
                ),
                RecordRow(
                  label: 'Ended',
                  value: session.endedAt == null
                      ? Fmt.noValue
                      : Fmt.stamp(session.endedAt!),
                  mono: session.endedAt != null,
                ),
                // Null coverage prints the refusal placeholder, never zero.
                RecordRow(
                  label: 'Covered',
                  value: Fmt.duration(session.coverageAt(now)),
                  mono: true,
                ),
              ],
            ),
          ),
        ],
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

/// Who this monitored period belongs to.
class WorkerIdentityScreen extends StatelessWidget {
  const WorkerIdentityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ContextDetail(
      title: 'Worker identity',
      emptyMessage:
          'Your identity is captured when you record a work context, and is '
          'then frozen for that monitored period.',
      builder: (context, c) => [
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Name', value: c.worker.displayName),
              RecordRow(
                label: 'Worker ID',
                value: c.worker.workerId,
                mono: true,
              ),
              RecordRow(label: 'Employment', value: c.worker.workerType.label),
              if (c.worker.workerType == WorkerType.contractor)
                RecordRow(
                  label: 'Contractor',
                  value: c.worker.contractorCompany ?? Fmt.noValue,
                ),
              RecordRow(
                label: 'Identity source',
                value: c.worker.source.explanation,
                origin: DataOrigin.uiDemo,
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Assignment'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Site', value: c.site.name),
              RecordRow(label: 'Department', value: c.department.name),
              RecordRow(label: 'Shift', value: c.shift.name),
            ],
          ),
        ),
        const SectionHeader(title: 'Gate pass'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.worker.gatePass case final pass?)
                ProvenanceRow.of(label: 'Gate pass', value: pass)
              else
                const RecordRow(label: 'Gate pass', value: 'Not provided'),
              const SizedBox(height: Space.xs),
              Text(
                'A gate pass is issued by site security. DoseBand records the '
                'reference you gave it and cannot confirm that the pass '
                'exists or is valid.',
                style: context.type.caption.copyWith(
                  color: context.corporate.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        _FrozenNote(),
      ],
    );
  }
}

/// Says why these values cannot be edited here.
class _FrozenNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    return InfoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 17, color: corporate.textSecondary),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              'These values were captured when the work context was recorded '
              'and belong to this monitored period. They are changed in the '
              'work-context form, and not at all once monitoring has started.',
              style: context.type.caption.copyWith(
                color: corporate.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the work is taking place.
class WorkAreaScreen extends StatelessWidget {
  const WorkAreaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ContextDetail(
      title: 'Work area',
      emptyMessage: 'Select a work area in the work-context form.',
      builder: (context, c) => [
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Site', value: c.site.name),
              RecordRow(label: 'Site ID', value: c.site.id, mono: true),
              RecordRow(label: 'Department', value: c.department.name),
              RecordRow(label: 'Work area', value: c.workArea.name),
              RecordRow(label: 'Area ID', value: c.workArea.id, mono: true),
              RecordRow(
                label: 'Source',
                value: 'Prototype configuration',
                origin: DataOrigin.uiDemo,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'The work area records where this monitored period took place. '
            'DoseBand stores no hazard classification for an area: where the '
            'work happens says nothing about what the atmosphere contains, '
            'and treating it as though it did would be an invented '
            'measurement.',
            style: context.type.caption.copyWith(
              color: context.corporate.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The permit this period is attached to.
class PtwReferenceScreen extends StatelessWidget {
  const PtwReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ContextDetail(
      title: 'Permit to Work',
      emptyMessage: 'Record a PTW reference in the work-context form.',
      builder: (context, c) => [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProvenanceRow.of(
                label: 'PTW reference',
                value: c.permit.reference,
                secondary: c.permit.type?.name,
              ),
              RecordRow(
                label: 'Permit type',
                value: c.permit.type?.name ?? 'Not recorded',
              ),
              RecordRow(label: 'Work area', value: c.workArea.name),
              RecordRow(label: 'Job', value: c.job.title),
            ],
          ),
        ),
        const SectionHeader(title: 'Integration'),
        const _IntegrationCard(
          name: 'Permit to Work system',
          explanation:
              'DoseBand cannot confirm that this permit exists, is open, or '
              'covers this work. The reference is what you typed.',
        ),
        const SizedBox(height: Space.base),
        _BoundaryCard(
          lines: const [
            'DoseBand does not issue a permit.',
            'DoseBand does not approve, extend or close a permit.',
            'DoseBand does not check a permit against any system.',
            'Holding a reference here is not permission to start work.',
          ],
        ),
      ],
    );
  }
}

/// The job safety analysis this period is attached to.
class JsaReferenceScreen extends StatelessWidget {
  const JsaReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ContextDetail(
      title: 'Job Safety Analysis',
      emptyMessage: 'Record a JSA reference in the work-context form.',
      builder: (context, c) => [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProvenanceRow.of(label: 'JSA reference', value: c.jsa.reference),
              RecordRow(label: 'Job', value: c.job.title),
              RecordRow(label: 'Work area', value: c.workArea.name),
              if (c.jsa.note case final note?)
                RecordRow(label: 'Note', value: note),
            ],
          ),
        ),
        const SectionHeader(title: 'Integration'),
        const _IntegrationCard(
          name: 'Job Safety Analysis system',
          explanation:
              'DoseBand cannot confirm that this JSA exists or covers this '
              'work. The reference is what you typed.',
        ),
        const SizedBox(height: Space.base),
        _BoundaryCard(
          lines: const [
            'DoseBand does not create a JSA.',
            'DoseBand does not approve, sign or close a JSA.',
            'DoseBand does not assess whether its controls are adequate.',
          ],
        ),
      ],
    );
  }
}

/// The toolbox-talk acknowledgement.
class ToolboxAcknowledgementScreen extends StatelessWidget {
  const ToolboxAcknowledgementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ContextDetail(
      title: 'Toolbox talk',
      emptyMessage: 'Record the acknowledgement in the work-context form.',
      builder: (context, c) => [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Acknowledged", never "Completed" or "Verified".
              const RecordRow(label: 'Status', value: 'Acknowledged'),
              RecordRow(
                label: 'Recorded at',
                value: Fmt.stamp(c.toolboxTalk.acknowledgedAt),
                mono: true,
              ),
              RecordRow(label: 'Source', value: c.toolboxTalk.source.label),
              if (c.toolboxTalk.reference case final reference?)
                RecordRow(label: 'Reference', value: reference),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        _BoundaryCard(
          lines: const [
            'This records that you acknowledged the toolbox-talk status for '
                'this work context, on this device, at this time.',
            'It is not evidence that the talk took place, who attended, or '
                'what was covered — DoseBand is not in the room.',
            'It does not replace your organisation’s toolbox-talk process.',
          ],
        ),
      ],
    );
  }
}

class _IntegrationCard extends StatelessWidget {
  const _IntegrationCard({required this.name, required this.explanation});

  final String name;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
              ),
              const OriginChip(DataOrigin.notConnected),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            explanation,
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// What DoseBand does not do. Stated as a list because a paragraph of
/// disclaimers is read as a paragraph of disclaimers — which is to say, not
/// read at all.
class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: corporate.textSecondary,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      line,
                      style: t.body.copyWith(color: corporate.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
