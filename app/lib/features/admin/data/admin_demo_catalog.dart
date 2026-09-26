import 'package:flutter/foundation.dart';

/// Fictional administration records.
///
/// ## Rules these obey
///
/// * Every identifier is obviously invented. No MRPL employee directory, no
///   real gate-pass numbers, no internal API names, no SAP endpoints.
/// * Nothing claims to be connected, validated, approved or released. Those
///   are states this system has not earned, and an administration screen is
///   exactly where a reviewer goes to find out whether it has.
/// * Timestamps exist only where an event genuinely could have happened on
///   this device. A "last successful sync" on a system with no backend is a
///   fabricated event, so those fields are null.
abstract final class AdminDemoCatalog {
  static final DateTime _today = DateTime(2026, 9, 25);

  static DateTime _at(int dayOffset, int hour, [int minute = 0]) =>
      DateTime(_today.year, _today.month, _today.day - dayOffset, hour, minute);

  // ------------------------------------------------------------ people

  static List<AdminUser> users() => [
    AdminUser(
      userId: 'CT-45832',
      name: 'Aditya Jadhav',
      role: AdminRole.worker,
      department: 'Operations',
      isContractor: true,
      contractorCompany: 'XYZ Engineering',
      lastActivity: _at(0, 6, 10),
    ),
    AdminUser(
      userId: 'EMP-20871',
      name: 'Meera Nair',
      role: AdminRole.worker,
      department: 'Operations',
      lastActivity: _at(0, 6, 5),
    ),
    AdminUser(
      userId: 'EMP-21003',
      name: 'Sunita Rao',
      role: AdminRole.hseOfficer,
      department: 'Health, Safety & Environment',
      lastActivity: _at(1, 22, 6),
    ),
    AdminUser(
      userId: 'EMP-20944',
      name: 'Rahul Shetty',
      role: AdminRole.supervisor,
      department: 'Maintenance',
      lastActivity: _at(1, 14, 30),
    ),
    AdminUser(
      userId: 'EMP-21100',
      name: 'Priya Menon',
      role: AdminRole.administrator,
      department: 'Information Systems',
      lastActivity: _at(2, 9, 0),
    ),
  ];

  // ----------------------------------------------------------- devices

  static List<AdminDevice> devices() => [
    AdminDevice(
      deviceId: 'DEV-8841',
      name: 'Demo handset A',
      platform: 'Android',
      osVersion: 'Android 14',
      appVersion: '0.1.0+1',
      lastSeen: _at(0, 6, 2),
    ),
    AdminDevice(
      deviceId: 'DEV-8842',
      name: 'Demo handset B',
      platform: 'Android',
      osVersion: 'Android 13',
      appVersion: '0.1.0+1',
      lastSeen: _at(1, 21, 40),
    ),
    AdminDevice(
      deviceId: 'DEV-8850',
      name: 'Demo handset C',
      platform: 'iOS',
      osVersion: 'iOS 18.6',
      appVersion: '0.1.0+1',
      lastSeen: _at(3, 8, 12),
    ),
  ];

  // ------------------------------------------------------ integrations

