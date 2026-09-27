import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:h2s_doseband/core/domain/doseband.dart';
import 'package:h2s_doseband/core/domain/monitoring_session.dart';
import 'package:h2s_doseband/core/domain/provenance.dart';
import 'package:h2s_doseband/core/router/route_gate.dart';
import 'package:h2s_doseband/features/history/domain/measurement_record.dart';
import 'package:h2s_doseband/features/operations/domain/assignment.dart';
import 'package:h2s_doseband/features/operations/domain/review.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/domain/physical_badge.dart';
import 'package:measurement/measurement.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:h2s_doseband/core/time/clock.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/operations/domain/operations_snapshot.dart';

/// An auth controller already signed in as [session]. Sign-in itself is
/// covered by the auth tests; everything else starts past it.
class SignedInAs extends AuthController {
  SignedInAs(this.session);

  final AppSession session;

  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, session: session);
}

/// A presentation account's session in [role] (default: its first).
AppSession presentationSession(String personId, {AppRole? role}) {
  final p = PresentationDataset.people.firstWhere(
    (x) => x.personId == personId,
  );
  return AppSession(
    personId: p.personId,
    displayName: p.displayName,
    roles: p.roles,
    activeRole: role ?? p.roles.first,
    source: AuthSource.demo,
  );
}

/// The presentation dataset with nobody part-way through a period: every
/// band available, no assignments, no sessions. For screens that start a
/// period from scratch.
OperationsSnapshot quietDataset(DateTime now) {
  final s = PresentationDataset.build(now);
  return s.copyWith(
    assignments: const [],
    sessions: const [],
    bands: {
      for (final e in s.bands.entries)
        e.key: DoseBand(
          dosebandId: e.value.dosebandId,
          lifecycle: DoseBandLifecycle.available,
          provenance: e.value.provenance,
          lotId: e.value.lotId,
          formulationId: e.value.formulationId,
          expiry: e.value.expiry,
          geometryVersion: e.value.geometryVersion,
        ),
    },
  );
}

/// Overrides that put a test signed in as [personId], over an operations
/// store seeded with [seed] (default: [quietDataset]) at [now].
List<Override> signedInOverrides({
  required String personId,
  AppRole? role,
  OperationsSnapshot? seed,
  DateTime? now,
  OperationsStore? store,
}) {
  final t = now ?? DateTime(2026, 9, 27, 10, 30);
  return [
    authControllerProvider.overrideWith(
      () => SignedInAs(presentationSession(personId, role: role)),
    ),
    operationsStoreProvider.overrideWithValue(
      store ?? InMemoryOperationsStore(seed ?? quietDataset(t)),
    ),
    idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
    clockProvider.overrideWithValue(() => t),
  ];
}

/// Who a route sweep signs in as: the account whose workspace the route
/// belongs to, so every screen renders with the data its role would see.
/// Shared routes (splash, sign-in, developer tools) run as the worker.
String personForRoute(String route) => switch (RouteGate.workspaceOf(route)) {
  AppRole.supervisor => PresentationDataset.aman,
  AppRole.hseOfficer => PresentationDataset.samhita,
  AppRole.management || AppRole.administrator => PresentationDataset.yashvi,
  AppRole.worker || null => PresentationDataset.aditya,
};

/// Overrides for sweeping [route]: signed in as its owner, over the full
/// presentation dataset.
List<Override> routeOverrides(String route, {DateTime? now}) {
  final t = now ?? DateTime(2026, 9, 27, 10, 30);
  return signedInOverrides(
    personId: personForRoute(route),
    role: RouteGate.workspaceOf(route),
    seed: datasetWithRecord(t),
    now: t,
  );
}

