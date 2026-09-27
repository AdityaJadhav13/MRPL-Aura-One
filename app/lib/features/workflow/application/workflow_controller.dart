import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:measurement/measurement.dart';

import '../../../core/domain/doseband.dart';
import '../../../core/domain/doseband_registry.dart';
import '../../../core/domain/monitoring_session.dart';
import '../../../core/time/clock.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../history/domain/measurement_record.dart';
import '../../operations/application/local_doseband_registry.dart';
import '../../operations/application/operations_repository.dart';
import '../../operations/application/worker_service.dart';
import '../../operations/domain/assignment.dart';
import '../data/simulation_catalog.dart';
import '../data/workflow_store.dart';
import '../domain/badge_specimen.dart';
import '../domain/physical_badge.dart';
import '../domain/work_context.dart';
import '../domain/workflow_state.dart';
import 'session_reconciliation.dart';

export '../../../core/time/clock.dart' show clockProvider;

/// Per-worker session stores. Overridden at the application root with the
/// file-backed factory.
final workflowStoreFactoryProvider = Provider<WorkflowStoreFactory>(
  (_) => InMemoryWorkflowStoreFactory(),
);

/// The signed-in worker's session store. Tests may override this directly
/// with a single store.
final workflowStoreProvider = Provider<WorkflowStore>((ref) {
  final id = ref.watch(currentActorProvider.select((a) => a?.personId));
  return ref.watch(workflowStoreFactoryProvider).forWorker(id ?? '-');
});

/// The DoseBand registry the worker claims against: the on-device operations
/// store. A server-backed registry replaces this provider, not the screens.
final dosebandRegistryProvider = Provider<LocalDoseBandRegistry>(
  (ref) => LocalDoseBandRegistry(
    repository: ref.watch(operationsProvider.notifier),
    ids: ref.watch(idGeneratorProvider),
    now: ref.watch(clockProvider),
  ),
);

/// The worker's current monitored period.
///
/// Every transition writes to the store before the new state is exposed, so the
/// persisted snapshot leads the UI rather than trailing it. Transitions are
/// explicit methods, not a generic setter: the workflow order is a product
/// invariant, not a convenience.
final shiftSessionProvider =
    AsyncNotifierProvider<ShiftSessionController, ShiftSession>(
      ShiftSessionController.new,
    );

class ShiftSessionController extends AsyncNotifier<ShiftSession> {
  WorkflowStore get _store => ref.read(workflowStoreProvider);

  @override
  Future<ShiftSession> build() async {
    final store = ref.watch(workflowStoreProvider);
    final local = await store.load();
    final actor = ref.watch(currentActorProvider);
    if (actor == null || actor.role != AppRole.worker) return local;
    final ops = await ref.read(operationsProvider.future);
    final reconciled = SessionReconciliation.reconcile(
      local: local,
      snapshot: ops,
      workerId: actor.personId,
    );
    if (!identical(reconciled, local)) await store.save(reconciled);
    return reconciled;
  }

  /// The worker's own commands against the operations store. Null when no
  /// worker is signed in — then there is no organisational record to write,
  /// and the device-local journey (development simulation) runs alone.
  WorkerCommands? get _ops {
    final actor = ref.read(currentActorProvider);
    if (actor == null || actor.role != AppRole.worker) return null;
    return WorkerCommands(
      repository: ref.read(operationsProvider.notifier),
      actor: actor,
      ids: ref.read(idGeneratorProvider),
      now: ref.read(clockProvider),
    );
  }

  Future<MonitoringSession?> _opsSession(String? id) async => id == null
      ? null
      : (await ref.read(operationsProvider.future)).session(id);

  Future<void> _commit(ShiftSession next) async {
    await _store.save(next);
    state = AsyncData(next);
  }

  ShiftSession get _current {
    final s = state;
    return s is AsyncData<ShiftSession> ? s.value : ShiftSession.none;
  }

