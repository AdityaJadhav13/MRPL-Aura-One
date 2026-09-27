import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

import '../../../core/domain/monitoring_session.dart';
import '../../history/domain/measurement_record.dart';
import '../domain/assignment.dart';
import '../domain/audit.dart';
import '../domain/measurement_state.dart';
import '../domain/operations_snapshot.dart';

/// Where one worker stands today — exactly one of these per worker, so the
/// supervisor's counts add up to the team size (§33: no double counting).
enum WorkerDayStatus {
  notStarted('Not started'),
  claimed('DoseBand claimed'),
  monitoring('Monitoring'),
  finalReadDue('Final scan due'),
  completed('Completed'),
  exception('Needs attention');

  const WorkerDayStatus(this.label);

  final String label;
}

/// What a worker's day looks like, derived from the store.
@immutable
final class WorkerDay {
  const WorkerDay({
    required this.workerId,
    required this.status,
    this.session,
    this.assignment,
    this.measurement,
  });

  final String workerId;
  final WorkerDayStatus status;

  /// The session the status describes: the open one, or today's latest.
  final MonitoringSession? session;
  final DoseBandAssignment? assignment;
  final MeasurementRecord? measurement;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

abstract final class DayStatus {
  /// Classifies [workerId]'s day as of [now]. Pure: the same snapshot and
  /// instant always give the same answer, so counts cannot drift from rows.
  static WorkerDay of(OperationsSnapshot s, String workerId, DateTime now) {
    final active = s.activeAssignmentOf(workerId);
    if (active != null) {
      final session = s.session(active.sessionId);
      final status = switch (session?.state) {
        MonitoringSessionState.notStarted => WorkerDayStatus.claimed,
        MonitoringSessionState.active || MonitoringSessionState.partial =>
          // Still "active" from a previous day: nobody ended it.
          _sameDay(session!.startedAt ?? now, now)
              ? WorkerDayStatus.monitoring
              : WorkerDayStatus.exception,
        MonitoringSessionState.readyForFinalRead =>
          _sameDay(session!.endedAt ?? now, now)
              ? WorkerDayStatus.finalReadDue
              : WorkerDayStatus.exception,
        _ => WorkerDayStatus.exception,
      };
      return WorkerDay(
        workerId: workerId,
        status: status,
        session: session,
        assignment: active,
      );
    }

    final today = s.sessionsOf(workerId).where((x) {
      final t = x.endedAt ?? x.startedAt;
      return t != null && _sameDay(t, now);
    }).firstOrNull;
    if (today == null) {
      return WorkerDay(workerId: workerId, status: WorkerDayStatus.notStarted);
    }
    final m = today.measurementId == null
        ? null
        : s.measurement(today.measurementId!);
    final status = switch (today.state) {
      MonitoringSessionState.readComplete ||
      MonitoringSessionState.reviewed ||
      MonitoringSessionState.closed => WorkerDayStatus.completed,
      _ => WorkerDayStatus.exception,
    };
    return WorkerDay(
      workerId: workerId,
      status: status,
      session: today,
      assignment: today.assignmentId == null
          ? null
          : s.assignment(today.assignmentId!),
      measurement: m,
    );
  }
}

/// A thing a supervisor may need to act on (§37). Several can concern the
/// same worker; the list says so and is never presented as a head count.
enum ExceptionKind {
  finalScanOverdue('Final scan overdue'),
  monitoringNotEnded('Monitoring left running'),
  monitoringInterrupted('Monitoring interrupted'),
  finalReadMissing('Final scan missing'),
  dosebandReported('DoseBand damaged or lost'),
  preUseRejected('DoseBand rejected at pre-use check'),
  noReading('No reading'),
  unsupportedCalibration('No calibration for this DoseBand'),
  awaitingReview('Awaiting HSE review');

  const ExceptionKind(this.label);

  final String label;
}

@immutable
final class OperationalException {
  const OperationalException({
    required this.kind,
    required this.workerId,
    required this.at,
    this.sessionId,
    this.measurementId,
    this.dosebandId,
    this.detail,
  });

