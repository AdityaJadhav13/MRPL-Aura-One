import 'package:flutter/foundation.dart';

import '../components/corporate.dart';

/// Typed demonstration records for the UI surfaces.
///
/// ## Why this exists in one file
///
/// The alternative is fifty widgets each holding a hard-coded name and number.
/// That makes demo data impossible to find, impossible to remove, and — the
/// real danger — impossible to distinguish from data that arrived from
/// somewhere. Everything fake in the corporate surfaces comes from here, so
/// "what is not real?" has a one-word answer.
///
/// ## Three kinds of data, kept apart
///
/// * **Real workflow data** — `ShiftSession`, the work context, the local
///   store. Never defined here.
/// * **Simulation data** — `SimulationCatalog`, badge specimens with declared
///   optical outcomes that play through the real `MeasurementResult` state
///   machine. Scientific, and deliberately separate.
/// * **UI demo data** — this file. Rows that exist so a list has something in
///   it during review. They describe **no real worker and no real
///   measurement**, and they never reach the measurement engine.
///
/// Mixing the second and third would be the worst outcome: a fabricated ppm·h
/// dressed as a simulation result. Nothing here carries a dose value at all —
/// see [DemoExposureRecord].
abstract final class UiDemoCatalog {
  /// Every record in this catalog is this origin. A helper, so screens do not
  /// hand-write the enum and accidentally mark demo rows as live.
  static const DataOrigin origin = DataOrigin.uiDemo;

  static final DateTime _today = DateTime(2026, 9, 25);

  static DateTime _at(int dayOffset, int hour, [int minute = 0]) =>
      DateTime(_today.year, _today.month, _today.day - dayOffset, hour, minute);

  // --------------------------------------------------------------- workers

  static List<DemoWorker> workers() => [
    DemoWorker(
      workerId: 'CT-45832',
      name: 'Aditya Jadhav',
      isContractor: true,
      contractorCompany: 'XYZ Engineering',
      department: 'Operations',
      workArea: 'Sulphur Recovery Unit — Demo area',
      shift: 'Shift A',
      monitoringState: DemoMonitoringState.active,
      startedAt: _at(0, 6, 10),
    ),
    DemoWorker(
      workerId: 'EMP-20871',
      name: 'Meera Nair',
      isContractor: false,
      department: 'Operations',
      workArea: 'PFCC — Demo area',
      shift: 'Shift A',
      monitoringState: DemoMonitoringState.active,
      startedAt: _at(0, 6, 5),
    ),
    DemoWorker(
      workerId: 'EMP-20944',
      name: 'Rahul Shetty',
      isContractor: false,
      department: 'Maintenance',
      workArea: 'Hydrocracker — Demo area',
      shift: 'Shift A',
      monitoringState: DemoMonitoringState.awaitingScan,
      startedAt: _at(0, 5, 50),
      endedAt: _at(0, 13, 55),
    ),
    DemoWorker(
      workerId: 'CT-45610',
      name: 'Imran Qureshi',
      isContractor: true,
      contractorCompany: 'Coastal Mechanical Services',
      department: 'Maintenance',
      workArea: 'Delayed Coker — Demo area',
      shift: 'Shift B',
      monitoringState: DemoMonitoringState.complete,
      startedAt: _at(1, 14, 0),
      endedAt: _at(1, 21, 58),
    ),
    DemoWorker(
      workerId: 'EMP-21003',
      name: 'Sunita Rao',
      isContractor: false,
      department: 'Health, Safety & Environment',
      workArea: 'Utilities / Offsites — Demo area',
      shift: 'General shift',
      monitoringState: DemoMonitoringState.notStarted,
    ),
    DemoWorker(
      workerId: 'CT-45778',
      name: 'Joseph Fernandes',
      isContractor: true,
      contractorCompany: 'XYZ Engineering',
      department: 'Projects',
      workArea: 'Diesel Hydro-Desulphurisation — Demo area',
      shift: 'Shift C',
      monitoringState: DemoMonitoringState.complete,
      startedAt: _at(2, 22, 0),
      endedAt: _at(1, 6, 2),
    ),
  ];

