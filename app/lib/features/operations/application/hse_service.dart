import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

import '../../../core/domain/doseband.dart';
import '../../../core/domain/monitoring_session.dart';
import '../../auth/domain/access_policy.dart';
import '../../auth/domain/auth_models.dart';
import '../../history/domain/measurement_record.dart';
import '../domain/assignment.dart';
import '../domain/audit.dart';
import '../domain/inventory.dart';
import '../domain/operations_snapshot.dart';
import '../domain/organisation.dart';
import '../domain/review.dart';
import 'access.dart';
import 'day_status.dart';
import 'operations_repository.dart';
import 'worker_service.dart';

/// Measurement-state filter for the exposure register.
enum MeasurementFilter {
  all('All states'),
  value('Value'),
  censored('Below / above range'),
  noReading('No reading');

  const MeasurementFilter(this.label);

  final String label;

  bool matches(MeasurementResult r) => switch (this) {
    MeasurementFilter.all => true,
    MeasurementFilter.value => r is Valid,
    MeasurementFilter.censored => r is Censored,
    MeasurementFilter.noReading => r is Refused,
  };
}

@immutable
final class RegisterRow {
  const RegisterRow({
    required this.record,
    required this.person,
    required this.session,
    required this.review,
    required this.isSuperseded,
  });

  final MeasurementRecord record;
  final Person person;
  final MonitoringSession? session;
  final HseReview? review;
  final bool isSuperseded;
}

/// The authoritative chain behind one record (§40): worker → work context →
/// DoseBand → session → capture → quality → algorithm/calibration → result →
/// review.
@immutable
final class TraceabilityChain {
  const TraceabilityChain({
    required this.record,
    required this.person,
    required this.band,
    required this.lot,
    required this.formulation,
    required this.assignment,
    required this.session,
    required this.review,
    required this.supersedes,
    required this.supersededBy,
    required this.events,
  });

  final MeasurementRecord record;
  final Person person;
  final DoseBand? band;
  final DoseBandLot? lot;
  final SensorFormulation? formulation;
  final DoseBandAssignment? assignment;
  final MonitoringSession? session;
  final HseReview? review;
  final MeasurementRecord? supersedes;
  final MeasurementRecord? supersededBy;

  /// Audit events about this record, its session and its band.
  final List<AuditEvent> events;
}

@immutable
final class HseOverview {
  const HseOverview({
    required this.workersInScope,
    required this.monitoringNow,
    required this.recordsLast7Days,
    required this.noReadingLast7Days,
    required this.openReviews,
    required this.overdueFinalScans,
  });

  final int workersInScope;
  final int monitoringNow;
  final int recordsLast7Days;
  final int noReadingLast7Days;
  final Map<ReviewState, int> openReviews;
  final int overdueFinalScans;

  int get openReviewTotal => openReviews.values.fold(0, (a, b) => a + b);
}

/// What an HSE officer may read: identified records within the configured
/// scope — a site by default, never the whole organisation by default
/// (§39, §147).
final class HseView {
  HseView(OperationsSnapshot snapshot, Actor actor)
    : _access = OperationsAccess(snapshot, actor) {
    _access.requireRole(AppRole.hseOfficer);
    _access.require(Permission.viewIdentifiedExposures);
    _scope = _access.identifiedWorkers();
  }

  final OperationsAccess _access;
  late final Set<String> _scope;

  OperationsSnapshot get _s => _access.snapshot;

  Person get officer => _access.person!;

  Set<String> get scopeSites => _access.grantedSites();

  bool _inScope(MeasurementRecord m) =>
      m.workerId != null && _scope.contains(m.workerId);

  HseOverview overview(DateTime now) {
    final since = now.subtract(const Duration(days: 7));
    final recent = _s.measurements
        .where((m) => _inScope(m) && m.scannedAt.isAfter(since))
        .toList();
    final open = <ReviewState, int>{};
    for (final r in _s.reviews) {
      final m = _s.measurement(r.measurementId);
      if (m == null || !_inScope(m) || !r.state.isOpen) continue;
      open[r.state] = (open[r.state] ?? 0) + 1;
    }
    var monitoring = 0;
    for (final w in _scope) {
      if (DayStatus.of(_s, w, now).status == WorkerDayStatus.monitoring) {
        monitoring++;
      }
    }
    return HseOverview(
      workersInScope: _scope.length,
      monitoringNow: monitoring,
      recordsLast7Days: recent.length,
      noReadingLast7Days: recent.where((m) => m.result is Refused).length,
      openReviews: open,
      overdueFinalScans: Exceptions.of(_s, _scope, now)
          .where(
            (e) =>
                e.kind == ExceptionKind.finalScanOverdue ||
                e.kind == ExceptionKind.monitoringNotEnded,
          )
          .length,
    );
  }

  /// The exposure register. Search matches worker name, worker ID, DoseBand
  /// and work area; every other filter narrows further.
  List<RegisterRow> register({
    String query = '',
    DateTime? from,
    DateTime? to,
    MeasurementFilter state = MeasurementFilter.all,
    ReviewState? review,
    String? departmentId,
    bool includeSuperseded = true,
  }) {
    final q = query.trim().toLowerCase();
    final out = <RegisterRow>[];
    for (final m in _s.measurements) {
      if (!_inScope(m)) continue;
      if (from != null && m.scannedAt.isBefore(from)) continue;
      if (to != null && !m.scannedAt.isBefore(to)) continue;
      if (!state.matches(m.result)) continue;
      final p = _s.person(m.workerId!)!;
      final r = _s.reviewFor(m.id);
      if (review != null && r?.state != review) continue;
      if (departmentId != null && m.context.department.id != departmentId) {
        continue;
      }
      final superseded = _s.supersededBy(m.id) != null;
      if (!includeSuperseded && superseded) continue;
      if (q.isNotEmpty &&
          !p.displayName.toLowerCase().contains(q) &&
          !p.personId.toLowerCase().contains(q) &&
          !m.badge.badgeId.toLowerCase().contains(q) &&
          !m.context.workArea.name.toLowerCase().contains(q)) {
        continue;
      }
      out.add(
        RegisterRow(
          record: m,
          person: p,
          session: m.sessionId == null ? null : _s.session(m.sessionId!),
          review: r,
          isSuperseded: superseded,
        ),
      );
    }
    out.sort((a, b) => b.record.scannedAt.compareTo(a.record.scannedAt));
    return out;
  }

