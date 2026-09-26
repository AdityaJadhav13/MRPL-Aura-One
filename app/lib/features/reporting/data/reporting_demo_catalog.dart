import 'package:flutter/foundation.dart';

import '../../../core/demo/ui_demo_catalog.dart';
import '../domain/simulated_exposure.dart';

/// Occupational exposure records for the Reporting surfaces.
///
/// ## What is different about this catalogue
///
/// Every other demo dataset in this product carries **no quantity at all**,
/// because no calibration exists to produce one. Reporting is the exception:
/// a register, a summary and an audit package cannot be reviewed without some
/// figures in them.
///
/// The figures here are therefore [SimulatedExposure] — a type with one
/// constructor, which always marks its value simulated. They are illustrative
/// numbers attached to fictional people, and the only claim made about them
/// is that they demonstrate a layout.
///
/// ## Rules these records obey
///
/// * Only the two simulated-valid states carry a quantity. Everything else —
///   no reading, below quantification, above range, saturated, partial,
///   unsupported calibration — has `exposure: null`, and
///   `MeasurementCell` refuses to format a figure for them.
/// * Above-range and saturated are **separate records**, because they are
///   separate failures: a limit of the model versus a limit of the chemistry.
/// * Partial monitoring is separate from complete, and a partial record's
///   figure is absent rather than scaled up to a full period.
/// * Every identifier is fictional. No real worker, badge, permit or batch.
abstract final class ReportingDemoCatalog {
  static final DateTime _today = DateTime(2026, 9, 25);

  static DateTime _at(int dayOffset, int hour, [int minute = 0]) =>
      DateTime(_today.year, _today.month, _today.day - dayOffset, hour, minute);

