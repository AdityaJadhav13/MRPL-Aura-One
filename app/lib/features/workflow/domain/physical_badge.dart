import 'package:flutter/foundation.dart';

/// How a badge's identity reached the app.
enum BadgeIdentitySource {
  /// Typed by the worker. Nothing verified it: no QR was read, no inventory
  /// was consulted. MEASUREMENT-INTEGRATION-02 §9.
  manualEntry,

  /// Read from the band's QR and resolved by this device's DoseBand registry.
  /// The registry is the on-device operations store, not a central server:
  /// the identity is checked against the local inventory, and nothing else
  /// (PRODUCT BUILD v1 §8, §9).
  localRegistry,
}

extension BadgeIdentitySourceLabel on BadgeIdentitySource {
  String get label => switch (this) {
    BadgeIdentitySource.manualEntry => 'Manual entry',
    BadgeIdentitySource.localRegistry => 'Scanned QR — on-device registry',
  };
}

/// What any assigned badge can say about itself.
///
/// Implemented by the real [PhysicalBadge] and by the simulation's
/// `BadgeSpecimen`, so a measurement record can name its badge without the
/// record's type deciding whether the badge was real. [isSimulated] is what
/// decides — and it is fixed by the implementing type, not by a field someone
/// could set.
abstract interface class BadgeIdentity {
  String get badgeId;

  /// Batch or lot. Null when not known.
  String? get batch;

  String? get formulation;

  /// Printed expiry, when known. Never inferred from the expiry patch's
  /// colour — no ageing chemistry has been validated.
  DateTime? get expiry;

  bool get isSimulated;

  /// One line saying where this identity came from, for provenance displays.
  String get identityProvenance;
}

/// A real, physical badge, identified by hand.
///
/// ## Why this is not a `BadgeSpecimen`
///
/// A specimen is a simulation: it carries a *declared outcome*, and scanning
/// it plays that outcome back. A physical badge has no outcome until it is
/// photographed and measured. Giving a real badge a specimen's shape would
/// mean either inventing an outcome for it or leaving a field that some code
/// path could one day read — so it gets its own type, and nothing on it can
/// hold a result. §8: a real photograph is never attached to a simulated
/// badge.
@immutable
final class PhysicalBadge implements BadgeIdentity {
  const PhysicalBadge({
    required this.badgeId,
    required this.identifiedAt,
    this.batchId,
    this.formulationId,
    this.expiresOn,
    this.source = BadgeIdentitySource.manualEntry,
  });

  @override
  final String badgeId;

  final String? batchId;
  final String? formulationId;

  /// The lot's printed expiry, when a registry supplied it. Null for a typed
  /// identity, which carries no lot record.
  final DateTime? expiresOn;
  final BadgeIdentitySource source;
  final DateTime identifiedAt;

  @override
  String? get batch => batchId;

  @override
  String? get formulation => formulationId;

  /// Known only when a registry supplied the lot record. A manually typed
  /// badge carries no printed-expiry record, and the expiry patch's colour is
  /// never read as one.
  @override
  DateTime? get expiry => expiresOn;

  @override
  bool get isSimulated => false;

  @override
  String get identityProvenance => switch (source) {
    BadgeIdentitySource.manualEntry =>
      '${source.label} — not verified against any inventory',
    BadgeIdentitySource.localRegistry =>
      '${source.label} — checked against the inventory on this device, '
          'not a central server',
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'badge_id': badgeId,
    'batch_id': batchId,
    'formulation_id': formulationId,
    'expires_on': expiresOn?.toUtc().toIso8601String(),
    'source': source.name,
    'identified_at': identifiedAt.toUtc().toIso8601String(),
  };

  /// Null when [raw] cannot be faithfully reconstructed. A partially decoded
  /// badge identity is worse than none.
  static PhysicalBadge? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final id = raw['badge_id'];
    final at = DateTime.tryParse(raw['identified_at'] as String? ?? '');
    final source = BadgeIdentitySource.values
        .where((s) => s.name == raw['source'])
        .firstOrNull;
    if (id is! String || id.trim().isEmpty || at == null || source == null) {
      return null;
    }
    return PhysicalBadge(
      badgeId: id,
      batchId: raw['batch_id'] as String?,
      formulationId: raw['formulation_id'] as String?,
      expiresOn: DateTime.tryParse(raw['expires_on'] as String? ?? ''),
      source: source,
      identifiedAt: at,
    );
  }
}