  /// Records the work context. Rejected while a period is open. After a
  /// completed period it starts the next one: the finished period's record is
  /// already in the operations store, and the device session moves on.
  Future<void> setContext(WorkContext context) {
    if (_current.stage == ShiftStage.complete) {
      return _commit(
        ShiftSession(stage: ShiftStage.contextSet, context: context),
      );
    }
    _refuseIfLocked('the work context');
    return _commit(
      _current.copyWith(stage: ShiftStage.contextSet, context: context),
    );
  }

  /// Assigns a badge. Rejected once monitoring has begun.
  Future<void> assignBadge(BadgeSpecimen badge) {
    _refuseIfLocked('the assigned badge');
    return _commit(
      _current.copyWith(stage: ShiftStage.badgeAssigned, badge: badge),
    );
  }

  /// Assigns a real badge, identified by hand. Rejected once monitoring has
  /// begun. Clears any simulated specimen: a session has one badge.
  Future<void> assignPhysicalBadge(PhysicalBadge badge) {
    _refuseIfLocked('the assigned badge');
    if (badge.badgeId.trim().isEmpty) {
      throw ArgumentError('a physical badge needs an id');
    }
    return _commit(
      _current.copyWith(stage: ShiftStage.badgeAssigned, physicalBadge: badge),
    );
  }

  Future<void> confirmPreWork() =>
      _commit(_current.copyWith(stage: ShiftStage.readyForDosimetry));

  /// Guards everything that would rewrite an exposure record's provenance.
  ///
  /// From the moment monitoring starts, the work context and the badge stop
  /// being form state and become the answer to "whose reading is this, taken
  /// where, during what work". Editing them in place would leave a measurement
  /// attributed to a site, area, permit or worker that was not in force while
  /// the badge was actually exposed — a record that looks complete and is
  /// quietly wrong, which is worse than one that is obviously missing.
  ///
  /// This throws rather than returning a failure because no screen offers these
  /// actions during monitoring: reaching here is a defect, not a user mistake.
  /// A worker who genuinely needs a correction ends the period and starts a new
  /// one, so the old record keeps its own provenance.
  void _refuseIfLocked(String what) {
    if (_current.contextIsLocked) {
      throw WorkflowLockedError(
        'Cannot change $what once monitoring has started '
        '(stage: ${_current.stage.name}). End the monitored period and start a '
        'new one instead.',
      );
    }
  }

  /// Begins the monitored period.
  ///
  /// Guarded independently of the screens. The pre-work check already refuses
  /// to enable its button until [WorkContextValidator] is satisfied, but that
  /// is one screen's opinion: a deep link, a restored session or a future
  /// caller could reach this directly. From this call onwards a physical badge
  /// is accumulating exposure that will be attributed to whatever context is
  /// on the session, so "started with no context" must be impossible rather
  /// than merely unreachable through the current UI.
  Future<void> startMonitoring() {
    final session = _current;
    if (session.context == null) {
      throw StateError(
        'startMonitoring called with no work context. An exposure record '
        'cannot be attributed to a worker, site, area or permit that was '
        'never recorded.',
      );
    }
    if (session.assignedBadge == null) {
      throw StateError('startMonitoring called with no assigned badge');
    }
    return _commit(
      session.copyWith(stage: ShiftStage.monitoring, startedAt: DateTime.now()),
    );
  }

  /// Ends monitoring. For a claimed DoseBand the operations store records the
  /// end first and the device session takes its timestamp from there, so the
  /// two can never disagree about when the window closed.
  Future<void> endMonitoring() async {
    final session = _current;
    final ops = _ops;
    if (ops != null && session.sessionId != null) {
      await ops.endMonitoring(sessionId: session.sessionId!);
      final x = await _opsSession(session.sessionId);
      return _commit(
        session.copyWith(stage: ShiftStage.awaitingScan, endedAt: x?.endedAt),
      );
    }
    return _commit(
      session.copyWith(stage: ShiftStage.awaitingScan, endedAt: DateTime.now()),
    );
  }

