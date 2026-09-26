import 'package:flutter/foundation.dart';

import 'enterprise_value.dart';
import 'work_taxonomy.dart';

/// A reference to a Permit to Work.
///
/// ## What this is not
///
/// The permit is MRPL's. DoseBand does not issue, approve, close, extend,
/// supersede or validate one, and it cannot tell whether the number recorded
/// here corresponds to a permit that exists, is open, or covers this work.
///
/// What it records is: *the worker said this monitored period is attached to
/// this permit*. That is a useful thing to carry alongside an exposure record
/// and a worthless thing to mistake for an authorisation.
///
/// The [reference] is an [EnterpriseValue], so the difference between a typed
/// number and one confirmed by a permit system is preserved in the data rather
/// than asserted by a label.
@immutable
final class PtwReference {
  const PtwReference({required this.reference, this.type});

  final EnterpriseValue<String> reference;

  /// The category the worker says the permit falls under. Optional: a worker
  /// who knows the number but not the category should not be blocked, and a
  /// guessed category is worse than an absent one.
  final PtwType? type;

  /// True only when a permit system confirmed the reference. Always false
  /// today — no permit integration exists.
  bool get isVerified => reference.isVerified;

  @override
  bool operator ==(Object other) =>
      other is PtwReference &&
      other.reference == reference &&
      other.type == type;

  @override
  int get hashCode => Object.hash(reference, type);
}

/// A reference to a Job Safety Analysis.
///
/// Same boundary as [PtwReference]. DoseBand does not create, approve, sign,
/// close or check a JSA. It records that one was referenced.
@immutable
final class JsaReference {
  const JsaReference({required this.reference, this.note});

  final EnterpriseValue<String> reference;

  /// Free-text the worker added, e.g. which activity the JSA covers. Never
  /// interpreted.
  final String? note;

  bool get isVerified => reference.isVerified;

  @override
  bool operator ==(Object other) =>
      other is JsaReference &&
      other.reference == reference &&
      other.note == note;

  @override
  int get hashCode => Object.hash(reference, note);
}

/// A worker's record that the toolbox talk for this work context happened.
///
/// ## Read this before changing the wording anywhere near it
///
/// A toolbox talk is a conversation between people. DoseBand is not in the
/// room, cannot observe it, and must never behave as though a tap on a phone
/// is evidence that it took place, that it covered anything in particular, or
/// that the right people attended.
///
/// What is stored is precisely: *the worker acknowledged, at this time, that
/// the toolbox-talk status has been recorded for this work context.* The
/// acknowledgement is the worker's statement about the process. It is not a
/// certification, not a signature, and not a substitute for the process.
///
/// Consequently there is deliberately **no** field here for a supervisor
/// signature, an attendee list, or a "verified by" — inventing any of those
/// would manufacture safety evidence, which is a considerably worse failure
/// than manufacturing a measurement.
@immutable
final class ToolboxTalkAcknowledgement {
  const ToolboxTalkAcknowledgement({
    required this.acknowledgedAt,
    required this.source,
    this.reference,
  });

  /// When the worker acknowledged. Absence of this object means no
  /// acknowledgement was recorded; there is no "acknowledged: false" state,
  /// because a recorded negative would imply DoseBand had asked and been told
  /// no, which is not what an empty field means.
  final DateTime acknowledgedAt;

  /// How the acknowledgement was captured. Today always manual entry.
  final EnterpriseDataSource source;

  /// An optional reference the worker supplied — a talk number, a supervisor's
  /// name as free text. Carried verbatim, never treated as corroboration.
  final String? reference;

  @override
  bool operator ==(Object other) =>
      other is ToolboxTalkAcknowledgement &&
      other.acknowledgedAt == acknowledgedAt &&
      other.source == source &&
      other.reference == reference;

  @override
  int get hashCode => Object.hash(acknowledgedAt, source, reference);
}

/// The job the monitored period is attached to.
@immutable
final class JobContext {
  const JobContext({
    required this.title,
    this.workOrder,
    this.supervisor,
    this.description,
  });

  /// What the worker is doing, e.g. "Routine field round".
  final String title;

  /// An optional work-order or job reference. DoseBand does not manage work
  /// orders; this is a string the worker can quote later.
  final String? workOrder;

  /// The supervisor's name as free text. Not an approver, not a signatory, and
  /// not looked up against any directory.
  final String? supervisor;

  final String? description;

  @override
  bool operator ==(Object other) =>
      other is JobContext &&
      other.title == title &&
      other.workOrder == workOrder &&
      other.supervisor == supervisor &&
      other.description == description;

  @override
  int get hashCode => Object.hash(title, workOrder, supervisor, description);
}