  /// The register's records, newest first.
  static List<OccupationalRecord> records() => [
    // --- simulated valid -------------------------------------------------
    OccupationalRecord(
      recordId: 'OER-2026-0924-0102',
      worker: UiDemoCatalog.workers()[1],
      badgeId: 'DB-4K7Q9',
      batchId: 'L26-0912-A',
      startedAt: _at(1, 6, 5),
      endedAt: _at(1, 13, 40),
      measurement: ReportedMeasurement.simulatedValid,
      exposure: const SimulatedExposure.ppmHours(4.2),
      reviewState: DemoReviewState.reviewed,
      disposition: 'Reviewed — no further action',
      reviewer: 'EMP-21003',
      reviewedAt: _at(1, 15, 20),
      permitReference: 'PTW-DEMO-4471',
      jsaReference: 'JSA-DEMO-2048',
      job: 'Routine field round',
      monitoringComplete: true,
    ),
    OccupationalRecord(
      recordId: 'OER-2026-0924-0098',
      worker: UiDemoCatalog.workers()[3],
      badgeId: 'DB-4K8C7',
      batchId: 'L26-0912-A',
      startedAt: _at(1, 14, 0),
      endedAt: _at(1, 21, 58),
      measurement: ReportedMeasurement.simulatedValidWithWarning,
      exposure: const SimulatedExposure.ppmHours(11.7),
      warning: 'Badge covered less of the period than requested',
      reviewState: DemoReviewState.reviewRequired,
      permitReference: 'PTW-DEMO-4482',
      jsaReference: 'JSA-DEMO-2051',
      job: 'Exchanger maintenance',
      monitoringComplete: true,
    ),

    // --- censored: three genuinely different things ----------------------
    OccupationalRecord(
      recordId: 'OER-2026-0923-0091',
      worker: UiDemoCatalog.workers()[0],
      badgeId: 'DB-4KB18',
      batchId: 'L26-0912-A',
      startedAt: _at(2, 6, 10),
      endedAt: _at(2, 14, 2),
      // Exposure happened; it was below what the method can quantify. Not
      // zero, and a register that prints 0.0 here has fabricated a reading.
      measurement: ReportedMeasurement.belowQuantificationLimit,
      reviewState: DemoReviewState.reviewed,
      disposition: 'Reviewed — no further action',
      reviewer: 'EMP-21003',
      reviewedAt: _at(2, 16, 0),
      permitReference: 'PTW-DEMO-4463',
      jsaReference: 'JSA-DEMO-2044',
      job: 'Sampling round',
      monitoringComplete: true,
    ),
    OccupationalRecord(
      recordId: 'OER-2026-0923-0087',
      worker: UiDemoCatalog.workers()[2],
      badgeId: 'DB-4K8B1',
      batchId: 'L26-0831-C',
      startedAt: _at(2, 14, 0),
      endedAt: _at(2, 22, 5),
      // The reading exists; the calibration does not cover it.
      measurement: ReportedMeasurement.aboveValidatedRange,
      reviewState: DemoReviewState.inReview,
      permitReference: 'PTW-DEMO-4488',
      jsaReference: 'JSA-DEMO-2057',
      job: 'Vessel preparation',
      monitoringComplete: true,
    ),
    OccupationalRecord(
      recordId: 'OER-2026-0922-0074',
      worker: UiDemoCatalog.workers()[5],
      badgeId: 'DB-4KA55',
      batchId: 'L26-0831-C',
      startedAt: _at(3, 22, 0),
      endedAt: _at(2, 6, 4),
      // The chemistry stopped responding. Different failure, different
      // remedy, and collapsing it into "above range" would hide which.
      measurement: ReportedMeasurement.saturated,
      reviewState: DemoReviewState.reviewRequired,
      permitReference: 'PTW-DEMO-4491',
      jsaReference: 'JSA-DEMO-2060',
      job: 'Drain and purge',
      monitoringComplete: true,
    ),

    // --- incomplete and invalid ------------------------------------------
    OccupationalRecord(
      recordId: 'OER-2026-0922-0069',
      worker: UiDemoCatalog.workers()[3],
      badgeId: 'DB-4K9D3',
      batchId: 'L26-0912-A',
      startedAt: _at(3, 14, 0),
      endedAt: _at(3, 17, 12),
      measurement: ReportedMeasurement.partialMonitoring,
      reviewState: DemoReviewState.informationRequired,
      permitReference: 'PTW-DEMO-4470',
      jsaReference: 'JSA-DEMO-2049',
      job: 'Line breaking',
      // Covered part of the intended period. The figure is absent rather
      // than extrapolated to a full shift.
      monitoringComplete: false,
    ),
    OccupationalRecord(
      recordId: 'OER-2026-0921-0058',
      worker: UiDemoCatalog.workers()[1],
      badgeId: 'DB-4KB22',
      batchId: 'L26-0831-C',
      startedAt: _at(4, 6, 0),
      endedAt: _at(4, 14, 10),
      measurement: ReportedMeasurement.noReading,
      refusalReason: 'POOR_IMAGE',
      reviewState: DemoReviewState.reviewRequired,
      permitReference: 'PTW-DEMO-4455',
      jsaReference: 'JSA-DEMO-2038',
      job: 'Routine field round',
      monitoringComplete: true,
    ),
    OccupationalRecord(
      recordId: 'OER-2026-0921-0051',
      worker: UiDemoCatalog.workers()[5],
      badgeId: 'DB-4K7M2',
      batchId: 'L26-0912-A',
      startedAt: _at(4, 22, 0),
      endedAt: _at(3, 6, 2),
      measurement: ReportedMeasurement.noReading,
      refusalReason: 'REFERENCE_PATCH_FAILURE',
      reviewState: DemoReviewState.informationRequired,
      permitReference: 'PTW-DEMO-4459',
      jsaReference: 'JSA-DEMO-2041',
      job: 'Night round',
      monitoringComplete: true,
    ),
    OccupationalRecord(
      recordId: 'OER-2026-0920-0044',
      worker: UiDemoCatalog.workers()[2],
      badgeId: 'DB-4K8C7',
      batchId: 'L26-0831-C',
      startedAt: _at(5, 6, 0),
      endedAt: _at(5, 14, 4),
      // No model applies to that batch at all — a different thing again from
      // a reading that failed.
      measurement: ReportedMeasurement.unsupportedCalibration,
      reviewState: DemoReviewState.newRecord,
      permitReference: 'PTW-DEMO-4447',
      jsaReference: 'JSA-DEMO-2030',
      job: 'Turnaround preparation',
      monitoringComplete: true,
    ),
    OccupationalRecord(
      recordId: 'OER-2026-0920-0039',
      worker: UiDemoCatalog.workers()[0],
      badgeId: 'DB-4K9D3',
      batchId: 'L26-0912-A',
      startedAt: _at(5, 14, 0),
      endedAt: _at(5, 22, 0),
      measurement: ReportedMeasurement.noReading,
      refusalReason: 'EXPOSURE_WINDOW_UNTRUSTED',
      reviewState: DemoReviewState.closed,
      disposition: 'Closed — period could not be timed',
      reviewer: 'EMP-21003',
      reviewedAt: _at(4, 9, 15),
      permitReference: 'PTW-DEMO-4452',
      jsaReference: 'JSA-DEMO-2035',
      job: 'Exchanger maintenance',
      monitoringComplete: false,
      clockTrusted: false,
    ),
  ];

