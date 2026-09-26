import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate.dart';
import '../../../core/demo/ui_demo_catalog.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';

/// Recording an HSE decision about a record.
///
/// ## What a disposition is, and what it is not
///
/// A disposition moves a record through a **workflow**. It records that a
/// competent person looked at it, what they decided to do, and why.
///
/// It does not change the measurement, and it does not make a claim about the
/// worker. There is no "safe", no "unsafe", no "medically cleared", no "fit
/// for duty" and no risk band — those are clinical or regulatory judgements
/// that a dosimetry application has no standing to record, and an officer
/// offered the button would eventually press it.
class HseDispositionScreen extends StatefulWidget {
  const HseDispositionScreen({required this.record, super.key});

  final DemoExposureRecord record;

  @override
  State<HseDispositionScreen> createState() => _HseDispositionScreenState();
}

class _HseDispositionScreenState extends State<HseDispositionScreen> {
  DemoReviewState? _selected;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// States an officer may move a record into.
  ///
  /// [DemoReviewState.newRecord] is absent on purpose: "new" is what the
  /// system says before anyone has looked, not something a reviewer can
  /// declare.
  static const _selectable = <DemoReviewState>[
    DemoReviewState.inReview,
    DemoReviewState.informationRequired,
    DemoReviewState.reviewed,
    DemoReviewState.closed,
  ];

  /// Transitions that must be explained.
  static bool _requiresReason(DemoReviewState state) =>
      state == DemoReviewState.informationRequired ||
      state == DemoReviewState.reviewed ||
      state == DemoReviewState.closed;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final record = widget.record;
    final needsReason = _selected != null && _requiresReason(_selected!);
    final reasonGiven = _reason.text.trim().isNotEmpty;

