import 'package:flutter/foundation.dart';

import '../../features/workflow/domain/physical_badge.dart';
import 'provenance.dart';
import 'provenance_mapping.dart';

/// The lifecycle of one physical, disposable DoseBand (APP-PRODUCT-01 §36).
///
/// A DoseBand is worn for **one** monitoring period and then leaves service.
/// There is no transition from any post-read state back to [available]: a
/// band is never reused across shifts (§1, §118).
enum DoseBandLifecycle {
  // ---- operational
  /// In inventory, never assigned. Eligible to be claimed.
  available,

  /// Claimed by a worker; pre-use check done; monitoring not yet started.
  assigned,

  /// Being worn in an active monitoring period.
  monitoring,

  /// Monitoring has ended; the final optical read is due.
  readyForFinalRead,

  /// The final read happened. Its *result* may be a value or a refusal — this
  /// state says only that the read occurred.
  read,

  /// An HSE officer has reviewed the record.
  reviewed,

  /// Out of service and disposed of under the site procedure. Terminal.
  disposed,

  // ---- exceptional
  /// Physically damaged before or during use.
  damaged,

  /// Not returned for its final read.
  lost,

  /// Failed validation: unrecognised, already used, unsupported lot.
  invalid,

  /// Past its printed expiry before use.
  expired,

  /// Assigned, then the assignment was withdrawn before monitoring began.
  assignmentCancelled,

  /// A final read was attempted and could not be completed.
  readFailed,

  /// Monitoring ended and no final read was ever recorded.
  missingFinalRead;

  bool get isExceptional => index >= DoseBandLifecycle.damaged.index;

  /// No further transition exists from here.
  bool get isTerminal => DoseBandLifecyclePolicy._next[this]!.isEmpty;

  /// The lifecycle word, qualified so it cannot be confused with a monitoring
  /// or measurement state of the same name (§140 Q22).
  String get label => switch (this) {
    DoseBandLifecycle.available => 'DoseBand available',
    DoseBandLifecycle.assigned => 'DoseBand assigned',
    DoseBandLifecycle.monitoring => 'DoseBand in use',
    DoseBandLifecycle.readyForFinalRead => 'Ready for final scan',
    DoseBandLifecycle.read => 'DoseBand read',
    DoseBandLifecycle.reviewed => 'Record reviewed',
    DoseBandLifecycle.disposed => 'DoseBand disposed',
    DoseBandLifecycle.damaged => 'DoseBand damaged',
    DoseBandLifecycle.lost => 'DoseBand lost',
    DoseBandLifecycle.invalid => 'DoseBand invalid',
    DoseBandLifecycle.expired => 'DoseBand expired',
    DoseBandLifecycle.assignmentCancelled => 'Assignment cancelled',
    DoseBandLifecycle.readFailed => 'Final scan failed',
    DoseBandLifecycle.missingFinalRead => 'Final scan missing',
  };
}

/// Which lifecycle transitions are legal.
///
/// The UI never writes a lifecycle state; it asks this policy for the next
/// one. An illegal transition is a typed refusal, not an exception, so a
/// screen can explain it (§36).
///
/// **Local rule only.** Claiming an available band is ultimately decided by
/// the central server, atomically, so two workers cannot both win (§127).
/// This policy answers "is this transition ever legal", not "did I win".
abstract final class DoseBandLifecyclePolicy {
  static const Map<DoseBandLifecycle, Set<DoseBandLifecycle>> _next = {
    DoseBandLifecycle.available: {
      DoseBandLifecycle.assigned,
      DoseBandLifecycle.damaged,
      DoseBandLifecycle.lost,
      DoseBandLifecycle.invalid,
      DoseBandLifecycle.expired,
    },
    DoseBandLifecycle.assigned: {
      DoseBandLifecycle.monitoring,
      DoseBandLifecycle.assignmentCancelled,
      DoseBandLifecycle.damaged,
      DoseBandLifecycle.lost,
      DoseBandLifecycle.invalid,
    },
    DoseBandLifecycle.monitoring: {
      DoseBandLifecycle.readyForFinalRead,
      DoseBandLifecycle.damaged,
      DoseBandLifecycle.lost,
    },
    DoseBandLifecycle.readyForFinalRead: {
      DoseBandLifecycle.read,
      DoseBandLifecycle.readFailed,
      DoseBandLifecycle.missingFinalRead,
      DoseBandLifecycle.damaged,
      DoseBandLifecycle.lost,
    },
    DoseBandLifecycle.read: {
      DoseBandLifecycle.reviewed,
      DoseBandLifecycle.disposed,
    },
    DoseBandLifecycle.reviewed: {DoseBandLifecycle.disposed},
    // A failed read may be retried while the band is still in hand.
    DoseBandLifecycle.readFailed: {
      DoseBandLifecycle.read,
      DoseBandLifecycle.missingFinalRead,
      DoseBandLifecycle.disposed,
    },
    DoseBandLifecycle.damaged: {DoseBandLifecycle.disposed},
    DoseBandLifecycle.invalid: {DoseBandLifecycle.disposed},
    DoseBandLifecycle.expired: {DoseBandLifecycle.disposed},
    DoseBandLifecycle.assignmentCancelled: {DoseBandLifecycle.disposed},
    DoseBandLifecycle.missingFinalRead: {DoseBandLifecycle.disposed},
    // A lost band that turns up is not put back into service: its history is
    // unknown. It can only be disposed of.
    DoseBandLifecycle.lost: {DoseBandLifecycle.disposed},
    DoseBandLifecycle.disposed: {},
  };

