import 'package:flutter/foundation.dart';

import '../../../core/domain/doseband.dart';
import '../../../core/domain/monitoring_session.dart';
import '../../auth/domain/access_policy.dart';
import '../../auth/domain/auth_models.dart';
import '../../history/domain/measurement_record.dart';
import '../domain/audit.dart';
import '../domain/operations_snapshot.dart';
import '../domain/organisation.dart';
import '../domain/review.dart';
import 'access.dart';
import 'day_status.dart';
import 'operations_repository.dart';
import 'worker_service.dart';

/// One row of the supervisor's team list.
@immutable
final class TeamMemberRow {
  const TeamMemberRow({required this.person, required this.day, this.band});

  final Person person;
  final WorkerDay day;
  final DoseBand? band;
}

/// Counts for the overview. Each worker is in exactly one status, so the
/// counts sum to [expected] (§33).
@immutable
final class TeamOverview {
  const TeamOverview({
    required this.teamNames,
    required this.expected,
    required this.byStatus,
    required this.exceptionItems,
  });

  final List<String> teamNames;
  final int expected;
  final Map<WorkerDayStatus, int> byStatus;

  /// Items, not people: one worker can have several.
  final int exceptionItems;

  int count(WorkerDayStatus s) => byStatus[s] ?? 0;
}

/// A supervisor's view of one team member (§35).
@immutable
final class SupervisedWorkerDetail {
  const SupervisedWorkerDetail({
    required this.person,
    required this.departmentName,
    required this.day,
    required this.recentSessions,
    required this.records,
    required this.exceptions,
  });

  final Person person;
  final String? departmentName;
  final WorkerDay day;
  final List<MonitoringSession> recentSessions;
  final List<MeasurementRecord> records;
  final List<OperationalException> exceptions;
}

/// What a supervisor may read: their team, and only their team (§32–§37,
/// §146).
final class SupervisorView {
  SupervisorView(OperationsSnapshot snapshot, Actor actor)
    : _access = OperationsAccess(snapshot, actor) {
    _access.requireRole(AppRole.supervisor);
    _access.require(Permission.viewTeamMonitoring);
    _team = _access.identifiedWorkers();
  }

  final OperationsAccess _access;
  late final Set<String> _team;

  OperationsSnapshot get _s => _access.snapshot;

  Person get supervisor => _access.person!;

  List<String> get teamNames => [
    for (final t in _s.teams)
      if (t.supervisorId == _access.actor.personId) t.name,
  ];

  Set<String> get teamIds => _team;

  List<Person> get _members =>
      _s.people.where((p) => _team.contains(p.personId)).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

  TeamOverview overview(DateTime now) {
    final by = <WorkerDayStatus, int>{};
    for (final p in _members) {
      final d = DayStatus.of(_s, p.personId, now);
      by[d.status] = (by[d.status] ?? 0) + 1;
    }
    return TeamOverview(
      teamNames: teamNames,
      expected: _members.length,
      byStatus: by,
      exceptionItems: Exceptions.of(_s, _team, now).length,
    );
  }

  /// The team, filtered by status and a case-insensitive search over name,
  /// ID and DoseBand.
  List<TeamMemberRow> team(
    DateTime now, {
    String query = '',
    WorkerDayStatus? status,
  }) {
    final q = query.trim().toLowerCase();
    final out = <TeamMemberRow>[];
    for (final p in _members) {
      final day = DayStatus.of(_s, p.personId, now);
      final bandId = day.session?.dosebandId;
      final band = bandId == null ? null : _s.bands[bandId];
      if (status != null && day.status != status) continue;
      if (q.isNotEmpty &&
          !p.displayName.toLowerCase().contains(q) &&
          !p.personId.toLowerCase().contains(q) &&
          !(band?.dosebandId.toLowerCase().contains(q) ?? false)) {
        continue;
      }
      out.add(TeamMemberRow(person: p, day: day, band: band));
    }
    return out;
  }

  SupervisedWorkerDetail worker(String workerId, DateTime now) {
    _access.requireWorker(workerId);
    final p = _s.person(workerId)!;
    final records =
        _s.registerMeasurements.where((m) => m.workerId == workerId).toList()
          ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return SupervisedWorkerDetail(
      person: p,
      departmentName: _s.department(p.departmentId)?.name,
      day: DayStatus.of(_s, workerId, now),
      recentSessions: _s.sessionsOf(workerId).take(10).toList(),
      records: records.take(10).toList(),
      exceptions: Exceptions.of(_s, {workerId}, now),
    );
  }

  List<OperationalException> exceptions(DateTime now) =>
      Exceptions.of(_s, _team, now);

  MeasurementRecord record(String measurementId) {
    final m = _s.measurement(measurementId);
    if (m == null || m.workerId == null || !_team.contains(m.workerId)) {
      throw const AccessDenied('This record is outside your access.');
    }
    return m;
  }

  HseReview? reviewOf(String measurementId) => _s.reviewFor(measurementId);

  Person? personOf(String workerId) =>
      _team.contains(workerId) ? _s.person(workerId) : null;
}

/// The one operational write a supervisor makes: closing out a period whose
/// DoseBand will never be scanned. It changes no scientific value (§37).
final class SupervisorCommands {
  SupervisorCommands({
    required this.repository,
    required this.actor,
    required this.ids,
    required this.now,
  });

  final OperationsRepository repository;
  final Actor actor;
  final IdGenerator ids;
  final DateTime Function() now;

  Future<void> closeMissingFinalRead({required String sessionId}) =>
      repository.transact((s) {
        final access = OperationsAccess(s, actor)
          ..requireRole(AppRole.supervisor);
        final x = s.session(sessionId);
        if (x == null) throw const AccessDenied('Unknown session.');
        access.requireWorker(x.workerId);
        AuditEvent event(
          AuditAction a,
          String type,
          String id, [
          String? detail,
        ]) => AuditEvent(
          eventId: ids.next('AUD'),
          at: now(),
          actorId: actor.personId,
          actorRole: actor.role,
          action: a,
          subjectType: type,
          subjectId: id,
          detail: detail,
        );
        return (
          next: WorkerCommands.closeMissing(s, x, now(), event),
          result: null,
        );
      });
}
