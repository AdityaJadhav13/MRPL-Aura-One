import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate.dart';
import '../../../core/demo/ui_demo_catalog.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';
import 'hse_review_screens.dart';
import 'hse_screens.dart';

/// Measurement review — the HSE technical workstation for one record.
///
/// ## The reviewer cannot change the number
///
/// There is no control here that edits a measured value, and there never
/// should be. A reviewer decides what to *do* about a record; the measurement
/// is what the instrument reported. An editable value would make every record
/// in the register an opinion, and the audit trail would record the opinion
/// rather than the reading.
class MeasurementReviewScreen extends StatelessWidget {
  const MeasurementReviewScreen({required this.record, super.key});

  final DemoExposureRecord record;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final w = record.worker;

    return SafetyScaffold(
      title: 'Measurement review',
      subtitle: record.recordId,
      children: [
        const DemoDataBanner(
          message:
              'This record is a demonstration row. It describes no real '
              'worker and no real measurement.',
        ),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Result'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.noValue,
                    style: t.readoutHero.copyWith(
                      color: corporate.textSecondary,
                    ),
                  ),
                  const SizedBox(width: Space.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.outcome.label,
                          style: t.bodyStrong.copyWith(
                            color: corporate.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record.refusalReason == null
                              ? 'Quantitative H₂S calibration is not '
                                    'available, so no exposure quantity can '
                                    'be reported for this reading.'
                              : 'No number can be reported for this record. '
                                    'Reason: ${record.refusalReason}.',
                          style: t.caption.copyWith(
                            color: corporate.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Divider(color: corporate.border),
              const SizedBox(height: Space.xs),
              Text(
                'This is not an exposure of zero. It means the exposure over '
                'this period is unknown.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Worker'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Name', value: w.name),
              RecordRow(label: 'Worker ID', value: w.workerId, mono: true),
              RecordRow(label: 'Type', value: w.typeLabel),
              if (w.contractorCompany != null)
                RecordRow(label: 'Contractor', value: w.contractorCompany!),
              RecordRow(label: 'Department', value: w.department),
            ],
          ),
        ),

        const SectionHeader(title: 'Work context'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Work area', value: w.workArea),
              RecordRow(label: 'Shift', value: w.shift),
              const RecordRow(
                label: 'PTW reference',
                value: 'PTW-DEMO-4471',
                mono: true,
                origin: DataOrigin.uiDemo,
              ),
              const RecordRow(
                label: 'JSA reference',
                value: 'JSA-DEMO-2048',
                mono: true,
                origin: DataOrigin.uiDemo,
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
            ],
          ),
        ),

        const SectionHeader(title: 'Badge'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Badge', value: record.badgeId, mono: true),
              RecordRow(label: 'Batch', value: record.batchId, mono: true),
              const RecordRow(
                label: 'Geometry',
                value: 'badge-v1-research',
                mono: true,
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Calibration'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RecordRow(
                label: 'Calibration model',
                value: 'None',
                mono: true,
              ),
              const SizedBox(height: Space.xs),
              Text(
                'No validated calibration model exists. Without one there is '
                'no defensible mapping from colour to ppm·h, which is why '
                'this record carries no quantity.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Capture'),
        _CaptureCard(record: record),

        const SectionHeader(title: 'Image quality and reference checks'),
        _QualityCard(quality: record.quality),

        const SectionHeader(title: 'Algorithm and versions'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(label: 'Algorithm version', value: 'sim-0', mono: true),
              RecordRow(
                label: 'Feature definition',
                value: 'fdv-0.2.0-m0b',
                mono: true,
              ),
              RecordRow(label: 'App version', value: '0.1.0+1', mono: true),
              RecordRow(label: 'Data domain', value: 'simulated'),
            ],
          ),
        ),

        const SectionHeader(title: 'Environmental context'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RecordRow(label: 'Temperature', value: 'Not recorded'),
              const RecordRow(
                label: 'Relative humidity',
                value: 'Not recorded',
              ),
              const SizedBox(height: Space.xs),
              Text(
                'No environmental sensing exists. These are shown as not '
                'recorded rather than omitted, because environment is part of '
                'a calibration’s validated domain and a reviewer needs to see '
                'that it is missing.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Audit'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(
                label: 'Scanned',
                value: Fmt.stamp(record.endedAt),
                mono: true,
              ),
              RecordRow(label: 'Recorded by', value: record.worker.workerId),
              const RecordRow(label: 'Device', value: 'DEV-8841', mono: true),
              const RecordRow(label: 'Source', value: 'DoseBand app'),
              const RecordRow(label: 'Signature', value: 'Not applicable'),
            ],
          ),
        ),

        const SectionHeader(title: 'Review'),
        // The measurement itself is immutable: there is no editable field for
        // a dose, an optical feature or a calibration output anywhere on this
        // screen. Review changes workflow state, not instrument output.
        DispositionLauncher(record: record),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'The measurement record is immutable. A reviewer decides what to '
            'do about a record; they do not change what it says.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// What the capture was.
