import '../../../core/domain/doseband.dart';
import '../../../core/domain/monitoring_session.dart';
import '../../../core/domain/provenance.dart';
import '../../auth/domain/access_policy.dart';
import '../../auth/domain/auth_models.dart';
import '../../workflow/domain/worker_identity.dart';
import '../domain/assignment.dart';
import '../domain/audit.dart';
import '../domain/inventory.dart';
import '../domain/operations_snapshot.dart';
import '../domain/organisation.dart';

/// THE presentation dataset — the one controlled source of organisational
/// data (PRODUCT BUILD v1 §84, §85, §138).
///
/// ## Rules this file keeps
///
/// * **Only the six approved people** (§31). No other person exists anywhere
///   in the product. Identifiers, designations and the contractor company are
///   minimal presentation placeholders, not personal data.
/// * **No measurement records.** Not one H₂S value, refusal or result is
///   seeded. Every record in the store was produced on this device by the
///   real capture path (or, in development tools, by the labelled
///   simulation). A reviewer who finds a measurement record can trust that
///   something produced it.
/// * **Operational state only.** One worker is part-way through a monitoring
///   period and one has a final scan that was never taken, so the supervisor
///   workspace has something true to show before the live demonstration adds
///   more. Times are relative to the moment of seeding, so they stay
///   plausible whenever the app is first opened.
/// * **Nothing here is from any MRPL system.** Every entity carries
///   [RecordProvenance.presentationSeeded].
abstract final class PresentationDataset {
  static const String version = 'presentation-2026.09-v1';

  static const String siteId = 'mangalore-refinery';
  static const String siteName = 'Mangalore Refinery';
  static const String organisationId = 'org-presentation';

  // People. The login identifier is the organisation identifier.
  static const String aditya = 'CT-45832';
  static const String lavitra = 'E-10231';
  static const String nikhil = 'CT-45871';
  static const String aman = 'E-10088';
  static const String samhita = 'E-10152';
  static const String yashvi = 'E-10007';

  static const String teamId = 'team-sru-maintenance-a';

  static const String formulationId = 'FORM-R0';
  static const String geometryVersion = 'badge-v1-research';

  static const String currentLot = 'LOT-2609-A';
  static const String expiredLot = 'LOT-2608-C';
  static const String unsupportedLot = 'LOT-2607-U';

  static const _seeded = RecordProvenance.presentationSeeded;

  static const List<Person> people = [
    Person(
      personId: aditya,
      displayName: 'Aditya Jadhav',
      workerType: WorkerType.contractor,
      contractorCompany: 'XYZ Engineering',
      siteId: siteId,
      departmentId: 'maintenance',
      designation: 'Maintenance technician',
      roles: [AppRole.worker],
      defaultWorkAreaId: 'sru',
      defaultShiftId: 'a',
      provenance: _seeded,
    ),
    Person(
      personId: lavitra,
      displayName: 'Lavitra Satam',
      workerType: WorkerType.employee,
      siteId: siteId,
      departmentId: 'operations',
      designation: 'Field operator',
      roles: [AppRole.worker],
      defaultWorkAreaId: 'sru',
      defaultShiftId: 'a',
      provenance: _seeded,
    ),
    Person(
      personId: nikhil,
      displayName: 'Nikhil Sharma',
      workerType: WorkerType.contractor,
      contractorCompany: 'XYZ Engineering',
      siteId: siteId,
      departmentId: 'maintenance',
      designation: 'Maintenance technician',
      roles: [AppRole.worker],
      defaultWorkAreaId: 'sru',
      defaultShiftId: 'a',
      provenance: _seeded,
    ),
    Person(
      personId: aman,
      displayName: 'Aman Singh',
      workerType: WorkerType.employee,
      siteId: siteId,
      departmentId: 'maintenance',
      designation: 'Shift supervisor',
      roles: [AppRole.supervisor],
      provenance: _seeded,
    ),
    Person(
      personId: samhita,
      displayName: 'Samhita Hejmadi',
      workerType: WorkerType.employee,
      siteId: siteId,
      departmentId: 'hse',
      designation: 'HSE officer',
      roles: [AppRole.hseOfficer],
      provenance: _seeded,
    ),
    Person(
      personId: yashvi,
      displayName: 'Yashvi Chotalia',
      workerType: WorkerType.employee,
      siteId: siteId,
      departmentId: 'administration',
      designation: 'Operations management and system administration',
      // Two roles, so the controlled workspace switch has a real account to
      // switch (§54). Management first: it is where she signs in.
      roles: [AppRole.management, AppRole.administrator],
      provenance: _seeded,
    ),
  ];

