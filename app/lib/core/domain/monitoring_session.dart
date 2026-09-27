import 'package:flutter/foundation.dart';

import '../../features/workflow/domain/workflow_state.dart';
import 'connectivity.dart';
import 'doseband.dart';
import 'provenance.dart';

/// The lifecycle of one worker's monitoring period (APP-PRODUCT-01 §37).
///
/// ## Terminology
///
/// * **Monitoring period** (user-facing) = **monitored period** (existing code,
///   53 uses) = [MonitoringSession] (canonical type). One concept.
/// * **Monitoring window** / **exposure window** = the session's *time
///   interval*, `startedAt → endedAt`. A property of the session, not a
///   second concept. It is what an exposure is integrated over.
///
/// The existing code's `ShiftStage` is the persisted form of this lifecycle
/// for the one local session; [MonitoringSessionStateMapping] maps it here.
enum MonitoringSessionState {
  // ---- operational
  /// No DoseBand assigned yet (context may be set).
  notStarted,

  /// The worker is wearing the assigned DoseBand.
  active,

  /// Monitoring ended; the final scan of the same DoseBand is due.
  readyForFinalRead,

  /// The final scan happened. The *result* may be a value or a refusal.
  readComplete,

  /// Reviewed by HSE.
  reviewed,

  /// Nothing further will happen to this session.
  closed,

  // ---- exceptional
  /// Ended early; the window is shorter than planned. Still readable.
  partial,

  /// Interrupted and not resumed.
  interrupted,

  /// The DoseBand was replaced mid-period (damage, loss). The window is split.
  bandReplaced,

  /// Monitoring ended and the final scan never happened.
  finalReadMissing,

  /// The final read cannot be used (e.g. the window could not be trusted).
  invalidRead;

  /// Qualified labels — "complete" alone is ambiguous across the DoseBand,
  /// the session, the measurement and the review (§140 Q22).
  String get label => switch (this) {
    MonitoringSessionState.notStarted => 'Monitoring not started',
    MonitoringSessionState.active => 'Monitoring active',
    MonitoringSessionState.readyForFinalRead => 'Final scan due',
    MonitoringSessionState.readComplete => 'Monitoring complete',
    MonitoringSessionState.reviewed => 'Monitoring reviewed',
    MonitoringSessionState.closed => 'Monitoring closed',
    MonitoringSessionState.partial => 'Partial monitoring',
    MonitoringSessionState.interrupted => 'Monitoring interrupted',
    MonitoringSessionState.bandReplaced => 'DoseBand replaced',
    MonitoringSessionState.finalReadMissing => 'Final scan missing',
    MonitoringSessionState.invalidRead => 'Final scan unusable',
  };
}

/// Legal monitoring-session transitions. As with the DoseBand policy, the UI
/// asks; it never writes a state.
abstract final class MonitoringSessionPolicy {
  static const Map<MonitoringSessionState, Set<MonitoringSessionState>>
  _next = {
    // Closed from not-started: the assignment was cancelled before any
    // monitoring happened, so there is no window and nothing to read.
    MonitoringSessionState.notStarted: {
      MonitoringSessionState.active,
      MonitoringSessionState.closed,
    },
    MonitoringSessionState.active: {
      MonitoringSessionState.readyForFinalRead,
      MonitoringSessionState.partial,
      MonitoringSessionState.interrupted,
      MonitoringSessionState.bandReplaced,
    },
    MonitoringSessionState.partial: {MonitoringSessionState.readyForFinalRead},
    MonitoringSessionState.bandReplaced: {
      MonitoringSessionState.active,
      MonitoringSessionState.readyForFinalRead,
    },
    MonitoringSessionState.readyForFinalRead: {
      MonitoringSessionState.readComplete,
      MonitoringSessionState.finalReadMissing,
      MonitoringSessionState.invalidRead,
    },
    MonitoringSessionState.readComplete: {
      MonitoringSessionState.reviewed,
      MonitoringSessionState.closed,
    },
    MonitoringSessionState.invalidRead: {
      MonitoringSessionState.reviewed,
      MonitoringSessionState.closed,
    },
    MonitoringSessionState.finalReadMissing: {
      MonitoringSessionState.reviewed,
      MonitoringSessionState.closed,
    },
    MonitoringSessionState.interrupted: {
      MonitoringSessionState.reviewed,
      MonitoringSessionState.closed,
    },
    MonitoringSessionState.reviewed: {MonitoringSessionState.closed},
    MonitoringSessionState.closed: {},
  };

  static Set<MonitoringSessionState> nextFrom(MonitoringSessionState from) =>
      _next[from]!;

  static bool allows(MonitoringSessionState from, MonitoringSessionState to) =>
      _next[from]!.contains(to);