  TraceabilityChain chain(String measurementId) {
    final m = _s.measurement(measurementId);
    if (m == null || !_inScope(m)) {
      throw const AccessDenied('This record is outside your access.');
    }
    final session = m.sessionId == null ? null : _s.session(m.sessionId!);
    final band = _s.bands[m.badge.badgeId];
    final lot = _s.lot(band?.lotId);
    final ids = {m.id, m.badge.badgeId, if (m.sessionId != null) m.sessionId!};
    return TraceabilityChain(
      record: m,
      person: _s.person(m.workerId!)!,
      band: band,
      lot: lot,
      formulation: _s.formulation(lot?.formulationId),
      assignment: session?.assignmentId == null
          ? null
          : _s.assignment(session!.assignmentId!),
      session: session,
      review: _s.reviewFor(m.id),
      supersedes: m.supersedesId == null
          ? null
          : _s.measurement(m.supersedesId!),
      supersededBy: _s.supersededBy(m.id),
      events: _s.audit.where((e) => ids.contains(e.subjectId)).toList()
        ..sort((a, b) => a.at.compareTo(b.at)),
    );
  }

  /// Open reviews, oldest first — the order they should be worked.
  List<RegisterRow> reviewQueue({ReviewState? state}) {
    final rows = register().where((row) {
      final r = row.review;
      if (r == null) return false;
      return state == null ? r.state.isOpen : r.state == state;
    }).toList();
    rows.sort((a, b) => a.record.scannedAt.compareTo(b.record.scannedAt));
    return rows;
  }
}

/// HSE's writes: review state and disposition. Neither touches the record,
/// the result or the session — the scientific value is not editable by
/// anyone (§40, §93).
final class HseCommands {
  HseCommands({
    required this.repository,
    required this.actor,
    required this.ids,
    required this.now,
  });

  final OperationsRepository repository;
  final Actor actor;
  final IdGenerator ids;
  final DateTime Function() now;

  HseReview _reviewInScope(OperationsSnapshot s, String measurementId) {
    final access = OperationsAccess(s, actor)
      ..requireRole(AppRole.hseOfficer)
      ..require(Permission.reviewMeasurements);
    final m = s.measurement(measurementId);
    if (m == null || m.workerId == null || !access.canSeeWorker(m.workerId!)) {
      throw const AccessDenied('This record is outside your access.');
    }
    final r = s.reviewFor(measurementId);
    if (r == null) throw const OperationRefused('This record has no review.');
    return r;
  }

  Future<void> moveReview({
    required String measurementId,
    required ReviewState to,
    String? note,
  }) => repository.transact((s) {
    final r = _reviewInScope(s, measurementId);
    final at = now();
    final moved = switch (ReviewPolicy.transition(r.state, to)) {
      TransitionAccepted(:final state) => r.copyWith(
        state: state,
        updatedAt: at,
        reviewerId: actor.personId,
        note: note,
      ),
      TransitionRefused(:final from, :final to) => throw OperationRefused(
        'A review cannot move from ${from.label} to ${to.label}.',
      ),
    };
    var next = s
        .withReview(moved)
        .appendAudit(
          AuditEvent(
            eventId: ids.next('AUD'),
            at: at,
            actorId: actor.personId,
            actorRole: actor.role,
            action: AuditAction.reviewStateChanged,
            subjectType: 'measurement',
            subjectId: measurementId,
            detail: '${r.state.label} → ${moved.state.label}',
          ),
        );
    // The session's own lifecycle records that HSE looked at it; the
    // measurement does not change.
    final session = s.measurement(measurementId)?.sessionId;
    final x = session == null ? null : next.session(session);
    if (x != null) {
      final target = switch (moved.state) {
        ReviewState.reviewed => MonitoringSessionState.reviewed,
        ReviewState.closed => MonitoringSessionState.closed,
        _ => null,
      };
      final advanced = target == null ? null : x.advanceTo(target);
      if (advanced != null) next = next.withSession(advanced);
    }
    return (next: next, result: null);
  });

  /// Records the operational follow-up. Allowed once the review is reviewed.
  Future<void> recordDisposition({
    required String measurementId,
    required ReviewDisposition disposition,
    String? note,
  }) => repository.transact((s) {
    OperationsAccess(s, actor).require(Permission.recordDisposition);
    final r = _reviewInScope(s, measurementId);
    if (r.state != ReviewState.reviewed) {
      throw const OperationRefused(
        'A disposition is recorded once the review is complete.',
      );
    }
    final at = now();
    return (
      next: s
          .withReview(
            r.copyWith(disposition: disposition, updatedAt: at, note: note),
          )
          .appendAudit(
            AuditEvent(
              eventId: ids.next('AUD'),
              at: at,
              actorId: actor.personId,
              actorRole: actor.role,
              action: AuditAction.dispositionRecorded,
              subjectType: 'measurement',
              subjectId: measurementId,
              detail: disposition.label,
            ),
          ),
      result: null,
    );
  });
}
