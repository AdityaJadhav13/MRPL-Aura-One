import 'package:flutter/foundation.dart';

import '../../../core/domain/doseband.dart';
import '../../../core/domain/doseband_registry.dart';
import '../../../core/domain/monitoring_session.dart';
import '../../../core/domain/provenance.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/assignment.dart';
import '../domain/audit.dart';
import '../domain/inventory.dart';
import '../domain/operations_snapshot.dart';
import 'access.dart';
import 'operations_repository.dart';

/// Whether [dosebandId] may be claimed by [workerId] right now (§10).
///
/// The registry half of the pre-use check: facts the inventory knows. The
/// optical half — can the band be read — is the camera's, and is separate on
/// purpose, because a failure there says nothing about the band.
@immutable
sealed class Eligibility {
  const Eligibility();
}

final class Eligible extends Eligibility {
  const Eligible(this.band, this.lot);
  final DoseBand band;
  final DoseBandLot lot;
}

/// The band must not be used. Carries the reason, where the inventory knows
/// it; never who else holds it.
final class NotEligible extends Eligibility {
  const NotEligible(this.reason, {this.lifecycle});
  final ReplaceReason reason;
  final DoseBandLifecycle? lifecycle;
}

/// This worker already has a DoseBand that has not been finished. A second
/// claim would leave two bands attributed to one person at once (§18).
final class WorkerHasActiveBand extends Eligibility {
  const WorkerHasActiveBand(this.assignment);
  final DoseBandAssignment assignment;
}

abstract final class DoseBandEligibility {
  static Eligibility assess(
    OperationsSnapshot s, {
    required String dosebandId,
    required String workerId,
    required DateTime now,
  }) {
    final active = s.activeAssignmentOf(workerId);
    final band = s.bands[dosebandId];
    if (band == null) {
      return const NotEligible(ReplaceReason.unknownDoseBand);
    }
    // Rescanning the band you already hold is not a new claim.
    if (active != null && active.dosebandId != dosebandId) {
      return WorkerHasActiveBand(active);
    }
    final lot = s.lot(band.lotId);
    if (lot == null) {
      return NotEligible(
        ReplaceReason.unsupportedLot,
        lifecycle: band.lifecycle,
      );
    }
    switch (band.lifecycle) {
      case DoseBandLifecycle.available:
        break;
      case DoseBandLifecycle.assigned ||
          DoseBandLifecycle.monitoring ||
          DoseBandLifecycle.readyForFinalRead:
        return NotEligible(
          ReplaceReason.alreadyAssigned,
          lifecycle: band.lifecycle,
        );
      case DoseBandLifecycle.read ||
          DoseBandLifecycle.reviewed ||
          DoseBandLifecycle.readFailed ||
          DoseBandLifecycle.missingFinalRead ||
          DoseBandLifecycle.disposed:
        return NotEligible(
          ReplaceReason.alreadyUsed,
          lifecycle: band.lifecycle,
        );
      case DoseBandLifecycle.expired:
        return NotEligible(ReplaceReason.expired, lifecycle: band.lifecycle);
      case DoseBandLifecycle.damaged ||
          DoseBandLifecycle.lost ||
          DoseBandLifecycle.invalid ||
          DoseBandLifecycle.assignmentCancelled:
        return NotEligible(
          ReplaceReason.recordedDamaged,
          lifecycle: band.lifecycle,
        );
    }
    if (lot.isExpiredOn(now)) {
      return NotEligible(ReplaceReason.expired, lifecycle: band.lifecycle);
    }
    if (!lot.supportedConfiguration) {
      return NotEligible(
        ReplaceReason.unsupportedLot,
        lifecycle: band.lifecycle,
      );
    }
    return Eligible(band, lot);
  }

  /// Which bucket a band falls in for inventory counts — the lifecycle, plus
  /// the one derived fact the lifecycle does not carry: an unused band from
  /// an expired lot is expired whether or not anyone has marked it.
  static InventoryBucket bucketOf(
    OperationsSnapshot s,
    DoseBand band,
    DateTime now,
  ) {
    if (band.lifecycle == DoseBandLifecycle.available &&
        (s.lot(band.lotId)?.isExpiredOn(now) ?? false)) {
      return InventoryBucket.expired;
    }
    return InventoryBucket.of(band.lifecycle);
  }
}