  final ExceptionKind kind;
  final String workerId;
  final DateTime at;
  final String? sessionId;
  final String? measurementId;
  final String? dosebandId;
  final String? detail;
}

abstract final class Exceptions {
  /// Exceptions for [workers] over the last [days] days, newest first.
  static List<OperationalException> of(
    OperationsSnapshot s,
    Set<String> workers,
    DateTime now, {
    int days = 7,
  }) {
    final since = now.subtract(Duration(days: days));
    final out = <OperationalException>[];

    for (final x in s.sessions.where((x) => workers.contains(x.workerId))) {
      final t = x.endedAt ?? x.startedAt;
      switch (x.state) {
        case MonitoringSessionState.readyForFinalRead
            when x.endedAt != null && !_sameDay(x.endedAt!, now):
          out.add(
            OperationalException(
              kind: ExceptionKind.finalScanOverdue,
              workerId: x.workerId,
              at: x.endedAt!,
              sessionId: x.sessionId,
              dosebandId: x.dosebandId,
            ),
          );
        case MonitoringSessionState.active
            when x.startedAt != null && !_sameDay(x.startedAt!, now):
          out.add(
            OperationalException(
              kind: ExceptionKind.monitoringNotEnded,
              workerId: x.workerId,
              at: x.startedAt!,
              sessionId: x.sessionId,
              dosebandId: x.dosebandId,
            ),
          );
        case MonitoringSessionState.interrupted
            when t != null && t.isAfter(since):
          out.add(
            OperationalException(
              kind: ExceptionKind.monitoringInterrupted,
              workerId: x.workerId,
              at: t,
              sessionId: x.sessionId,
              dosebandId: x.dosebandId,
            ),
          );
        case MonitoringSessionState.finalReadMissing
            when t != null && t.isAfter(since):
          out.add(
            OperationalException(
              kind: ExceptionKind.finalReadMissing,
              workerId: x.workerId,
              at: t,
              sessionId: x.sessionId,
              dosebandId: x.dosebandId,
            ),
          );
        default:
          break;
      }
    }

    for (final m in s.measurements) {
      final w = m.workerId;
      if (w == null || !workers.contains(w)) continue;
      if (m.scannedAt.isBefore(since)) continue;
      // A superseded record is history, not an open problem.
      if (s.supersededBy(m.id) != null) continue;
      final r = m.result;
      if (MeasurementStateText.isException(r)) {
        out.add(
          OperationalException(
            kind: r.status == ResultStatus.unsupportedCalibration
                ? ExceptionKind.unsupportedCalibration
                : ExceptionKind.noReading,
            workerId: w,
            at: m.scannedAt,
            sessionId: m.sessionId,
            measurementId: m.id,
            dosebandId: m.badge.badgeId,
            detail: MeasurementStateText.label(r.status),
          ),
        );
      }
      final review = s.reviewFor(m.id);
      if (review != null && review.state.isOpen) {
        out.add(
          OperationalException(
            kind: ExceptionKind.awaitingReview,
            workerId: w,
            at: m.scannedAt,
            sessionId: m.sessionId,
            measurementId: m.id,
            dosebandId: m.badge.badgeId,
            detail: review.state.label,
          ),
        );
      }
    }

    for (final e in s.audit) {
      if (!workers.contains(e.actorId) || e.at.isBefore(since)) continue;
      final kind = switch (e.action) {
        AuditAction.dosebandReported => ExceptionKind.dosebandReported,
        AuditAction.preUseChecked
            when e.detail?.startsWith('Replace') ?? false =>
          ExceptionKind.preUseRejected,
        _ => null,
      };
      if (kind == null) continue;
      out.add(
        OperationalException(
          kind: kind,
          workerId: e.actorId,
          at: e.at,
          dosebandId: e.subjectType == 'doseband' ? e.subjectId : null,
          detail: e.detail,
        ),
      );
    }

    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }
}