  /// Workers whose badge is currently being worn.
  static List<DemoWorker> activelyMonitored() => workers()
      .where((w) => w.monitoringState == DemoMonitoringState.active)
      .toList();

  // ------------------------------------------------------- exposure records

  /// Exposure records.
  ///
  /// The refusal reasons span the pipeline's real vocabulary so the exception
  /// queue can be reviewed with something in every category. **No record
  /// carries a dose**, because no calibration exists to produce one — see
  /// [DemoRecordOutcome].
  static List<DemoExposureRecord> exposureRecords() => [
    DemoExposureRecord(
      recordId: 'EXP-2026-0918-0041',
      worker: workers()[3],
      badgeId: 'DB-4K8C7',
      batchId: 'L26-0912-A',
      startedAt: _at(1, 14, 0),
      endedAt: _at(1, 21, 58),
      outcome: DemoRecordOutcome.readComplete,
      reviewState: DemoReviewState.reviewRequired,
      quality: const DemoCaptureQuality(
        focusAssessed: true,
        exposureAssessed: true,
        glareDetected: false,
        fiducialsFound: 4,
        fiducialsExpected: 4,
        referencePatchesRead: 6,
        referencePatchesExpected: 6,
      ),
    ),
    DemoExposureRecord(
      recordId: 'EXP-2026-0918-0038',
      worker: workers()[5],
      badgeId: 'DB-4K9D3',
      batchId: 'L26-0912-A',
      startedAt: _at(2, 22, 0),
      endedAt: _at(1, 6, 2),
      outcome: DemoRecordOutcome.noReading,
      refusalReason: 'REFERENCE_PATCH_FAILURE',
      reviewState: DemoReviewState.informationRequired,
      quality: const DemoCaptureQuality(
        focusAssessed: true,
        exposureAssessed: true,
        glareDetected: true,
        fiducialsFound: 4,
        fiducialsExpected: 4,
        referencePatchesRead: 2,
        referencePatchesExpected: 6,
      ),
    ),
    DemoExposureRecord(
      recordId: 'EXP-2026-0917-0029',
      worker: workers()[2],
      badgeId: 'DB-4KA55',
      batchId: 'L26-0831-C',
      startedAt: _at(3, 6, 0),
      endedAt: _at(3, 14, 4),
      outcome: DemoRecordOutcome.noReading,
      refusalReason: 'BADGE_EXPIRED',
      reviewState: DemoReviewState.reviewed,
    ),
    DemoExposureRecord(
      recordId: 'EXP-2026-0917-0022',
      worker: workers()[1],
      badgeId: 'DB-4K7Q9',
      batchId: 'L26-0912-A',
      startedAt: _at(3, 6, 5),
      endedAt: _at(3, 13, 40),
      outcome: DemoRecordOutcome.readComplete,
      reviewState: DemoReviewState.closed,
      quality: const DemoCaptureQuality(
        focusAssessed: true,
        exposureAssessed: true,
        glareDetected: false,
        fiducialsFound: 4,
        fiducialsExpected: 4,
        referencePatchesRead: 6,
        referencePatchesExpected: 6,
      ),
    ),
    DemoExposureRecord(
      recordId: 'EXP-2026-0916-0014',
      worker: workers()[3],
      badgeId: 'DB-4K8B1',
      batchId: 'L26-0831-C',
      startedAt: _at(4, 14, 0),
      endedAt: _at(4, 17, 12),
      outcome: DemoRecordOutcome.noReading,
      refusalReason: 'PARTIAL_MONITORING',
      reviewState: DemoReviewState.inReview,
    ),
    DemoExposureRecord(
      recordId: 'EXP-2026-0916-0009',
      worker: workers()[0],
      badgeId: 'DB-4K7M2',
      batchId: 'L26-0912-A',
      startedAt: _at(5, 6, 10),
      endedAt: _at(5, 14, 2),
      outcome: DemoRecordOutcome.noReading,
      refusalReason: 'EXPOSURE_WINDOW_UNTRUSTED',
      reviewState: DemoReviewState.newRecord,
    ),
    DemoExposureRecord(
      recordId: 'EXP-2026-0915-0061',
      worker: workers()[1],
      badgeId: 'DB-4KB18',
      batchId: 'L26-0831-C',
      startedAt: _at(6, 6, 0),
      endedAt: _at(6, 14, 10),
      outcome: DemoRecordOutcome.noReading,
      refusalReason: 'POOR_IMAGE',
      reviewState: DemoReviewState.reviewRequired,
      quality: const DemoCaptureQuality(
        focusAssessed: false,
        exposureAssessed: true,
        glareDetected: false,
        fiducialsFound: 2,
        fiducialsExpected: 4,
        referencePatchesRead: 0,
        referencePatchesExpected: 6,
      ),
    ),
    DemoExposureRecord(
      recordId: 'EXP-2026-0915-0058',
      worker: workers()[5],
      badgeId: 'DB-4KB22',
      batchId: 'L26-0831-C',
      startedAt: _at(6, 22, 0),
      endedAt: _at(5, 6, 5),
      outcome: DemoRecordOutcome.noReading,
      refusalReason: 'UNSUPPORTED_CALIBRATION',
      reviewState: DemoReviewState.reviewRequired,
    ),
    DemoExposureRecord(
      recordId: 'EXP-2026-0914-0044',
      worker: workers()[2],
      badgeId: 'DB-4K8C7',
      batchId: 'L26-0912-A',
      startedAt: _at(7, 14, 0),
      endedAt: _at(7, 22, 3),
      outcome: DemoRecordOutcome.noReading,
      refusalReason: 'SENSOR_BLANK_DISAGREEMENT',
      reviewState: DemoReviewState.newRecord,
    ),
    DemoExposureRecord(
      recordId: 'EXP-2026-0914-0031',
      worker: workers()[3],
      badgeId: 'DB-4K9D3',
      batchId: 'L26-0912-A',
      startedAt: _at(8, 6, 0),
      endedAt: _at(8, 14, 0),
      outcome: DemoRecordOutcome.noReading,
      refusalReason: 'ENVIRONMENT_OUTSIDE_VALIDATED_RANGE',
      reviewState: DemoReviewState.reviewed,
    ),
  ];

