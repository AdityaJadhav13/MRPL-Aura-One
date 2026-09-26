import 'package:flutter/foundation.dart';

import 'doseband.dart';

/// The authority that decides whether a scanned DoseBand may be claimed
/// (APP-PRODUCT-01 §41, §127).
///
/// ## Why this is a contract and not an implementation
///
/// Claiming must be **atomic across devices**: if two workers scan the same
/// available band, exactly one claim succeeds. Only a central data layer can
/// guarantee that — a check on the phone cannot see the other phone. So this
/// interface exists for P2 to build against and P10 to implement, and the
/// only implementation today, [NotConnectedDoseBandRegistry], says plainly
/// that no authority is reachable. It does not fake uniqueness locally.
abstract interface class DoseBandRegistry {
  /// Resolve a scanned identity to what the authority knows about it.
  Future<DoseBandLookup> lookup(String dosebandId);

  /// Attempt to claim [dosebandId] for [workerId]. At most one concurrent
  /// claim for a band may return [ClaimAccepted].
  Future<ClaimResult> claim({
    required String dosebandId,
    required String workerId,
  });
}

@immutable
sealed class DoseBandLookup {
  const DoseBandLookup();
}

final class DoseBandFound extends DoseBandLookup {
  const DoseBandFound(this.doseband);
  final DoseBand doseband;
}

/// The authority has no band with this identity.
final class DoseBandNotFound extends DoseBandLookup {
  const DoseBandNotFound();
}

/// No authority could be asked. Not the same as "not found".
final class DoseBandAuthorityUnavailable extends DoseBandLookup {
  const DoseBandAuthorityUnavailable(this.reason);
  final RegistryUnavailableReason reason;
}

/// The typed outcomes of a claim. Each maps to one worker-facing message;
/// none of them is a generic "something went wrong" (§22).
@immutable
sealed class ClaimResult {
  const ClaimResult();
}

final class ClaimAccepted extends ClaimResult {
  const ClaimAccepted({required this.doseband, required this.assignmentId});
  final DoseBand doseband;
  final String assignmentId;
}

/// Someone else already holds this band. Carries **no** detail about who:
/// the losing worker does not need another person's identity (§127).
final class ClaimConflict extends ClaimResult {
  const ClaimConflict();
}

/// The band exists but is not claimable: used, expired, damaged, invalid.
final class ClaimIneligible extends ClaimResult {
  const ClaimIneligible(this.lifecycle);
  final DoseBandLifecycle lifecycle;
}

final class ClaimNotFound extends ClaimResult {
  const ClaimNotFound();
}

/// The authority could not be reached, so no claim was made. The band has
/// **not** been assigned; nothing may proceed as though it had.
final class ClaimAuthorityUnavailable extends ClaimResult {
  const ClaimAuthorityUnavailable(this.reason);
  final RegistryUnavailableReason reason;
}

enum RegistryUnavailableReason {
  /// The device is offline.
  offline,

  /// A server is configured but did not answer.
  serverUnavailable,

  /// No server exists for this build.
  notConnected,
}

/// The registry this build has: none.
///
/// Every call answers [RegistryUnavailableReason.notConnected]. The existing
/// simulated and manual-entry assignment flows do not go through a registry
/// at all, and are labelled as such where they are shown.
final class NotConnectedDoseBandRegistry implements DoseBandRegistry {
  const NotConnectedDoseBandRegistry();

  @override
  Future<DoseBandLookup> lookup(String dosebandId) async =>
      const DoseBandAuthorityUnavailable(
        RegistryUnavailableReason.notConnected,
      );

  @override
  Future<ClaimResult> claim({
    required String dosebandId,
    required String workerId,
  }) async =>
      const ClaimAuthorityUnavailable(RegistryUnavailableReason.notConnected);
}
