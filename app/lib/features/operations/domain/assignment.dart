import 'package:flutter/foundation.dart';

/// What the pre-use check concluded before a DoseBand was assigned (§10, §11).
///
/// Three outcomes, and the distinction between the last two is the point:
/// a photograph that could not be read says nothing about the band.
enum PreUseOutcome {
  /// Known, eligible, and optically readable.
  readyToUse('DoseBand ready to use'),

  /// The band itself must not be used: already used, expired, unsupported,
  /// or recorded as damaged. Get another one.
  replace('Replace DoseBand'),

  /// The check could not be completed — usually the photograph. The band may
  /// be perfectly good. Try again.
  cannotVerify('Cannot verify — try again');

  const PreUseOutcome(this.label);

  final String label;
}

/// Why a band must be replaced, where known.
enum ReplaceReason {
  alreadyAssigned('This DoseBand is already assigned.'),
  alreadyUsed('This DoseBand has already been used.'),
  expired('This DoseBand is past its expiry date.'),
  unsupportedLot('This DoseBand’s lot is not supported by this app.'),
  recordedDamaged('This DoseBand is recorded as damaged or out of service.'),
  unknownDoseBand('This DoseBand is not in the inventory.');

  const ReplaceReason(this.message);

  final String message;
}

/// The recorded result of a pre-use check, kept on the assignment so the
/// supervisor and HSE can see what the worker was told.
@immutable
final class PreUseRecord {
  const PreUseRecord({
    required this.outcome,
    required this.checkedAt,
    required this.opticalCheck,
    this.captureId,
  });

  final PreUseOutcome outcome;
  final DateTime checkedAt;

  /// What the optical readability check established.
  final OpticalCheckStatus opticalCheck;

  /// The archived photograph behind the optical check, when one was taken.
  final String? captureId;
}

/// The optical half of the pre-use check.
enum OpticalCheckStatus {
  /// Target, fiducials, geometry and reference regions were all read.
  readable('Readable — geometry and reference regions found'),

  /// The photograph could not be read. Says nothing about the band.
  notReadable('Photograph not readable'),

  /// No optical check was performed (no camera on this device).
  notPerformed('Not performed');

  const OpticalCheckStatus(this.label);

  final String label;
}

enum AssignmentState {
  /// Claimed and not yet finished.
  active,

  /// The monitoring period it covered has ended with a final read, or has
  /// been closed out as an exception.
  completed,

  /// Withdrawn before monitoring began.
  cancelled,
}

/// One claim of one DoseBand by one worker (§12). Created only by the
/// registry's atomic claim; screens never construct one.
@immutable
final class DoseBandAssignment {
  const DoseBandAssignment({
    required this.assignmentId,
    required this.dosebandId,
    required this.workerId,
    required this.sessionId,
    required this.claimedAt,
    required this.state,
    this.preUse,
    this.endedAt,
    this.cancelReason,
  });

  final String assignmentId;
  final String dosebandId;
  final String workerId;
  final String sessionId;
  final DateTime claimedAt;
  final AssignmentState state;
  final PreUseRecord? preUse;
  final DateTime? endedAt;
  final String? cancelReason;

  bool get isActive => state == AssignmentState.active;

  DoseBandAssignment copyWith({
    AssignmentState? state,
    PreUseRecord? preUse,
    DateTime? endedAt,
    String? cancelReason,
  }) => DoseBandAssignment(
    assignmentId: assignmentId,
    dosebandId: dosebandId,
    workerId: workerId,
    sessionId: sessionId,
    claimedAt: claimedAt,
    state: state ?? this.state,
    preUse: preUse ?? this.preUse,
    endedAt: endedAt ?? this.endedAt,
    cancelReason: cancelReason ?? this.cancelReason,
  );
}
