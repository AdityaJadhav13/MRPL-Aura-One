import 'package:flutter/foundation.dart';

import '../../auth/domain/auth_models.dart';

/// Operations that leave an audit event (§94).
enum AuditAction {
  signedIn('Signed in'),
  signedOut('Signed out'),
  workspaceSwitched('Switched workspace'),
  dosebandClaimed('DoseBand claimed'),
  preUseChecked('Pre-use check recorded'),
  assignmentCancelled('Assignment cancelled'),
  monitoringStarted('Monitoring started'),
  monitoringEnded('Monitoring ended'),
  monitoringInterrupted('Monitoring interrupted'),
  dosebandReported('DoseBand reported damaged or lost'),
  measurementRecorded('Measurement recorded'),
  measurementSuperseded('Measurement superseded'),
  reviewStateChanged('Review state changed'),
  dispositionRecorded('Disposition recorded'),
  inventoryChanged('Inventory changed'),
  accountChanged('Account changed'),
  presentationDataReset('Presentation data reset');

  const AuditAction(this.label);

  final String label;
}

/// One append-only audit event.
///
/// **Local audit log.** Held in the on-device operations store; there is no
/// enterprise audit backend, and the store offers no operation that edits or
/// removes an event. That is a property of this code, not a tamper-proof
/// guarantee — anyone with the device's file system can edit the file.
@immutable
final class AuditEvent {
  const AuditEvent({
    required this.eventId,
    required this.at,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.subjectType,
    required this.subjectId,
    this.detail,
  });

  final String eventId;
  final DateTime at;
  final String actorId;
  final AppRole actorRole;
  final AuditAction action;

  /// "doseband", "session", "measurement", "review", "account", "lot".
  final String subjectType;
  final String subjectId;
  final String? detail;
}