  /// Claims [band] for the signed-in worker and starts monitoring, as one
  /// step the worker confirmed (PRODUCT BUILD v1 §7, §12).
  ///
  /// The operations store decides the claim atomically; only an accepted
  /// claim reaches the device session. The work context must already be
  /// recorded: from the first second the band is exposed, its record needs
  /// to say whose, where and during what work.
  Future<ClaimResult> claimAndStart({
    required DoseBand band,
    required PreUseRecord preUse,
  }) async {
    final session = _current;
    final context = session.context;
    if (context == null) {
      throw StateError('claimAndStart needs a recorded work context');
    }
    if (session.stage == ShiftStage.monitoring ||
        session.stage == ShiftStage.awaitingScan) {
      return const ClaimWorkerHasActiveBand();
    }
    final ops = _ops;
    final actor = ref.read(currentActorProvider);
    if (ops == null || actor == null) {
      throw StateError('claimAndStart needs a signed-in worker');
    }
    final result = await ref
        .read(dosebandRegistryProvider)
        .claimWith(
          dosebandId: band.dosebandId,
          workerId: actor.personId,
          preUse: preUse,
          work: SessionReconciliation.summaryOf(context),
        );
    if (result is! ClaimAccepted) return result;

    final snapshot = await ref.read(operationsProvider.future);
    final assignment = snapshot.assignment(result.assignmentId)!;
    await ops.startMonitoring(sessionId: assignment.sessionId);
    final started = await _opsSession(assignment.sessionId);
    final lot = snapshot.lot(band.lotId);
    await _commit(
      ShiftSession(
        stage: ShiftStage.monitoring,
        context: context,
        physicalBadge: PhysicalBadge(
          badgeId: band.dosebandId,
          batchId: band.lotId,
          formulationId: band.formulationId,
          expiresOn: lot?.expiresOn,
          source: BadgeIdentitySource.localRegistry,
          identifiedAt: assignment.claimedAt,
        ),
        startedAt: started?.startedAt,
        sessionId: assignment.sessionId,
        assignmentId: assignment.assignmentId,
      ),
    );
    return result;
  }

  /// Clears a completed period so the next one can begin, keeping the work
  /// context as a starting point only if it was recorded today.
  Future<void> startNewPeriod() async {
    final session = _current;
    if (session.stage == ShiftStage.monitoring ||
        session.stage == ShiftStage.awaitingScan) {
      throw WorkflowLockedError(
        'A monitored period is still open (${session.stage.name}).',
      );
    }
    await _commit(ShiftSession.none);
  }

  /// The worn DoseBand was damaged or lost. The period is interrupted in the
  /// operations store and closed on this device; the worker can claim a
  /// replacement for a new period.
  Future<void> reportDoseBand(DoseBandLifecycle condition) async {
    final session = _current;
    final ops = _ops;
    if (ops == null || session.sessionId == null) {
      throw StateError('reportDoseBand needs a claimed DoseBand');
    }
    await ops.reportDoseBand(
      sessionId: session.sessionId!,
      condition: condition,
    );
    await _commit(ShiftSession.none);
  }

  /// Plays the assigned specimen's declared outcome through the real result
  /// state machine. Nothing is measured; the specimen already knows what it is.
  Future<MeasurementResult> completeScan() async {
    final session = _current;
    if (session.isPhysical) {
      // A physical badge's result comes from a photograph. Playing back a
      // declared outcome for it would attach a simulation to a real badge.
      throw StateError(
        'completeScan is the simulation path; a physical badge is completed '
        'by completePhysicalScan with a result from a real capture',
      );
    }
    final badge = session.badge;
    if (badge == null) {
      throw StateError('completeScan called with no assigned badge');
    }
    final result = _resultFor(badge, session);
    await _commit(session.copyWith(stage: ShiftStage.complete, result: result));
    return result;
  }