  /// Records an officer still has to act on.
  static List<DemoExposureRecord> requiringReview() =>
      exposureRecords().where((r) => r.reviewState.isOpen).toList();

  static List<DemoExposureRecord> exceptions() =>
      exposureRecords().where((r) => r.refusalReason != null).toList();

  // ---------------------------------------------------------------- badges

  static List<DemoBadge> badges() => [
    const DemoBadge(
      badgeId: 'DB-4K7M2',
      batchId: 'L26-0912-A',
      status: DemoBadgeStatus.read,
    ),
    const DemoBadge(
      badgeId: 'DB-4K7Q9',
      batchId: 'L26-0912-A',
      status: DemoBadgeStatus.read,
    ),
    const DemoBadge(
      badgeId: 'DB-4K8B1',
      batchId: 'L26-0831-C',
      status: DemoBadgeStatus.quarantined,
    ),
    const DemoBadge(
      badgeId: 'DB-4K8C7',
      batchId: 'L26-0912-A',
      status: DemoBadgeStatus.awaitingRead,
    ),
    const DemoBadge(
      badgeId: 'DB-4K9D3',
      batchId: 'L26-0912-A',
      status: DemoBadgeStatus.active,
    ),
    const DemoBadge(
      badgeId: 'DB-4KA55',
      batchId: 'L26-0831-C',
      status: DemoBadgeStatus.archived,
    ),
    const DemoBadge(
      badgeId: 'DB-4KB18',
      batchId: 'L26-0912-A',
      status: DemoBadgeStatus.inventory,
    ),
    const DemoBadge(
      badgeId: 'DB-4KB22',
      batchId: 'L26-0912-A',
      status: DemoBadgeStatus.inventory,
    ),
  ];