class _CaptureCard extends StatelessWidget {
  const _CaptureCard({required this.record});

  final DemoExposureRecord record;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A neutral placeholder, not a fabricated badge photograph. The
          // image surfaces stay chromatically neutral wherever a badge would
          // appear, and there is no image to show.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: context.colours.surfaceViewfinder,
                borderRadius: BorderRadius.circular(CorporateRadii.sm),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 30,
                      color: Neutral.l74,
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      'No capture stored',
                      style: t.caption.copyWith(color: Neutral.l86),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          RecordRow(
            label: 'Captured',
            value: Fmt.stamp(record.endedAt),
            mono: true,
          ),
          const RecordRow(label: 'Rectified preview', value: 'Not stored'),
          const SizedBox(height: Space.xs),
          Text(
            'This prototype does not retain capture images. A stored image is '
            'a record in its own right, with retention and access rules that '
            'have not been decided.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The checks the pipeline actually ran.
class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.quality});

  final DemoCaptureQuality? quality;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final q = quality;

    if (q == null) {
      return InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Not assessed',
              style: t.bodyStrong.copyWith(color: corporate.textPrimary),
            ),
            const SizedBox(height: Space.sm),
            Text(
              'No quality checks were recorded for this record. That is not '
              'the same as the checks passing — nothing ran, or nothing was '
              'kept.',
              style: t.body.copyWith(color: corporate.textSecondary),
            ),
          ],
        ),
      );
    }

    String ratio(int? found, int? expected) => found == null || expected == null
        ? 'Not assessed'
        : '$found of $expected';

    String verdict(bool? value, {required String pass, required String fail}) =>
        value == null ? 'Not assessed' : (value ? pass : fail);

    return InfoCard(
      child: Column(
        children: [
          RecordRow(
            label: 'Focus',
            value: verdict(q.focusAssessed, pass: 'Acceptable', fail: 'Poor'),
          ),
          RecordRow(
            label: 'Exposure',
            value: verdict(
              q.exposureAssessed,
              pass: 'Acceptable',
              fail: 'Poor',
            ),
          ),
          RecordRow(
            label: 'Glare',
            value: verdict(
              q.glareDetected,
              pass: 'Detected',
              fail: 'None detected',
            ),
          ),
          RecordRow(
            label: 'Fiducials found',
            value: ratio(q.fiducialsFound, q.fiducialsExpected),
            mono: true,
          ),
          RecordRow(
            label: 'Reference patches read',
            value: ratio(q.referencePatchesRead, q.referencePatchesExpected),
            mono: true,
          ),
        ],
      ),
    );
  }
}

/// Worker search over the demo directory.
class HseWorkerSearchScreen extends StatefulWidget {
  const HseWorkerSearchScreen({super.key});

  @override
  State<HseWorkerSearchScreen> createState() => _HseWorkerSearchScreenState();
}

