import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/identity.dart';
import '../../../core/components/product_fields.dart';
import '../../../core/components/product_page.dart';
import '../../../core/components/product_states.dart';
import '../../../core/components/product_status.dart';
import '../../../core/components/workspace_components.dart';
import '../../../core/design/responsive.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../core/util/format.dart';
import '../../account/presentation/workspace_more_screen.dart';
import '../../operations/application/day_status.dart';
import '../../operations/application/operations_providers.dart';
import '../../operations/application/supervisor_service.dart';
import '../../operations/application/worker_service.dart';
import '../../operations/domain/measurement_state.dart';
import '../../operations/presentation/ops_chips.dart';

/// The data-origin line every supervisor page carries once, at the foot.
const _origin =
    'Team state from the operations records on this device. Not live from a '
    'server: another phone’s activity appears only after it is synced, and '
    'no sync exists yet.';

String _since(DateTime? t, DateTime now) => t == null
    ? Fmt.noValue
    : '${Fmt.clock(t)} · ${Fmt.duration(now.difference(t))}';

/// Overview — "what does my team need from me right now?" (§33).
class SupervisorOverviewScreen extends ConsumerWidget {
  const SupervisorOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'Team today',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(supervisorViewProvider),
          builder: (context, v) {
            final o = v.overview(now);
            final ex = v.exceptions(now);
            final notStarted = v.team(now, status: WorkerDayStatus.notStarted);
            final due = v.team(now, status: WorkerDayStatus.finalReadDue);
            void team(WorkerDayStatus s) =>
                context.go('/supervisor/team?status=${s.name}');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TeamHeading(
                  names: o.teamNames,
                  expected: o.expected,
                  now: now,
                ),
                const SizedBox(height: Space.base),
                CountGrid(
                  tiles: [
                    for (final s in WorkerDayStatus.values)
                      CountTile(
                        label: s.label,
                        value: '${o.count(s)}',
                        tone: s == WorkerDayStatus.exception && o.count(s) > 0
                            ? StatusTone.critical
                            : StatusTone.neutral,
                        onTap: () => team(s),
                      ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'Each worker is counted once. The ${o.expected} counts add '
                  'up to the team.',
                  style: context.type.caption.copyWith(
                    color: context.product.textSecondary,
                  ),
                ),
                const SizedBox(height: Gaps.section),
                PageSection(
                  title: 'Needs attention (${ex.length})',
                  trailing: ex.isEmpty
                      ? null
                      : DoseBandButton.tertiary(
                          label: 'All',
                          onPressed: () => context.go('/supervisor/exceptions'),
                        ),
                  children: [
                    if (ex.isEmpty)
                      const StateView(
                        kind: StateKind.empty,
                        title: 'Nothing needs attention',
                        message: 'No exceptions in the last seven days.',
                        compact: true,
                      )
                    else
                      RowList(
                        children: [
                          for (final e in ex.take(3))
                            _ExceptionRow(item: e, view: v, now: now),
                        ],
                      ),
                  ],
                ),
                if (notStarted.isNotEmpty)
                  PageSection(
                    title: 'Not started (${notStarted.length})',
                    children: [_MemberList(rows: notStarted, now: now)],
                  ),
                if (due.isNotEmpty)
                  PageSection(
                    title: 'Final scan due (${due.length})',
                    children: [_MemberList(rows: due, now: now)],
                  ),
                const DataOriginNote(_origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TeamHeading extends StatelessWidget {
  const _TeamHeading({
    required this.names,
    required this.expected,
    required this.now,
  });

  final List<String> names;
  final int expected;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          names.isEmpty ? 'No team assigned' : names.join(' · '),
          style: t.heading.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          '${Fmt.date(now)} · $expected expected',
          style: t.body.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({required this.rows, required this.now});

  final List<TeamMemberRow> rows;
  final DateTime now;

  @override
  Widget build(BuildContext context) => RowList(
    children: [
      for (final r in rows)
        PersonTile(
          name: r.person.displayName,
          detail: _detailOf(r, now),
          status: DayStatusChip(r.day.status),
          onTap: () => context.push('/supervisor/worker/${r.person.personId}'),
        ),
    ],
  );
}

String _detailOf(TeamMemberRow r, DateTime now) {
  final session = r.day.session;
  final band = r.band?.dosebandId;
  return switch (r.day.status) {
    WorkerDayStatus.notStarted => '${r.person.personId} · no DoseBand yet',
    WorkerDayStatus.monitoring =>
      '${r.person.personId} · $band · since ${_since(session?.startedAt, now)}',
    WorkerDayStatus.finalReadDue =>
      '${r.person.personId} · $band · ended ${session?.endedAt == null ? Fmt.noValue : Fmt.clock(session!.endedAt!)}',
    WorkerDayStatus.completed =>
      '${r.person.personId} · $band · '
          '${r.day.measurement == null ? 'no record' : MeasurementStateText.label(r.day.measurement!.result.status)}',
    _ => '${r.person.personId}${band == null ? '' : ' · $band'}',
  };
}

/// The team, searchable and filterable (§34).
class SupervisorTeamScreen extends ConsumerStatefulWidget {
  const SupervisorTeamScreen({this.initialStatus, super.key});

  final WorkerDayStatus? initialStatus;

  @override
  ConsumerState<SupervisorTeamScreen> createState() =>
      _SupervisorTeamScreenState();
}

class _SupervisorTeamScreenState extends ConsumerState<SupervisorTeamScreen> {
  String _query = '';
  late WorkerDayStatus? _status = widget.initialStatus;

  @override
  void didUpdateWidget(covariant SupervisorTeamScreen old) {
    super.didUpdateWidget(old);
    if (old.initialStatus != widget.initialStatus) {
      _status = widget.initialStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'Team',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(supervisorViewProvider),
          builder: (context, v) {
            final rows = v.team(now, query: _query, status: _status);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductSearchField(
                  label: 'Search your team',
                  hint: 'Name, worker ID or DoseBand',
                  onChanged: (q) => setState(() => _query = q),
                ),
                const SizedBox(height: Space.sm),
                ChoiceChips<WorkerDayStatus?>(
                  options: const [null, ...WorkerDayStatus.values],
                  selected: _status,
                  labelOf: (s) => s?.label ?? 'All',
                  onSelected: (s) => setState(() => _status = s),
                ),
                const SizedBox(height: Space.base),
                if (rows.isEmpty)
                  StateView(
                    kind: _query.isEmpty && _status == null
                        ? StateKind.empty
                        : StateKind.noResults,
                    message: _query.isEmpty && _status == null
                        ? 'No one is assigned to your team.'
                        : 'No team member matches.',
                  )
                else
                  _MemberList(rows: rows, now: now),
                const SizedBox(height: Space.base),
                const DataOriginNote(_origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Expected → claimed → monitoring → final read due → completed (§36).
class SupervisorMonitoringScreen extends ConsumerWidget {
  const SupervisorMonitoringScreen({super.key});

  static const _stages = [
    (WorkerDayStatus.notStarted, 'Expected'),
    (WorkerDayStatus.claimed, 'DoseBand claimed'),
    (WorkerDayStatus.monitoring, 'Monitoring'),
    (WorkerDayStatus.finalReadDue, 'Final read due'),
    (WorkerDayStatus.completed, 'Completed'),
    (WorkerDayStatus.exception, 'Needs attention'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final wide = WindowClass.of(context).prefersTable;
    return ProductPage(
      title: 'Monitoring',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(supervisorViewProvider),
          builder: (context, v) {
            final columns = [
              for (final (status, title) in _stages)
                _StageColumn(
                  title: title,
                  rows: v.team(now, status: status),
                  now: now,
                ),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final c in columns) SizedBox(width: 220, child: c),
                    ],
                  )
                else ...[
                  for (final c in columns) ...[
                    c,
                    const SizedBox(height: Space.base),
                  ],
                ],
                const DataOriginNote(_origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({
    required this.title,
    required this.rows,
    required this.now,
  });

  final String title;
  final List<TeamMemberRow> rows;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            '$title · ${rows.length}',
            style: t.bodyStrong.copyWith(color: p.textPrimary),
          ),
        ),
        const SizedBox(height: Space.xs),
        if (rows.isEmpty)
          Text('None', style: t.caption.copyWith(color: p.textSecondary))
        else
          _MemberList(rows: rows, now: now),
      ],
    );
  }
}

/// Operational exceptions (§37). The supervisor can close out a period whose
/// DoseBand will never be scanned; nothing here edits a measurement.
class SupervisorExceptionsScreen extends ConsumerWidget {
  const SupervisorExceptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'Exceptions',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(supervisorViewProvider),
          builder: (context, v) {
            final items = v.exceptions(now);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Last seven days. One worker can have several items.',
                  style: context.type.caption.copyWith(
                    color: context.product.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.sm),
                if (items.isEmpty)
                  const StateView(
                    kind: StateKind.empty,
                    title: 'No exceptions',
                    message: 'Nothing in your team needs attention.',
                  )
                else
                  RowList(
                    children: [
                      for (final e in items)
                        _ExceptionRow(
                          item: e,
                          view: v,
                          now: now,
                          actions: true,
                        ),
                    ],
                  ),
                const SizedBox(height: Space.base),
                const DataOriginNote(_origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ExceptionRow extends ConsumerWidget {
  const _ExceptionRow({
    required this.item,
    required this.view,
    required this.now,
    this.actions = false,
  });

  final OperationalException item;
  final SupervisorView view;
  final DateTime now;
  final bool actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.product;
    final t = context.type;
    final person = view.personOf(item.workerId);
    final canClose =
        actions &&
        item.kind == ExceptionKind.finalScanOverdue &&
        item.sessionId != null;
    return InkWell(
      onTap: person == null
          ? null
          : () => context.push('/supervisor/worker/${person.personId}'),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.report_outlined, size: 18, color: p.textSecondary),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    item.kind.label,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [
                person?.displayName ?? item.workerId,
                if (item.dosebandId != null) item.dosebandId!,
                Fmt.stamp(item.at),
              ].join(' · '),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            if (item.detail != null) ...[
              const SizedBox(height: 2),
              Text(
                item.detail!,
                style: t.caption.copyWith(color: p.textPrimary),
              ),
            ],
            if (canClose) ...[
              const SizedBox(height: Space.sm),
              DoseBandButton.secondary(
                label: 'Close as final scan missing',
                expand: false,
                onPressed: () => _close(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Close as final scan missing?'),
        content: const Text(
          'Use this only when the DoseBand will not be scanned — it was lost '
          'or discarded. The period is recorded as having no final read. No '
          'exposure is inferred for it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Close period'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(supervisorCommandsProvider)
          .closeMissingFinalRead(sessionId: item.sessionId!);
    } on OperationRefused catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.reason)));
      }
    }
  }
}

/// One team member, as their supervisor may see them (§35).
class SupervisorWorkerScreen extends ConsumerWidget {
  const SupervisorWorkerScreen({required this.workerId, super.key});

  final String workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final view = ref.watch(supervisorViewProvider);
    return ProductPage(
      title: 'Team member',
      children: [
        OpsView(
          value: view.whenData((v) => v.worker(workerId, now)),
          builder: (context, d) {
            final session = d.day.session;
            final m = d.day.measurement;
            final records = {for (final r in d.records) r.id: r};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  children: [
                    IdentityHeader(
                      name: d.person.displayName,
                      subtitle:
                          '${d.person.personId} · ${d.person.designation}',
                      detail: [
                        ?d.departmentName,
                        d.person.workerType.label,
                        ?d.person.contractorCompany,
                      ].join(' · '),
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.section),
                PageSection(
                  title: 'Today',
                  trailing: DayStatusChip(d.day.status),
                  children: [
                    SectionCard(
                      children: [
                        FactRow(
                          label: 'DoseBand',
                          value: session?.dosebandId ?? 'None assigned',
                          mono: true,
                        ),
                        FactRow(
                          label: 'Work',
                          value: [
                            ?session?.work?.workAreaName,
                            ?session?.work?.shiftName,
                          ].join(' · ').ifEmpty(Fmt.noValue),
                        ),
                        FactRow(
                          label: 'Started',
                          value: session?.startedAt == null
                              ? Fmt.noValue
                              : Fmt.stamp(session!.startedAt!),
                        ),
                        FactRow(
                          label: 'Ended',
                          value: session?.endedAt == null
                              ? Fmt.noValue
                              : Fmt.stamp(session!.endedAt!),
                        ),
                        FactRow(
                          label: 'Duration',
                          value: session?.startedAt == null
                              ? Fmt.noValue
                              : Fmt.duration(
                                  (session!.endedAt ?? now).difference(
                                    session.startedAt!,
                                  ),
                                ),
                        ),
                        FactRow(
                          label: 'Measurement',
                          value: m == null
                              ? 'No record yet'
                              : MeasurementStateText.exposureCell(m.result),
                        ),
                      ],
                    ),
                  ],
                ),
                if (d.exceptions.isNotEmpty)
                  PageSection(
                    title: 'Needs attention',
                    children: [
                      RowList(
                        children: [
                          for (final e in d.exceptions)
                            ListTile(
                              title: Text(e.kind.label),
                              subtitle: Text(
                                [Fmt.stamp(e.at), ?e.detail].join(' · '),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                PageSection(
                  title: 'Recent monitoring',
                  children: [
                    if (d.recentSessions.isEmpty)
                      const StateView(
                        kind: StateKind.empty,
                        message: 'No monitoring periods recorded.',
                        compact: true,
                      )
                    else
                      RowList(
                        children: [
                          for (final x in d.recentSessions)
                            ListTile(
                              title: Text(
                                '${x.startedAt == null ? 'Not started' : Fmt.date(x.startedAt!)} · ${x.dosebandId ?? ''}',
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: Space.xs),
                                child: Wrap(
                                  spacing: Space.xs,
                                  runSpacing: Space.xs,
                                  children: [
                                    SessionStateChip(x.state),
                                    if (records[x.measurementId] case final r?)
                                      MeasurementStateChip(r.result),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                Text(
                  'You can see this worker because they are in your team. '
                  'Measurements are shown as recorded and cannot be changed '
                  'here.',
                  style: context.type.caption.copyWith(
                    color: context.product.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// The supervisor's More page.
class SupervisorMoreScreen extends StatelessWidget {
  const SupervisorMoreScreen({super.key});

  @override
  Widget build(BuildContext context) => const WorkspaceMoreScreen();
}

/// Parses `?status=` for the team list.
WorkerDayStatus? teamStatusParam(String? name) =>
    WorkerDayStatus.values.where((s) => s.name == name).firstOrNull;