  static List<DemoBatch> batches() => [
    DemoBatch(
      batchId: 'L26-0912-A',
      formulation: 'Bi-based colorimetric (sim)',
      geometryVersion: 'badge-v1-research',
      badgeCount: 5,
      manufacturedAt: null,
      expiresAt: null,
    ),
    DemoBatch(
      batchId: 'L26-0831-C',
      formulation: 'Bi-based colorimetric (sim)',
      geometryVersion: 'badge-v1-research',
      badgeCount: 3,
      manufacturedAt: null,
      expiresAt: null,
    ),
  ];

  // ---------------------------------------------------------- integrations

  /// Every enterprise integration, and its true state.
  ///
  /// All of them are [DataOrigin.notConnected]. That is the honest answer, and
  /// the Integration Status screen exists largely to say so in one place — a
  /// reviewer should be able to see the extent of what is not wired up without
  /// reading the source.
  static List<DemoIntegration> integrations() => const [
    DemoIntegration(
      name: 'Organisation identity',
      description:
          'Sign-in against the organisation directory. Today the app accepts '
          'one published demo account and verifies nothing.',
    ),
    DemoIntegration(
      name: 'Gate pass',
      description:
          'Reading and confirming a gate-pass credential issued by site '
          'security.',
    ),
    DemoIntegration(
      name: 'Permit to Work',
      description:
          'Confirming that a referenced permit exists, is open and covers the '
          'work. Permit references are typed by hand and checked by nothing.',
    ),
    DemoIntegration(
      name: 'Job Safety Analysis',
      description: 'Confirming a referenced JSA. References are typed by hand.',
    ),
    DemoIntegration(
      name: 'Hazard and near-miss reporting',
      description:
          'Submitting a hazard or near-miss report into the organisation '
          'process. DoseBand can only hand off.',
    ),
    DemoIntegration(
      name: 'Occupational health',
      description:
          'Referring an exposure record for occupational-health review. '
          'DoseBand stores no medical information.',
    ),
    DemoIntegration(
      name: 'Enterprise resource planning',
      description: 'Work orders, materials and cost objects.',
    ),
    DemoIntegration(
      name: 'Document repository',
      description:
          'Safety data sheets, procedures and toolbox material served from '
          'the organisation document store.',
    ),
    DemoIntegration(
      name: 'Backend synchronisation',
      description:
          'Pushing local records to a server. The app is local-only: records '
          'live on this device and are not synchronised anywhere.',
    ),
  ];

  // --------------------------------------------------------------- devices

  static List<DemoDevice> devices() => [
    DemoDevice(
      deviceId: 'DEV-8841',
      model: 'Demo handset A',
      os: 'Android 14',
      appVersion: '0.1.0+1',
      lastSeen: _at(0, 6, 2),
    ),
    DemoDevice(
      deviceId: 'DEV-8842',
      model: 'Demo handset B',
      os: 'Android 13',
      appVersion: '0.1.0+1',
      lastSeen: _at(1, 21, 40),
    ),
  ];

  // ----------------------------------------------------------- audit trail

