import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

import 'badge_specimen.dart';
import 'physical_badge.dart';
import 'work_context.dart';

/// The stage a worker's monitored period has reached.
///
/// The order is the workflow order (directive §2): a worker moves forward one
/// step at a time, every transition is written to storage before the UI
/// advances, and killing the app resumes at the same stage.
enum ShiftStage {
  /// No badge assigned, no monitored period.
  noShift,

  /// Work context selected; no badge yet.
  contextSet,

  /// A badge has been scanned and assigned, its verification recorded.
  badgeAssigned,

  /// Pre-work dosimetry check passed. Ready to begin — not "safe to work".
  readyForDosimetry,

  /// Monitoring is active.
  monitoring,

  /// Monitoring ended; the badge still needs its final scan.
  awaitingScan,

  /// A measurement has been produced for this period.
  complete,
}

/// The whole state of a worker's current (or just-completed) monitored period.
///
/// Immutable; the controller replaces it wholesale on every transition so the
/// persisted snapshot and the in-memory state can never drift.
@immutable
final class ShiftSession {
  const ShiftSession({
    this.stage = ShiftStage.noShift,
    this.context,
    this.badge,
    this.physicalBadge,
    this.startedAt,
    this.endedAt,
    this.result,
    this.captureId,
    this.sessionId,
    this.assignmentId,
  }) : assert(
         badge == null || physicalBadge == null,
         'a session holds a simulated specimen or a physical badge, never both',
       );

  final ShiftStage stage;
  final WorkContext? context;

  /// A simulated specimen, for presentation data. Its scan plays back a
  /// declared outcome.
  final BadgeSpecimen? badge;

  /// A real badge, identified by hand. Its scan opens the real camera and runs
  /// the real pipeline. MEASUREMENT-INTEGRATION-02 §8.
  final PhysicalBadge? physicalBadge;

  /// Whichever badge is assigned.
  BadgeIdentity? get assignedBadge => physicalBadge ?? badge;

  /// Whether this session's final scan is a real capture.
  bool get isPhysical => physicalBadge != null;

  /// The archived capture that produced [result], for a physical scan.
  final String? captureId;

  /// The organisational monitoring session this device-local period mirrors,
  /// in the operations store. Null for a simulated period, which has none.
  final String? sessionId;

  /// The DoseBand claim the period runs under.
  final String? assignmentId;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// The outcome of the final scan. Present only at [ShiftStage.complete].
  final MeasurementResult? result;

  static const ShiftSession none = ShiftSession();

  bool get isActive => stage == ShiftStage.monitoring;

  /// Whether the work context and badge have become measurement provenance.
  ///
  /// True from the moment monitoring starts and for every later stage. Before
  /// that the worker is still filling in a form and may change anything; after
  /// it, the record describes a badge that has actually been exposed, and the
  /// context under which that happened is a fact about the past.
  bool get contextIsLocked => stage.index >= ShiftStage.monitoring.index;

  /// The window the badge has been (or was) exposed for, or null when that
  /// window cannot be established. Never extrapolated to a full shift — it is
  /// what it is.
  ///
  /// Null is returned in two distinct cases, and neither may be shown as a
  /// duration:
  ///
  /// * monitoring has not started, so there is no window yet;
  /// * the end of the window precedes its start, which cannot happen while
  ///   time runs forward. A session restored after a cold start can see this
  ///   when the device clock has been moved backwards — by a reboot without a
  ///   battery-backed clock, a timezone or manual change, or an NTP
  ///   correction. Clamping that to `Duration.zero`, as this used to, printed
  ///   "0h 00m" for a period that had genuinely been running: a plausible
  ///   number in place of an unknown one. Exposure duration multiplies
  ///   directly into ppm*h, so an untrustworthy window must refuse, not round.
  ///
  /// A forward jump is NOT detectable here and is not claimed to be. See
  /// `docs/design/persistence.md`.
  Duration? coverageAt(DateTime now) {
    final start = startedAt;
    if (start == null) return null;
    final end = endedAt ?? now;
    final d = end.difference(start);
    return d.isNegative ? null : d;
  }

  ShiftSession copyWith({
    ShiftStage? stage,
    WorkContext? context,
    BadgeSpecimen? badge,
    PhysicalBadge? physicalBadge,
    DateTime? startedAt,
    DateTime? endedAt,
    MeasurementResult? result,
    String? captureId,
    String? sessionId,
    String? assignmentId,
  }) {
    // Assigning one kind of badge clears the other. A session carrying both
    // would leave "which badge was exposed?" to whichever field a screen
    // happened to read.
    return ShiftSession(
      stage: stage ?? this.stage,
      context: context ?? this.context,
      badge: physicalBadge != null ? null : (badge ?? this.badge),
      physicalBadge: badge != null
          ? null
          : (physicalBadge ?? this.physicalBadge),
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      result: result ?? this.result,
      captureId: captureId ?? this.captureId,
      sessionId: sessionId ?? this.sessionId,
      assignmentId: assignmentId ?? this.assignmentId,
    );
  }
}

/// Thrown when something tries to rewrite an exposure record's provenance.
///
/// Not a user-facing error: no screen offers a locked action, so this surfacing
/// at runtime means a navigation or state bug let one through.
final class WorkflowLockedError extends StateError {
  WorkflowLockedError(super.message);
}
