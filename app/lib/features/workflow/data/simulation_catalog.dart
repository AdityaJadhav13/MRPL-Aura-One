import 'package:measurement/measurement.dart';

import '../domain/badge_specimen.dart';
import '../domain/enterprise_value.dart';
import '../domain/permit_context.dart';
import '../domain/work_context.dart';
import '../domain/work_taxonomy.dart';
import '../domain/worker_identity.dart';
import 'work_context_repository.dart';

/// Deterministic simulation data.
///
/// This is the only place declared outcomes live. Everything here is
/// demonstration data in the `simulated` domain: the work context is a demo
/// reference, and each badge specimen carries a fixed outcome so the same
/// specimen always produces the same result. No value is computed from an image
/// or a calibration model.
abstract final class SimulationCatalog {
  /// A demo worker identity. **No identity provider verified any of this.**
  ///
  /// The contractor variant deliberately matches the published demo account on
  /// the sign-in screen, so the same person appears everywhere a reviewer
  /// looks. The values are duplicated rather than imported — the workflow
  /// domain does not depend on the authentication feature, because this is
  /// stored provenance and must outlive any sign-in redesign — and
  /// `test/workflow/demo_persona_test.dart` fails if the two drift apart.
  static WorkerIdentity demoWorker({
    WorkerType type = WorkerType.contractor,
    String? contractorCompany,
  }) => WorkerIdentity(
    workerId: type == WorkerType.employee ? 'EMP-DEMO-4471' : 'CT-45832',
    displayName: type == WorkerType.employee ? 'Demo Worker' : 'Aditya Jadhav',
    workerType: type,
    source: EnterpriseDataSource.demo,
    contractorCompany: type == WorkerType.contractor
        ? (contractorCompany ?? 'XYZ Engineering')
        : null,
    gatePass: const EnterpriseValue.demo('GP-DEMO-7284'),
  );

  /// A complete demo work context.
  ///
  /// Every reference carries [EnterpriseDataSource.demo], so nothing here can
  /// render as verified. The site name is a plausible label only; DoseBand
  /// claims no integration with MRPL systems.
  ///
  /// Used by tests and by the development "fill with demo data" affordance. It
  /// is not what a worker gets by default — the work-context form starts from
  /// their identity and selected site and is filled in by hand.
  static WorkContext demoContext({
    WorkerType workerType = WorkerType.contractor,
    String siteId = 'mangalore-refinery',
  }) {
    const config = DemoWorkContextRepository();
    final areas = config.workAreas(siteId);
    return WorkContext(
      worker: demoWorker(type: workerType),
      site: SiteRef(id: siteId, name: _demoSiteNames[siteId] ?? siteId),
      department: config.departments().first,
      workArea: areas.first,
      shift: config.shifts()[1],
      job: const JobContext(
        title: 'Routine field round',
        workOrder: 'WO-DEMO-22190',
        supervisor: 'Shift supervisor (demo)',
      ),
      permit: PtwReference(
        reference: const EnterpriseValue.demo('PTW-DEMO-4471'),
        type: config.permitTypes()[1],
      ),
      jsa: const JsaReference(reference: EnterpriseValue.demo('JSA-DEMO-2048')),
      toolboxTalk: ToolboxTalkAcknowledgement(
        acknowledgedAt: DateTime(2026, 9, 25, 5, 50),
        source: EnterpriseDataSource.demo,
      ),
    );
  }

  /// Display names for the seeded sites, so a demo context can name its site
  /// without the workflow reaching into the authentication feature.
  static const Map<String, String> _demoSiteNames = {
    'mangalore-refinery': 'Mangalore Refinery',
    'corporate-office': 'Corporate Office',
    'retail-hiq': 'MRPL Retail (HiQ)',
    'projects-site': 'Projects Site',
  };

  static DateTime _expiryFromNow(int days) =>
      DateTime.now().add(Duration(days: days));

  static const String _formulation = 'Bi-based colorimetric (sim)';
  static const String _calModel = 'cal-sim-1.2.0';
  static const String _geometry = 'geo-sim-3';

  static BadgeValidity _eligible() => const BadgeValidity(
    eligible: true,
    checks: [
      BadgeCheck(label: 'Batch supported', passed: true),
      BadgeCheck(
        label: 'Calibration available',
        passed: true,
        detail: _calModel,
      ),
      BadgeCheck(label: 'Not previously read', passed: true),
      BadgeCheck(label: 'Within validity period', passed: true),
      BadgeCheck(label: 'QR integrity', passed: true),
    ],
  );