/// The operations store as it would be for [s]: a registered open period
/// has its assignment and session there too, or reconciliation would
/// (rightly) clear the device session as closed elsewhere.
OperationsSnapshot seedForSession(ShiftSession s, DateTime now) {
  final base = quietDataset(now);
  final open =
      s.stage == ShiftStage.monitoring || s.stage == ShiftStage.awaitingScan;
  if (s.sessionId == null || !open) return base;
  final band = base.bands['DB-2609-0010']!;
  return base.copyWith(
    bands: {
      ...base.bands,
      band.dosebandId: DoseBand(
        dosebandId: band.dosebandId,
        lifecycle: s.stage == ShiftStage.monitoring
            ? DoseBandLifecycle.monitoring
            : DoseBandLifecycle.readyForFinalRead,
        provenance: band.provenance,
        lotId: band.lotId,
        formulationId: band.formulationId,
        expiry: band.expiry,
        assignmentId: 'ASG-1',
        geometryVersion: band.geometryVersion,
      ),
    },
    assignments: [
      DoseBandAssignment(
        assignmentId: 'ASG-1',
        dosebandId: band.dosebandId,
        workerId: PresentationDataset.aditya,
        sessionId: 'SES-1',
        claimedAt: s.startedAt ?? now,
        state: AssignmentState.active,
      ),
    ],
    sessions: [
      MonitoringSession(
        sessionId: 'SES-1',
        workerId: PresentationDataset.aditya,
        state: s.stage == ShiftStage.monitoring
            ? MonitoringSessionState.active
            : MonitoringSessionState.readyForFinalRead,
        provenance: RecordProvenance.realLocal,
        dosebandId: band.dosebandId,
        assignmentId: 'ASG-1',
        startedAt: s.startedAt,
        endedAt: s.endedAt,
      ),
    ],
  );
}

/// The presentation dataset plus one completed period for Aditya, closed by a
/// real-capture refusal (no calibration) awaiting HSE review — the state
/// the live demonstration produces.
OperationsSnapshot datasetWithRecord(DateTime now) {
  final base = PresentationDataset.build(now);
  const band = 'DB-2609-0010';
  final start = now.subtract(const Duration(hours: 8));
  final end = now.subtract(const Duration(minutes: 20));
  final record = MeasurementRecord(
    id: 'CAP-TEST-1',
    result: Refused(
      status: ResultStatus.unsupportedCalibration,
      reasons: const [ReasonCode('NO_CALIBRATION_MODEL')],
      provenance: const Provenance(
        algorithmVersion: 'm0a',
        geometryVersion: 'badge-v1-research',
        calibrationModelId: null,
        referenceProfileId: null,
        appVersion: 'test',
        deviceModel: 'Test phone',
      ),
    ),
    badge: PhysicalBadge(
      badgeId: band,
      batchId: PresentationDataset.currentLot,
      identifiedAt: start,
      source: BadgeIdentitySource.localRegistry,
    ),
    context: SimulationCatalog.demoContext(),
    startedAt: start,
    endedAt: end,
    scannedAt: end.add(const Duration(minutes: 2)),
    domain: DataDomain.field,
    captureId: 'CAP-TEST-1',
    workerId: PresentationDataset.aditya,
    sessionId: 'SES-REC-1',
  );
  final b = base.bands[band]!;
  return base.copyWith(
    bands: {
      ...base.bands,
      band: DoseBand(
        dosebandId: band,
        lifecycle: DoseBandLifecycle.read,
        provenance: b.provenance,
        lotId: b.lotId,
        formulationId: b.formulationId,
        expiry: b.expiry,
        assignmentId: 'ASG-REC-1',
        geometryVersion: b.geometryVersion,
      ),
    },
    assignments: [
      ...base.assignments,
      DoseBandAssignment(
        assignmentId: 'ASG-REC-1',
        dosebandId: band,
        workerId: PresentationDataset.aditya,
        sessionId: 'SES-REC-1',
        claimedAt: start,
        state: AssignmentState.completed,
        endedAt: record.scannedAt,
      ),
    ],
    sessions: [
      ...base.sessions,
      MonitoringSession(
        sessionId: 'SES-REC-1',
        workerId: PresentationDataset.aditya,
        state: MonitoringSessionState.readComplete,
        provenance: RecordProvenance.realLocal,
        dosebandId: band,
        assignmentId: 'ASG-REC-1',
        startedAt: start,
        endedAt: end,
        measurementId: record.id,
        work: const WorkSummary(
          siteId: PresentationDataset.siteId,
          siteName: PresentationDataset.siteName,
          departmentId: 'maintenance',
          departmentName: 'Maintenance',
          workAreaId: 'sru',
          workAreaName: 'Sulphur Recovery Unit — Demo area',
        ),
      ),
    ],
    measurements: [record],
    reviews: [
      HseReview(
        reviewId: 'REV-REC-1',
        measurementId: record.id,
        state: ReviewState.pending,
        openedAt: record.scannedAt,
        updatedAt: record.scannedAt,
      ),
    ],
  );
}
