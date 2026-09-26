import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart';

import '../../core/components/corporate.dart';
import '../../core/components/step_scaffold.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../history/domain/measurement_record.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/data/simulation_catalog.dart';
import '../workflow/domain/badge_specimen.dart';
import '../workflow/domain/workflow_state.dart';

/// Development-only index of the worker screens, in each of their states.
///
/// ## Why this exists
///
/// Reviewing a refusal means arranging for a measurement to fail; reviewing an
/// untrusted clock means moving the device clock mid-shift. Those states are
/// the ones most worth looking at and the hardest to reach by hand, so without
/// a way in they simply do not get reviewed.
///
/// ## Why it cannot reach a worker
///
/// The route is registered only when [EnvironmentConfig.simulationAvailable]
/// is true — the same flag that compiles the design-system gallery and the
/// dossier capture tool out of release builds. There is no entry point to it
/// in the worker UI at all; it is reached from the development gallery.
///
/// Everything it seeds comes from `SimulationCatalog`, so every record it
/// produces is already marked simulated and can never become a production
/// record.
class WorkerPreviewScreen extends ConsumerWidget {
  const WorkerPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corporate = context.corporate;
    final t = context.type;

    Future<void> seedAndGo(ShiftStage stage, String route) async {
      final store = ref.read(workflowStoreProvider);
      await store.save(_sessionFor(stage));
      // Rebuild the session from the store so the screen reads exactly what
      // persistence would have handed it on a cold start.
      ref.invalidate(shiftSessionProvider);
      if (context.mounted) context.push(route);
    }

    void goToResult(BadgeSpecimen specimen) {
      final record = _recordFor(specimen);
      context.push('/result', extra: record);
    }

