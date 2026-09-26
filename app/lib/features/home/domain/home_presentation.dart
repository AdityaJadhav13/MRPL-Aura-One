import 'package:flutter/foundation.dart';

import '../../workflow/domain/work_context_validator.dart';
import '../../workflow/domain/workflow_state.dart';

/// Where the worker is in the journey, as Home needs to talk about it.
///
/// These are not new workflow stages. They are a **projection** of the real
/// `ShiftStage`, plus the two things the stage alone cannot express: whether
/// the work context is complete enough to proceed, and whether the monitored
/// period's clock can be trusted.
///
/// One state-aware Home renders all of them. The architecture stays put — hero,
/// identity, shift, context, monitoring, action, strip, quick actions — and
/// only the content and the available action change. A screen whose layout
/// reorganises itself between states teaches the worker nothing, because there
/// is no stable place to look.
enum HomeStage {
  /// HOME-01 — nothing recorded yet.
  noContext,

  /// HOME-02 — a context exists but does not satisfy the validator.
  contextIncomplete,

  /// HOME-03 — context complete, no badge.
  awaitingBadge,

  /// HOME-04/05 — a badge is assigned, pre-work not yet confirmed.
  badgeAssigned,

  /// HOME-06 — every requirement met.
  readyForDosimetry,

  /// HOME-07 — the badge is being worn.
  monitoringActive,

  /// HOME-08 — the period ended; the badge still needs its final scan.
  scanRequired,

  /// HOME-09 — a reading exists.
  resultAvailable,

  /// HOME-10 — something needs a person to look at it. Today this means the
  /// exposure window cannot be trusted, which is the one condition Home can
  /// detect on its own.
  requiresAttention,
}

/// What Home should offer next.
///
/// Every action here is one the workflow genuinely permits from the current
/// stage. Home never offers a shortcut that skips a step — the controller
/// would refuse it, and a button that throws is worse than no button.
@immutable
final class HomeAction {
  const HomeAction({required this.label, required this.route, this.icon});

  final String label;
  final String route;
  final String? icon;
}

/// Everything Home needs to render, derived once.
///
/// Built in one place so the card, the button and the strip cannot disagree
/// about what is happening — three widgets each deciding for themselves is how
/// a screen ends up saying "not started" above a button that says "end
/// monitoring".
@immutable
final class HomePresentation {
  const HomePresentation({
    required this.stage,
    required this.actionLabel,
    required this.actionRoute,
    required this.statusStrip,
    required this.monitoringTitle,
    required this.monitoringState,
  });

  final HomeStage stage;

  /// The single large contextual action.
  final String actionLabel;
  final String actionRoute;

  /// The narrow line under the action. Describes **DoseBand's workflow state
  /// only** — never the atmosphere, the permit or the worker's safety.
  final String statusStrip;

  /// Heading on the monitoring card.
  final String monitoringTitle;

  /// The card's one-line state, e.g. "Not started".
  final String monitoringState;

  bool get isMonitoring => stage == HomeStage.monitoringActive;

  /// Derives the projection from real application state.
  ///
  /// [readiness] comes from `WorkContextValidator`, so Home cannot invent its
  /// own idea of "ready" — it asks the same policy the pre-work check uses.
  factory HomePresentation.from({
    required ShiftSession session,
    required WorkContextReadiness readiness,
    required DateTime now,
  }) {
    // An untrusted window outranks everything else. A worker whose clock moved
    // needs to know that before they are told how long they have been
    // monitoring, because the answer to that question is "we cannot say".
    final windowUntrusted =
        session.startedAt != null && session.coverageAt(now) == null;

    if (windowUntrusted && session.stage != ShiftStage.complete) {
      return const HomePresentation(
        stage: HomeStage.requiresAttention,
        actionLabel: 'End monitoring and read badge',
        actionRoute: '/end',
        statusStrip:
            'The monitored period cannot be timed. End the period and read '
            'the badge — the exposure window will be reported as unknown.',
        monitoringTitle: 'DoseBand monitoring',
        monitoringState: 'Duration not trustworthy',
      );
    }

    return switch (session.stage) {
      ShiftStage.noShift => const HomePresentation(
        stage: HomeStage.noContext,
        actionLabel: 'Start work context',
        actionRoute: '/work-context',
        statusStrip:
            'Record your work context before a DoseBand can be assigned.',
        monitoringTitle: 'DoseBand monitoring',
        monitoringState: 'Not started',
      ),

      ShiftStage.contextSet when !readiness.contextIsComplete =>
        const HomePresentation(
          stage: HomeStage.contextIncomplete,
          actionLabel: 'Complete work context',
          actionRoute: '/work-context',
          statusStrip:
              'Work context is incomplete. Finish it before assigning a '
              'DoseBand.',
          monitoringTitle: 'DoseBand monitoring',
          monitoringState: 'Not started',
        ),

      ShiftStage.contextSet => const HomePresentation(
        stage: HomeStage.awaitingBadge,
        actionLabel: 'Assign DoseBand',
        actionRoute: '/assign',
        statusStrip:
            'Work context recorded. Assign the DoseBand you have been issued.',
        monitoringTitle: 'DoseBand monitoring',
        monitoringState: 'Badge not assigned',
      ),

      ShiftStage.badgeAssigned => const HomePresentation(
        stage: HomeStage.badgeAssigned,
        actionLabel: 'Pre-work check',
        actionRoute: '/prework',
        statusStrip:
            'DoseBand assigned. Complete the pre-work dosimetry check.',
        monitoringTitle: 'DoseBand monitoring',
        monitoringState: 'Ready for pre-work check',
      ),

      ShiftStage.readyForDosimetry => const HomePresentation(
        stage: HomeStage.readyForDosimetry,
        actionLabel: 'Start monitoring',
        actionRoute: '/prework',
        statusStrip:
            'Ready for dosimetry. This confirms DoseBand has what it needs — '
            'it does not authorise work.',
        monitoringTitle: 'DoseBand monitoring',
        monitoringState: 'Ready for dosimetry',
      ),

      ShiftStage.monitoring => const HomePresentation(
        stage: HomeStage.monitoringActive,
        actionLabel: 'End monitoring',
        actionRoute: '/end',
        statusStrip:
            'Monitoring active. The DoseBand is recording cumulative '
            'exposure and cannot warn you about anything.',
        monitoringTitle: 'Monitoring active',
        monitoringState: 'Active',
      ),

      ShiftStage.awaitingScan => const HomePresentation(
        stage: HomeStage.scanRequired,
        actionLabel: 'Scan DoseBand',
        actionRoute: '/read',
        statusStrip: 'Monitoring ended. Scan the badge to produce a reading.',
        monitoringTitle: 'DoseBand monitoring',
        monitoringState: 'Awaiting badge scan',
      ),

      ShiftStage.complete => const HomePresentation(
        stage: HomeStage.resultAvailable,
        actionLabel: 'Start new work context',
        actionRoute: '/work-context',
        statusStrip:
            'Reading complete. Start a new work context when issued '
            'your next DoseBand.',
        monitoringTitle: 'DoseBand monitoring',
        monitoringState: 'Reading complete',
      ),
    };
  }
}