  /// Every integration, with what it would do and what it would need.
  ///
  /// All are [IntegrationState.notConnected]. There is no constructor for
  /// any other state, because no other state is true — see the enum.
  static List<AdminIntegration> integrations() => const [
    AdminIntegration(
      id: 'identity',
      name: 'Enterprise identity',
      purpose:
          'Sign in against the organisation directory and establish who a '
          'worker actually is.',
      dataDirection: 'Read — identity and group membership',
      blockedBy:
          'Today the application accepts one published demo account and '
          'verifies nothing.',
    ),
    AdminIntegration(
      id: 'gate-pass',
      name: 'Gate pass',
      purpose: 'Read and confirm a gate-pass credential issued by security.',
      dataDirection: 'Read — credential validity',
      blockedBy:
          'Gate-pass references are typed by hand and checked by '
          'nothing.',
    ),
    AdminIntegration(
      id: 'ptw',
      name: 'Permit to Work',
      purpose:
          'Confirm that a referenced permit exists, is open and covers the '
          'work being monitored.',
      dataDirection: 'Read — permit status',
      blockedBy: 'Permit references are typed by hand.',
    ),
    AdminIntegration(
      id: 'jsa',
      name: 'Job Safety Analysis',
      purpose: 'Confirm a referenced JSA and the activity it covers.',
      dataDirection: 'Read — JSA status',
      blockedBy: 'JSA references are typed by hand.',
    ),
    AdminIntegration(
      id: 'hazard',
      name: 'Hazard and near-miss reporting',
      purpose:
          'Hand a hazard or near-miss report to the organisation process, '
          'carrying the work context.',
      dataDirection: 'Write — report submission',
      blockedBy: 'DoseBand cannot submit a report and does not claim to.',
    ),
    AdminIntegration(
      id: 'occupational-health',
      name: 'Occupational health',
      purpose:
          'Refer an exposure record for occupational-health review, without '
          'any medical content.',
      dataDirection: 'Write — referral of an exposure record',
      blockedBy: 'No referral can be made, and none is claimed.',
    ),
    AdminIntegration(
      id: 'documents',
      name: 'Document repository',
      purpose:
          'Serve safety data sheets, procedures and toolbox material from '
          'the organisation store.',
      dataDirection: 'Read — controlled documents',
      blockedBy: 'No document is held or downloaded.',
    ),
    AdminIntegration(
      id: 'backend',
      name: 'Backend service',
      purpose: 'Store exposure records beyond a single device.',
      dataDirection: 'Read and write — records',
      blockedBy:
          'Records live on the device that produced them and are not '
          'synchronised anywhere.',
    ),
    AdminIntegration(
      id: 'enterprise',
      name: 'Enterprise resource planning',
      purpose: 'Work orders, materials and cost objects.',
      dataDirection: 'Read — work order context',
      blockedBy: 'No enterprise system is configured.',
    ),
    AdminIntegration(
      id: 'export',
      name: 'Report export',
      purpose: 'Produce PDF, CSV and audit packages from reporting.',
      dataDirection: 'Write — generated files',
      blockedBy: 'No exporter exists; reporting offers previews only.',
    ),
    AdminIntegration(
      id: 'calibration-distribution',
      name: 'Calibration distribution',
      purpose:
          'Receive and activate signed calibration packages as they are '
          'produced.',
      dataDirection: 'Read — calibration packages',
      blockedBy:
          'No production calibration exists to distribute. Scientific gates '
          'S1, S2 and S3 are open.',
    ),
  ];

  static AdminIntegration? integrationById(String id) {
    for (final integration in integrations()) {
      if (integration.id == id) return integration;
    }
    return null;
  }

  // ------------------------------------------------------- retention

  /// Retention profiles.
  ///
  /// **No duration is filled in.** Retention periods for occupational
  /// exposure records are set by regulation and by organisation policy, they
  /// differ by jurisdiction and record class, and DoseBand's record classes
  /// have not been formally mapped to any of them. A hard-coded period here
  /// would be a compliance claim in a field that looks like configuration.
  static List<RetentionProfile> retentionProfiles() => const [
    RetentionProfile(
      recordType: 'Occupational exposure records',
      note: 'The primary occupational record class.',
    ),
    RetentionProfile(
      recordType: 'Measurement images',
      note:
          'Capture images are a record in their own right, with their own '
          'access and retention questions. Not currently retained at all.',
    ),
    RetentionProfile(
      recordType: 'Audit trail',
      note: 'Who did what, and when.',
    ),
    RetentionProfile(
      recordType: 'Worker identity',
      note: 'Personal data. Subject to separate obligations.',
    ),
    RetentionProfile(
      recordType: 'Badge and batch records',
      note: 'Supply-chain traceability.',
    ),
    RetentionProfile(
      recordType: 'Generated reports',
      note: 'Reports and audit packages, once an exporter exists.',
    ),
  ];
}

// ============================================================ types