    return StepScaffold(
      title: 'Worker screen previews',
      simulated: true,
      children: [
        InfoCard(
          child: Text(
            'Development only. Each entry seeds the workflow store and opens '
            'the screen in that state. Nothing here is reachable from the '
            'worker interface, and every record is simulated.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),

        const SectionHeader(title: 'Workflow states'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _Row(
                label: 'Badge unassigned',
                detail: 'Home · work context recorded',
                onTap: () => seedAndGo(ShiftStage.contextSet, '/home'),
              ),
              _Row(
                label: 'Badge assigned',
                detail: 'Home · pre-work outstanding',
                onTap: () => seedAndGo(ShiftStage.badgeAssigned, '/home'),
              ),
              _Row(
                label: 'Pre-work complete',
                detail: 'Home · ready for dosimetry',
                onTap: () => seedAndGo(ShiftStage.readyForDosimetry, '/home'),
              ),
              _Row(
                label: 'Monitoring active',
                detail: 'Home · trusted duration',
                onTap: () => seedAndGo(ShiftStage.monitoring, '/home'),
              ),
              _Row(
                label: 'Scan required',
                detail: 'Home · monitoring ended',
                onTap: () => seedAndGo(ShiftStage.awaitingScan, '/home'),
              ),
              _Row(
                label: 'Untrusted clock',
                detail: 'Home · window runs backwards',
                onTap: () async {
                  final store = ref.read(workflowStoreProvider);
                  await store.save(
                    ShiftSession(
                      stage: ShiftStage.monitoring,
                      context: SimulationCatalog.demoContext(),
                      badge: SimulationCatalog.specimens().first,
                      // Started "in the future": what a clock change looks
                      // like from the other side.
                      startedAt: DateTime.now().add(const Duration(hours: 3)),
                    ),
                  );
                  ref.invalidate(shiftSessionProvider);
                  if (context.mounted) context.push('/home');
                },
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Instrument screens'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _Row(
                label: 'Scanner',
                detail: 'Guided scan',
                onTap: () => seedAndGo(ShiftStage.awaitingScan, '/read'),
              ),
              _Row(
                label: 'Processing',
                detail: 'Indeterminate pipeline state',
                onTap: () => seedAndGo(ShiftStage.awaitingScan, '/processing'),
              ),
              _Row(
                label: 'Badge QR scan',
                detail: 'Camera unavailable',
                onTap: () => context.push('/scan-badge'),
              ),
            ],
          ),
        ),

        const SectionHeader(
          title: 'Result and refusal',
          subtitle: 'One entry per declared specimen outcome',
        ),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final specimen in SimulationCatalog.specimens())
                _Row(
                  label: specimen.label,
                  detail: specimen.description,
                  onTap: () => goToResult(specimen),
                ),
            ],
          ),
        ),

        const SectionHeader(title: 'History'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _Row(
                label: 'History · empty',
                detail: 'No records yet',
                onTap: () => context.push('/history'),
              ),
              _Row(
                label: 'Exposure record',
                detail: 'Measurement detail',
                onTap: () => context.push(
                  '/measurement',
                  extra: _recordFor(SimulationCatalog.specimens().first),
                ),
              ),
              _Row(
                label: 'Badge traceability',
                detail: 'Lifecycle timeline',
                onTap: () => seedAndGo(ShiftStage.monitoring, '/traceability'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
      ],
    );
  }

  static ShiftSession _sessionFor(ShiftStage stage) {
    final now = DateTime.now();
    return ShiftSession(
      stage: stage,
      context: stage.index >= ShiftStage.contextSet.index
          ? SimulationCatalog.demoContext()
          : null,
      badge: stage.index >= ShiftStage.badgeAssigned.index
          ? SimulationCatalog.specimens().first
          : null,
      startedAt: stage.index >= ShiftStage.monitoring.index
          ? now.subtract(const Duration(hours: 3, minutes: 42))
          : null,
      endedAt: stage.index >= ShiftStage.awaitingScan.index ? now : null,
    );
  }

  /// A record carrying the specimen's declared outcome.
  ///
  /// The outcome is played through the real `MeasurementResult` types, so the
  /// result screen renders exactly what it would for a genuine reading of that
  /// status. Nothing is computed from an image.
  static MeasurementRecord _recordFor(BadgeSpecimen specimen) {
    final now = DateTime.now();
    final started = now.subtract(const Duration(hours: 7, minutes: 52));
    final provenance = SimulationCatalog.provenance(
      calibrationModelId: specimen.outcome is ValidOutcome
          ? specimen.calibrationModelId
          : null,
      geometryVersion: specimen.geometryVersion,
      appVersion: '0.1.0+1',
      deviceModel: 'Preview',
    );

    final result = switch (specimen.outcome) {
      ValidOutcome(
        :final dosePpmHours,
        :final uncertaintyHalfWidth,
        :final uncertaintyBasis,
        :final warning,
      ) =>
        Valid(
          dose: Dose.ppmHours(dosePpmHours),
          uncertainty: Uncertainty(
            halfWidth: uncertaintyHalfWidth,
            basis: uncertaintyBasis,
          ),
          coverage: now.difference(started),
          provenance: provenance,
          warnings: warning == null
              ? const []
              : [ReasonCode('PARTIAL_SHIFT', detail: warning)],
        ),
      CensoredOutcome(:final status, :final direction, :final boundPpmHours) =>
        Censored(
          status: status,
          direction: direction,
          bound: boundPpmHours == null ? null : Dose.ppmHours(boundPpmHours),
          reasons: [
            ReasonCode(
              direction == CensorDirection.above
                  ? 'ABOVE_RANGE'
                  : 'BELOW_QUANTIFICATION_LIMIT',
            ),
          ],
          provenance: provenance,
        ),
      RefusedOutcome(:final status, :final reason) => Refused(
        status: status,
        reasons: [reason],
        provenance: provenance,
      ),
    };

    return MeasurementRecord(
      id: 'preview-${specimen.badgeId}',
      result: result,
      badge: specimen,
      context: SimulationCatalog.demoContext(),
      startedAt: started,
      endedAt: now,
      scannedAt: now,
      // Stated, not defaulted: a preview replays a simulated specimen.
      domain: DataDomain.simulated,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.detail, required this.onTap});

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.md,
          ),
          child: Row(
            children: [
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
              Icon(
                Icons.chevron_right,
                size: 20,
                color: corporate.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
