import 'package:flutter/foundation.dart';

import 'permit_context.dart';
import 'work_taxonomy.dart';
import 'worker_identity.dart';

/// Where, under what authority, and for whom a monitored period takes place.
///
/// ## This is measurement provenance, not form state
///
/// Once monitoring starts, every field here describes an exposure record. It is
/// the answer to "whose reading is this, taken where, during what work". That
/// makes it subject to the same rules as the measurement itself: it is frozen
/// when the period starts, it is never silently rewritten, and a stored copy
/// that cannot be read back faithfully is refused rather than patched.
///
/// ## Every field is required
///
/// There are no nullable required fields to forget to check. A partially filled
/// context is a [WorkContextDraft]; only a complete one can become a
/// [WorkContext], so "monitoring started without a site" is not a bug that can
/// be written — it is a state that cannot be constructed.
///
/// ## What DoseBand does not claim
///
/// Holding a [PtwReference] and a [JsaReference] means those processes were
/// *referenced*. It does not mean they were checked, approved, or are open, and
/// nothing in this model may be rendered as though it did. See
/// `docs/product/work-context.md`.
@immutable
final class WorkContext {
  const WorkContext({
    required this.worker,
    required this.site,
    required this.department,
    required this.workArea,
    required this.shift,
    required this.job,
    required this.permit,
    required this.jsa,
    required this.toolboxTalk,
  });

  final WorkerIdentity worker;
  final SiteRef site;
  final Department department;
  final WorkArea workArea;
  final WorkShift shift;
  final JobContext job;
  final PtwReference permit;
  final JsaReference jsa;
  final ToolboxTalkAcknowledgement toolboxTalk;

  /// True when nothing in this context has been confirmed by an external
  /// system — which is every context today, since no integration is connected.
  /// Drives the honest labelling on screen.
  bool get isEntirelyUnverified =>
      !permit.isVerified &&
      !jsa.isVerified &&
      (worker.gatePass?.isUnverified ?? true);

  @override
  bool operator ==(Object other) =>
      other is WorkContext &&
      other.worker == worker &&
      other.site == site &&
      other.department == department &&
      other.workArea == workArea &&
      other.shift == shift &&
      other.job == job &&
      other.permit == permit &&
      other.jsa == jsa &&
      other.toolboxTalk == toolboxTalk;

  @override
  int get hashCode => Object.hash(
    worker,
    site,
    department,
    workArea,
    shift,
    job,
    permit,
    jsa,
    toolboxTalk,
  );
}

/// A work context being filled in.
///
/// Every field is nullable because the worker is part-way through. This type
/// exists so that "incomplete" lives in one place with a name, instead of being
/// scattered across screens as null checks on a half-built [WorkContext].
///
/// [build] is the only bridge between the two, and it returns null unless every
/// requirement is met.
@immutable
final class WorkContextDraft {
  const WorkContextDraft({
    this.worker,
    this.site,
    this.department,
    this.workArea,
    this.shift,
    this.job,
    this.permit,
    this.jsa,
    this.toolboxTalk,
  });

  final WorkerIdentity? worker;
  final SiteRef? site;
  final Department? department;
  final WorkArea? workArea;
  final WorkShift? shift;
  final JobContext? job;
  final PtwReference? permit;
  final JsaReference? jsa;
  final ToolboxTalkAcknowledgement? toolboxTalk;

  static const WorkContextDraft empty = WorkContextDraft();

  /// Promotes a complete draft to a committed context, or returns null.
  ///
  /// Null is not an error to work around: it means the requirements in
  /// `WorkContextValidator` are not met, and the caller should be showing the
  /// worker what is missing rather than constructing something anyway.
  WorkContext? build() {
    final w = worker;
    final s = site;
    final d = department;
    final a = workArea;
    final sh = shift;
    final j = job;
    final p = permit;
    final js = jsa;
    final t = toolboxTalk;
    if (w == null ||
        s == null ||
        d == null ||
        a == null ||
        sh == null ||
        j == null ||
        p == null ||
        js == null ||
        t == null) {
      return null;
    }
    if (!w.contractorCompanyIsCoherent) return null;
    // Blank is not filled in. Without this, `build()` would accept a permit
    // reference of "   " that `WorkContextValidator` reports as missing, and
    // the screen gating on one while the checklist reports the other would
    // disagree with itself in front of the worker.
    if (j.title.trim().isEmpty) return null;
    if (p.reference.value.trim().isEmpty) return null;
    if (js.reference.value.trim().isEmpty) return null;
    // An area belonging to a different site would attach this period to a
    // place the worker did not select.
    if (a.siteId != s.id) return null;

    return WorkContext(
      worker: w,
      site: s,
      department: d,
      workArea: a,
      shift: sh,
      job: j,
      permit: p,
      jsa: js,
      toolboxTalk: t,
    );
  }

  /// Re-opens a committed context for editing. Used only before monitoring
  /// starts; see `ShiftSessionController.setContext`.
  static WorkContextDraft from(WorkContext c) => WorkContextDraft(
    worker: c.worker,
    site: c.site,
    department: c.department,
    workArea: c.workArea,
    shift: c.shift,
    job: c.job,
    permit: c.permit,
    jsa: c.jsa,
    toolboxTalk: c.toolboxTalk,
  );

  /// `clearWorkArea` exists because `copyWith` cannot otherwise express
  /// "remove this": passing null means "leave unchanged". Changing site must be
  /// able to drop an area that belonged to the old one.
  WorkContextDraft copyWith({
    WorkerIdentity? worker,
    SiteRef? site,
    Department? department,
    WorkArea? workArea,
    WorkShift? shift,
    JobContext? job,
    PtwReference? permit,
    JsaReference? jsa,
    ToolboxTalkAcknowledgement? toolboxTalk,
    bool clearWorkArea = false,
    bool clearToolboxTalk = false,
  }) => WorkContextDraft(
    worker: worker ?? this.worker,
    site: site ?? this.site,
    department: department ?? this.department,
    workArea: clearWorkArea ? null : (workArea ?? this.workArea),
    shift: shift ?? this.shift,
    job: job ?? this.job,
    permit: permit ?? this.permit,
    jsa: jsa ?? this.jsa,
    toolboxTalk: clearToolboxTalk ? null : (toolboxTalk ?? this.toolboxTalk),
  );
}