  static LifecycleTransition<MonitoringSessionState> transition(
    MonitoringSessionState from,
    MonitoringSessionState to,
  ) => allows(from, to)
      ? LifecycleTransition.accepted(to)
      : LifecycleTransition.refused(from, to);
}

/// Where and on what a monitoring period was worked — the part of the work
/// context the organisation views need (§13). A snapshot: it records what was
/// in force during the period, and is not re-derived from later edits.
@immutable
final class WorkSummary {
  const WorkSummary({
    required this.siteId,
    required this.siteName,
    required this.departmentId,
    required this.departmentName,
    this.workAreaId,
    this.workAreaName,
    this.shiftId,
    this.shiftName,
    this.activity,
  });

  final String siteId;
  final String siteName;
  final String departmentId;
  final String departmentName;
  final String? workAreaId;
  final String? workAreaName;
  final String? shiftId;
  final String? shiftName;

  /// Job or activity title, when one was recorded.
  final String? activity;
}

/// One worker's monitoring period with one DoseBand.
@immutable
final class MonitoringSession {
  const MonitoringSession({
    required this.sessionId,
    required this.workerId,
    required this.state,
    required this.provenance,
    this.dosebandId,
    this.assignmentId,
    this.workContextId,
    this.work,
    this.startedAt,
    this.endedAt,
    this.measurementId,
    this.syncState = SyncState.localOnly,
  });

  final String sessionId;
  final String workerId;

  /// Null until a DoseBand is assigned.
  final String? dosebandId;

  /// The claim this period runs under.
  final String? assignmentId;

  /// Shift / work-context reference.
  final String? workContextId;

  /// Site, department, area, shift and activity, as recorded for the period.
  final WorkSummary? work;

  final MonitoringSessionState state;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// The measurement (value or refusal) produced by the final read.
  final String? measurementId;

  final RecordProvenance provenance;

  /// The fifth status axis (§48). Independent of every other: a sync failure
  /// says nothing about the reading. Only [SyncState.producibleToday] can
  /// occur in this build.
  final SyncState syncState;

  /// The monitoring window. Null when it cannot be established — including a
  /// window that runs backwards, which is evidence the clock moved. Never
  /// clamped to zero: an unknown window is not a zero-length one.
  Duration? get window {
    final s = startedAt;
    final e = endedAt;
    if (s == null || e == null) return null;
    final d = e.difference(s);
    return d.isNegative ? null : d;
  }

  /// Returns the session in [to], or null if the lifecycle does not allow it.
  MonitoringSession? advanceTo(
    MonitoringSessionState to, {
    DateTime? startedAt,
    DateTime? endedAt,
    String? measurementId,
  }) => switch (MonitoringSessionPolicy.transition(state, to)) {
    TransitionAccepted(:final state) => copyWith(
      state: state,
      startedAt: startedAt,
      endedAt: endedAt,
      measurementId: measurementId,
    ),
    TransitionRefused() => null,
  };

  /// Field copy. Deliberately no way to *clear* a timestamp or measurement:
  /// once recorded, they are part of the record.
  MonitoringSession copyWith({
    MonitoringSessionState? state,
    String? dosebandId,
    String? assignmentId,
    WorkSummary? work,
    DateTime? startedAt,
    DateTime? endedAt,
    String? measurementId,
    SyncState? syncState,
  }) => MonitoringSession(
    sessionId: sessionId,
    workerId: workerId,
    state: state ?? this.state,
    provenance: provenance,
    dosebandId: dosebandId ?? this.dosebandId,
    assignmentId: assignmentId ?? this.assignmentId,
    workContextId: workContextId,
    work: work ?? this.work,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    measurementId: measurementId ?? this.measurementId,
    syncState: syncState ?? this.syncState,
  );
}

/// Maps the persisted local workflow stage onto the canonical lifecycle.
extension MonitoringSessionStateMapping on ShiftStage {
  MonitoringSessionState get sessionState => switch (this) {
    ShiftStage.noShift ||
    ShiftStage.contextSet ||
    ShiftStage.badgeAssigned ||
    ShiftStage.readyForDosimetry => MonitoringSessionState.notStarted,
    ShiftStage.monitoring => MonitoringSessionState.active,
    ShiftStage.awaitingScan => MonitoringSessionState.readyForFinalRead,
    ShiftStage.complete => MonitoringSessionState.readComplete,
  };

  /// The DoseBand's lifecycle implied by the local stage, or null when no
  /// band is assigned.
  DoseBandLifecycle? get dosebandLifecycle => switch (this) {
    ShiftStage.noShift || ShiftStage.contextSet => null,
    ShiftStage.badgeAssigned ||
    ShiftStage.readyForDosimetry => DoseBandLifecycle.assigned,
    ShiftStage.monitoring => DoseBandLifecycle.monitoring,
    ShiftStage.awaitingScan => DoseBandLifecycle.readyForFinalRead,
    ShiftStage.complete => DoseBandLifecycle.read,
  };
}
