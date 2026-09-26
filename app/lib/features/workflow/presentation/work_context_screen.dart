import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/info_note.dart';
import '../../../core/components/step_scaffold.dart';
import '../../../core/components/surfaces.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/async_value_x.dart';
import '../application/work_context_controller.dart';
import '../application/workflow_controller.dart';
import '../domain/enterprise_value.dart';
import '../domain/permit_context.dart';
import '../domain/work_context.dart';
import '../domain/work_taxonomy.dart';
import '../domain/worker_identity.dart';
import '../domain/workflow_state.dart';
import 'widgets/provenance.dart';

/// Work context.
///
/// Collects who is working, where, under what job, and which external safety
/// references this monitored period is attached to.
///
/// ## The boundary this screen has to hold
///
/// Everything below the worker's identity is a *reference to somebody else's
/// process*. MRPL issues permits; MRPL runs job safety analyses; a supervisor
/// and a crew hold the toolbox talk. DoseBand writes down which ones this
/// exposure record belongs beside, so the record can be interpreted later.
///
/// It does not check any of them, and no wording here may suggest it did.
/// Every value the worker types is recorded as [EnterpriseDataSource.manualEntry]
/// and rendered with its provenance chip attached, because a permit number that
/// has been read by nothing but the person who typed it must never look like
/// one a permit system confirmed.
class WorkContextScreen extends ConsumerStatefulWidget {
  const WorkContextScreen({super.key});

  @override
  ConsumerState<WorkContextScreen> createState() => _WorkContextScreenState();
}

class _WorkContextScreenState extends ConsumerState<WorkContextScreen> {
  final _jobTitle = TextEditingController();
  final _workOrder = TextEditingController();
  final _supervisor = TextEditingController();
  final _permit = TextEditingController();
  final _jsa = TextEditingController();
  final _gatePass = TextEditingController();
  final _contractorCompany = TextEditingController();
  final _toolboxReference = TextEditingController();

  bool _seeded = false;

