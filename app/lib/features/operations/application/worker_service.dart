import '../../../core/domain/doseband.dart';
import '../../../core/domain/monitoring_session.dart';
import '../../auth/domain/access_policy.dart';
import '../../auth/domain/auth_models.dart';
import '../../history/domain/measurement_record.dart';
import '../domain/assignment.dart';
import '../domain/audit.dart';
import '../domain/operations_snapshot.dart';
import '../domain/organisation.dart';
import '../domain/review.dart';
import 'access.dart';
import 'day_status.dart';
import 'operations_repository.dart';

/// What a worker may read about themselves — and nothing else (§145).
///
/// Every method is scoped to the actor. There is no parameter naming another
/// worker, so there is nothing to tamper with: a route or a cached screen
/// that asks for someone else's record reaches [record], which refuses.
final class WorkerView {
  WorkerView(OperationsSnapshot snapshot, Actor actor)
    : _access = OperationsAccess(snapshot, actor) {
    _access.requireRole(AppRole.worker);
    _access.require(Permission.viewOwnMonitoring);
  }

  final OperationsAccess _access;

  OperationsSnapshot get _s => _access.snapshot;
  String get _me => _access.actor.personId;

  Person get person => _access.person!;

  WorkerDay today(DateTime now) {
    _access.require(Permission.viewOwnMonitoring);
    return DayStatus.of(_s, _me, now);
  }

  DoseBandAssignment? get activeAssignment => _s.activeAssignmentOf(_me);

  MonitoringSession? get activeSession {
    final a = activeAssignment;
    return a == null ? null : _s.session(a.sessionId);
  }

  /// Own measurement records in [from, to), newest first.
  List<MeasurementRecord> history({DateTime? from, DateTime? to}) {
    _access.require(Permission.viewOwnHistory);
    final list = _s.measurements.where((m) {
      if (m.workerId != _me) return false;
      if (from != null && m.scannedAt.isBefore(from)) return false;
      if (to != null && !m.scannedAt.isBefore(to)) return false;
      return true;
    }).toList()..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return list;
  }

  /// One own record. Anyone else's — or one that does not exist — is refused
  /// with the same message, so the refusal confirms nothing.
  MeasurementRecord record(String measurementId) {
    _access.require(Permission.viewOwnHistory);
    final m = _s.measurement(measurementId);
    if (m == null || m.workerId != _me) {
      throw const AccessDenied('This record is outside your access.');
    }
    return m;
  }

  MonitoringSession? sessionOf(MeasurementRecord m) =>
      m.sessionId == null ? null : _s.session(m.sessionId!);

  HseReview? reviewOf(MeasurementRecord m) => _s.reviewFor(m.id);

  MeasurementRecord? supersededBy(MeasurementRecord m) => _s.supersededBy(m.id);
}

/// Thrown when a command's precondition does not hold — e.g. ending a
/// session that is not active. A defect or a stale screen, never a result.
final class OperationRefused implements Exception {
  const OperationRefused(this.reason);

  final String reason;

  @override
  String toString() => 'OperationRefused: $reason';
}

/// The worker's own writes to the operations store.
///
/// Each runs as one repository transaction, re-checks access inside it, and
/// appends an audit event in the same write — so a state change and its
/// audit event cannot be separated by a crash.
final class WorkerCommands {
  WorkerCommands({
    required this.repository,
    required this.actor,
    required this.ids,
    required this.now,
  });

  final OperationsRepository repository;
  final Actor actor;
  final IdGenerator ids;
  final DateTime Function() now;

  AuditEvent _event(
    AuditAction action,
    String type,
    String id, [
    String? detail,
  ]) => AuditEvent(
    eventId: ids.next('AUD'),
    at: now(),
    actorId: actor.personId,
    actorRole: actor.role,
    action: action,
    subjectType: type,
    subjectId: id,
    detail: detail,
  );

  MonitoringSession _ownSession(OperationsSnapshot s, String sessionId) {
    OperationsAccess(s, actor).require(Permission.viewOwnMonitoring);
    final x = s.session(sessionId);
    if (x == null || x.workerId != actor.personId) {
      throw const AccessDenied('This monitoring session is not yours.');
    }
    return x;
  }

  /// Records a pre-use check that ended in "replace" or "cannot verify". No
  /// state changes — the band was not claimed — but the supervisor can see
  /// that a band was turned away (§37).
  Future<void> recordPreUseOutcome({
    required String dosebandId,
    required PreUseOutcome outcome,
    String? reason,
  }) => repository.transact((s) {
    OperationsAccess(s, actor).require(Permission.claimDoseBand);
    final detail = reason == null ? outcome.label : '${outcome.label}: $reason';
    return (
      next: s.appendAudit(
        _event(AuditAction.preUseChecked, 'doseband', dosebandId, detail),
      ),
      result: null,
    );
  });

