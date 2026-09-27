import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

import '../../../core/domain/monitoring_session.dart';
import '../../auth/domain/access_policy.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/inventory.dart';
import '../domain/measurement_state.dart';
import '../domain/operations_snapshot.dart';
import 'access.dart';
import 'day_status.dart';
import 'local_doseband_registry.dart';

/// A count that may be too small to show safely.
///
/// In a breakdown by work area or state, a cell of one or two can point at a
/// specific person ("the one contractor in the coker yesterday"). Such cells
/// are suppressed, not rounded (§59: de-identified means more than deleting
/// the name column).
@immutable
final class CountCell {
  const CountCell(this.value) : suppressed = false;
  const CountCell.suppressed() : value = null, suppressed = true;

  factory CountCell.of(int n, {int threshold = kSmallCell}) =>
      n > 0 && n < threshold ? const CountCell.suppressed() : CountCell(n);

  final int? value;
  final bool suppressed;

  String get display => suppressed ? '<$kSmallCell' : '$value';

  static const int kSmallCell = 3;
}

@immutable
final class WorkAreaSummary {
  const WorkAreaSummary({
    required this.workArea,
    required this.periods,
    required this.completed,
    required this.noReading,
  });

  final String workArea;
  final CountCell periods;
  final CountCell completed;
  final CountCell noReading;
}

@immutable
final class DayCount {
  const DayCount({
    required this.day,
    required this.started,
    required this.completed,
    required this.withoutFinalRead,
  });

  final DateTime day;
  final int started;
  final int completed;
  final int withoutFinalRead;
}

/// The management overview. **No field on this type, or any type it holds,
/// identifies a person**: no name, no ID, no photo, no DoseBand-to-person
/// link. That is enforced by the types, not by a screen choosing not to show
/// a column (§42, §148).
@immutable
final class ManagementOverview {
  const ManagementOverview({
    required this.expectedWorkers,
    required this.byStatus,
    required this.recordsLast30Days,
    required this.stateDistribution,
    required this.reviewBacklog,
    required this.bandUtilisation,
    required this.workAreas,
    required this.validatedExposureStatistics,
  });

  final int expectedWorkers;
  final Map<WorkerDayStatus, int> byStatus;
  final int recordsLast30Days;
  final Map<String, CountCell> stateDistribution;
  final int reviewBacklog;
  final Map<InventoryBucket, int> bandUtilisation;
  final List<WorkAreaSummary> workAreas;

  /// Always false today: no validated calibration exists, so there are no
  /// exposure values to summarise and none are computed (§43).
  final bool validatedExposureStatistics;

  int get startedToday =>
      expectedWorkers - (byStatus[WorkerDayStatus.notStarted] ?? 0);
}

/// De-identified, organisational information only (§42, §58 Class B).
final class ManagementView {
  ManagementView(OperationsSnapshot snapshot, Actor actor)
    : _access = OperationsAccess(snapshot, actor) {
    _access.requireRole(AppRole.management);
    _access.require(Permission.viewDeidentifiedReports);
  }

  final OperationsAccess _access;

  OperationsSnapshot get _s => _access.snapshot;

  Iterable<String> get _workers =>
      _s.people.where((p) => p.hasRole(AppRole.worker)).map((p) => p.personId);

  ManagementOverview overview(DateTime now) {
    final by = <WorkerDayStatus, int>{};
    for (final w in _workers) {
      final d = DayStatus.of(_s, w, now);
      by[d.status] = (by[d.status] ?? 0) + 1;
    }
    final since = now.subtract(const Duration(days: 30));
    final recent = _s.measurements
        .where(
          (m) => m.scannedAt.isAfter(since) && _s.supersededBy(m.id) == null,
        )
        .toList();
    final states = <String, int>{};
    for (final m in recent) {
      final label = switch (m.result) {
        Valid() => 'Value',
        Censored() => 'Below / above range',
        Refused() => 'No reading',
      };
      states[label] = (states[label] ?? 0) + 1;
    }
    final util = <InventoryBucket, int>{};
    for (final b in _s.bands.values) {
      final k = DoseBandEligibility.bucketOf(_s, b, now);
      util[k] = (util[k] ?? 0) + 1;
    }
    final areas = <String, List<int>>{};
    for (final x in _s.sessions) {
      final t = x.endedAt ?? x.startedAt;
      if (t == null || t.isBefore(since)) continue;
      final area = x.work?.workAreaName ?? 'Not recorded';
      final row = areas.putIfAbsent(area, () => [0, 0, 0]);
      row[0]++;
      if (x.measurementId != null) {
        row[1]++;
        final m = _s.measurement(x.measurementId!);
        if (m != null && m.result is Refused) row[2]++;
      }
    }
    return ManagementOverview(
      expectedWorkers: _workers.length,
      byStatus: by,
      recordsLast30Days: recent.length,
      stateDistribution: {
        for (final e in states.entries) e.key: CountCell.of(e.value),
      },
      reviewBacklog: _s.reviews.where((r) => r.state.isOpen).length,
      bandUtilisation: util,
      workAreas: [
        for (final e in areas.entries)
          WorkAreaSummary(
            workArea: e.key,
            periods: CountCell.of(e.value[0]),
            completed: CountCell.of(e.value[1]),
            noReading: CountCell.of(e.value[2]),
          ),
      ]..sort((a, b) => a.workArea.compareTo(b.workArea)),
      validatedExposureStatistics: false,
    );
  }

  /// Monitoring activity per day — operational counts only, no exposure.
  List<DayCount> trend(DateTime now, {int days = 14}) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final day = today.subtract(Duration(days: i));
          final end = day.add(const Duration(days: 1));
          bool inDay(DateTime? t) =>
              t != null && !t.isBefore(day) && t.isBefore(end);
          final started = _s.sessions.where((x) => inDay(x.startedAt)).length;
          final completed = _s.measurements
              .where((m) => inDay(m.scannedAt) && m.supersedesId == null)
              .length;
          final missing = _s.sessions
              .where(
                (x) =>
                    inDay(x.endedAt) &&
                    x.measurementId == null &&
                    x.state != MonitoringSessionState.readyForFinalRead,
              )
              .length;
          return DayCount(
            day: day,
            started: started,
            completed: completed,
            withoutFinalRead: missing,
          );
        }(),
    ];
  }

  /// Measurement-state wording for the distribution legend.
  static String describe(ResultStatus s) => MeasurementStateText.label(s);
}