  /// Records the result of a real capture of the session's physical badge,
  /// and returns the measurement record it made.
  ///
  /// [result] is whatever the real pipeline produced — today always a
  /// refusal, because no calibration exists. [captureId] ties the session to
  /// the archived photograph and record it came from. §76. For a claimed
  /// DoseBand the record is written to the operations store first — the
  /// organisational record — and only then is the device session closed.
  Future<MeasurementRecord> completePhysicalScan({
    required MeasurementResult result,
    required String captureId,
    required DataDomain domain,
  }) async {
    final session = _current;
    final badge = session.physicalBadge;
    final context = session.context;
    if (!session.isPhysical || badge == null || context == null) {
      throw StateError('completePhysicalScan called without a physical badge');
    }
    if (session.stage != ShiftStage.awaitingScan) {
      throw StateError(
        'completePhysicalScan called at ${session.stage.name}; the monitored '
        'period must have ended first',
      );
    }
    final scannedAt = ref.read(clockProvider)();
    final actor = ref.read(currentActorProvider);
    final record = MeasurementRecord(
      id: captureId,
      result: result,
      badge: badge,
      context: context,
      startedAt: session.startedAt ?? scannedAt,
      endedAt: session.endedAt ?? scannedAt,
      scannedAt: scannedAt,
      domain: domain,
      captureId: captureId,
      workerId: actor?.personId ?? context.worker.workerId,
      sessionId: session.sessionId,
    );
    final ops = _ops;
    if (ops != null && session.sessionId != null) {
      await ops.recordMeasurement(record);
    }
    await _commit(
      session.copyWith(
        stage: ShiftStage.complete,
        result: result,
        captureId: captureId,
      ),
    );
    return record;
  }

  /// Ends the whole monitored period and returns to no-shift.
  Future<void> reset() async {
    await _store.clear();
    state = const AsyncData(ShiftSession.none);
  }

  MeasurementResult _resultFor(BadgeSpecimen badge, ShiftSession session) {
    final outcome = badge.outcome;
    final coverage = session.coverageAt(session.endedAt ?? DateTime.now());
    final coversDose = outcome is ValidOutcome;
    final provenance = SimulationCatalog.provenance(
      calibrationModelId: coversDose ? badge.calibrationModelId : null,
      geometryVersion: badge.geometryVersion,
      appVersion: '0.1.0+1',
      deviceModel: 'Simulator',
    );

    // A dose is a concentration integrated over an exposure window. If the
    // window itself is not established, the integral has no meaning, and the
    // specimen's declared dose would be attributed to a period we cannot state.
    // This is the one place the declared outcome is overridden, and it can only
    // ever be overridden towards a refusal.
    if (coversDose && coverage == null) {
      return Refused(
        status: ResultStatus.resultUnreliable,
        reasons: const [
          ReasonCode(
            'EXPOSURE_WINDOW_UNTRUSTED',
            detail:
                'The monitored period ended before it started, so its duration '
                'cannot be established. The device clock was most likely '
                'changed while monitoring was active.',
          ),
        ],
        provenance: SimulationCatalog.provenance(
          calibrationModelId: null,
          geometryVersion: badge.geometryVersion,
          appVersion: '0.1.0+1',
          deviceModel: 'Simulator',
        ),
      );
    }

    return switch (outcome) {
      ValidOutcome(
        :final dosePpmHours,
        :final uncertaintyHalfWidth,
        :final uncertaintyBasis,
        :final warning,
      ) =>
        Valid(
          dose: Dose.ppmHours(dosePpmHours),
          uncertainty: Uncertainty(
            halfWidth: uncertaintyHalfWidth,
            basis: uncertaintyBasis,
          ),
          coverage: coverage!,
          provenance: provenance,
          warnings: warning == null
              ? const []
              : [ReasonCode('PARTIAL_SHIFT', detail: warning)],
        ),
      CensoredOutcome(:final status, :final direction, :final boundPpmHours) =>
        Censored(
          status: status,
          direction: direction,
          bound: boundPpmHours == null ? null : Dose.ppmHours(boundPpmHours),
          reasons: [
            ReasonCode(
              direction == CensorDirection.above
                  ? 'ABOVE_RANGE'
                  : 'BELOW_QUANTIFICATION_LIMIT',
            ),
          ],
          provenance: provenance,
        ),
      RefusedOutcome(:final status, :final reason) => Refused(
        status: status,
        reasons: [reason],
        provenance: provenance,
      ),
    };
  }
}