  /// The specimens offered in the simulation picker, in demonstration order.
  static List<BadgeSpecimen> specimens() => [
    BadgeSpecimen(
      badgeId: 'DB-4K7M2',
      lot: 'L26-0912-A',
      formulation: _formulation,
      calibrationModelId: _calModel,
      geometryVersion: _geometry,
      expiry: _expiryFromNow(120),
      validity: _eligible(),
      label: 'Valid — mid response',
      description: 'A clean reading inside the quantifiable range.',
      outcome: const ValidOutcome(
        dosePpmHours: 3.2,
        uncertaintyHalfWidth: 0.8,
        uncertaintyBasis:
            'Simulated interval — not a validated coverage claim.',
      ),
    ),
    BadgeSpecimen(
      badgeId: 'DB-4K7Q9',
      lot: 'L26-0912-A',
      formulation: _formulation,
      calibrationModelId: _calModel,
      geometryVersion: _geometry,
      expiry: _expiryFromNow(120),
      validity: _eligible(),
      label: 'Valid — with a caveat',
      description: 'Inside range, but coverage was incomplete.',
      outcome: const ValidOutcome(
        dosePpmHours: 6.4,
        uncertaintyHalfWidth: 1.5,
        uncertaintyBasis:
            'Simulated interval — not a validated coverage claim.',
        warning: 'Coverage was shorter than the assigned monitored period.',
      ),
    ),
    BadgeSpecimen(
      badgeId: 'DB-4K8B1',
      lot: 'L26-0912-A',
      formulation: _formulation,
      calibrationModelId: _calModel,
      geometryVersion: _geometry,
      expiry: _expiryFromNow(120),
      validity: _eligible(),
      label: 'Below measurable range',
      description: 'Response beneath the quantification limit.',
      outcome: const CensoredOutcome(
        status: ResultStatus.belowQuantificationLimit,
        direction: CensorDirection.below,
        boundPpmHours: 0.5,
      ),
    ),
    BadgeSpecimen(
      badgeId: 'DB-4K8C7',
      lot: 'L26-0912-A',
      formulation: _formulation,
      calibrationModelId: _calModel,
      geometryVersion: _geometry,
      expiry: _expiryFromNow(120),
      validity: _eligible(),
      label: 'Above range — saturated',
      description: 'Sensor saturated; a lower bound is retained.',
      outcome: const CensoredOutcome(
        status: ResultStatus.aboveRange,
        direction: CensorDirection.above,
        boundPpmHours: 40,
      ),
    ),
    BadgeSpecimen(
      badgeId: 'DB-4K9D3',
      lot: 'L26-0912-A',
      formulation: _formulation,
      calibrationModelId: _calModel,
      geometryVersion: _geometry,
      expiry: _expiryFromNow(120),
      validity: _eligible(),
      label: 'No reading — reference failure',
      description: 'Reference patches could not be read (glare).',
      outcome: const RefusedOutcome(
        status: ResultStatus.referencePatchFailure,
        reason: ReasonCode('REFERENCE_PATCH_FAILURE', detail: 'glare'),
      ),
    ),
    BadgeSpecimen(
      badgeId: 'DB-4KA55',
      lot: 'L25-0431-C',
      formulation: _formulation,
      calibrationModelId: _calModel,
      geometryVersion: _geometry,
      expiry: _expiryFromNow(-3),
      validity: const BadgeValidity(
        eligible: false,
        checks: [
          BadgeCheck(label: 'Batch supported', passed: true),
          BadgeCheck(
            label: 'Calibration available',
            passed: true,
            detail: _calModel,
          ),
          BadgeCheck(label: 'Not previously read', passed: true),
          BadgeCheck(
            label: 'Within validity period',
            passed: false,
            detail: 'Expired 3 days ago',
          ),
          BadgeCheck(label: 'QR integrity', passed: true),
        ],
      ),
      label: 'Expired badge',
      description: 'Fails verification; assignment is blocked.',
      outcome: const RefusedOutcome(
        status: ResultStatus.badgeExpired,
        reason: ReasonCode('BADGE_EXPIRED'),
      ),
    ),
  ];

  /// Simulation provenance stamped onto every simulated result.
  static Provenance provenance({
    required String? calibrationModelId,
    required String geometryVersion,
    required String appVersion,
    required String deviceModel,
  }) => Provenance(
    algorithmVersion: 'sim-0',
    geometryVersion: geometryVersion,
    calibrationModelId: calibrationModelId,
    referenceProfileId: calibrationModelId == null ? null : 'ref-sim-1',
    appVersion: appVersion,
    deviceModel: deviceModel,
  );
}