    return SafetyScaffold(
      title: 'Disposition',
      subtitle: record.recordId,
      children: [
        const DemoDataBanner(
          message:
              'A demonstration record. No disposition is written anywhere — '
              'no record store exists to write to.',
        ),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Record'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Worker', value: record.worker.name),
              RecordRow(label: 'Record', value: record.recordId, mono: true),
              RecordRow(label: 'Work area', value: record.worker.workArea),
              RecordRow(label: 'Badge', value: record.badgeId, mono: true),
              RecordRow(
                label: 'Measurement',
                value: record.refusalReason == null
                    ? record.outcome.label
                    : '${record.outcome.label} · ${record.refusalReason}',
              ),
              RecordRow(
                label: 'Current state',
                value: record.reviewState.label,
              ),
            ],
          ),
        ),

        const SectionHeader(
          title: 'Decision',
          subtitle: 'Moves the record through the workflow',
        ),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final state in _selectable)
                _DispositionOption(
                  state: state,
                  selected: _selected == state,
                  onTap: () => setState(() => _selected = state),
                ),
            ],
          ),
        ),

        const SectionHeader(title: 'Reason'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _reason,
                minLines: 3,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                style: t.body.copyWith(color: corporate.textPrimary),
                decoration: InputDecoration(
                  hintText: needsReason
                      ? 'Required for this decision'
                      : 'Optional',
                  hintStyle: t.body.copyWith(color: corporate.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CorporateRadii.md),
                    borderSide: BorderSide(color: corporate.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CorporateRadii.md),
                    borderSide: BorderSide(color: corporate.border),
                  ),
                ),
              ),
              if (needsReason && !reasonGiven) ...[
                const SizedBox(height: Space.sm),
                Text(
                  'A reason is required before this decision can be recorded. '
                  'The record keeps it, so a later reader knows why the '
                  'decision was made rather than only what it was.',
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ],
            ],
          ),
        ),

        const SectionHeader(title: 'Audit'),
        InfoCard(
          child: Column(
            children: [
              const RecordRow(label: 'Actor', value: 'Signed-in HSE officer'),
              RecordRow(
                label: 'When',
                value: Fmt.stamp(DateTime.now()),
                mono: true,
              ),
              RecordRow(
                label: 'Previous state',
                value: record.reviewState.label,
              ),
              RecordRow(
                label: 'New state',
                value: _selected?.label ?? 'Not selected',
              ),
              // No signature. DoseBand holds no signing keys.
              const RecordRow(label: 'Signature', value: 'Not applicable'),
            ],
          ),
        ),
        const SizedBox(height: Space.base),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            // Disabled in this phase: there is no record store to write to.
            // The gating logic is live so the rule — a reason is required for
            // a closing decision — is visible and reviewable.
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: corporate.accent,
              foregroundColor: corporate.textOnAccent,
              minimumSize: const Size.fromHeight(kMinTouchTarget),
            ),
            child: const Text('Record decision'),
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          _selected == null
              ? 'Select a decision. Recording is unavailable in this '
                    'prototype — no record store exists.'
              : needsReason && !reasonGiven
              ? 'Add a reason. Recording is unavailable in this prototype.'
              : 'Recording is unavailable in this prototype — no record store '
                    'exists to write to.',
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: corporate.textSecondary),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'A disposition records what was decided about this record and '
            'why. It does not change the measurement, and it makes no '
            'statement about the worker’s health or fitness for work.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _DispositionOption extends StatelessWidget {
  const _DispositionOption({
    required this.state,
    required this.selected,
    required this.onTap,
  });

  final DemoReviewState state;
  final bool selected;
  final VoidCallback onTap;

  static String _explain(DemoReviewState state) => switch (state) {
    DemoReviewState.inReview => 'You are looking at it now',
    DemoReviewState.informationRequired =>
      'Something is needed before this can be closed',
    DemoReviewState.reviewed => 'Looked at; no further action',
    DemoReviewState.closed => 'Complete and closed',
    DemoReviewState.newRecord ||
    DemoReviewState.reviewRequired => 'Set by the system',
  };

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.md,
            ),
            color: selected ? corporate.selectedFill : null,
            child: Row(
              children: [
                // Selection is carried by the icon as well as the fill, so it
                // does not depend on colour alone.
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 19,
                  color: selected
                      ? corporate.selectedBorder
                      : corporate.textSecondary,
                ),
                const SizedBox(width: Space.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.label,
                        style: t.body.copyWith(color: corporate.textPrimary),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _explain(state),
                        style: t.caption.copyWith(
                          color: corporate.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Handing an exposure record to occupational health.
///
/// ## Minimum necessary information
///
/// Only what a referral needs: who, the work context, the monitoring window
/// and the measurement state. No medical fields, no diagnosis, no history
/// beyond the record being referred — an occupational-health handoff is not an
/// excuse to forward a worker's file.
class OccupationalHealthHandoffScreen extends StatelessWidget {
  const OccupationalHealthHandoffScreen({required this.record, super.key});

  final DemoExposureRecord record;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Occupational health handoff',
      subtitle: record.recordId,
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),

        const SectionHeader(
          title: 'Information included',
          subtitle: 'Only what a referral needs',
        ),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Worker', value: record.worker.name),
              RecordRow(
                label: 'Worker ID',
                value: record.worker.workerId,
                mono: true,
              ),
              RecordRow(label: 'Employment', value: record.worker.typeLabel),
              RecordRow(label: 'Department', value: record.worker.department),
              RecordRow(label: 'Work area', value: record.worker.workArea),
              RecordRow(label: 'Shift', value: record.worker.shift),
            ],
          ),
        ),

        const SectionHeader(title: 'Monitoring record'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Record', value: record.recordId, mono: true),
              RecordRow(
                label: 'Started',
                value: Fmt.stamp(record.startedAt),
                mono: true,
              ),
              RecordRow(
                label: 'Ended',
                value: Fmt.stamp(record.endedAt),
                mono: true,
              ),
              RecordRow(
                label: 'Covered',
                value: Fmt.duration(record.coverage),
                mono: true,
              ),
              RecordRow(label: 'Badge', value: record.badgeId, mono: true),
              // Never a dose. No calibration exists.
              RecordRow(label: 'Exposure', value: Fmt.noValue, mono: true),
              RecordRow(
                label: 'Measurement state',
                value: record.refusalReason == null
                    ? record.outcome.label
                    : '${record.outcome.label} · ${record.refusalReason}',
              ),
              RecordRow(label: 'HSE review', value: record.reviewState.label),
            ],
          ),
        ),

        const SectionHeader(title: 'Excluded'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DoseBand holds none of the following and will not send them:',
                style: t.body.copyWith(color: corporate.textSecondary),
              ),
              const SizedBox(height: Space.sm),
              for (final excluded in const <String>[
                'Any medical or clinical information',
                'Any diagnosis, assessment or opinion',
                'Any judgement about fitness for work',
                'Exposure records other than the one being referred',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.remove,
                          size: 11,
                          color: corporate.textSecondary,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          excluded,
                          style: t.caption.copyWith(
                            color: corporate.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SectionHeader(title: 'Handoff'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Occupational health service',
                      style: t.bodyStrong.copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                  ),
                  const OriginChip(DataOrigin.notConnected),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                'No integration is connected. Nothing has been sent, and no '
                'referral has been made.',
                style: t.body.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send to occupational health'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(kMinTouchTarget),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Unavailable — no occupational health integration exists.',
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: corporate.textSecondary),
        ),
      ],
    );
  }
}

