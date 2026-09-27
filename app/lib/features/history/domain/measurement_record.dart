import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

import '../../workflow/domain/physical_badge.dart';
import '../../workflow/domain/work_context.dart';

/// A completed measurement, kept for history and traceability.
///
/// ## The data domain is required
///
/// It used to default to `simulated`, through a private copy of the engine's
/// `DataDomain` enum. The engine forbids exactly that default — "a default is
/// how a simulated observation eventually gets treated as a real one" — and a
/// second enum is a second definition waiting to drift. Both are gone: every
/// construction states its domain, using the engine's own type. G-26.
@immutable
final class MeasurementRecord {
  const MeasurementRecord({
    required this.id,
    required this.result,
    required this.badge,
    required this.context,
    required this.startedAt,
    required this.endedAt,
    required this.scannedAt,
    required this.domain,
    this.captureId,
    this.workerId,
    this.sessionId,
    this.supersedesId,
    this.supersessionReason,
  }) : assert(
         (supersedesId == null) == (supersessionReason == null),
         'a superseding record states which record it replaces and why',
       );

  final String id;
  final MeasurementResult result;

  /// The badge this measurement belongs to — a real [PhysicalBadge] or a
  /// simulated specimen. [BadgeIdentity.isSimulated] says which.
  final BadgeIdentity badge;

  final WorkContext context;
  final DateTime startedAt;
  final DateTime endedAt;
  final DateTime scannedAt;
  final DataDomain domain;

  /// The archived capture — original photograph, features, quality report —
  /// behind a real scan. Null for a simulated one, which has no photograph.
  final String? captureId;

  /// The worker the record belongs to. Null only for records made before
  /// records were keyed to people.
  final String? workerId;

  /// The monitoring session the record closes.
  final String? sessionId;

  /// The record this one supersedes, when it is a re-read or a
  /// recalculation. The earlier record is never edited or removed: both stay,
  /// and this link says which is current (§26, §93).
  final String? supersedesId;
  final String? supersessionReason;

  Duration get coverage => endedAt.difference(startedAt);
}
