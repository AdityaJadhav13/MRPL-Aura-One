import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/buttons.dart';
import '../../core/components/identity.dart';
import '../../core/components/markers.dart';
import '../../core/components/product_page.dart';
import '../../core/components/product_status.dart';
import '../../core/components/step_scaffold.dart';
import '../../core/components/workspace_components.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/format.dart';
import '../history/application/history_controller.dart';
import '../history/domain/measurement_record.dart';
import '../operations/application/operations_providers.dart';
import '../operations/presentation/ops_chips.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/domain/work_context.dart';
import '../workflow/domain/workflow_state.dart';
import 'domain/home_presentation.dart';

/// Worker Home (PRODUCT BUILD v1 §15, §16).
///
/// Answers, top to bottom: who am I, which DoseBand is mine, is monitoring
/// running and since when, what do I do next, and what work is this for.
/// No dashboard, no HSE or calibration concepts.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The elapsed time is monitoring duration, not exposure. A minute's
    // resolution is all it needs.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final session = ref.watch(shiftSessionProvider).value ?? ShiftSession.none;
    final now = ref.watch(clockProvider)();
    final presentation = HomePresentation.from(session: session, now: now);
    final history = ref.watch(historyProvider);
    final profile = ref.watch(ownProfileProvider).value;

    final name =
        profile?.person.displayName ?? session.context?.worker.displayName;
    final detail = profile == null
        ? session.context?.worker.workerId
        : [
            profile.person.personId,
            profile.person.contractorCompany ?? profile.departmentName,
          ].whereType<String>().join(' · ');

    return StepRegisterScope(
      register: StepRegister.corporate,
      child: Scaffold(
        backgroundColor: p.surfacePage,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Gaps.screenGutter,
              Space.base,
              Gaps.screenGutter,
              Space.xl,
            ),
            children: [
              for (final child in [
                _Greeting(name: name, detail: detail, now: now),
                const SizedBox(height: Space.base),
                _StateCard(
                  presentation: presentation,
                  session: session,
                  now: now,
                ),
                const SizedBox(height: Gaps.section),
                _TodaysWork(session: session),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: Gaps.section),
                  _Recent(records: history.take(3).toList()),
                ],
                const SizedBox(height: Space.base),
                const DataOriginNote(
                  'Your records are stored on this phone. No central server '
                  'is connected yet.',
                ),
              ])
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Breakpoints.maxContentWidth,
                    ),
                    child: child,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    required this.detail,
    required this.now,
  });

  final String? name;
  final String? detail;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    // The identity block is also the way to the profile: a screen-reader
    // user hears who is signed in and that it opens the account.
    return Semantics(
      header: true,
      button: true,
      label: 'Account and profile: ${name ?? 'worker'}',
      child: InkWell(
        onTap: () => context.go('/profile'),
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Row(
            children: [
              IdentityAvatar(name: name ?? '?', size: 48),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'Worker',
                      style: t.heading.copyWith(color: p.textPrimary),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    Text(
                      Fmt.date(now),
                      style: t.caption.copyWith(color: p.textSecondary),
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

/// The one card that says where the worker's day stands, with its action.
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.presentation,
    required this.session,
    required this.now,
  });

  final HomePresentation presentation;
  final ShiftSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final badge = session.assignedBadge;
    final (IconData icon, StatusTone tone) = switch (presentation.stage) {
      HomeStage.noDoseBand => (Icons.qr_code_2, StatusTone.neutral),
      HomeStage.doseBandAssigned => (Icons.qr_code_2, StatusTone.info),
      HomeStage.monitoringActive => (Icons.sensors, StatusTone.info),
      HomeStage.readyForFinalRead => (
        Icons.document_scanner_outlined,
        StatusTone.attention,
      ),
      HomeStage.completed => (Icons.task_alt, StatusTone.neutral),
      HomeStage.requiresAttention => (Icons.schedule, StatusTone.critical),
    };
    final showsBand =
        badge != null && presentation.stage != HomeStage.noDoseBand;
    return SectionCard(
      children: [
        if (badge?.isSimulated ?? false) ...[
          const SimulationMarker(),
          const SizedBox(height: Space.md),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: ToneChip(label: presentation.title, icon: icon, tone: tone),
        ),
        if (showsBand) ...[
          const SizedBox(height: Space.md),
          Text('DoseBand', style: t.caption.copyWith(color: p.textSecondary)),
          Text(
            badge.badgeId,
            style: t.readoutLarge.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: Space.sm),
          FactRow(
            label: 'Started',
            value: session.startedAt == null
                ? Fmt.noValue
                : Fmt.stamp(session.startedAt!),
          ),
          if (session.stage == ShiftStage.monitoring ||
              presentation.stage == HomeStage.requiresAttention)
            FactRow(
              label: 'Monitoring for',
              value: Fmt.duration(session.coverageAt(now)),
            )
          else if (session.endedAt != null)
            FactRow(label: 'Ended', value: Fmt.stamp(session.endedAt!)),
          if (session.context case final WorkContext c)
            FactRow(
              label: 'Work',
              value: '${c.workArea.name} · ${c.shift.name}',
            ),
        ],
        const SizedBox(height: Space.md),
        Text(
          presentation.message,
          style: t.body.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: Space.base),
        DoseBandButton.primary(
          label: presentation.actionLabel,
          onPressed: () => context.push(presentation.actionRoute),
        ),
        if (presentation.secondaryLabel != null) ...[
          const SizedBox(height: Space.sm),
          DoseBandButton.secondary(
            label: presentation.secondaryLabel!,
            onPressed: () => context.push(presentation.secondaryRoute!),
          ),
        ],
      ],
    );
  }
}

class _TodaysWork extends StatelessWidget {
  const _TodaysWork({required this.session});

  final ShiftSession session;

  @override
  Widget build(BuildContext context) {
    final c = session.stage == ShiftStage.complete ? null : session.context;
    return PageSection(
      title: 'Today’s work',
      children: [
        if (c == null)
          ActionCard(
            icon: Icons.assignment_outlined,
            title: 'Not recorded yet',
            message:
                'Your site, area and shift are filled in from your record. '
                'Add the job, permit and JSA references.',
            onTap: () => context.push('/work-context'),
          )
        else
          SectionCard(
            children: [
              FactRow(label: 'Site', value: c.site.name),
              FactRow(label: 'Area', value: c.workArea.name),
              FactRow(label: 'Shift', value: c.shift.name),
              FactRow(label: 'Job', value: c.job.title),
              FactRow(
                label: 'PTW',
                value: c.permit.reference.value,
                mono: true,
              ),
              if (!session.contextIsLocked) ...[
                const SizedBox(height: Space.sm),
                DoseBandButton.tertiary(
                  label: 'Change',
                  onPressed: () => context.push('/work-context'),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.records});

  final List<MeasurementRecord> records;

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: 'Recent records',
      trailing: DoseBandButton.tertiary(
        label: 'All',
        onPressed: () => context.go('/history'),
      ),
      children: [
        RowList(
          children: [
            for (final r in records)
              InkWell(
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
                                '${Fmt.date(r.scannedAt)} · ${r.badge.badgeId}',
                                style: context.type.bodyStrong.copyWith(
                                  color: context.product.textPrimary,
                                ),
                              ),
                              const SizedBox(height: Space.xs),
                              Wrap(
                                spacing: Space.xs,
                                runSpacing: Space.xs,
                                children: [
                                  MeasurementStateChip(r.result),
                                  if (r.badge.isSimulated)
                                    const SimulationMarker(),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: context.product.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
