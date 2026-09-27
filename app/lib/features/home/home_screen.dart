import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/buttons.dart';
import '../../core/components/markers.dart';
import '../../core/components/step_scaffold.dart';
import '../../core/components/workspace_components.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/format.dart';
import '../auth/application/auth_controller.dart';
import '../history/application/history_controller.dart';
import '../history/domain/measurement_record.dart';
import '../operations/application/operations_providers.dart';
import '../operations/presentation/ops_chips.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/data/work_context_repository.dart';
import '../workflow/domain/workflow_state.dart';
import 'domain/home_presentation.dart';
import 'presentation/home_cards.dart';

/// Worker Home (PRODUCT BUILD v1 §15, §16; corrective §3C).
///
/// The approved Home's hierarchy — refinery header, identity, today's shift,
/// work context, monitoring card, one next action — over the current state
/// model: every value comes from the signed-in person's directory record,
/// the recorded work context or the monitoring session. Nothing here is a
/// static demonstration.
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
    // The elapsed figure is monitoring duration, not exposure; a refresh
    // every half minute is all it needs.
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
    final corporate = context.corporate;
    final session = ref.watch(shiftSessionProvider).value ?? ShiftSession.none;
    final now = ref.watch(clockProvider)();
    final presentation = HomePresentation.from(session: session, now: now);
    final history = ref.watch(historyProvider);
    final profile = ref.watch(ownProfileProvider).value;
    final person = profile?.person;
    final sites = ref.watch(availableSitesProvider);

    // Today's work: what the worker recorded, or — until they do — the usual
    // site, department, area and shift from their company record. A context
    // from a period completed on an earlier day is not today's.
    final recorded =
        session.stage == ShiftStage.complete &&
            presentation.stage != HomeStage.completed
        ? null
        : session.context;
    const repo = DemoWorkContextRepository();
    final siteName =
        recorded?.site.name ??
        sites.where((s) => s.id == person?.siteId).firstOrNull?.name;
    final department = recorded?.department.name ?? profile?.departmentName;
    final shift =
        recorded?.shift.name ??
        repo.shiftById(person?.defaultShiftId ?? '')?.name;
    final area =
        recorded?.workArea.name ??
        repo.workAreaById(person?.defaultWorkAreaId ?? '')?.name;
    final gatePass = recorded?.worker.gatePass?.value;

    final worker = recorded?.worker;
    final name = person?.displayName ?? worker?.displayName;
    final typeAndId = person != null
        ? '${person.workerType.label} · ID ${person.personId}'
        : worker == null
        ? null
        : '${worker.workerType.label} · ID ${worker.workerId}';
    final company = person?.contractorCompany ?? worker?.contractorCompany;

    final badge = session.assignedBadge;
    final elapsed = session.coverageAt(session.endedAt ?? now);

    return StepRegisterScope(
      register: StepRegister.corporate,
      child: Scaffold(
        backgroundColor: corporate.surfaceMuted,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            const HomeHero(),
            // Everything below lifts into the header by the same amount, so
            // the identity card overlaps the photograph and no gap opens.
            Transform.translate(
              offset: const Offset(0, -24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Breakpoints.maxContentWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gaps.screenGutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WorkerIdentityCard(
                          name: name,
                          typeAndId: typeAndId,
                          company: company,
                          onOpenProfile: () => context.go('/profile'),
                        ),
                        const SizedBox(height: Space.md),
                        HomeSectionCard(
                          title: 'Today’s shift',
                          actionLabel: recorded == null
                              ? 'Record'
                              : 'View details',
                          onAction: () => context.push('/work-context'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              HomeFieldGrid(
                                fields: [
                                  ('Site', orNotRecorded(siteName), false),
                                  (
                                    'Department',
                                    orNotRecorded(department),
                                    false,
                                  ),
                                  ('Shift', orNotRecorded(shift), false),
                                  ('Work area', orNotRecorded(area), false),
                                  if (gatePass != null)
                                    ('Gate pass', _mask(gatePass), true),
                                  ('Date', Fmt.date(now), true),
                                ],
                              ),
                              if (recorded == null) ...[
                                const SizedBox(height: Space.sm),
                                Text(
                                  'Usual assignment from your company record. '
                                  'Confirm today’s work before a DoseBand is '
                                  'assigned.',
                                  style: context.type.caption.copyWith(
                                    color: corporate.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        HomeSectionCard(
                          title: 'Work context',
                          actionLabel: recorded == null ? null : 'View all',
                          onAction: () => context.push('/work-context'),
                          child: recorded == null
                              ? HomeContextRows(
                                  rows: [
                                    ('PTW', 'Not recorded', false),
                                    ('JSA', 'Not recorded', false),
                                    ('Toolbox talk', 'Not recorded', false),
                                    (
                                      'Supervisor',
                                      orNotRecorded(profile?.supervisorName),
                                      false,
                                    ),
                                  ],
                                )
                              : HomeContextRows(
                                  rows: [
                                    ('Job', recorded.job.title, false),
                                    (
                                      'PTW',
                                      recorded.permit.reference.value,
                                      true,
                                    ),
                                    ('JSA', recorded.jsa.reference.value, true),
                                    // Acknowledged, never "completed": a tap
                                    // on a phone is not evidence a talk
                                    // happened.
                                    ('Toolbox talk', 'Acknowledged', false),
                                    (
                                      'Supervisor',
                                      orNotRecorded(profile?.supervisorName),
                                      false,
                                    ),
                                  ],
                                  footnote:
                                      'Recorded by you. Not checked against '
                                      'a permit system; DoseBand does not '
                                      'authorise work.',
                                ),
                        ),
                        const SizedBox(height: Space.md),
                        MonitoringStatusCard(
                          presentation: presentation,
                          badgeId: badge?.badgeId,
                          simulated: badge?.isSimulated ?? false,
                          startedAt: session.startedAt,
                          endedAt: session.endedAt,
                          elapsed: elapsed,
                          work: session.context == null
                              ? null
                              : '${session.context!.workArea.name} · '
                                    '${session.context!.shift.name}',
                        ),
                        const SizedBox(height: Space.md),
                        DoseBandButton.primary(
                          label: presentation.actionLabel,
                          icon: switch (presentation.stage) {
                            HomeStage.noDoseBand => Icons.qr_code_scanner,
                            HomeStage.readyForFinalRead =>
                              Icons.document_scanner_outlined,
                            HomeStage.completed => Icons.receipt_long_outlined,
                            _ => Icons.arrow_forward,
                          },
                          onPressed: () =>
                              context.push(presentation.actionRoute),
                        ),
                        if (presentation.secondaryLabel != null) ...[
                          const SizedBox(height: Space.sm),
                          DoseBandButton.secondary(
                            label: presentation.secondaryLabel!,
                            onPressed: () =>
                                context.push(presentation.secondaryRoute!),
                          ),
                        ],
                        if (history.isNotEmpty) ...[
                          const SizedBox(height: Space.lg),
                          _Recent(records: history.take(3).toList()),
                        ],
                        const SizedBox(height: Space.base),
                        const DataOriginNote(
                          'Your records are stored on this phone. No central '
                          'server is connected yet.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A gate pass is a credential reference: only the last four characters.
  static String _mask(String value) =>
      value.length <= 4 ? value : '•••• ${value.substring(value.length - 4)}';
}

class _Recent extends StatelessWidget {
  const _Recent({required this.records});

  final List<MeasurementRecord> records;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return HomeSectionCard(
      title: 'Recent records',
      actionLabel: 'History',
      onAction: () => context.go('/history'),
      child: Column(
        children: [
          for (var i = 0; i < records.length; i++) ...[
            if (i > 0) Divider(height: 1, color: corporate.border),
            InkWell(
              onTap: () => context.push(
                '/history/record/${records[i].id}',
                extra: records[i],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kMinTouchTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Fmt.date(records[i].scannedAt)} · '
                              '${records[i].badge.badgeId}',
                              style: t.bodyStrong.copyWith(
                                color: corporate.textPrimary,
                              ),
                            ),
                            const SizedBox(height: Space.xs),
                            Wrap(
                              spacing: Space.xs,
                              runSpacing: Space.xs,
                              children: [
                                MeasurementStateChip(records[i].result),
                                if (records[i].badge.isSimulated)
                                  const SimulationMarker(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: corporate.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