  static Set<DoseBandLifecycle> nextFrom(DoseBandLifecycle from) =>
      _next[from]!;

  static bool allows(DoseBandLifecycle from, DoseBandLifecycle to) =>
      _next[from]!.contains(to);

  static LifecycleTransition<DoseBandLifecycle> transition(
    DoseBandLifecycle from,
    DoseBandLifecycle to,
  ) => allows(from, to)
      ? LifecycleTransition.accepted(to)
      : LifecycleTransition.refused(from, to);
}

/// The outcome of asking a lifecycle policy for a transition.
@immutable
sealed class LifecycleTransition<S extends Enum> {
  const LifecycleTransition();

  const factory LifecycleTransition.accepted(S state) = TransitionAccepted<S>;
  const factory LifecycleTransition.refused(S from, S to) =
      TransitionRefused<S>;
}

final class TransitionAccepted<S extends Enum> extends LifecycleTransition<S> {
  const TransitionAccepted(this.state);
  final S state;
}

final class TransitionRefused<S extends Enum> extends LifecycleTransition<S> {
  const TransitionRefused(this.from, this.to);
  final S from;
  final S to;
}

/// One physical, serialised, disposable DoseBand (§35).
///
/// ## Relationship to existing types
///
/// The app already identifies bands through `BadgeIdentity`, implemented by
/// the real `PhysicalBadge` and the simulated `BadgeSpecimen`. Their
/// `badgeId` **is** the DoseBand id — the technical field keeps its historical
/// name because it is persisted and renaming it is a regression risk for no
/// behavioural gain (§2). [DoseBand.fromIdentity] is the bridge.
///
/// Fields that are not known are null. Manufacturing data is never invented:
/// a band typed in by hand has no lot until a registry supplies one.
@immutable
final class DoseBand {
  const DoseBand({
    required this.dosebandId,
    required this.lifecycle,
    required this.provenance,
    this.lotId,
    this.formulationId,
    this.expiry,
    this.assignmentId,
    this.calibrationApplicabilityId,
    this.geometryVersion,
  });

  /// Bridges the existing identity types to the canonical concept. Lifecycle
  /// is supplied by the caller because an identity alone does not know it.
  factory DoseBand.fromIdentity(
    BadgeIdentity identity, {
    required DoseBandLifecycle lifecycle,
    String? assignmentId,
    String? geometryVersion,
  }) => DoseBand(
    dosebandId: identity.badgeId,
    lifecycle: lifecycle,
    provenance: identity.isSimulated
        ? RecordProvenance.simulated
        : switch (identity) {
            PhysicalBadge(:final source) => source.provenance,
            _ => RecordProvenance.manualEntry,
          },
    lotId: identity.batch,
    formulationId: identity.formulation,
    expiry: identity.expiry,
    assignmentId: assignmentId,
    geometryVersion: geometryVersion,
  );

  /// The serialised identity printed on the band and encoded in its QR.
  /// Technical name `doseband_id`; historically `badge_id` (§2).
  final String dosebandId;

  final DoseBandLifecycle lifecycle;

  /// Where this band's identity came from. A simulated specimen is
  /// [RecordProvenance.simulated] and can never become a real band.
  final RecordProvenance provenance;

  /// Manufacturing lot / batch. Null when unknown.
  final String? lotId;

  final String? formulationId;

  /// Printed expiry, when known. Never inferred from the expiry patch.
  final DateTime? expiry;

  /// The assignment (claim) this band is under, if any.
  final String? assignmentId;

  /// Which calibration package applies to this band's lot, when one exists.
  /// None exists today: no production calibration (S1–S3 open).
  final String? calibrationApplicabilityId;

  /// The printed geometry the reader must use for this band.
  final String? geometryVersion;

  bool get isSimulated => provenance == RecordProvenance.simulated;

  /// The band claimed under [assignmentId], or null unless it is available.
  /// The only way a band acquires an assignment.
  DoseBand? claimedUnder(String assignmentId) =>
      switch (DoseBandLifecyclePolicy.transition(
        lifecycle,
        DoseBandLifecycle.assigned,
      )) {
        TransitionAccepted(:final state) => DoseBand(
          dosebandId: dosebandId,
          lifecycle: state,
          provenance: provenance,
          lotId: lotId,
          formulationId: formulationId,
          expiry: expiry,
          assignmentId: assignmentId,
          calibrationApplicabilityId: calibrationApplicabilityId,
          geometryVersion: geometryVersion,
        ),
        TransitionRefused() => null,
      };

  /// Returns the band in [to], or null if the lifecycle does not allow it.
  DoseBand? advanceTo(DoseBandLifecycle to) =>
      switch (DoseBandLifecyclePolicy.transition(lifecycle, to)) {
        TransitionAccepted(:final state) => DoseBand(
          dosebandId: dosebandId,
          lifecycle: state,
          provenance: provenance,
          lotId: lotId,
          formulationId: formulationId,
          expiry: expiry,
          assignmentId: assignmentId,
          calibrationApplicabilityId: calibrationApplicabilityId,
          geometryVersion: geometryVersion,
        ),
        TransitionRefused() => null,
      };
}