  /// Records whose measurement could not be produced.
  static List<OccupationalRecord> invalidMeasurements() => records()
      .where((r) => r.measurement == ReportedMeasurement.noReading)
      .toList();

  /// Records outside the quantifiable interval. **Kept separate** from
  /// invalid: the measurement succeeded, the value is outside the range.
  static List<OccupationalRecord> aboveRangeOrSaturated() => records()
      .where(
        (r) =>
            r.measurement == ReportedMeasurement.aboveValidatedRange ||
            r.measurement == ReportedMeasurement.saturated,
      )
      .toList();

  /// Records where the monitored period itself was not complete.
  static List<OccupationalRecord> incompleteMonitoring() =>
      records().where((r) => !r.monitoringComplete).toList();

  /// Everything an exception report covers.
  static List<OccupationalRecord> exceptions() => records()
      .where(
        (r) =>
            r.measurement != ReportedMeasurement.simulatedValid &&
            r.measurement != ReportedMeasurement.simulatedValidWithWarning,
      )
      .toList();

  /// Demonstration report history.
  ///
  /// Deliberately short and unmistakably fictional. No official report
  /// identifiers — nothing has been generated, so a populated-looking history
  /// would be the clearest possible lie about export.
  static List<DemoReportHistoryEntry> reportHistory() => const [];
}

/// One occupational exposure record, with its full traceability chain.
@immutable
final class OccupationalRecord {
  // Deliberately not const. The assertion below is worth more than
  // constness: it is the guard that stops a record carrying a figure its
  // measurement state says does not exist, and an enum field cannot be read
  // in a const expression. No record is const anyway — they hold DateTimes.
  // ignore: prefer_const_constructors_in_immutables
  OccupationalRecord({
    required this.recordId,
    required this.worker,
    required this.badgeId,
    required this.batchId,
    required this.startedAt,
    required this.endedAt,
    required this.measurement,
    required this.reviewState,
    required this.permitReference,
    required this.jsaReference,
    required this.job,
    required this.monitoringComplete,
    this.exposure,
    this.warning,
    this.refusalReason,
    this.disposition,
    this.reviewer,
    this.reviewedAt,
    this.clockTrusted = true,
  }) : assert(
         exposure == null || measurement.carriesQuantity,
         'only a simulated-valid record may carry a quantity',
       );

  final String recordId;
  final DemoWorker worker;
  final String badgeId;
  final String batchId;
  final DateTime startedAt;
  final DateTime endedAt;

  final ReportedMeasurement measurement;

  /// Present only for the simulated-valid states. Enforced by the assertion
  /// above and by `MeasurementCell`, which throws rather than formatting a
  /// figure a state is not entitled to.
  final SimulatedExposure? exposure;

  final String? warning;
  final String? refusalReason;

  final DemoReviewState reviewState;
  final String? disposition;
  final String? reviewer;
  final DateTime? reviewedAt;

  final String permitReference;
  final String jsaReference;
  final String job;

  /// Whether the badge covered the whole intended period.
  final bool monitoringComplete;

  /// Whether the device clock could be trusted across the window.
  final bool clockTrusted;

  /// The window, or null where it cannot be established.
  ///
  /// An untrusted clock yields null, which renders as the absent placeholder
  /// — never as a duration computed from timestamps that moved.
  Duration? get coverage {
    if (!clockTrusted) return null;
    final d = endedAt.difference(startedAt);
    return d.isNegative ? null : d;
  }

  /// Versions this record was produced under, so a historical report stays
  /// reproducible when software changes.
  Map<String, String> get versions => const {
    'Algorithm version': 'sim-0',
    'Geometry version': 'badge-v1-research',
    'App version': '0.1.0+1',
    'Calibration version': 'None — simulated result',
  };
}

/// A previously generated report. None exist.
@immutable
final class DemoReportHistoryEntry {
  const DemoReportHistoryEntry({
    required this.reportId,
    required this.title,
    required this.createdAt,
  });

  final String reportId;
  final String title;
  final DateTime createdAt;
}
