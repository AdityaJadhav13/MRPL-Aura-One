import '../../features/workflow/data/simulation_catalog.dart';
import '../../features/workflow/data/workflow_store.dart';
import '../../features/workflow/domain/workflow_state.dart';
import '../env/environment.dart';

/// Development-only preview of the Worker Home states.
///
/// Home has nine states and one architecture. Reviewing them by hand means
/// walking the whole workflow each time — record a context, assign a badge,
/// pass the pre-work check, start monitoring — which is slow and makes the
/// rarer states (an untrusted clock, a scan still outstanding) effectively
/// unreachable during a review.
///
/// This seeds the workflow store directly and starts the app on a chosen
/// route, so any state can be opened in one command:
///
/// ```
/// flutter run \
///   --dart-define=DOSEBAND_INITIAL_ROUTE=/home \
///   --dart-define=DOSEBAND_HOME_STATE=monitoring
/// ```
///
/// ## Why this cannot reach production
///
/// It is gated on [EnvironmentConfig.simulationAvailable], the same flag that
/// compiles the design-system gallery and the dossier capture tool out of
/// release builds. A production build ignores both defines entirely: there is
/// no switch in the worker's UI and no way to ask for one.
///
/// The seeded session uses `SimulationCatalog` data, so anything it produces
/// is already marked as simulated and can never become a production record.
abstract final class HomeStatePreview {
  static const String _routeDefine = String.fromEnvironment(
    'DOSEBAND_INITIAL_ROUTE',
  );

  static const String _stateDefine = String.fromEnvironment(
    'DOSEBAND_HOME_STATE',
  );

  /// The route to start on, or null to use the normal splash entry.
  static String? initialRoute(EnvironmentConfig config) {
    if (!config.simulationAvailable) return null;
    return _routeDefine.isEmpty ? null : _routeDefine;
  }

  /// Seeds [store] with the requested state. A no-op in production, and a
  /// no-op when no state was asked for.
  static Future<void> seed(
    EnvironmentConfig config,
    WorkflowStore store,
  ) async {
    if (!config.simulationAvailable || _stateDefine.isEmpty) return;

    final session = _sessionFor(_stateDefine);
    if (session != null) await store.save(session);
  }

  /// The states worth reviewing, by name.
  static const List<String> names = [
    'no-context',
    'awaiting-badge',
    'badge-assigned',
    'ready',
    'monitoring',
    'scan-required',
    'untrusted-clock',
  ];

  static ShiftSession? _sessionFor(String name) {
    final now = DateTime.now();
    final context = SimulationCatalog.demoContext();
    final badge = SimulationCatalog.specimens().first;

    return switch (name) {
      'no-context' => ShiftSession.none,
      'awaiting-badge' => ShiftSession(
        stage: ShiftStage.contextSet,
        context: context,
      ),
      'badge-assigned' => ShiftSession(
        stage: ShiftStage.badgeAssigned,
        context: context,
        badge: badge,
      ),
      'ready' => ShiftSession(
        stage: ShiftStage.readyForDosimetry,
        context: context,
        badge: badge,
      ),
      'monitoring' => ShiftSession(
        stage: ShiftStage.monitoring,
        context: context,
        badge: badge,
        startedAt: now.subtract(const Duration(hours: 3, minutes: 42)),
      ),
      'scan-required' => ShiftSession(
        stage: ShiftStage.awaitingScan,
        context: context,
        badge: badge,
        startedAt: now.subtract(const Duration(hours: 7, minutes: 52)),
        endedAt: now,
      ),
      // The window runs backwards, as it would after the device clock moved.
      'untrusted-clock' => ShiftSession(
        stage: ShiftStage.monitoring,
        context: context,
        badge: badge,
        startedAt: now.add(const Duration(hours: 3)),
      ),
      _ => null,
    };
  }
}
