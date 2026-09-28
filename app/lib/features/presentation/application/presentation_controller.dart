import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/doseband.dart';
import '../../auth/application/auth_controller.dart';
import '../../operations/application/operations_repository.dart';
import '../../operations/data/presentation_dataset.dart';
import '../../operations/domain/audit.dart';
import '../../workflow/application/workflow_controller.dart';
import '../../workflow/domain/workflow_state.dart';
import '../domain/presentation_mode.dart';

/// Presentation mode as the operator set it in Presentation Controls.
/// In memory only: every restart returns to the real path.
final presentationModeProvider =
    NotifierProvider<PresentationModeController, PresentationMode>(
      PresentationModeController.new,
    );

class PresentationModeController extends Notifier<PresentationMode> {
  @override
  PresentationMode build() => PresentationMode.off;

  void setEnabled(bool enabled) => state = state.copyWith(enabled: enabled);

  void setLevel(FallbackLevel level) => state = state.copyWith(level: level);
}

/// The fallback in force, or null when none may apply: presentation mode is
/// off, or this is a production build (which has no presentation accounts
/// and no presentation mode at all).
final activeFallbackProvider = Provider<FallbackLevel?>((ref) {
  if (!ref.watch(presentationAccessProvider)) return null;
  final mode = ref.watch(presentationModeProvider);
  return mode.enabled ? mode.level : null;
});

/// Whether [dosebandId] is the one presentation DoseBand. The fallback never
/// applies to any other band: a real band always takes the real path.
bool isPresentationBand(String dosebandId) =>
    dosebandId == PresentationDataset.presentationBandId;

/// The fallback that applies to [dosebandId] given the [active] level (from
/// [activeFallbackProvider]), or null: never for any band but the
/// presentation DoseBand.
FallbackLevel? fallbackFor(FallbackLevel? active, String dosebandId) =>
    active != null && isPresentationBand(dosebandId) ? active : null;

/// Workflow shortcuts for filming. Each is a real workflow transition or a
/// removal of presentation-origin data — never a measurement.
final presentationWorkflowProvider = Provider<PresentationWorkflow>(
  PresentationWorkflow.new,
);

class PresentationWorkflow {
  PresentationWorkflow(this._ref);

  final Ref _ref;

  /// Monitoring → ready for final read, now. The same transition the
  /// worker's "Complete monitoring" makes; it creates no exposure and no
  /// measurement.
  Future<bool> advanceToFinalRead() async {
    final session = _ref.read(shiftSessionProvider).value;
    if (session == null || session.stage != ShiftStage.monitoring) {
      return false;
    }
    await _ref.read(shiftSessionProvider.notifier).endMonitoring();
    return true;
  }

  /// Clears the presentation DoseBand's workflow so another take can start:
  /// its assignment, monitoring session and presentation-origin records, and
  /// the band back to available. Real records, real captures and the
  /// capture archive are not touched.
  Future<int> reset() async {
    const band = PresentationDataset.presentationBandId;
    final now = _ref.read(clockProvider);
    final ids = _ref.read(idGeneratorProvider);
    final actor = _ref.read(currentActorProvider);

    final removed = await _ref.read(operationsProvider.notifier).transact((s) {
      final gone = {
        for (final m in s.measurements)
          if (m.isPresentation) m.id,
      };
      final current = s.bands[band];
      final next = s.copyWith(
        measurements: [
          for (final m in s.measurements)
            if (!m.isPresentation) m,
        ],
        reviews: [
          for (final r in s.reviews)
            if (!gone.contains(r.measurementId)) r,
        ],
        assignments: [
          for (final a in s.assignments)
            if (a.dosebandId != band) a,
        ],
        sessions: [
          for (final x in s.sessions)
            if (x.dosebandId != band) x,
        ],
        bands: {
          ...s.bands,
          if (current != null)
            band: DoseBand(
              dosebandId: current.dosebandId,
              lifecycle: DoseBandLifecycle.available,
              provenance: current.provenance,
              lotId: current.lotId,
              formulationId: current.formulationId,
              expiry: current.expiry,
              geometryVersion: current.geometryVersion,
            ),
        },
      );
      return (
        next: actor == null
            ? next
            : next.appendAudit(
                AuditEvent(
                  eventId: ids.next('AUD'),
                  at: now(),
                  actorId: actor.personId,
                  actorRole: actor.role,
                  action: AuditAction.presentationDataReset,
                  subjectType: 'doseband',
                  subjectId: band,
                  detail:
                      'Presentation workflow reset: ${gone.length} '
                      'presentation record(s) removed',
                ),
              ),
        result: gone.length,
      );
    });

    // The device's own session, if it is the presentation band's.
    final session = _ref.read(shiftSessionProvider).value;
    if (session?.physicalBadge?.badgeId == band) {
      await _ref.read(shiftSessionProvider.notifier).reset();
    }
    return removed;
  }
}