  /// Audit events.
  ///
  /// Every entry names an actor, a device and a source, and a state-changing
  /// action carries its transition and the reason given. Nothing is signed:
  /// DoseBand holds no signing keys, so a "digitally signed" badge here would
  /// be a claim about integrity that nothing backs.
  static List<DemoAuditEntry> auditTrail() => [
    DemoAuditEntry(
      at: _at(0, 6, 10),
      actor: 'CT-45832',
      action: 'Started monitored period',
      entity: 'EXP-2026-0925-0002',
      previousState: 'Ready for dosimetry',
      newState: 'Monitoring',
      device: 'DEV-8841',
    ),
    DemoAuditEntry(
      at: _at(0, 6, 8),
      actor: 'CT-45832',
      action: 'Assigned DoseBand',
      entity: 'DB-4K9D3',
      previousState: 'Work context recorded',
      newState: 'Badge assigned',
      device: 'DEV-8841',
    ),
    DemoAuditEntry(
      at: _at(0, 6, 4),
      actor: 'CT-45832',
      action: 'Recorded work context',
      entity: 'EXP-2026-0925-0002',
      previousState: 'Not started',
      newState: 'Work context recorded',
      device: 'DEV-8841',
    ),
    DemoAuditEntry(
      at: _at(1, 22, 6),
      actor: 'EMP-21003',
      action: 'Requested additional information',
      entity: 'EXP-2026-0918-0038',
      previousState: 'In review',
      newState: 'Additional information required',
      reason:
          'Reference patches unreadable; asked for the capture conditions at '
          'the time of the scan.',
      device: 'DEV-8842',
    ),
    DemoAuditEntry(
      at: _at(1, 22, 3),
      actor: 'EMP-21003',
      action: 'Marked record reviewed',
      entity: 'EXP-2026-0917-0029',
      previousState: 'Review required',
      newState: 'Reviewed',
      reason: 'Badge past its validity period; no reading is expected.',
      device: 'DEV-8842',
    ),
    DemoAuditEntry(
      at: _at(1, 21, 58),
      actor: 'CT-45610',
      action: 'Ended monitored period',
      entity: 'EXP-2026-0918-0041',
      previousState: 'Monitoring',
      newState: 'Awaiting scan',
      device: 'DEV-8841',
    ),
  ];
}

// ============================================================ record types

enum DemoMonitoringState {
  notStarted('Not started'),
  active('Monitoring active'),
  awaitingScan('Awaiting scan'),
  complete('Reading complete');

  const DemoMonitoringState(this.label);

  final String label;
}

/// What a demo record's scan produced.
///
/// There is deliberately **no** "valid, 12.4 ppm·h" outcome. No calibration
/// model exists, so any dose shown anywhere in this product today would be
/// fabricated — and a fabricated number on an HSE register is exactly the
/// failure this project was set up to avoid. `readComplete` means the badge
/// was read; the quantity is unavailable because the science is not done.
enum DemoRecordOutcome {
  readComplete('Badge read complete'),
  noReading('No reading');

  const DemoRecordOutcome(this.label);

  final String label;
}

/// Where a record sits in the HSE review workflow.
///
/// These are **workflow** states, deliberately not severities. There is no
/// low/medium/high risk banding here: a severity scale is a clinical or
/// regulatory classification, and inventing one would let an officer sort a
/// register by a number this product has no basis to produce.
enum DemoReviewState {
  newRecord('New'),
  reviewRequired('Review required'),
  inReview('In review'),
  informationRequired('Additional information required'),
  reviewed('Reviewed'),
  closed('Closed');

  const DemoReviewState(this.label);

  final String label;

  /// Whether this record still needs an officer to do something.
  bool get isOpen =>
      this != DemoReviewState.reviewed && this != DemoReviewState.closed;
}

/// What the capture itself looked like, where the pipeline recorded it.
///
/// Null fields mean the check did not run or was not recorded — never that it
/// passed. A review screen has to be able to say "not assessed" without that
/// reading as "fine".
@immutable
final class DemoCaptureQuality {
  const DemoCaptureQuality({
    this.focusAssessed,
    this.exposureAssessed,
    this.glareDetected,
    this.fiducialsFound,
    this.fiducialsExpected,
    this.referencePatchesRead,
    this.referencePatchesExpected,
  });

  final bool? focusAssessed;
  final bool? exposureAssessed;
  final bool? glareDetected;
  final int? fiducialsFound;
  final int? fiducialsExpected;
  final int? referencePatchesRead;
  final int? referencePatchesExpected;
}

enum DemoBadgeStatus {
  inventory('Inventory'),
  assigned('Assigned'),
  active('Active'),
  awaitingRead('Awaiting read'),
  read('Read'),
  quarantined('Quarantined'),
  archived('Archived');

  const DemoBadgeStatus(this.label);

  final String label;
}

@immutable
final class DemoWorker {
  const DemoWorker({
    required this.workerId,
    required this.name,
    required this.isContractor,
    required this.department,
    required this.workArea,
    required this.shift,
    required this.monitoringState,
    this.contractorCompany,
    this.startedAt,
    this.endedAt,
  });

