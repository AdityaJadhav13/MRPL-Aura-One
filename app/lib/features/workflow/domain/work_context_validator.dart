import 'package:flutter/foundation.dart';

import 'badge_specimen.dart';
import 'physical_badge.dart';
import 'work_context.dart';

/// One thing DoseBand needs before a monitored period can begin.
///
/// The order is the order the pre-work checklist renders in, which is the order
/// the work-context form collects them in, so a worker reading a failed check
/// knows where to go back to.
enum WorkContextRequirement {
  workerIdentity('Worker identified'),
  contractorCompany('Contractor company recorded'),
  site('Site selected'),
  department('Department selected'),
  workArea('Work area selected'),
  shift('Shift selected'),
  job('Job or activity recorded'),
  permitReference('PTW reference recorded'),
  jsaReference('JSA reference recorded'),
  toolboxTalk('Toolbox talk acknowledged'),
  badgeAssigned('DoseBand assigned'),
  badgeUsable('DoseBand usable');

  const WorkContextRequirement(this.label);

  /// Shown on the checklist. Deliberately factual and free of any word that
  /// could read as an authorisation — see the wording test in
  /// `test/workflow/safety_language_test.dart`.
  final String label;
}

/// A non-blocking observation about an otherwise complete context.
enum WorkContextWarning {
  /// Nothing in the context has been confirmed by an external system. True of
  /// every context today. Surfaced so the worker is never left to assume the
  /// references were checked.
  nothingVerifiedExternally(
    'No reference in this context has been checked against an MRPL system.',
  ),

  /// The area belongs to a different site than the one selected.
  workAreaSiteMismatch(
    'The selected work area does not belong to the selected site.',
  );

  const WorkContextWarning(this.message);

  final String message;
}

/// The result of assessing a draft.
@immutable
final class WorkContextReadiness {
  const WorkContextReadiness({
    required this.missingRequirements,
    required this.warnings,
  });

  /// Empty when every requirement is met.
  final List<WorkContextRequirement> missingRequirements;

  final List<WorkContextWarning> warnings;

  /// Whether DoseBand has what it needs to begin monitoring.
  ///
  /// **This is not a statement about safety.** It means only that the minimum
  /// information required to attribute an exposure measurement is present. It
  /// says nothing about the atmosphere, the permit's validity, or whether the
  /// job should proceed. The UI renders this as "Ready for dosimetry" and never
  /// as anything resembling "safe to work".
  bool get isReady => missingRequirements.isEmpty;

  bool isMissing(WorkContextRequirement r) => missingRequirements.contains(r);

  /// Whether the work context alone is complete, ignoring the badge.
  ///
  /// The badge is assigned in a later step, so the work-context form has to be
  /// able to let the worker move on before one exists. This is the same policy
  /// as [isReady] with the badge requirements removed — not a second, parallel
  /// rule that could drift away from it.
  bool get contextIsComplete => missingRequirements
      .where(
        (r) =>
            r != WorkContextRequirement.badgeAssigned &&
            r != WorkContextRequirement.badgeUsable,
      )
      .isEmpty;
}

/// The single place that decides whether a monitored period may begin.
///
/// Centralised so that the rule is stated once and tested once. Screens ask
/// this; they do not re-implement it with their own null checks, because a
/// requirement enforced in three widgets is a requirement that will be enforced
/// in two of them after the next redesign.
abstract final class WorkContextValidator {
  /// Assesses [draft] together with the badge assignment.
  ///
  /// The badge is passed separately because it is assigned in its own workflow
  /// step and lives on the session, not on the context — but it is a
  /// requirement for starting, so readiness has to account for it.
  static WorkContextReadiness assess(
    WorkContextDraft draft, {
    required BadgeIdentity? badge,
  }) {
    final missing = <WorkContextRequirement>[];
    final warnings = <WorkContextWarning>[];

    final worker = draft.worker;
    if (worker == null) {
      missing.add(WorkContextRequirement.workerIdentity);
      // Without a worker there is nothing to say about the contractor company,
      // and reporting both would be two failures for one cause.
    } else if (!worker.contractorCompanyIsCoherent) {
      missing.add(WorkContextRequirement.contractorCompany);
    }

    if (draft.site == null) missing.add(WorkContextRequirement.site);
    if (draft.department == null) {
      missing.add(WorkContextRequirement.department);
    }
    if (draft.workArea == null) missing.add(WorkContextRequirement.workArea);
    if (draft.shift == null) missing.add(WorkContextRequirement.shift);
    if (draft.job == null || draft.job!.title.trim().isEmpty) {
      missing.add(WorkContextRequirement.job);
    }
    if (draft.permit == null || draft.permit!.reference.value.trim().isEmpty) {
      missing.add(WorkContextRequirement.permitReference);
    }
    if (draft.jsa == null || draft.jsa!.reference.value.trim().isEmpty) {
      missing.add(WorkContextRequirement.jsaReference);
    }
    if (draft.toolboxTalk == null) {
      missing.add(WorkContextRequirement.toolboxTalk);
    }

    switch (badge) {
      case null:
        missing.add(WorkContextRequirement.badgeAssigned);
      case BadgeSpecimen(:final validity) when !validity.eligible:
        // "Usable by the current demo rules" — the specimen's own
        // verification checks. Not a claim that the badge is fit for a real
        // measurement.
        missing.add(WorkContextRequirement.badgeUsable);
      case PhysicalBadge():
        // Assigned, and deliberately not failed on checks that cannot be
        // made: with no inventory, batch registry or QR, a hand-typed badge's
        // batch, calibration, prior use and expiry are unknowable. Blocking
        // on them would mean no real badge could ever be monitored. They are
        // shown as NOT VERIFIED on the pre-work screen instead, and the scan
        // refuses at calibration, where the gap actually bites.
        break;
      default:
        break;
    }

    final site = draft.site;
    final area = draft.workArea;
    if (site != null && area != null && area.siteId != site.id) {
      warnings.add(WorkContextWarning.workAreaSiteMismatch);
      if (!missing.contains(WorkContextRequirement.workArea)) {
        missing.add(WorkContextRequirement.workArea);
      }
    }

    final unverified =
        (draft.permit?.isVerified ?? false) == false &&
        (draft.jsa?.isVerified ?? false) == false;
    if (unverified) warnings.add(WorkContextWarning.nothingVerifiedExternally);

    return WorkContextReadiness(
      missingRequirements: List.unmodifiable(missing),
      warnings: List.unmodifiable(warnings),
    );
  }
}
