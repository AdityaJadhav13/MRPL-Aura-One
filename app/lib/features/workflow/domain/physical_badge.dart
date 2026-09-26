import 'package:flutter/foundation.dart';

/// How a badge's identity reached the app.
enum BadgeIdentitySource {
  /// Typed by the worker. Nothing verified it: no QR was read, no inventory
  /// was consulted. MEASUREMENT-INTEGRATION-02 §9.
  manualEntry,
}

extension BadgeIdentitySourceLabel on BadgeIdentitySource {
  String get label => switch (this) {
    BadgeIdentitySource.manualEntry => 'Manual entry',
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
    this.source = BadgeIdentitySource.manualEntry,
  });

  @override
  final String badgeId;

  final String? batchId;
  final String? formulationId;
  final BadgeIdentitySource source;
  final DateTime identifiedAt;

  @override
  String? get batch => batchId;

  @override
  String? get formulation => formulationId;

  /// Not known: no inventory is connected, and a manually typed badge carries
  /// no printed-expiry record.
  @override
  DateTime? get expiry => null;

  @override
  bool get isSimulated => false;

  @override
  String get identityProvenance =>
      '${source.label} — not verified against any inventory';

  Map<String, Object?> toJson() => <String, Object?>{
    'badge_id': badgeId,
    'batch_id': batchId,
    'formulation_id': formulationId,
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
      source: source,
      identifiedAt: at,
    );
  }
}