class _HseWorkerSearchScreenState extends State<HseWorkerSearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final workers = UiDemoCatalog.workers()
        .where(
          (w) =>
              _query.isEmpty ||
              w.name.toLowerCase().contains(_query.toLowerCase()) ||
              w.workerId.toLowerCase().contains(_query.toLowerCase()) ||
              (w.contractorCompany ?? '').toLowerCase().contains(
                _query.toLowerCase(),
              ),
        )
        .toList();

    return SafetyScaffold(
      title: 'Workers',
      subtitle: 'Demonstration directory',
      bottom: CorporateSearchField(
        hint: 'Search name, worker ID or contractor',
        onChanged: (v) => setState(() => _query = v),
      ),
      children: [
        const DemoDataBanner(
          message:
              'A demonstration directory. No organisation directory is '
              'connected, and these are not real people.',
        ),
        const SizedBox(height: Space.base),
        if (workers.isEmpty)
          const InfoCard(child: Text('No workers match this search.'))
        else
          for (final w in workers)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: InfoCard(
                onTap: () => context.push('/hse/worker', extra: w),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.name,
                            style: t.bodyStrong.copyWith(
                              color: corporate.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${w.workerId} · ${w.typeLabel} · ${w.department}',
                            style: t.caption.copyWith(
                              color: corporate.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: corporate.textSecondary),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// One worker's exposure profile.
class WorkerExposureProfileScreen extends StatelessWidget {
  const WorkerExposureProfileScreen({required this.worker, super.key});

  final DemoWorker worker;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final records = UiDemoCatalog.exposureRecords()
        .where((r) => r.worker.workerId == worker.workerId)
        .toList();

    return SafetyScaffold(
      title: worker.name,
      subtitle: '${worker.workerId} · ${worker.typeLabel}',
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Identity'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Worker ID', value: worker.workerId, mono: true),
              RecordRow(label: 'Employment', value: worker.typeLabel),
              if (worker.contractorCompany != null)
                RecordRow(
                  label: 'Contractor',
                  value: worker.contractorCompany!,
                ),
              RecordRow(label: 'Department', value: worker.department),
              RecordRow(label: 'Current area', value: worker.workArea),
              RecordRow(label: 'Shift', value: worker.shift),
            ],
          ),
        ),

        const SectionHeader(title: 'Cumulative exposure'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.noValue,
                    style: t.readoutLarge.copyWith(
                      color: corporate.textSecondary,
                    ),
                  ),
                  const SizedBox(width: Space.base),
                  Expanded(
                    child: Text(
                      'Unavailable',
                      style: t.bodyStrong.copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              // The most tempting number in the entire product, and the one
              // least entitled to exist.
              Text(
                'DoseBand does not present a lifetime or cumulative exposure '
                'figure. No calibration exists to produce the individual '
                'quantities, and summing readings across different badges, '
                'periods and work contexts would not give a defensible total '
                'even once it does. A number here would be believed, acted '
                'on, and wrong.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Records'),
        if (records.isEmpty)
          const InfoCard(child: Text('No records for this worker.'))
        else
          for (final r in records)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: ExposureRecordCard(record: r),
            ),
      ],
    );
  }
}

/// The exception queue, grouped by reason.
///
/// ## Why there is no severity here
///
/// Exceptions are grouped by **what went wrong** and filtered by **where the
/// record is in the workflow**. There is no low/medium/high banding: a
/// severity scale is a clinical or regulatory classification, and inventing
/// one would let an officer sort the queue by a number this product has no
/// basis to produce — and then work down it as though the ordering meant
/// something.
class ExceptionQueueScreen extends StatefulWidget {
  const ExceptionQueueScreen({super.key});

  @override
  State<ExceptionQueueScreen> createState() => _ExceptionQueueScreenState();
}

class _ExceptionQueueScreenState extends State<ExceptionQueueScreen> {
  DemoReviewState? _state;

