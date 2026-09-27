import 'package:flutter/foundation.dart';

import '../../../core/domain/doseband.dart';
import '../../../core/domain/provenance.dart';

/// A sensor formulation (§46): the chemistry a lot is made with.
///
/// No formulation is validated. [validated] exists so the day one is, the
/// inventory can say so from data — not so a screen can print "validated".
@immutable
final class SensorFormulation {
  const SensorFormulation({
    required this.formulationId,
    required this.name,
    required this.version,
    this.validated = false,
  });

  final String formulationId;
  final String name;
  final String version;
  final bool validated;
}

/// A manufacturing lot of serialised DoseBands (§46).
@immutable
final class DoseBandLot {
  const DoseBandLot({
    required this.lotId,
    required this.formulationId,
    required this.geometryVersion,
    required this.receivedOn,
    required this.provenance,
    this.expiresOn,
    this.supportedConfiguration = true,
    this.calibrationPackageId,
  });

  final String lotId;
  final String formulationId;

  /// The printed geometry every band in the lot carries.
  final String geometryVersion;

  final DateTime receivedOn;

  /// Printed expiry. Null when the lot record carries none.
  final DateTime? expiresOn;

  /// Whether this app supports the lot's printed configuration at all. An
  /// unsupported lot cannot be read, so it cannot be assigned.
  final bool supportedConfiguration;

  /// The validated calibration that applies to this lot. **None exists**
  /// (S1–S3 open), so this is null for every lot.
  final String? calibrationPackageId;

  final RecordProvenance provenance;

  bool isExpiredOn(DateTime day) {
    final e = expiresOn;
    if (e == null) return false;
    final end = DateTime(e.year, e.month, e.day).add(const Duration(days: 1));
    return !day.isBefore(end);
  }
}

/// Lifecycle states grouped into mutually exclusive inventory buckets, so a
/// lot's counts always add up to the number of bands in it (§46: "avoid
/// overlapping counts").
enum InventoryBucket {
  available('Available'),
  inUse('Assigned / in use'),
  read('Read'),
  outOfService('Rejected / damaged / lost'),
  expired('Expired'),
  disposed('Disposed');

  const InventoryBucket(this.label);

  final String label;

  static InventoryBucket of(DoseBandLifecycle l) => switch (l) {
    DoseBandLifecycle.available => InventoryBucket.available,
    DoseBandLifecycle.assigned ||
    DoseBandLifecycle.monitoring ||
    DoseBandLifecycle.readyForFinalRead => InventoryBucket.inUse,
    DoseBandLifecycle.read ||
    DoseBandLifecycle.reviewed ||
    DoseBandLifecycle.readFailed ||
    DoseBandLifecycle.missingFinalRead => InventoryBucket.read,
    DoseBandLifecycle.damaged ||
    DoseBandLifecycle.lost ||
    DoseBandLifecycle.invalid ||
    DoseBandLifecycle.assignmentCancelled => InventoryBucket.outOfService,
    DoseBandLifecycle.expired => InventoryBucket.expired,
    DoseBandLifecycle.disposed => InventoryBucket.disposed,
  };
}
