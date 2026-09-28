import 'package:flutter/foundation.dart';

import '../../../core/domain/doseband.dart';
import '../../../core/domain/monitoring_session.dart';
import '../../history/domain/measurement_record.dart';
import 'assignment.dart';
import 'audit.dart';
import 'inventory.dart';
import 'organisation.dart';
import 'review.dart';

/// Everything the on-device operations store holds (PRODUCT BUILD v1 §49).
///
/// ## What this is
///
/// The **single local authority** for organisational state on this device:
/// the directory, the teams and scopes, the DoseBand inventory, every
/// assignment and monitoring session, every measurement record, every HSE
/// review and the audit log. Every workspace reads the same snapshot through
/// role-checked services, so a supervisor sees exactly the session a worker
/// started — not a parallel catalogue that happens to look similar.
///
/// ## What this is not
///
/// A central server. The target architecture puts all of this in a relational
/// database behind an authenticated API (docs/architecture/system-architecture.md).
/// None of that is deployed. Nothing here is synced, and nothing here claims
/// to be: every record's sync state is `localOnly`.
///
/// Immutable. The repository replaces it wholesale on every transaction, so
/// the persisted file and the in-memory state cannot drift.
@immutable
final class OperationsSnapshot {
  const OperationsSnapshot({
    required this.datasetVersion,
    required this.seededAt,
    required this.people,
    required this.departments,
    required this.teams,
    required this.grants,
    required this.formulations,
    required this.lots,
    required this.bands,
    required this.assignments,
    required this.sessions,
    required this.measurements,
    required this.reviews,
    required this.audit,
  });

  /// Which presentation dataset this snapshot was seeded from.
  final String datasetVersion;
  final DateTime seededAt;

  final List<Person> people;
  final List<OrgDepartment> departments;
  final List<Team> teams;
  final List<ScopeGrant> grants;
  final List<SensorFormulation> formulations;
  final List<DoseBandLot> lots;

  /// Serialised bands, keyed by DoseBand id.
  final Map<String, DoseBand> bands;
  final List<DoseBandAssignment> assignments;
  final List<MonitoringSession> sessions;

  /// Append-only. A superseding record is added alongside; nothing is
  /// replaced.
  final List<MeasurementRecord> measurements;

  /// Every record that belongs in an organisational view — HSE registers,
  /// management statistics, supervisor views, exceptions, reports and any
  /// future dataset. Presentation records are excluded: they are the
  /// worker's own demonstration history, never exposure data.
  Iterable<MeasurementRecord> get registerMeasurements =>
      measurements.where((m) => !m.isPresentation);
  final List<HseReview> reviews;

  /// Append-only.
  final List<AuditEvent> audit;

  Person? person(String id) =>
      people.where((p) => p.personId == id).firstOrNull;

  DoseBandLot? lot(String? id) =>
      id == null ? null : lots.where((l) => l.lotId == id).firstOrNull;

  SensorFormulation? formulation(String? id) => id == null
      ? null
      : formulations.where((f) => f.formulationId == id).firstOrNull;

  OrgDepartment? department(String id) =>
      departments.where((d) => d.departmentId == id).firstOrNull;

  MonitoringSession? session(String id) =>
      sessions.where((s) => s.sessionId == id).firstOrNull;

  DoseBandAssignment? assignment(String id) =>
      assignments.where((a) => a.assignmentId == id).firstOrNull;

  MeasurementRecord? measurement(String id) =>
      measurements.where((m) => m.id == id).firstOrNull;

  HseReview? reviewFor(String measurementId) =>
      reviews.where((r) => r.measurementId == measurementId).firstOrNull;

  /// The record that supersedes [measurementId], if any.
  MeasurementRecord? supersededBy(String measurementId) =>
      measurements.where((m) => m.supersedesId == measurementId).firstOrNull;

  /// The worker's claim that has not finished, if any. At most one exists —
  /// the registry refuses a second claim while one is active.
  DoseBandAssignment? activeAssignmentOf(String workerId) => assignments
      .where((a) => a.workerId == workerId && a.isActive)
      .firstOrNull;

  /// Sessions of [workerId], newest first.
  List<MonitoringSession> sessionsOf(String workerId) {
    final list = sessions.where((s) => s.workerId == workerId).toList();
    list.sort((a, b) => _newest(a).compareTo(_newest(b)));
    return list.reversed.toList();
  }

  static DateTime _newest(MonitoringSession s) =>
      s.endedAt ?? s.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  OperationsSnapshot copyWith({
    List<Person>? people,
    List<Team>? teams,
    List<ScopeGrant>? grants,
    List<DoseBandLot>? lots,
    Map<String, DoseBand>? bands,
    List<DoseBandAssignment>? assignments,
    List<MonitoringSession>? sessions,
    List<MeasurementRecord>? measurements,
    List<HseReview>? reviews,
    List<AuditEvent>? audit,
  }) => OperationsSnapshot(
    datasetVersion: datasetVersion,
    seededAt: seededAt,
    people: people ?? this.people,
    departments: departments,
    teams: teams ?? this.teams,
    grants: grants ?? this.grants,
    formulations: formulations,
    lots: lots ?? this.lots,
    bands: bands ?? this.bands,
    assignments: assignments ?? this.assignments,
    sessions: sessions ?? this.sessions,
    measurements: measurements ?? this.measurements,
    reviews: reviews ?? this.reviews,
    audit: audit ?? this.audit,
  );

  /// Replaces one session by id.
  OperationsSnapshot withSession(MonitoringSession s) => copyWith(
    sessions: [for (final x in sessions) x.sessionId == s.sessionId ? s : x],
  );

  OperationsSnapshot withAssignment(DoseBandAssignment a) => copyWith(
    assignments: [
      for (final x in assignments) x.assignmentId == a.assignmentId ? a : x,
    ],
  );

  OperationsSnapshot withBand(DoseBand b) =>
      copyWith(bands: {...bands, b.dosebandId: b});

  OperationsSnapshot withReview(HseReview r) => copyWith(
    reviews: [for (final x in reviews) x.reviewId == r.reviewId ? r : x],
  );

  OperationsSnapshot appendAudit(AuditEvent e) =>
      copyWith(audit: [...audit, e]);
}