  @override
  Widget build(BuildContext context) {
    final all = UiDemoCatalog.exceptions();
    final exceptions = all
        .where((e) => _state == null || e.reviewState == _state)
        .toList();

    final byReason = <String, List<DemoExposureRecord>>{};
    for (final e in exceptions) {
      byReason.putIfAbsent(e.refusalReason!, () => []).add(e);
    }

    return SafetyScaffold(
      title: 'Exceptions',
      subtitle: 'Records with no valid reading',
      bottom: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: ChoiceChip(
                label: Text('All (${all.length})'),
                selected: _state == null,
                showCheckmark: true,
                onSelected: (_) => setState(() => _state = null),
              ),
            ),
            for (final state in DemoReviewState.values)
              if (all.any((e) => e.reviewState == state))
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: ChoiceChip(
                    label: Text(
                      '${state.label} '
                      '(${all.where((e) => e.reviewState == state).length})',
                    ),
                    selected: _state == state,
                    showCheckmark: true,
                    onSelected: (selected) =>
                        setState(() => _state = selected ? state : null),
                  ),
                ),
          ],
        ),
      ),
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),
        if (byReason.isEmpty)
          const InfoCard(
            child: Text('No exceptions match this workflow state.'),
          )
        else
          for (final entry in byReason.entries) ...[
            SectionHeader(
              title: entry.key,
              subtitle: '${entry.value.length} record(s)',
            ),
            for (final record in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: ExposureRecordCard(record: record),
              ),
          ],
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'Exceptions are grouped by what the pipeline reported and '
            'filtered by workflow state. DoseBand does not rank them by '
            'severity — it has no basis on which to do so.',
            style: context.type.caption.copyWith(
              color: context.corporate.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Badge inventory.
class BadgeInventoryScreen extends StatefulWidget {
  const BadgeInventoryScreen({super.key});

  @override
  State<BadgeInventoryScreen> createState() => _BadgeInventoryScreenState();
}

class _BadgeInventoryScreenState extends State<BadgeInventoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final badges = UiDemoCatalog.badges()
        .where(
          (b) =>
              _query.isEmpty ||
              b.badgeId.toLowerCase().contains(_query.toLowerCase()) ||
              b.batchId.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return SafetyScaffold(
      title: 'Badge inventory',
      subtitle: 'Demonstration stock',
      bottom: CorporateSearchField(
        hint: 'Search badge or batch',
        onChanged: (v) => setState(() => _query = v),
      ),
      children: [
        const DemoDataBanner(
          message:
              'No DoseBand badge has been manufactured. These rows exist so '
              'the inventory surface can be reviewed; they record no real '
              'stock and no manufacturing release.',
        ),
        const SizedBox(height: Space.base),
        for (final badge in badges)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: InfoCard(
              onTap: () => context.push('/hse/batch', extra: badge.batchId),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.badgeId,
                          style: t.readoutSmall.copyWith(
                            color: corporate.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Batch ${badge.batchId}',
                          style: t.caption.copyWith(
                            color: corporate.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(label: badge.status.label),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.sm),
        border: Border.all(color: corporate.border),
      ),
      child: Text(
        label,
        style: context.type.caption.copyWith(color: corporate.textSecondary),
      ),
    );
  }
}

/// Batch detail.
class BatchDetailScreen extends StatelessWidget {
  const BatchDetailScreen({required this.batchId, super.key});

  final String batchId;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final batch = UiDemoCatalog.batches().firstWhere(
      (b) => b.batchId == batchId,
      orElse: () => UiDemoCatalog.batches().first,
    );

    return SafetyScaffold(
      title: 'Batch ${batch.batchId}',
      subtitle: 'Manufacturing and calibration association',
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Batch', value: batch.batchId, mono: true),
              RecordRow(label: 'Formulation', value: batch.formulation),
              RecordRow(
                label: 'Geometry',
                value: batch.geometryVersion,
                mono: true,
              ),
              RecordRow(label: 'Badges', value: '${batch.badgeCount}'),
              // Deliberately unavailable rather than invented.
              RecordRow(
                label: 'Manufactured',
                value: batch.manufacturedAt == null
                    ? 'Unavailable'
                    : Fmt.date(batch.manufacturedAt!),
              ),
              RecordRow(
                label: 'Expires',
                value: batch.expiresAt == null
                    ? 'Unavailable'
                    : Fmt.date(batch.expiresAt!),
              ),
              const RecordRow(label: 'Calibration model', value: 'None'),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'Manufacture and expiry are unavailable because no badge has been '
            'manufactured. A fabricated manufacturing date would be a '
            'supply-chain record, and those get trusted without question.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Calibration detail — the most scientifically consequential screen here.
class CalibrationDetailScreen extends StatelessWidget {
  const CalibrationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Calibration',
      subtitle: 'Model packages',
      children: [
        InfoCard(
          emphasis: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 21,
                    color: corporate.textSecondary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'No production calibration available',
                      style: t.heading.copyWith(color: corporate.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.base),
              Text(
                'DoseBand converts a colour measurement into cumulative '
                'exposure using a calibration model. No such model exists: no '
                'laboratory data has been collected, and the scientific gates '
                'that would justify one are open.',
                style: t.body.copyWith(color: corporate.textSecondary),
              ),
              const SizedBox(height: Space.base),
              Text(
                'Until that changes, DoseBand reports that a badge was read '
                'and that the quantity is unavailable. It does not estimate, '
                'interpolate or approximate a figure.',
                style: t.body.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Open scientific gates'),
        InfoCard(
          child: Column(
            children: const [
              _Gate(
                code: 'S1',
                question:
                    'Passive uptake — does the badge sample H₂S at a known, '
                    'reproducible rate?',
              ),
              _Gate(
                code: 'S2',
                question:
                    'Chemical integration — is the colour change a faithful '
                    'integral of exposure?',
              ),
              _Gate(
                code: 'S3',
                question:
                    'Selectivity — what else changes the colour, and by how '
                    'much?',
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Package fields',
          subtitle: 'The shape a calibration will take',
        ),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(label: 'Calibration ID', value: 'Unavailable'),
              RecordRow(label: 'Version', value: 'Unavailable'),
              RecordRow(label: 'Formulation', value: 'Unavailable'),
              RecordRow(label: 'Geometry', value: 'badge-v1-research'),
              RecordRow(label: 'Model type', value: 'Unavailable'),
              RecordRow(label: 'Validated domain', value: 'Unavailable'),
              RecordRow(label: 'Created', value: 'Unavailable'),
              RecordRow(label: 'Status', value: 'None exists'),
              RecordRow(label: 'Superseded by', value: 'Not applicable'),
              RecordRow(label: 'Evidence summary', value: 'Unavailable'),
            ],
          ),
        ),

        const SectionHeader(
          title: 'Performance metrics',
          subtitle: 'Produced by experiments, not by software',
        ),
        InfoCard(
          child: Column(
            children: const [
              // Deliberately empty. Each of these is a number a reader would
              // act on, and each requires an experiment nobody has run.
              RecordRow(label: 'Accuracy', value: 'Unavailable'),
              RecordRow(label: 'Limit of detection', value: 'Unavailable'),
              RecordRow(label: 'Limit of quantification', value: 'Unavailable'),
              RecordRow(label: 'RMSE', value: 'Unavailable'),
              RecordRow(label: 'R²', value: 'Unavailable'),
              RecordRow(label: 'Uncertainty budget', value: 'Unavailable'),
              RecordRow(label: 'Validated range', value: 'Unavailable'),
            ],
          ),
        ),

        const SectionHeader(
          title: 'Versioning',
          subtitle: 'How a future recalibration will behave',
        ),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              _VersionState(
                label: 'Current',
                detail: 'The model new readings are measured against',
              ),
              _VersionState(
                label: 'Superseded',
                detail: 'Replaced, but kept — old records keep their model',
              ),
              _VersionState(
                label: 'Research',
                detail: 'Under evaluation; never used for a field reading',
              ),
              _VersionState(
                label: 'Unavailable',
                detail: 'The state today: no model exists',
                isCurrent: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recalibration never rewrites history',
                style: t.bodyStrong.copyWith(color: corporate.textPrimary),
              ),
              const SizedBox(height: Space.sm),
              Text(
                'A new calibration supersedes the old one for future '
                'readings. It does not silently restate past measurements: a '
                'record keeps the model that produced it, and a re-evaluation '
                'creates a new result beside the original rather than '
                'replacing it.',
                style: t.body.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'No accuracy figure, limit of detection, limit of quantification '
            'or coefficient of determination is shown anywhere in this '
            'application, because no experiment has produced one.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({required this.code, required this.question});

  final String code;
  final String question;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              code,
              style: t.readoutSmall.copyWith(color: corporate.textPrimary),
            ),
          ),
          Expanded(
            child: Text(
              question,
              style: t.caption.copyWith(color: corporate.textSecondary),
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(
            'OPEN',
            style: t.caption.copyWith(
              color: corporate.accent,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// One calibration lifecycle state.
class _VersionState extends StatelessWidget {
  const _VersionState({
    required this.label,
    required this.detail,
    this.isCurrent = false,
  });

  final String label;
  final String detail;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.md,
      ),
      child: Row(
        children: [
          Icon(
            isCurrent ? Icons.radio_button_checked : Icons.circle_outlined,
            size: 17,
            color: isCurrent ? corporate.accent : corporate.textSecondary,
          ),
          const SizedBox(width: Space.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: t.body.copyWith(color: corporate.textPrimary),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Text(
              'Now',
              style: t.caption.copyWith(
                color: corporate.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// Audit trail.
class AuditTrailScreen extends StatelessWidget {
  const AuditTrailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final entries = UiDemoCatalog.auditTrail();

    return SafetyScaffold(
      title: 'Audit trail',
      subtitle: 'Recorded actions',
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),
        InfoCard(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++)
                _AuditRow(entry: entries[i], isLast: i == entries.length - 1),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'Entries are not digitally signed. DoseBand does not hold signing '
            'keys, so presenting a signature would be a claim about integrity '
            'that nothing backs.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry, required this.isLast});

  final DemoAuditEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: corporate.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1, color: corporate.border)),
            ],
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Space.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.action,
                    style: t.body.copyWith(color: corporate.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Fmt.stamp(entry.at)} · ${entry.actor} · ${entry.entity}',
                    style: t.caption.copyWith(color: corporate.textSecondary),
                  ),
                  if (entry.previousState != null && entry.newState != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Text(
                            entry.previousState!,
                            style: t.caption.copyWith(
                              color: corporate.textSecondary,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.xs,
                            ),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 11,
                              color: corporate.textSecondary,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              entry.newState!,
                              style: t.caption.copyWith(
                                color: corporate.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (entry.reason case final reason?)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        reason,
                        style: t.caption.copyWith(
                          color: corporate.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      entry.device == null
                          ? entry.source
                          : '${entry.source} · ${entry.device}',
                      style: t.caption.copyWith(
                        color: corporate.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
