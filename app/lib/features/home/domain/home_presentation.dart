import 'package:flutter/foundation.dart';

import '../../workflow/domain/workflow_state.dart';

/// Worker Home's states (PRODUCT BUILD v1 §15).
///
/// * A — [noDoseBand]
/// * B — validating: the DoseBand check screen itself, which shows its
///   progress step by step; Home is never shown mid-check.
/// * C — [monitoringActive]
/// * D — [readyForFinalRead]
/// * E — [completed]
///
/// [doseBandAssigned] exists only for the development simulation, which
/// still walks the older assign → pre-work → start steps. [requiresAttention]
/// is the untrusted-clock case, which outranks everything.
enum HomeStage {
  noDoseBand,
  doseBandAssigned,
  monitoringActive,
  readyForFinalRead,
  completed,
  requiresAttention,
}

@immutable
final class HomePresentation {
  const HomePresentation({
    required this.stage,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionRoute,
    this.secondaryLabel,
    this.secondaryRoute,
  });

  final HomeStage stage;

  /// What is true now, in a few words.
  final String title;

  /// The next instruction.
  final String message;

  final String actionLabel;
  final String actionRoute;
  final String? secondaryLabel;
  final String? secondaryRoute;

  bool get isMonitoring => stage == HomeStage.monitoringActive;

  /// Pure: the same session and instant always give the same Home.
  factory HomePresentation.from({
    required ShiftSession session,
    required DateTime now,
  }) {
    // An untrusted window outranks everything else: the worker needs to know
    // the duration cannot be stated before being told what it is.
    final windowUntrusted =
        session.startedAt != null && session.coverageAt(now) == null;
    if (windowUntrusted && session.stage != ShiftStage.complete) {
      return const HomePresentation(
        stage: HomeStage.requiresAttention,
        title: 'Monitoring time cannot be trusted',
        message:
            'The phone’s clock moved while monitoring was running, so the '
            'monitoring window cannot be stated. End monitoring and scan the '
            'DoseBand — the result will say the window is unknown.',
        actionLabel: 'End monitoring and scan',
        actionRoute: '/end',
      );
    }

    final registered = session.sessionId != null;
    final completedToday =
        session.stage == ShiftStage.complete &&
        _sameDay(session.endedAt ?? now, now);

    return switch (session.stage) {
      ShiftStage.noShift || ShiftStage.contextSet => HomePresentation(
        stage: HomeStage.noDoseBand,
        title: 'No DoseBand assigned',
        message: session.stage == ShiftStage.contextSet
            ? 'Today’s work is recorded. Take an unused DoseBand and scan it '
                  'to start monitoring.'
            : 'Take an unused DoseBand and scan it. You will confirm today’s '
                  'work before it is assigned.',
        actionLabel: 'Scan new DoseBand',
        actionRoute: '/doseband/scan',
      ),
      ShiftStage.badgeAssigned ||
      ShiftStage.readyForDosimetry => const HomePresentation(
        stage: HomeStage.doseBandAssigned,
        title: 'DoseBand assigned',
        message: 'Complete the pre-work check to start monitoring.',
        actionLabel: 'Pre-work check',
        actionRoute: '/prework',
      ),
      ShiftStage.monitoring => const HomePresentation(
        stage: HomeStage.monitoringActive,
        title: 'Monitoring active',
        message:
            'Wear the DoseBand as your site instructs. It records cumulative '
            'exposure for later reading; it cannot warn you. Your H₂S alarm '
            'does that.',
        actionLabel: 'Final DoseBand read',
        actionRoute: '/end',
      ),
      ShiftStage.awaitingScan => HomePresentation(
        stage: HomeStage.readyForFinalRead,
        title: 'Ready for final scan',
        message: 'Monitoring has ended. Scan the DoseBand you wore.',
        actionLabel: 'Scan assigned DoseBand',
        actionRoute: registered ? '/doseband/scan?purpose=final' : '/read',
      ),
      ShiftStage.complete when completedToday => HomePresentation(
        stage: HomeStage.completed,
        title: 'Today’s monitoring complete',
        message:
            'Remove the DoseBand and dispose of it following your site '
            'procedure. It is not reused.',
        actionLabel: 'View today’s record',
        actionRoute: session.captureId == null
            ? '/history'
            : '/history/record/${session.captureId}',
        secondaryLabel: 'Scan new DoseBand',
        secondaryRoute: '/doseband/scan',
      ),
      ShiftStage.complete => const HomePresentation(
        stage: HomeStage.noDoseBand,
        title: 'No DoseBand assigned',
        message:
            'Your last monitoring period is complete. Take an unused DoseBand '
            'and scan it to start today’s.',
        actionLabel: 'Scan new DoseBand',
        actionRoute: '/doseband/scan',
      ),
    };
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