/// One active monitoring session, in detail. Observation only.
class ActiveMonitoringDetailScreen extends StatelessWidget {
  const ActiveMonitoringDetailScreen({required this.worker, super.key});

  final DemoWorker worker;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final coverage = worker.coverageAt(DateTime.now());

    return SafetyScaffold(
      title: worker.name,
      subtitle: '${worker.workerId} · ${worker.monitoringState.label}',
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Worker'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Name', value: worker.name),
              RecordRow(label: 'Worker ID', value: worker.workerId, mono: true),
              RecordRow(label: 'Employment', value: worker.typeLabel),
              if (worker.contractorCompany case final company?)
                RecordRow(label: 'Contractor', value: company),
              RecordRow(label: 'Department', value: worker.department),
            ],
          ),
        ),

        const SectionHeader(title: 'Work context'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Work area', value: worker.workArea),
              RecordRow(label: 'Shift', value: worker.shift),
              const RecordRow(
                label: 'PTW',
                value: 'PTW-DEMO-4471',
                mono: true,
                origin: DataOrigin.uiDemo,
              ),
              const RecordRow(
                label: 'JSA',
                value: 'JSA-DEMO-2048',
                mono: true,
                origin: DataOrigin.uiDemo,
              ),
              const RecordRow(
                label: 'Toolbox talk',
                value: 'Acknowledged',
                origin: DataOrigin.uiDemo,
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Monitoring'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(
                label: 'Started',
                value: worker.startedAt == null
                    ? 'Not started'
                    : Fmt.stamp(worker.startedAt!),
                mono: worker.startedAt != null,
              ),
              // Never computed from an untrusted clock.
              RecordRow(
                label: 'Duration',
                value: Fmt.duration(coverage),
                mono: true,
              ),
              RecordRow(label: 'State', value: worker.monitoringState.label),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'This is an observation view. An HSE officer cannot change a '
            'worker’s work context, badge assignment or measured exposure '
            'from here — the record belongs to the monitored period, not to '
            'the reviewer.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// A compact card that opens the disposition screen.
class DispositionLauncher extends StatelessWidget {
  const DispositionLauncher({required this.record, super.key});

  final DemoExposureRecord record;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          NavigationRow(
            icon: Icons.rule_outlined,
            title: 'Record a disposition',
            subtitle: 'Currently ${record.reviewState.label.toLowerCase()}',
            onTap: () => context.push('/hse/disposition', extra: record),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Divider(height: 1, color: context.corporate.border),
          ),
          NavigationRow(
            icon: Icons.medical_information_outlined,
            title: 'Occupational health handoff',
            origin: DataOrigin.notConnected,
            onTap: () => context.push('/hse/handoff', extra: record),
          ),
        ],
      ),
    );
  }
}
