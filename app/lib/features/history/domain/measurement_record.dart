import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

import '../../workflow/domain/badge_specimen.dart';
import '../../workflow/domain/work_context.dart';

/// A completed measurement, kept for history and traceability.
///
/// Carries its data domain explicitly. Everything produced in this phase is
/// [DataDomain.simulated] and can never be shown as production evidence.
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
    this.domain = DataDomain.simulated,
  });

  final String id;
  final MeasurementResult result;
  final BadgeSpecimen badge;
  final WorkContext context;
  final DateTime startedAt;
  final DateTime endedAt;
  final DateTime scannedAt;
  final DataDomain domain;

  Duration get coverage => endedAt.difference(startedAt);
}

/// Which body of data a record belongs to. These must never be visually
/// confused (directive §65). Field/production is not producible in this phase.
enum DataDomain { simulated, lab, field }
