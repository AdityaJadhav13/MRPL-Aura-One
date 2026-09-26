import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/util/async_value_x.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/badge_specimen.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:measurement/measurement.dart';

BadgeSpecimen _byLabel(String label) =>
    SimulationCatalog.specimens().firstWhere((s) => s.label == label);

void main() {
  late WorkflowStore store;
  late ProviderContainer container;

  setUp(() {
    store = InMemoryWorkflowStore();
    container = ProviderContainer(
      overrides: [workflowStoreProvider.overrideWithValue(store)],
    );
  });

  tearDown(() => container.dispose());

  Future<ShiftSession> current() async {
    await container.read(shiftSessionProvider.future);
    return container.read(shiftSessionProvider).dataOrNull ?? ShiftSession.none;
  }

  group('the workflow advances one stage at a time', () {
    test('a valid specimen runs to a dose', () async {
      final n = container.read(shiftSessionProvider.notifier);
      await container.read(shiftSessionProvider.future);

      await n.setContext(SimulationCatalog.demoContext());
      expect((await current()).stage, ShiftStage.contextSet);

      await n.assignBadge(_byLabel('Valid — mid response'));
      expect((await current()).stage, ShiftStage.badgeAssigned);

      await n.confirmPreWork();
      expect((await current()).stage, ShiftStage.readyForDosimetry);

      await n.startMonitoring();
      final started = await current();
      expect(started.stage, ShiftStage.monitoring);
      expect(started.startedAt, isNotNull);

      await n.endMonitoring();
      expect((await current()).stage, ShiftStage.awaitingScan);

      final result = await n.completeScan();
      expect((await current()).stage, ShiftStage.complete);
      expect(result, isA<Valid>());
      expect((result as Valid).dose.value, 3.2);
    });
  });

  group('a refusal is never a number', () {
    test('a reference failure returns Refused with no dose', () async {
      final n = container.read(shiftSessionProvider.notifier);
      await container.read(shiftSessionProvider.future);
      await n.setContext(SimulationCatalog.demoContext());
      await n.assignBadge(_byLabel('No reading — reference failure'));
      await n.confirmPreWork();
      await n.startMonitoring();
      await n.endMonitoring();

      final result = await n.completeScan();

      expect(result, isA<Refused>());
      expect(result.status.isRefusal, isTrue);
      // The type itself makes a dose impossible; assert the reason is explained.
      expect(result.reasons, isNotEmpty);
    });

    test(
      'an expired badge is refused and carries a calibration-free provenance',
      () async {
        final n = container.read(shiftSessionProvider.notifier);
        await container.read(shiftSessionProvider.future);
        await n.setContext(SimulationCatalog.demoContext());
        await n.assignBadge(_byLabel('Expired badge'));
        await n.confirmPreWork();
        await n.startMonitoring();
        await n.endMonitoring();

        final result = await n.completeScan();

        expect(result, isA<Refused>());
        expect(result.provenance.calibrationModelId, isNull);
      },
    );
  });

  group('persistence leads the UI', () {
    test('a fresh controller on the same store resumes mid-workflow', () async {
      final n = container.read(shiftSessionProvider.notifier);
      await container.read(shiftSessionProvider.future);
      await n.setContext(SimulationCatalog.demoContext());
      await n.assignBadge(_byLabel('Valid — mid response'));

      // A new container over the same store — as if the app were reopened.
      final resumed = ProviderContainer(
        overrides: [workflowStoreProvider.overrideWithValue(store)],
      );
      addTearDown(resumed.dispose);
      final session = await resumed.read(shiftSessionProvider.future);

      expect(session.stage, ShiftStage.badgeAssigned);
      expect(session.badge?.badgeId, isNotNull);
    });
  });
}