  static const List<OrgDepartment> departments = [
    OrgDepartment(
      departmentId: 'operations',
      name: 'Operations',
      siteId: siteId,
    ),
    OrgDepartment(
      departmentId: 'maintenance',
      name: 'Maintenance',
      siteId: siteId,
    ),
    OrgDepartment(
      departmentId: 'hse',
      name: 'Health, Safety & Environment',
      siteId: siteId,
    ),
    OrgDepartment(
      departmentId: 'administration',
      name: 'Administration',
      siteId: siteId,
    ),
  ];

  static const List<Team> teams = [
    Team(
      teamId: teamId,
      name: 'SRU maintenance crew A',
      siteId: siteId,
      departmentId: 'maintenance',
      supervisorId: aman,
      // Lavitra is in Operations, not Maintenance, and still in the team:
      // supervision follows the explicit team, never the department (§146).
      memberIds: [aditya, lavitra, nikhil],
    ),
  ];

  static const List<ScopeGrant> grants = [
    ScopeGrant(
      personId: aditya,
      role: AppRole.worker,
      scope: AccessScope.self,
      targetId: aditya,
    ),
    ScopeGrant(
      personId: lavitra,
      role: AppRole.worker,
      scope: AccessScope.self,
      targetId: lavitra,
    ),
    ScopeGrant(
      personId: nikhil,
      role: AppRole.worker,
      scope: AccessScope.self,
      targetId: nikhil,
    ),
    ScopeGrant(
      personId: aman,
      role: AppRole.supervisor,
      scope: AccessScope.team,
      targetId: teamId,
    ),
    ScopeGrant(
      personId: samhita,
      role: AppRole.hseOfficer,
      scope: AccessScope.site,
      targetId: siteId,
    ),
    ScopeGrant(
      personId: yashvi,
      role: AppRole.management,
      scope: AccessScope.organization,
      targetId: organisationId,
    ),
    ScopeGrant(
      personId: yashvi,
      role: AppRole.administrator,
      scope: AccessScope.organization,
      targetId: organisationId,
    ),
  ];

  static String _serial(String lot, int n) =>
      'DB-${lot.substring(4, 8)}-${n.toString().padLeft(4, '0')}';

