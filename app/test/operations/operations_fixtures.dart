import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:h2s_doseband/core/time/clock.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/history/domain/measurement_record.dart';
import 'package:h2s_doseband/features/operations/application/access.dart';
import 'package:h2s_doseband/features/operations/application/local_doseband_registry.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/application/worker_service.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/operations/domain/operations_snapshot.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/domain/physical_badge.dart';
import 'package:measurement/measurement.dart';

/// A fixed instant for every operations test: mid-morning, so the seeded
/// "since two hours ago" session is today and yesterday's is yesterday.
final DateTime fixedNow = DateTime(2026, 9, 27, 10, 30);

const Actor aditya = Actor(
  personId: PresentationDataset.aditya,
  role: AppRole.worker,
);
const Actor lavitra = Actor(
  personId: PresentationDataset.lavitra,
  role: AppRole.worker,
);
const Actor nikhil = Actor(
  personId: PresentationDataset.nikhil,
  role: AppRole.worker,
);
const Actor aman = Actor(
  personId: PresentationDataset.aman,
  role: AppRole.supervisor,
);
const Actor samhita = Actor(
  personId: PresentationDataset.samhita,
  role: AppRole.hseOfficer,
);
const Actor yashviManagement = Actor(
  personId: PresentationDataset.yashvi,
  role: AppRole.management,
);
const Actor yashviAdmin = Actor(
  personId: PresentationDataset.yashvi,
  role: AppRole.administrator,
);

/// A container whose operations store starts from [seed] (default: the
/// presentation dataset at [fixedNow]).
ProviderContainer opsContainer({
  OperationsStore? store,
  DateTime? now,
  OperationsSnapshot? seed,
}) {
  final t = now ?? fixedNow;
  return ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(() => t),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      operationsStoreProvider.overrideWithValue(
        store ?? InMemoryOperationsStore(seed ?? PresentationDataset.build(t)),
      ),
    ],
  );
}

LocalDoseBandRegistry registryOf(ProviderContainer c) => LocalDoseBandRegistry(
  repository: c.read(operationsProvider.notifier),
  ids: c.read(idGeneratorProvider),
  now: c.read(clockProvider),
);

WorkerCommands workerOf(ProviderContainer c, Actor actor) => WorkerCommands(
  repository: c.read(operationsProvider.notifier),
  actor: actor,
  ids: c.read(idGeneratorProvider),
  now: c.read(clockProvider),
);

Future<OperationsSnapshot> snap(ProviderContainer c) =>
    c.read(operationsProvider.future);

/// A real-capture refusal record, as the final scan produces today: no
/// calibration exists, so no value.
MeasurementRecord refusalRecord({
  required String id,
  required String workerId,
  required String sessionId,
  required String dosebandId,
  DateTime? scannedAt,
  ResultStatus status = ResultStatus.unsupportedCalibration,
  String? supersedesId,
  String? supersessionReason,
}) {
  final t = scannedAt ?? fixedNow;
  return MeasurementRecord(
    id: id,
    result: Refused(
      status: status,
      reasons: const [ReasonCode('NO_CALIBRATION_MODEL')],
      provenance: const Provenance(
        algorithmVersion: 'cv-test',
        geometryVersion: 'badge-v1-research',
        calibrationModelId: null,
        referenceProfileId: null,
        appVersion: 'test',
        deviceModel: 'test',
      ),
    ),
    badge: PhysicalBadge(
      badgeId: dosebandId,
      identifiedAt: t,
      source: BadgeIdentitySource.localRegistry,
    ),
    context: SimulationCatalog.demoContext(),
    startedAt: t.subtract(const Duration(hours: 8)),
    endedAt: t.subtract(const Duration(minutes: 5)),
    scannedAt: t,
    domain: DataDomain.field,
    captureId: 'CAP-$id',
    workerId: workerId,
    sessionId: sessionId,
    supersedesId: supersedesId,
    supersessionReason: supersessionReason,
  );
}
