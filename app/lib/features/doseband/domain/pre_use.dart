import 'package:flutter/foundation.dart';

import '../../capture/domain/capture_outcome.dart';
import '../../operations/application/local_doseband_registry.dart';
import '../../operations/domain/assignment.dart';

/// What the optical half of the pre-use check found (PRODUCT BUILD v1 §10).
@immutable
sealed class OpticalResult {
  const OpticalResult();

  OpticalCheckStatus get status;
}

/// The reader found the band: target, fiducials, geometry and the reference
/// and sensor regions, in a photograph good enough to sample them.
final class OpticalReadable extends OpticalResult {
  const OpticalReadable({this.correctionCaveat});

  /// Set when the colour correction itself did not validate. That is a
  /// measurement-time question — it is checked again, and decided, at the
  /// final scan — so it does not stop a band from being used.
  final String? correctionCaveat;

  @override
  OpticalCheckStatus get status => OpticalCheckStatus.readable;
}

/// The photograph could not be read. Says nothing about the band.
final class OpticalNotReadable extends OpticalResult {
  const OpticalNotReadable({required this.reason, required this.action});

  final String reason;

  /// The one thing to change before trying again.
  final String action;

  @override
  OpticalCheckStatus get status => OpticalCheckStatus.notReadable;
}

/// No camera could be used on this device, or permission was refused.
final class OpticalCameraUnavailable extends OpticalResult {
  const OpticalCameraUnavailable(this.reason);

  final String reason;

  @override
  OpticalCheckStatus get status => OpticalCheckStatus.notPerformed;
}

/// The pre-use verdict shown to the worker.
@immutable
final class PreUseVerdict {
  const PreUseVerdict({
    required this.outcome,
    required this.title,
    required this.message,
    this.replaceReason,
  });

  final PreUseOutcome outcome;
  final String title;
  final String message;
  final ReplaceReason? replaceReason;
}

abstract final class PreUseAssessment {
  /// Colour-correction checks. They decide whether a *measurement* can be
  /// trusted, at the final scan; they do not decide whether a band is
  /// usable, and gating on them here would turn a lighting problem (or the
  /// known REF-BLACK behaviour under JPEG compression) into "replace a good
  /// DoseBand".
  static const Set<String> correctionChecks = {
    'reference_fit',
    'withheld_references',
  };

  /// Reads a capture as a readability result.
  static OpticalResult fromCapture(CaptureOutcome outcome) {
    final blocking = outcome.quality.checks
        .where((c) => c.failedAndBlocks && !correctionChecks.contains(c.id))
        .toList();
    if (outcome is CaptureObserved && blocking.isEmpty) {
      final correction = outcome.quality.checks
          .where((c) => c.failedAndBlocks && correctionChecks.contains(c.id))
          .firstOrNull;
      return OpticalReadable(
        correctionCaveat: correction == null
            ? null
            : 'The colour references did not validate in this light. The '
                  'final scan checks them again.',
      );
    }
    final first = blocking.firstOrNull ?? outcome.quality.primaryFailure;
    return OpticalNotReadable(
      reason: first?.reason.isNotEmpty ?? false
          ? first!.reason
          : 'The DoseBand could not be found in the photo.',
      action: first?.workerAction.isNotEmpty ?? false
          ? first!.workerAction
          : 'Show the whole DoseBand, flat, in even light, and hold steady.',
    );
  }

  /// Combines the registry's facts with the optical result.
  ///
  /// The order is the point: a band the registry rules out is "replace"
  /// whatever the photo shows; a band the registry accepts is only ever
  /// "cannot verify" because of the photo — never "replace" (§11, §117).
  static PreUseVerdict verdict(Eligibility registry, OpticalResult? optical) {
    switch (registry) {
      case NotEligible(:final reason):
        return PreUseVerdict(
          outcome: PreUseOutcome.replace,
          title: 'Replace DoseBand',
          message: '${reason.message} Take a different DoseBand and scan it.',
          replaceReason: reason,
        );
      case WorkerHasActiveBand(:final assignment):
        return PreUseVerdict(
          outcome: PreUseOutcome.cannotVerify,
          title: 'You already have a DoseBand',
          message:
              'DoseBand ${assignment.dosebandId} is assigned to you and its '
              'monitoring period is not finished. Finish it before taking '
              'another.',
        );
      case Eligible():
        break;
    }
    return switch (optical) {
      null => const PreUseVerdict(
        outcome: PreUseOutcome.cannotVerify,
        title: 'Photo needed',
        message: 'Photograph the DoseBand to check it can be read.',
      ),
      OpticalReadable() => const PreUseVerdict(
        outcome: PreUseOutcome.readyToUse,
        title: 'DoseBand ready to use',
        message:
            'Known, unused, in date and readable. Its chemistry is not '
            'assessed — no validated method for that exists yet.',
      ),
      OpticalNotReadable(:final action) => PreUseVerdict(
        outcome: PreUseOutcome.cannotVerify,
        title: 'Cannot verify — try again',
        message:
            'The photo could not be read. The DoseBand may be fine. $action',
      ),
      OpticalCameraUnavailable(:final reason) => PreUseVerdict(
        outcome: PreUseOutcome.cannotVerify,
        title: 'Cannot verify — camera unavailable',
        message:
            'The DoseBand could not be photographed ($reason). It has not '
            'been assigned.',
      ),
    };
  }
}