  /// assigned → monitoring. Idempotent for a session already active.
  Future<void> startMonitoring({
    required String sessionId,
    WorkSummary? work,
  }) => repository.transact((s) {
    final x = _ownSession(s, sessionId);
    if (x.state == MonitoringSessionState.active)
      return (next: s, result: null);
    final at = now();
    final started = x.advanceTo(MonitoringSessionState.active, startedAt: at);
    final band = s.bands[x.dosebandId];
    final wearing = band?.advanceTo(DoseBandLifecycle.monitoring);
    if (started == null || wearing == null) {
      throw OperationRefused(
        'Cannot start monitoring from ${x.state.name} '
        '(DoseBand ${band?.lifecycle.name ?? 'missing'}).',
      );
    }
    final next = s
        .withSession(work == null ? started : started.copyWith(work: work))
        .withBand(wearing)
        .appendAudit(
          _event(AuditAction.monitoringStarted, 'session', sessionId),
        );
    return (next: next, result: null);
  });

  /// monitoring → ready for final read. Idempotent once ended.
  Future<void> endMonitoring({required String sessionId}) =>
      repository.transact((s) {
        final x = _ownSession(s, sessionId);
        if (x.state == MonitoringSessionState.readyForFinalRead) {
          return (next: s, result: null);
        }
        final ended = x.advanceTo(
          MonitoringSessionState.readyForFinalRead,
          endedAt: now(),
        );
        final band = s.bands[x.dosebandId]?.advanceTo(
          DoseBandLifecycle.readyForFinalRead,
        );
        if (ended == null || band == null) {
          throw OperationRefused('Cannot end monitoring from ${x.state.name}.');
        }
        return (
          next: s
              .withSession(ended)
              .withBand(band)
              .appendAudit(
                _event(AuditAction.monitoringEnded, 'session', sessionId),
              ),
          result: null,
        );
      });

  /// Stores the final read's record and closes the monitoring period.
  ///
  /// ## Immutability
  ///
  /// A session takes exactly one record. A second one is accepted only if it
  /// names the first in `supersedesId` and says why; the first is kept,
  /// untouched, and both stay in history (§26, §93). Re-recording the same
  /// record id is a no-op, so a retried write cannot duplicate it.
  Future<void> recordMeasurement(MeasurementRecord record) =>
      repository.transact((s) {
        final sessionId = record.sessionId;
        if (sessionId == null || record.workerId != actor.personId) {
          throw const OperationRefused(
            'A record must name its session and belong to the worker.',
          );
        }
        final x = _ownSession(s, sessionId);
        if (s.measurement(record.id) != null) return (next: s, result: null);

        final existing = x.measurementId;
        if (existing != null) {
          if (record.supersedesId != existing) {
            throw const OperationRefused(
              'This monitoring period already has a record. A new reading '
              'must supersede it explicitly.',
            );
          }
          final superseded = x.copyWith(measurementId: record.id);
          return (
            next: s
                .withSession(superseded)
                .copyWith(measurements: [...s.measurements, record])
                .appendAudit(
                  _event(
                    AuditAction.measurementSuperseded,
                    'measurement',
                    record.id,
                    'Supersedes ${record.supersedesId}: '
                        '${record.supersessionReason}',
                  ),
                ),
            result: null,
          );
        }

        final at = now();
        final done = x.advanceTo(
          MonitoringSessionState.readComplete,
          measurementId: record.id,
        );
        final band = s.bands[x.dosebandId]?.advanceTo(DoseBandLifecycle.read);
        final assignment = x.assignmentId == null
            ? null
            : s.assignment(x.assignmentId!);
        if (done == null || band == null) {
          throw OperationRefused(
            'Cannot record a measurement from ${x.state.name}.',
          );
        }
        var next = s
            .withSession(done)
            .withBand(band)
            .copyWith(
              measurements: [...s.measurements, record],
              reviews: [
                ...s.reviews,
                HseReview(
                  reviewId: ids.next('REV'),
                  measurementId: record.id,
                  state: ReviewState.pending,
                  openedAt: at,
                  updatedAt: at,
                ),
              ],
            )
            .appendAudit(
              _event(AuditAction.measurementRecorded, 'measurement', record.id),
            );
        if (assignment != null) {
          next = next.withAssignment(
            assignment.copyWith(state: AssignmentState.completed, endedAt: at),
          );
        }
        return (next: next, result: null);
      });