/// A role in the demonstration directory.
///
/// These describe what a person *would* be permitted to do. They grant
/// nothing: the prototype's role selector is a review convenience, and
/// routing by role is not authorisation.
enum AdminRole {
  worker('Worker', [AdminPermission.workerWorkflow]),
  hseOfficer('HSE Officer', [
    AdminPermission.hseReview,
    AdminPermission.reporting,
  ]),
  supervisor('Supervisor', [AdminPermission.reporting]),
  management('Management', [AdminPermission.reporting]),
  administrator('Administrator', [
    AdminPermission.reporting,
    AdminPermission.badgeAdministration,
    AdminPermission.calibrationAdministration,
    AdminPermission.systemAdministration,
  ]);

  const AdminRole(this.label, this.permissions);

  final String label;
  final List<AdminPermission> permissions;
}

enum AdminPermission {
  workerWorkflow('Worker workflow'),
  hseReview('HSE review'),
  reporting('Reporting'),
  badgeAdministration('Badge administration'),
  calibrationAdministration('Calibration administration'),
  systemAdministration('System administration');

  const AdminPermission(this.label);

  final String label;
}

@immutable
final class AdminUser {
  const AdminUser({
    required this.userId,
    required this.name,
    required this.role,
    required this.department,
    required this.lastActivity,
    this.isContractor = false,
    this.contractorCompany,
  });

  final String userId;
  final String name;
  final AdminRole role;
  final String department;
  final DateTime lastActivity;
  final bool isContractor;
  final String? contractorCompany;

  /// Always demo. No identity provider is connected, so nothing about this
  /// person has been established by anything.
  String get identitySource => 'Demonstration — no identity provider';

  String get employmentLabel => isContractor ? 'Contractor' : 'Employee';
}

/// How a device's fitness to take a measurement is known.
///
/// **Nothing is [validated] today** and nothing may be, because M0C is open:
/// no physical smartphone has photographed a printed target through this
/// application. A device marked validated without that evidence would be the
/// administration screen endorsing an instrument nobody has tested.
enum DeviceValidationState {
  untested('Untested', 'No capture validation has been performed.'),
  research(
    'Research',
    'Used for development capture work. Not evidence of measurement '
        'performance.',
  ),
  validated(
    'Validated',
    'Validated against a printed target. No device is in this state.',
  ),
  unsupported('Unsupported', 'Known not to meet capture requirements.');

  const DeviceValidationState(this.label, this.explanation);

  final String label;
  final String explanation;
}

@immutable
final class AdminDevice {
  const AdminDevice({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.lastSeen,
  });

  final String deviceId;
  final String name;
  final String platform;
  final String osVersion;
  final String appVersion;
  final DateTime lastSeen;

  /// Untested, always. See [DeviceValidationState].
  DeviceValidationState get validation => DeviceValidationState.untested;

  /// What the camera can do is a capability question the app answers at
  /// runtime per device. Nothing has been recorded here.
  String get captureCapability => 'Not assessed';
}

/// Whether an integration is wired up.
///
/// There is deliberately no `connected` value. Adding one is the change that
/// should require a conversation, rather than a state a screen can slip into
/// because a field was left at its default.
enum IntegrationState {
  notConnected('Not connected'),
  unavailable('Unavailable');

  const IntegrationState(this.label);

  final String label;
}

@immutable
final class AdminIntegration {
  const AdminIntegration({
    required this.id,
    required this.name,
    required this.purpose,
    required this.dataDirection,
    required this.blockedBy,
  });

  final String id;
  final String name;

  /// What it would do once it exists.
  final String purpose;

  final String dataDirection;

  /// What the absence means in practice today.
  final String blockedBy;

  IntegrationState get state => IntegrationState.notConnected;

  /// Null, always. A "last successful sync" on a system with no backend is a
  /// fabricated event, and it is the field a reviewer would most readily
  /// believe.
  DateTime? get lastSuccess => null;

  DateTime? get lastAttempt => null;
}

/// A retention profile with no duration set.
@immutable
final class RetentionProfile {
  const RetentionProfile({required this.recordType, required this.note});

  final String recordType;
  final String note;

  /// Null until the organisation supplies one. Renders as not configured.
  String? get duration => null;

  /// Null until a formal mapping exists.
  String? get authority => null;

  String get status => 'Policy mapping required';
}
