import '../../operations/data/presentation_dataset.dart';
import '../../operations/domain/assignment.dart';
import 'presentation_mode.dart';

/// Today's printed prototype QR → the presentation DoseBand.
///
/// The production QR carries the DoseBand serial (`DOSEBAND:1:<serial>`) and
/// needs none of this. The badge printed for the SIH demonstration carries a
/// placeholder payload, so — in presentation mode only (level 1 and above) —
/// a QR that is not a DoseBand code is *mapped* to the presentation DoseBand.
/// It is never presented as a serial encoded in the QR: the assignment
/// records [BandIdentification.presentationQrMapping] and the raw payload,
/// and the final read accepts only that same payload.
///
/// Isolated here so it can be deleted when production QRs are printed,
/// without touching the assignment system.
abstract final class PresentationQrResolver {
  /// The serial a non-DoseBand [rawPayload] maps to when claiming, or null
  /// when no mapping applies (presentation mode off, or below level 1).
  static String? resolveForClaim({
    required String rawPayload,
    required FallbackLevel? active,
  }) {
    if (active == null || !active.usesPresentationIdentity) return null;
    if (rawPayload.trim().isEmpty) return null;
    return PresentationDataset.presentationBandId;
  }

  /// Whether a non-DoseBand [rawPayload] scanned at the final read is the
  /// same printed code the active [assignment] was claimed with. Independent
  /// of presentation mode: it compares with what was recorded, so it holds
  /// across a restart.
  static bool matchesAssignment({
    required String rawPayload,
    required DoseBandAssignment? assignment,
  }) =>
      assignment != null &&
      assignment.identifiedBy == BandIdentification.presentationQrMapping &&
      assignment.qrPayload != null &&
      assignment.qrPayload == rawPayload;
}