  /// Withdraws a claim before monitoring began: the band leaves service
  /// (it was handed out and may have been handled) and the session closes
  /// with no window.
  Future<void> cancelAssignment({
    required String sessionId,
    required String reason,
  }) => repository.transact((s) {
    final x = _ownSession(s, sessionId);
    final closed = x.advanceTo(MonitoringSessionState.closed);
    final band = s.bands[x.dosebandId]?.advanceTo(
      DoseBandLifecycle.assignmentCancelled,
    );
    final a = x.assignmentId == null ? null : s.assignment(x.assignmentId!);
    if (closed == null || band == null || a == null) {
      throw OperationRefused(
        'Only an assignment that has not started can be cancelled '
        '(session ${x.state.name}).',
      );
    }
    return (
      next: s
          .withSession(closed)
          .withBand(band)
          .withAssignment(
            a.copyWith(
              state: AssignmentState.cancelled,
              endedAt: now(),
              cancelReason: reason,
            ),
          )
          .appendAudit(
            _event(
              AuditAction.assignmentCancelled,
              'doseband',
              band.dosebandId,
              reason,
            ),
          ),
      result: null,
    );
  });

  /// The worn band was damaged or lost during monitoring. The period is
  /// interrupted — it cannot be read — and the worker may claim a new band
  /// for a new period. The interrupted one stays on record (§118).
  Future<void> reportDoseBand({
    required String sessionId,
    required DoseBandLifecycle condition,
    String? note,
  }) {
    if (condition != DoseBandLifecycle.damaged &&
        condition != DoseBandLifecycle.lost) {
      throw ArgumentError.value(condition, 'condition', 'damaged or lost');
    }
    return repository.transact((s) {
      final x = _ownSession(s, sessionId);
      final at = now();
      final interrupted = x.advanceTo(
        MonitoringSessionState.interrupted,
        endedAt: at,
      );
      final band = s.bands[x.dosebandId]?.advanceTo(condition);
      final a = x.assignmentId == null ? null : s.assignment(x.assignmentId!);
      if (interrupted == null || band == null || a == null) {
        throw OperationRefused(
          'A DoseBand can be reported only while it is being worn '
          '(session ${x.state.name}).',
        );
      }
      return (
        next: s
            .withSession(interrupted)
            .withBand(band)
            .withAssignment(
              a.copyWith(state: AssignmentState.completed, endedAt: at),
            )
            .appendAudit(
              _event(
                AuditAction.dosebandReported,
                'doseband',
                band.dosebandId,
                '${condition == DoseBandLifecycle.lost ? 'Lost' : 'Damaged'}'
                    ' during monitoring${note == null ? '' : ': $note'}',
              ),
            ),
        result: null,
      );
    });
  }

  /// The final scan of an ended period will never happen — the band is gone.
  /// Closes the period as "final scan missing" rather than leaving it open
  /// forever; nothing is inferred about the exposure.
  Future<void> closeMissingFinalRead({required String sessionId}) =>
      repository.transact((s) {
        final x = _ownSession(s, sessionId);
        return (next: closeMissing(s, x, now(), _event), result: null);
      });

  /// Shared with the supervisor's version of the same action.
  static OperationsSnapshot closeMissing(
    OperationsSnapshot s,
    MonitoringSession x,
    DateTime at,
    AuditEvent Function(AuditAction, String, String, [String?]) event,
  ) {
    final missing = x.advanceTo(MonitoringSessionState.finalReadMissing);
    final band = s.bands[x.dosebandId]?.advanceTo(
      DoseBandLifecycle.missingFinalRead,
    );
    final a = x.assignmentId == null ? null : s.assignment(x.assignmentId!);
    if (missing == null || band == null || a == null) {
      throw OperationRefused(
        'Only a period awaiting its final scan can be closed as missing '
        '(session ${x.state.name}).',
      );
    }
    return s
        .withSession(missing)
        .withBand(band)
        .withAssignment(
          a.copyWith(state: AssignmentState.completed, endedAt: at),
        )
        .appendAudit(
          event(
            AuditAction.monitoringInterrupted,
            'session',
            x.sessionId,
            'Closed as final scan missing',
          ),
        );
  }
}

/// What any signed-in person may read about themselves: the directory
/// record, their department, and — for a team member — the team and its
/// supervisor by name. Available to every role (§29).
final class OwnProfileView {
  OwnProfileView(OperationsSnapshot snapshot, Actor actor)
    : _access = OperationsAccess(snapshot, actor) {
    _access.require(Permission.viewOwnProfile);
  }

  final OperationsAccess _access;

  OperationsSnapshot get _s => _access.snapshot;
  String get _me => _access.actor.personId;

  Person get person => _access.person!;

  String? get departmentName => _s.department(person.departmentId)?.name;

  String? get teamName =>
      _s.teams.where((t) => t.memberIds.contains(_me)).firstOrNull?.name;

  String? get supervisorName {
    for (final t in _s.teams) {
      if (t.memberIds.contains(_me)) {
        return _s.person(t.supervisorId)?.displayName;
      }
    }
    return null;
  }

  /// Teams this person supervises, by name.
  List<String> get supervises => [
    for (final t in _s.teams)
      if (t.supervisorId == _me) t.name,
  ];

  List<ScopeGrant> get grants =>
      _s.grants.where((g) => g.personId == _me).toList();
}