  /// Builds the dataset as of [now].
  static OperationsSnapshot build(DateTime now) {
    final lots = [
      DoseBandLot(
        lotId: currentLot,
        formulationId: formulationId,
        geometryVersion: geometryVersion,
        receivedOn: now.subtract(const Duration(days: 7)),
        expiresOn: now.add(const Duration(days: 90)),
        provenance: _seeded,
      ),
      DoseBandLot(
        lotId: expiredLot,
        formulationId: formulationId,
        geometryVersion: geometryVersion,
        receivedOn: now.subtract(const Duration(days: 40)),
        expiresOn: now.subtract(const Duration(days: 3)),
        provenance: _seeded,
      ),
      DoseBandLot(
        lotId: unsupportedLot,
        formulationId: formulationId,
        // An earlier printed configuration this reader does not support.
        geometryVersion: 'demo-badge-v0',
        receivedOn: now.subtract(const Duration(days: 60)),
        expiresOn: now.add(const Duration(days: 30)),
        supportedConfiguration: false,
        provenance: _seeded,
      ),
    ];

    DoseBand band(
      String lot,
      int n, [
      DoseBandLifecycle l = DoseBandLifecycle.available,
      String? assignmentId,
    ]) {
      final record = lots.firstWhere((x) => x.lotId == lot);
      return DoseBand(
        dosebandId: _serial(lot, n),
        lifecycle: l,
        provenance: _seeded,
        lotId: lot,
        formulationId: record.formulationId,
        expiry: record.expiresOn,
        assignmentId: assignmentId,
        geometryVersion: record.geometryVersion,
      );
    }

    // ---- Lavitra: monitoring now, since a little over two hours ago.
    final lavitraClaim = now.subtract(const Duration(hours: 2, minutes: 10));
    final lavitraStart = now.subtract(const Duration(hours: 2, minutes: 5));
    // ---- Nikhil: yesterday's period ended and the final scan never happened.
    final nikhilClaim = now.subtract(const Duration(days: 1, hours: 8));
    final nikhilStart = nikhilClaim.add(const Duration(minutes: 4));
    final nikhilEnd = now.subtract(const Duration(days: 1));
    final nikhilDamaged = nikhilClaim.subtract(const Duration(minutes: 3));

    const shiftA = WorkSummary(
      siteId: siteId,
      siteName: siteName,
      departmentId: 'maintenance',
      departmentName: 'Maintenance',
      workAreaId: 'sru',
      workAreaName: 'Sulphur Recovery Unit — Demo area',
      shiftId: 'a',
      shiftName: 'Shift A',
    );

    final bands = <String, DoseBand>{
      for (var n = 1; n <= 24; n++)
        _serial(currentLot, n): switch (n) {
          1 => band(currentLot, 1, DoseBandLifecycle.monitoring, 'ASG-SEED-01'),
          2 => band(
            currentLot,
            2,
            DoseBandLifecycle.readyForFinalRead,
            'ASG-SEED-02',
          ),
          3 => band(currentLot, 3, DoseBandLifecycle.damaged),
          _ => band(currentLot, n),
        },
      for (var n = 1; n <= 4; n++) _serial(expiredLot, n): band(expiredLot, n),
      for (var n = 1; n <= 3; n++)
        _serial(unsupportedLot, n): band(unsupportedLot, n),
    };

    const preUseReadable = OpticalCheckStatus.readable;

    return OperationsSnapshot(
      datasetVersion: version,
      seededAt: now,
      people: people,
      departments: departments,
      teams: teams,
      grants: grants,
      formulations: const [
        SensorFormulation(
          formulationId: formulationId,
          name: 'Research sensor formulation',
          version: 'R0',
        ),
      ],
      lots: lots,
      bands: bands,
      assignments: [
        DoseBandAssignment(
          assignmentId: 'ASG-SEED-01',
          dosebandId: _serial(currentLot, 1),
          workerId: lavitra,
          sessionId: 'SES-SEED-01',
          claimedAt: lavitraClaim,
          state: AssignmentState.active,
          preUse: PreUseRecord(
            outcome: PreUseOutcome.readyToUse,
            checkedAt: lavitraClaim,
            opticalCheck: preUseReadable,
          ),
        ),
        DoseBandAssignment(
          assignmentId: 'ASG-SEED-02',
          dosebandId: _serial(currentLot, 2),
          workerId: nikhil,
          sessionId: 'SES-SEED-02',
          claimedAt: nikhilClaim,
          state: AssignmentState.active,
          preUse: PreUseRecord(
            outcome: PreUseOutcome.readyToUse,
            checkedAt: nikhilClaim,
            opticalCheck: preUseReadable,
          ),
        ),
      ],
      sessions: [
        MonitoringSession(
          sessionId: 'SES-SEED-01',
          workerId: lavitra,
          state: MonitoringSessionState.active,
          provenance: _seeded,
          dosebandId: _serial(currentLot, 1),
          assignmentId: 'ASG-SEED-01',
          work: const WorkSummary(
            siteId: siteId,
            siteName: siteName,
            departmentId: 'operations',
            departmentName: 'Operations',
            workAreaId: 'sru',
            workAreaName: 'Sulphur Recovery Unit — Demo area',
            shiftId: 'a',
            shiftName: 'Shift A',
          ),
          startedAt: lavitraStart,
        ),
        MonitoringSession(
          sessionId: 'SES-SEED-02',
          workerId: nikhil,
          state: MonitoringSessionState.readyForFinalRead,
          provenance: _seeded,
          dosebandId: _serial(currentLot, 2),
          assignmentId: 'ASG-SEED-02',
          work: shiftA,
          startedAt: nikhilStart,
          endedAt: nikhilEnd,
        ),
      ],
      measurements: const [],
      reviews: const [],
      audit: [
        AuditEvent(
          eventId: 'AUD-SEED-01',
          at: nikhilDamaged,
          actorId: nikhil,
          actorRole: AppRole.worker,
          action: AuditAction.dosebandReported,
          subjectType: 'doseband',
          subjectId: _serial(currentLot, 3),
          detail: 'Reported damaged before use; replaced with another band.',
        ),
        AuditEvent(
          eventId: 'AUD-SEED-02',
          at: nikhilClaim,
          actorId: nikhil,
          actorRole: AppRole.worker,
          action: AuditAction.dosebandClaimed,
          subjectType: 'doseband',
          subjectId: _serial(currentLot, 2),
        ),
        AuditEvent(
          eventId: 'AUD-SEED-03',
          at: nikhilStart,
          actorId: nikhil,
          actorRole: AppRole.worker,
          action: AuditAction.monitoringStarted,
          subjectType: 'session',
          subjectId: 'SES-SEED-02',
        ),
        AuditEvent(
          eventId: 'AUD-SEED-04',
          at: nikhilEnd,
          actorId: nikhil,
          actorRole: AppRole.worker,
          action: AuditAction.monitoringEnded,
          subjectType: 'session',
          subjectId: 'SES-SEED-02',
        ),
        AuditEvent(
          eventId: 'AUD-SEED-05',
          at: lavitraClaim,
          actorId: lavitra,
          actorRole: AppRole.worker,
          action: AuditAction.dosebandClaimed,
          subjectType: 'doseband',
          subjectId: _serial(currentLot, 1),
        ),
        AuditEvent(
          eventId: 'AUD-SEED-06',
          at: lavitraStart,
          actorId: lavitra,
          actorRole: AppRole.worker,
          action: AuditAction.monitoringStarted,
          subjectType: 'session',
          subjectId: 'SES-SEED-01',
        ),
      ],
    );
  }
}