  final String workerId;
  final String name;
  final bool isContractor;
  final String? contractorCompany;
  final String department;
  final String workArea;
  final String shift;
  final DemoMonitoringState monitoringState;
  final DateTime? startedAt;
  final DateTime? endedAt;

  String get typeLabel => isContractor ? 'Contractor' : 'Employee';

  /// How long the badge has been worn, or null when that cannot be stated.
  ///
  /// Null propagates to `- - -` on screen. It is never rendered as zero: the
  /// same rule the real workflow follows, applied to demo rows so the two
  /// cannot teach a reviewer different habits.
  Duration? coverageAt(DateTime now) {
    final start = startedAt;
    if (start == null) return null;
    final end = endedAt ?? now;
    final d = end.difference(start);
    return d.isNegative ? null : d;
  }
}

@immutable
final class DemoExposureRecord {
  const DemoExposureRecord({
    required this.recordId,
    required this.worker,
    required this.badgeId,
    required this.batchId,
    required this.startedAt,
    required this.endedAt,
    required this.outcome,
    required this.reviewState,
    this.refusalReason,
    this.quality,
  });

  final String recordId;
  final DemoWorker worker;
  final String badgeId;
  final String batchId;
  final DateTime startedAt;
  final DateTime endedAt;
  final DemoRecordOutcome outcome;
  final DemoReviewState reviewState;

  /// The reason code when [outcome] is [DemoRecordOutcome.noReading].
  final String? refusalReason;

  /// What the capture looked like, where the pipeline recorded it. Null means
  /// nothing was recorded — not that the capture was good.
  final DemoCaptureQuality? quality;

  Duration? get coverage {
    final d = endedAt.difference(startedAt);
    return d.isNegative ? null : d;
  }

  bool get hasReading => outcome == DemoRecordOutcome.readComplete;
}

@immutable
final class DemoBadge {
  const DemoBadge({
    required this.badgeId,
    required this.batchId,
    required this.status,
  });

  final String badgeId;
  final String batchId;
  final DemoBadgeStatus status;
}

@immutable
final class DemoBatch {
  const DemoBatch({
    required this.batchId,
    required this.formulation,
    required this.geometryVersion,
    required this.badgeCount,
    required this.manufacturedAt,
    required this.expiresAt,
  });

  final String batchId;
  final String formulation;
  final String geometryVersion;
  final int badgeCount;

  /// Null, and shown as unavailable.
  ///
  /// No badge has been manufactured. Inventing a manufacture date would
  /// fabricate a supply-chain record, which is a worse kind of invention than
  /// a fabricated measurement because it would be believed without question.
  final DateTime? manufacturedAt;

  /// Null for the same reason.
  final DateTime? expiresAt;
}

@immutable
final class DemoIntegration {
  const DemoIntegration({required this.name, required this.description});

  final String name;
  final String description;

  /// Always not connected. There is no constructor that says otherwise,
  /// because there is no integration that would justify one.
  DataOrigin get origin => DataOrigin.notConnected;
}

@immutable
final class DemoDevice {
  const DemoDevice({
    required this.deviceId,
    required this.model,
    required this.os,
    required this.appVersion,
    required this.lastSeen,
  });

  final String deviceId;
  final String model;
  final String os;
  final String appVersion;
  final DateTime lastSeen;
}

@immutable
final class DemoAuditEntry {
  const DemoAuditEntry({
    required this.at,
    required this.actor,
    required this.action,
    required this.entity,
    this.previousState,
    this.newState,
    this.reason,
    this.source = 'DoseBand app',
    this.device,
  });

  final DateTime at;
  final String actor;
  final String action;
  final String entity;

  /// The transition, where the action changed a state. Null for actions that
  /// did not — a capture is an event, not a transition.
  final String? previousState;
  final String? newState;

  /// Why, where a reason was required. An officer's disposition needs one; a
  /// worker starting a period does not.
  final String? reason;

  final String source;
  final String? device;
}