  @override
  void dispose() {
    for (final c in [
      _jobTitle,
      _workOrder,
      _supervisor,
      _permit,
      _jsa,
      _gatePass,
      _contractorCompany,
      _toolboxReference,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills the text fields from the draft once, so that returning to this
  /// screen shows what was already entered without fighting the keyboard on
  /// every rebuild.
  void _seedControllers(WorkContextDraft draft) {
    if (_seeded) return;
    _seeded = true;
    _jobTitle.text = draft.job?.title ?? '';
    _workOrder.text = draft.job?.workOrder ?? '';
    _supervisor.text = draft.job?.supervisor ?? '';
    _permit.text = draft.permit?.reference.value ?? '';
    _jsa.text = draft.jsa?.reference.value ?? '';
    _gatePass.text = draft.worker?.gatePass?.value ?? '';
    _contractorCompany.text = draft.worker?.contractorCompany ?? '';
    _toolboxReference.text = draft.toolboxTalk?.reference ?? '';
  }

  void _pushJob() {
    ref
        .read(workContextDraftProvider.notifier)
        .setJob(
          JobContext(
            title: _jobTitle.text,
            workOrder: _emptyToNull(_workOrder.text),
            supervisor: _emptyToNull(_supervisor.text),
          ),
        );
  }

  static String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final draft = ref.watch(workContextDraftProvider);
    final notifier = ref.read(workContextDraftProvider.notifier);
    final config = ref.watch(workContextRepositoryProvider);
    final readiness = ref.watch(workContextReadinessProvider);
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;

    _seedControllers(draft);

    // Once monitoring has begun this context is provenance for a badge that is
    // already being exposed. The form becomes a read-only record.
    if (session.contextIsLocked) {
      return _LockedContext(context: session.context);
    }

    final areas = draft.site == null
        ? const <WorkArea>[]
        : config.workAreas(draft.site!.id);

    return StepScaffold(
      title: 'Work context',
      primaryAction: DoseBandButton.primary(
        label: 'Continue to badge',
        icon: Icons.arrow_forward,
        // Gated by the shared policy, so this button and the checklist on the
        // next screen can never disagree about what "complete" means.
        onPressed: !readiness.contextIsComplete
            ? null
            : () async {
                final built = draft.build();
                if (built == null) return;
                await ref.read(shiftSessionProvider.notifier).setContext(built);
                if (context.mounted) context.push('/assign');
              },
      ),
      children: [
        Text(
          'This monitored period is attached to the work below. DoseBand records '
          'these references so the reading can be interpreted later. It does not '
          'check them, and it does not authorise the work.',
          style: t.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.lg),

        _Section(
          title: 'Worker',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (draft.worker case final w?) ...[
                TraceabilityRow(label: 'Name', value: w.displayName),
                TraceabilityRow(label: 'Worker ID', value: w.workerId),
                Row(
                  children: [
                    Expanded(
                      child: TraceabilityRow(
                        label: 'Type',
                        value: w.workerType.label,
                      ),
                    ),
                    ProvenanceChip(w.source),
                  ],
                ),
                if (w.workerType == WorkerType.contractor) ...[
                  const SizedBox(height: Space.sm),
                  _Field(
                    controller: _contractorCompany,
                    label: 'Contractor company',
                    hint: 'Employing contractor',
                    onChanged: notifier.setContractorCompany,
                  ),
                ],
                const SizedBox(height: Space.sm),
                _Field(
                  controller: _gatePass,
                  label: 'Gate pass (optional)',
                  hint: 'Gate-pass identifier',
                  onChanged: notifier.setGatePass,
                ),
                if (w.gatePass case final g?)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: ProvenanceRow.of(label: 'Gate pass', value: g),
                  ),
              ] else
                Text(
                  'No signed-in worker. Sign in before recording a work context.',
                  style: t.body.copyWith(color: c.textSecondary),
                ),
            ],
          ),
        ),

        _Section(
          title: "Today's work",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TraceabilityRow(
                label: 'Site',
                value: draft.site?.name ?? 'Not selected',
              ),
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  'Inherited from sign-in. Change it there before starting a '
                  'monitored period.',
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ),
              const SizedBox(height: Space.md),
              _Picker<Department>(
                label: 'Department',
                value: draft.department,
                options: config.departments(),
                nameOf: (d) => d.name,
                onSelected: notifier.setDepartment,
              ),
              const SizedBox(height: Space.md),
              _Picker<WorkArea>(
                label: 'Work area',
                value: draft.workArea,
                options: areas,
                nameOf: (a) => a.name,
                onSelected: notifier.setWorkArea,
                emptyMessage: draft.site == null
                    ? 'Select a site first.'
                    : 'No work areas are configured for this site.',
              ),
              const SizedBox(height: Space.md),
              _Picker<WorkShift>(
                label: 'Shift',
                value: draft.shift,
                options: config.shifts(),
                nameOf: (s) =>
                    s.window == null ? s.name : '${s.name} · ${s.window}',
                onSelected: notifier.setShift,
              ),
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  'The shift records which work period this belongs to. Exposure '
                  'is measured from the actual start and end times, never from '
                  'the shift length.',
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),

        _Section(
          title: 'Job / activity',
          child: Column(
            children: [
              _Field(
                controller: _jobTitle,
                label: 'Job or activity',
                hint: 'e.g. Routine field round',
                onChanged: (_) => _pushJob(),
              ),
              const SizedBox(height: Space.sm),
              _Field(
                controller: _workOrder,
                label: 'Work order (optional)',
                hint: 'Reference only',
                onChanged: (_) => _pushJob(),
              ),
              const SizedBox(height: Space.sm),
              _Field(
                controller: _supervisor,
                label: 'Supervisor (optional)',
                hint: 'Name, for reference',
                onChanged: (_) => _pushJob(),
              ),
            ],
          ),
        ),

        _Section(
          title: 'Permit to Work',
          note:
              'DoseBand records the permit this work is carried out under. It '
              'does not issue, approve, check or close a permit.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(
                controller: _permit,
                label: 'PTW reference',
                hint: 'e.g. PTW-24-11873',
                onChanged: (v) => notifier.setPermit(reference: v),
              ),
              const SizedBox(height: Space.md),
              _Picker<PtwType>(
                label: 'Permit type (optional)',
                value: draft.permit?.type,
                options: config.permitTypes(),
                nameOf: (p) => p.name,
                onSelected: notifier.setPermitType,
                emptyMessage: 'Enter a PTW reference first.',
                enabled: draft.permit != null,
              ),
              if (draft.permit case final p?)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: ProvenanceRow.of(
                    label: 'PTW reference',
                    value: p.reference,
                    secondary: p.type?.name,
                  ),
                ),
            ],
          ),
        ),

        _Section(
          title: 'Job Safety Analysis',
          note:
              'DoseBand records that a JSA was referenced. It does not create, '
              'approve, sign or check one.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(
                controller: _jsa,
                label: 'JSA reference',
                hint: 'e.g. JSA-2048',
                onChanged: (v) => notifier.setJsa(reference: v),
              ),
              if (draft.jsa case final j?)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: ProvenanceRow.of(
                    label: 'JSA reference',
                    value: j.reference,
                  ),
                ),
            ],
          ),
        ),

        _Section(
          title: 'Toolbox talk',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Its own Material: DoseBandSurface paints a background, which
              // would otherwise swallow the tile's ink response and leave the
              // tap with no visual feedback at all.
              Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: draft.toolboxTalk != null,
                  onChanged: (v) => notifier.setToolboxTalk(
                    acknowledged: v ?? false,
                    reference: _toolboxReference.text,
                  ),
                  title: Text(
                    'I confirm the toolbox-talk status has been recorded for '
                    'this work context.',
                    style: t.body.copyWith(color: c.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: Space.sm),
              _Field(
                controller: _toolboxReference,
                label: 'Reference (optional)',
                hint: 'Talk number or supervisor name',
                onChanged: (v) {
                  if (draft.toolboxTalk == null) return;
                  notifier.setToolboxTalk(acknowledged: true, reference: v);
                },
              ),
              const SizedBox(height: Space.sm),
              Text(
                'This acknowledgement is recorded in DoseBand for work context. '
                'It does not replace the organisation’s toolbox-talk '
                'process, and it is not evidence that the talk took place.',
                style: t.caption.copyWith(color: c.textSecondary),
              ),
              if (draft.toolboxTalk case final tb?)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Acknowledged by the worker on this device.',
                          style: t.caption.copyWith(color: c.textSecondary),
                        ),
                      ),
                      ProvenanceChip(tb.source),
                    ],
                  ),
                ),
            ],
          ),
        ),

        if (!readiness.isReady) ...[
          const SizedBox(height: Space.sm),
          DoseBandSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Still needed',
                  style: t.label.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: Space.sm),
                for (final r in readiness.missingRequirements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.xs),
                    child: Row(
                      children: [
                        Icon(
                          Icons.radio_button_unchecked,
                          size: 15,
                          color: c.textSecondary,
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            r.label,
                            style: t.body.copyWith(color: c.textSecondary),
                          ),
                        ),
                      ],
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
}

