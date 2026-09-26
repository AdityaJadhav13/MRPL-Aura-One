import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:measurement/measurement.dart';

import '../data/simulation_catalog.dart';
import '../data/workflow_store.dart';
import '../domain/badge_specimen.dart';
import '../domain/work_context.dart';
import '../domain/workflow_state.dart';

/// The active store. Overridden in tests and, later, swapped for the persistent
/// implementation without any screen changing.
final workflowStoreProvider = Provider<WorkflowStore>(
  (_) => InMemoryWorkflowStore(),
);

/// The wall clock, injectable.
///
/// Home renders today's date and decides several of its states by comparing
/// the session against *now*, so a screen that calls `DateTime.now()` directly
/// is a screen whose output changes with the day. That made the Home goldens
/// fail every midnight — a golden that fails on a calendar boundary trains
/// people to regenerate goldens without looking at them, which is exactly the
/// value ADR-0010 says goldens exist to provide.
///
/// Overridden in tests with a fixed instant. Production reads the real clock,
/// which is still untrusted for measurement purposes — see the untrusted-clock
/// handling in `HomePresentation`.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

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
  Future<ShiftSession> build() => _store.load();

  Future<void> _commit(ShiftSession next) async {
    await _store.save(next);
    state = AsyncData(next);
  }

  ShiftSession get _current {
    final s = state;
    return s is AsyncData<ShiftSession> ? s.value : ShiftSession.none;
  }

  /// Records the work context. Rejected once monitoring has begun.
  Future<void> setContext(WorkContext context) {
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
    if (session.badge == null) {
      throw StateError('startMonitoring called with no assigned badge');
    }
    return _commit(
      session.copyWith(stage: ShiftStage.monitoring, startedAt: DateTime.now()),
    );
  }

  Future<void> endMonitoring() => _commit(
    _current.copyWith(stage: ShiftStage.awaitingScan, endedAt: DateTime.now()),
  );

  /// Plays the assigned specimen's declared outcome through the real result
  /// state machine. Nothing is measured; the specimen already knows what it is.
  Future<MeasurementResult> completeScan() async {
    final session = _current;
    final badge = session.badge;
    if (badge == null) {
      throw StateError('completeScan called with no assigned badge');
    }
    final result = _resultFor(badge, session);
    await _commit(session.copyWith(stage: ShiftStage.complete, result: result));
    return result;
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
