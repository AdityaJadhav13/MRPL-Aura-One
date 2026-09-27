import '../domain/workflow_state.dart';

/// The single narrow seam the workflow persists through.
///
/// Phase 2 proves interruption recovery against the *interface*, so Phase 6 can
/// drop Drift/SQLite behind it without touching the workflow or the screens
/// (implementation-plan.md). An in-memory implementation is enough to exercise
/// the state machine now; it is deliberately the only thing that knows how a
/// session is serialised.
abstract interface class WorkflowStore {
  Future<ShiftSession> load();
  Future<void> save(ShiftSession session);
  Future<void> clear();
}

/// Process-lifetime store. Survives navigation but not a cold start. Real
/// interruption recovery lands with the persistent store in Phase 6; this keeps
/// the seam honest in the meantime.
final class InMemoryWorkflowStore implements WorkflowStore {
  ShiftSession _session = ShiftSession.none;

  @override
  Future<ShiftSession> load() async => _session;

  @override
  Future<void> save(ShiftSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = ShiftSession.none;
}

/// One store per worker (PRODUCT BUILD v1 §14, §145).
///
/// A phone may be shared across a crew, or a presenter may sign in as each
/// person in turn. A single session file would hand one worker's open period
/// to whoever signed in next; keying by person keeps each period with the
/// person wearing the band.
abstract interface class WorkflowStoreFactory {
  WorkflowStore forWorker(String workerId);
}

final class InMemoryWorkflowStoreFactory implements WorkflowStoreFactory {
  final Map<String, InMemoryWorkflowStore> _stores = {};

  @override
  WorkflowStore forWorker(String workerId) =>
      _stores.putIfAbsent(workerId, InMemoryWorkflowStore.new);
}