/// The committed, read-only view shown once monitoring has started.
class _LockedContext extends StatelessWidget {
  const _LockedContext({required this.context});

  final WorkContext? context;

  @override
  Widget build(BuildContext buildContext) {
    final c = buildContext.colours;
    final t = buildContext.type;
    final ctx = context;

    return StepScaffold(
      title: 'Work context',
      children: [
        DoseBandSurface(
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: c.textSecondary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  'Monitoring is in progress, so this context is now part of the '
                  'exposure record and cannot be changed. End the monitored '
                  'period to start a new one.',
                  style: t.body.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        if (ctx != null)
          DoseBandSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TraceabilityRow(label: 'Worker', value: ctx.worker.displayName),
                TraceabilityRow(label: 'Site', value: ctx.site.name),
                TraceabilityRow(
                  label: 'Department',
                  value: ctx.department.name,
                ),
                TraceabilityRow(label: 'Work area', value: ctx.workArea.name),
                TraceabilityRow(label: 'Shift', value: ctx.shift.name),
                TraceabilityRow(label: 'Job / activity', value: ctx.job.title),
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
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.note});

  final String title;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final n = note;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.label.copyWith(color: c.textPrimary)),
          if (n != null) ...[
            const SizedBox(height: Space.xs),
            Text(n, style: t.caption.copyWith(color: c.textSecondary)),
          ],
          const SizedBox(height: Space.sm),
          DoseBandSurface(child: child),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.caption.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.xs),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: t.body.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: t.body.copyWith(color: c.textDisabled),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: c.border),
            ),
          ),
        ),
      ],
    );
  }
}

/// A labelled chooser.
///
/// A wrap of chips rather than a dropdown: the option sets are short, the
/// choice is consequential, and a glove on a refinery floor does not operate a
/// dropdown well.
class _Picker<T extends Object> extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.options,
    required this.nameOf,
    required this.onSelected,
    this.emptyMessage,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) nameOf;
  final ValueChanged<T> onSelected;
  final String? emptyMessage;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.caption.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.sm),
        if (!enabled || options.isEmpty)
          Text(
            emptyMessage ?? 'No options configured.',
            style: t.body.copyWith(color: c.textDisabled),
          )
        else
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(nameOf(option)),
                  selected: option == value,
                  onSelected: (_) => onSelected(option),
                ),
            ],
          ),
      ],
    );
  }
}
