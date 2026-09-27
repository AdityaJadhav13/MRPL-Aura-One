import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/identity.dart';
import '../../../core/components/markers.dart';
import '../../../core/components/product_fields.dart';
import '../../../core/components/product_page.dart';
import '../../../core/components/product_states.dart';
import '../../../core/components/product_status.dart';
import '../../../core/components/workspace_components.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/env/environment.dart';
import '../../../core/time/clock.dart';
import '../../../core/util/format.dart';
import '../../account/presentation/workspace_more_screen.dart';
import '../../operations/application/hse_service.dart';
import '../../operations/application/operations_providers.dart';
import '../../operations/application/worker_service.dart';
import '../../operations/domain/measurement_state.dart';
import '../../operations/domain/review.dart';
import '../../operations/presentation/ops_chips.dart';

const _origin =
    'Identified records within your HSE scope, from the operations records on '
    'this device. Not a central register: records from other phones appear '
    'only once sync exists.';

/// HSE overview (PRODUCT BUILD v1 §38).
class HseOverviewScreen extends ConsumerWidget {
  const HseOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'HSE overview',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(hseViewProvider),
          builder: (context, v) {
            final o = v.overview(now);
            final queue = v.reviewQueue().take(3).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scope: ${v.scopeSites.join(', ')} (site) · ${Fmt.date(now)}',
                  style: context.type.body.copyWith(
                    color: context.product.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.base),
                CountGrid(
                  tiles: [
                    CountTile(
                      label: 'Workers in scope',
                      value: '${o.workersInScope}',
                    ),
                    CountTile(
                      label: 'Monitoring now',
                      value: '${o.monitoringNow}',
                    ),
                    CountTile(
                      label: 'Records, last 7 days',
                      value: '${o.recordsLast7Days}',
                      onTap: () => context.go('/hse/exposures'),
                    ),
                    CountTile(
                      label: 'No reading, last 7 days',
                      value: '${o.noReadingLast7Days}',
                    ),
                    CountTile(
                      label: 'Open reviews',
                      value: '${o.openReviewTotal}',
                      tone: o.openReviewTotal > 0
                          ? StatusTone.attention
                          : StatusTone.neutral,
                      onTap: () => context.go('/hse/reviews'),
                    ),
                    CountTile(
                      label: 'Final scans overdue',
                      value: '${o.overdueFinalScans}',
                      tone: o.overdueFinalScans > 0
                          ? StatusTone.critical
                          : StatusTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.section),
                PageSection(
                  title: 'Oldest open reviews',
                  children: [
                    if (queue.isEmpty)
                      const StateView(
                        kind: StateKind.empty,
                        title: 'No open reviews',
                        message: 'Every record in scope has been reviewed.',
                        compact: true,
                      )
                    else
                      RowList(
                        children: [
                          for (final r in queue) _RegisterTile(row: r),
                        ],
                      ),
                  ],
                ),
                const NoCalibrationNote(),
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

/// The one boundary under every exposure record today.
class NoCalibrationNote extends StatelessWidget {
  const NoCalibrationNote({super.key});

  @override
  Widget build(BuildContext context) => const StatusBanner(
    tone: StatusTone.info,
    icon: Icons.science_outlined,
    title: 'No validated H₂S calibration',
    message:
        'Records are real captures, but no calibration applies, so none '
        'carries an exposure value. "No Reading" is a state, never zero.',
  );
}

/// The exposure register (§39): search and filters over authorised fields.
class HseExposureRegisterScreen extends ConsumerStatefulWidget {
  const HseExposureRegisterScreen({super.key});

  @override
  ConsumerState<HseExposureRegisterScreen> createState() =>
      _HseExposureRegisterScreenState();
}

class _HseExposureRegisterScreenState
    extends ConsumerState<HseExposureRegisterScreen> {
  String _query = '';
  MeasurementFilter _state = MeasurementFilter.all;
  ReviewState? _review;
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'Exposure register',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(hseViewProvider),
          builder: (context, v) {
            final rows = v.register(
              query: _query,
              from: now.subtract(Duration(days: _days)),
              state: _state,
              review: _review,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductSearchField(
                  label: 'Search the register',
                  hint: 'Worker, ID, DoseBand or work area',
                  onChanged: (q) => setState(() => _query = q),
                ),
                const SizedBox(height: Space.sm),
                ChoiceChips<int>(
                  options: const [7, 30, 365],
                  selected: _days,
                  labelOf: (d) => d == 365 ? '12 months' : '$d days',
                  onSelected: (d) => setState(() => _days = d),
                ),
                const SizedBox(height: Space.xs),
                ChoiceChips<MeasurementFilter>(
                  options: MeasurementFilter.values,
                  selected: _state,
                  labelOf: (f) => f.label,
                  onSelected: (f) => setState(() => _state = f),
                ),
                const SizedBox(height: Space.xs),
                ChoiceChips<ReviewState?>(
                  options: const [null, ...ReviewState.values],
                  selected: _review,
                  labelOf: (r) => r?.label ?? 'Any review state',
                  onSelected: (r) => setState(() => _review = r),
                ),
                const SizedBox(height: Space.base),
                if (rows.isEmpty)
                  const StateView(
                    kind: StateKind.noResults,
                    message:
                        'No records match. Records appear here after a '
                        'worker’s final scan.',
                  )
                else
                  RowList(
                    children: [for (final r in rows) _RegisterTile(row: r)],
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

class _RegisterTile extends StatelessWidget {
  const _RegisterTile({required this.row});

  final RegisterRow row;

  @override
  Widget build(BuildContext context) {
    final m = row.record;
    return PersonTile(
      name: row.person.displayName,
      detail:
          '${row.person.personId} · ${m.badge.badgeId} · '
          '${Fmt.stamp(m.scannedAt)}\n${m.context.workArea.name}',
      status: Wrap(
        spacing: Space.xs,
        runSpacing: Space.xs,
        children: [
          MeasurementStateChip(m.result),
          if (row.review != null) ReviewStateChip(row.review!.state),
          if (row.isSuperseded)
            const ToneChip(
              label: 'Superseded',
              icon: Icons.history,
              tone: StatusTone.neutral,
            ),
          if (m.badge.isSimulated) const SimulationMarker(),
        ],
      ),
      onTap: () => context.push('/hse/record/${m.id}'),
    );
  }
}

/// Reviews (§41), oldest first.
class HseReviewQueueScreen extends ConsumerStatefulWidget {
  const HseReviewQueueScreen({super.key});

  @override
  ConsumerState<HseReviewQueueScreen> createState() =>
      _HseReviewQueueScreenState();
}

class _HseReviewQueueScreenState extends ConsumerState<HseReviewQueueScreen> {
  ReviewState? _state;

  @override
  Widget build(BuildContext context) {
    return ProductPage(
      title: 'Reviews',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(hseViewProvider),
          builder: (context, v) {
            final rows = v.reviewQueue(state: _state);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoiceChips<ReviewState?>(
                  options: const [null, ...ReviewState.values],
                  selected: _state,
                  labelOf: (r) => r?.label ?? 'All open',
                  onSelected: (r) => setState(() => _state = r),
                ),
                const SizedBox(height: Space.base),
                if (rows.isEmpty)
                  const StateView(
                    kind: StateKind.empty,
                    message: 'Nothing waiting in this state.',
                  )
                else
                  RowList(
                    children: [for (final r in rows) _RegisterTile(row: r)],
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

/// One record's full chain (§40), with its review. The measurement is shown
/// as evidence; nothing on this screen can change it.
class HseRecordScreen extends ConsumerWidget {
  const HseRecordScreen({required this.measurementId, super.key});

  final String measurementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProductPage(
      title: 'Record traceability',
      children: [
        OpsView(
          value: ref
              .watch(hseViewProvider)
              .whenData((v) => v.chain(measurementId)),
          builder: (context, c) {
            final m = c.record;
            final p = m.result.provenance;
            final x = c.session;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (m.badge.isSimulated) ...[
                  const SimulationMarker(),
                  const SizedBox(height: Space.base),
                ],
                _Step(
                  n: 1,
                  title: 'Worker',
                  children: [
                    IdentityHeader(
                      name: c.person.displayName,
                      subtitle:
                          '${c.person.personId} · ${c.person.designation}',
                      detail: c.person.contractorCompany,
                    ),
                  ],
                ),
                _Step(
                  n: 2,
                  title: 'Work context',
                  children: [
                    FactRow(label: 'Site', value: m.context.site.name),
                    FactRow(
                      label: 'Department',
                      value: m.context.department.name,
                    ),
                    FactRow(label: 'Work area', value: m.context.workArea.name),
                    FactRow(label: 'Shift', value: m.context.shift.name),
                    FactRow(label: 'Job', value: m.context.job.title),
                    FactRow(
                      label: 'PTW',
                      value:
                          '${m.context.permit.reference.value} (${m.context.permit.reference.source.label})',
                    ),
                    FactRow(
                      label: 'JSA',
                      value:
                          '${m.context.jsa.reference.value} (${m.context.jsa.reference.source.label})',
                    ),
                  ],
                ),
                _Step(
                  n: 3,
                  title: 'DoseBand',
                  children: [
                    FactRow(
                      label: 'Serial',
                      value: m.badge.badgeId,
                      mono: true,
                    ),
                    FactRow(
                      label: 'Lot',
                      value: c.lot?.lotId ?? 'Unknown',
                      mono: true,
                    ),
                    FactRow(
                      label: 'Formulation',
                      value: c.formulation == null
                          ? 'Unknown'
                          : '${c.formulation!.name} ${c.formulation!.version}'
                                '${c.formulation!.validated ? '' : ' (not validated)'}',
                    ),
                    FactRow(
                      label: 'Lifecycle',
                      value: c.band?.lifecycle.label ?? 'Unknown',
                    ),
                    FactRow(
                      label: 'Pre-use check',
                      value: c.assignment?.preUse == null
                          ? 'Not recorded'
                          : '${c.assignment!.preUse!.outcome.label} · '
                                '${c.assignment!.preUse!.opticalCheck.label}',
                    ),
                  ],
                ),
                _Step(
                  n: 4,
                  title: 'Monitoring session',
                  children: [
                    FactRow(label: 'State', value: x?.state.label ?? 'Unknown'),
                    FactRow(label: 'Started', value: Fmt.stamp(m.startedAt)),
                    FactRow(label: 'Ended', value: Fmt.stamp(m.endedAt)),
                    FactRow(
                      label: 'Duration',
                      value: Fmt.duration(
                        m.endedAt.isBefore(m.startedAt) ? null : m.coverage,
                      ),
                    ),
                    FactRow(
                      label: 'Sync',
                      value: x?.syncState.label ?? 'Saved on this device',
                    ),
                  ],
                ),
                _Step(
                  n: 5,
                  title: 'Capture and quality',
                  children: [
                    FactRow(
                      label: 'Capture',
                      value: m.captureId ?? 'None — simulated',
                      mono: true,
                    ),
                    FactRow(label: 'Data domain', value: m.domain.disclosure),
                    FactRow(label: 'Device', value: p.deviceModel),
                    const FactRow(
                      label: 'Quality report',
                      value:
                          'Archived with the capture on the device that took '
                          'it (research archive).',
                    ),
                  ],
                ),
                _Step(
                  n: 6,
                  title: 'Algorithm and calibration',
                  children: [
                    FactRow(
                      label: 'Algorithm',
                      value: p.algorithmVersion,
                      mono: true,
                    ),
                    FactRow(
                      label: 'Geometry',
                      value: p.geometryVersion,
                      mono: true,
                    ),
                    FactRow(
                      label: 'Calibration',
                      value: p.calibrationModelId ?? 'None applies',
                    ),
                    FactRow(label: 'App', value: p.appVersion, mono: true),
                  ],
                ),
                _Step(
                  n: 7,
                  title: 'Measurement result',
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MeasurementStateChip(m.result),
                    ),
                    const SizedBox(height: Space.xs),
                    FactRow(
                      label: 'Exposure',
                      value: MeasurementStateText.exposureCell(m.result),
                    ),
                    FactRow(
                      label: 'Reasons',
                      value: m.result.reasons.isEmpty
                          ? '—'
                          : m.result.reasons.map((r) => r.code).join(', '),
                      mono: true,
                    ),
                    if (c.supersedes != null)
                      FactRow(
                        label: 'Supersedes',
                        value: '${c.supersedes!.id} — ${m.supersessionReason}',
                      ),
                    if (c.supersededBy != null)
                      FactRow(
                        label: 'Superseded by',
                        value: c.supersededBy!.id,
                      ),
                    Text(
                      'Measurement results are evidence and cannot be edited. '
                      'A re-read is a new record that names this one.',
                      style: context.type.caption.copyWith(
                        color: context.product.textSecondary,
                      ),
                    ),
                  ],
                ),
                _Step(
                  n: 8,
                  title: 'HSE review',
                  children: [
                    if (c.review == null)
                      const Text('No review is open for this record.')
                    else
                      _ReviewPanel(measurementId: m.id, review: c.review!),
                  ],
                ),
                PageSection(
                  title: 'Audit events',
                  children: [
                    RowList(
                      children: [
                        for (final e in c.events)
                          ListTile(
                            title: Text(e.action.label),
                            subtitle: Text(
                              '${Fmt.stamp(e.at)} · ${e.actorRole.label}'
                              '${e.detail == null ? '' : ' · ${e.detail}'}',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      'Local audit log on this device — not an enterprise '
                      'audit service.',
                      style: context.type.caption.copyWith(
                        color: context.product.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, required this.children});

  final int n;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PageSection(
    title: '$n · $title',
    children: [SectionCard(children: children)],
  );
}

class _ReviewPanel extends ConsumerWidget {
  const _ReviewPanel({required this.measurementId, required this.review});

  final String measurementId;
  final HseReview review;

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    ReviewState to,
  ) async {
    final note = await _askNote(context, to);
    if (note == null) return;
    try {
      await ref
          .read(hseCommandsProvider)
          .moveReview(
            measurementId: measurementId,
            to: to,
            note: note.isEmpty ? null : note,
          );
    } on OperationRefused catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.reason)));
      }
    }
  }

  Future<String?> _askNote(BuildContext context, ReviewState to) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Move to “${to.label}”'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Operational note (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(c.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ReviewPolicy.nextFrom(review.state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ReviewStateChip(review.state),
        ),
        const SizedBox(height: Space.xs),
        if (review.note != null) FactRow(label: 'Note', value: review.note!),
        if (review.disposition != null)
          FactRow(label: 'Disposition', value: review.disposition!.label),
        const SizedBox(height: Space.sm),
        for (final to in next) ...[
          DoseBandButton.secondary(
            label: 'Move to ${to.label.toLowerCase()}',
            onPressed: () => _move(context, ref, to),
          ),
          const SizedBox(height: Space.sm),
        ],
        if (review.state == ReviewState.reviewed &&
            review.disposition == null) ...[
          Text(
            'Record the follow-up. These are operational actions, not medical '
            'conclusions; a referral uses the site’s own procedure.',
            style: context.type.caption.copyWith(
              color: context.product.textSecondary,
            ),
          ),
          const SizedBox(height: Space.sm),
          for (final d in ReviewDisposition.values) ...[
            DoseBandButton.tertiary(
              label: d.label,
              expand: true,
              onPressed: () => ref
                  .read(hseCommandsProvider)
                  .recordDisposition(
                    measurementId: measurementId,
                    disposition: d,
                  ),
            ),
          ],
        ],
      ],
    );
  }
}

class HseMoreScreen extends StatelessWidget {
  const HseMoreScreen({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) => WorkspaceMoreScreen(config: config);
}