/// The DoseBand registry this build has: the on-device operations store
/// (§9, §50).
///
/// Implements Phase 0's [DoseBandRegistry] contract, so a server-backed
/// registry can replace it without a screen changing. Claims are atomic
/// **within this device** — see [OperationsRepository]. Cross-device
/// uniqueness is NOT CONNECTED and nothing here pretends otherwise: every
/// accepted claim says it was decided locally.
final class LocalDoseBandRegistry implements DoseBandRegistry {
  LocalDoseBandRegistry({
    required this.repository,
    required this.ids,
    required this.now,
  });

  final OperationsRepository repository;
  final IdGenerator ids;
  final DateTime Function() now;

  @override
  Future<DoseBandLookup> lookup(String dosebandId) async {
    final s = await repository.current();
    final band = s.bands[dosebandId];
    return band == null ? const DoseBandNotFound() : DoseBandFound(band);
  }

  @override
  Future<ClaimResult> claim({
    required String dosebandId,
    required String workerId,
  }) => claimWith(dosebandId: dosebandId, workerId: workerId);

  /// Claims and opens the monitoring session in one transaction, recording
  /// the pre-use check the worker was shown. Re-assesses eligibility inside
  /// the transaction: whatever the screen saw a moment ago, the claim is
  /// decided against the store as it is now.
  Future<ClaimResult> claimWith({
    required String dosebandId,
    required String workerId,
    PreUseRecord? preUse,
    WorkSummary? work,
  }) => repository.transact((s) {
    // The claimant must be a real, active worker account. The caller passes
    // the signed-in identity; this does not take it on trust.
    final person = s.person(workerId);
    if (person == null || !person.active || !person.hasRole(AppRole.worker)) {
      throw const AccessDenied('Only a worker account can claim a DoseBand.');
    }
    final at = now();
    final verdict = DoseBandEligibility.assess(
      s,
      dosebandId: dosebandId,
      workerId: workerId,
      now: at,
    );
    switch (verdict) {
      case WorkerHasActiveBand():
        return (next: s, result: const ClaimWorkerHasActiveBand());
      case NotEligible(:final reason, :final lifecycle):
        if (reason == ReplaceReason.unknownDoseBand) {
          return (next: s, result: const ClaimNotFound());
        }
        final band = s.bands[dosebandId];
        final held = band?.assignmentId == null
            ? null
            : s.assignment(band!.assignmentId!);
        // Only a claim that is still open counts as "yours": a band from a
        // finished period is spent, whoever wore it.
        final heldBySelf =
            held != null && held.isActive && held.workerId == workerId;
        if (heldBySelf) {
          // Idempotent: the same worker re-claiming the band they already
          // hold gets the same assignment back, not a conflict (§53).
          return (
            next: s,
            result: ClaimAccepted(
              doseband: band!,
              assignmentId: held.assignmentId,
            ),
          );
        }
        if (reason == ReplaceReason.alreadyAssigned) {
          return (next: s, result: const ClaimConflict());
        }
        return (
          next: s,
          result: ClaimIneligible(
            lifecycle ??
                (reason == ReplaceReason.expired
                    ? DoseBandLifecycle.expired
                    : DoseBandLifecycle.invalid),
          ),
        );
      case Eligible(:final band):
        final assignmentId = ids.next('ASG');
        final sessionId = ids.next('SES');
        final claimed = band.claimedUnder(assignmentId)!;
        final next = s
            .withBand(claimed)
            .copyWith(
              assignments: [
                ...s.assignments,
                DoseBandAssignment(
                  assignmentId: assignmentId,
                  dosebandId: dosebandId,
                  workerId: workerId,
                  sessionId: sessionId,
                  claimedAt: at,
                  state: AssignmentState.active,
                  preUse: preUse,
                ),
              ],
              sessions: [
                ...s.sessions,
                MonitoringSession(
                  sessionId: sessionId,
                  workerId: workerId,
                  state: MonitoringSessionState.notStarted,
                  provenance: RecordProvenance.realLocal,
                  dosebandId: dosebandId,
                  assignmentId: assignmentId,
                  work: work,
                ),
              ],
              audit: [
                ...s.audit,
                AuditEvent(
                  eventId: ids.next('AUD'),
                  at: at,
                  actorId: workerId,
                  actorRole: AppRole.worker,
                  action: AuditAction.dosebandClaimed,
                  subjectType: 'doseband',
                  subjectId: dosebandId,
                  detail: preUse == null
                      ? 'Claimed on this device.'
                      : 'Claimed on this device. Pre-use: '
                            '${preUse.outcome.label}; optical: '
                            '${preUse.opticalCheck.label}.',
                ),
              ],
            );
        return (
          next: next,
          result: ClaimAccepted(doseband: claimed, assignmentId: assignmentId),
        );
    }
  });
}
