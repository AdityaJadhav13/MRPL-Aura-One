@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/design/brand_assets.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/physical_badge.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:h2s_doseband/main.dart';

import '../support/signed_in.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// Worker Home states A, C, D, E and the untrusted-clock state (PRODUCT
/// BUILD v1 §15, §129), signed in as the presentation worker with a
/// registered DoseBand. Clock pinned so the date and durations never drift.
void main() {
  final now = DateTime(2026, 9, 27, 11, 46);
  final start = now.subtract(const Duration(hours: 3, minutes: 42));
  final band = PhysicalBadge(
    badgeId: 'DB-2609-0010',
    batchId: 'LOT-2609-A',
    identifiedAt: start,
    source: BadgeIdentitySource.localRegistry,
  );

  ShiftSession session(
    ShiftStage stage, {
    DateTime? startedAt,
    DateTime? endedAt,
  }) => ShiftSession(
    stage: stage,
    context: stage.index >= ShiftStage.contextSet.index
        ? SimulationCatalog.demoContext()
        : null,
    physicalBadge: stage.index >= ShiftStage.badgeAssigned.index ? band : null,
    startedAt: startedAt,
    endedAt: endedAt,
    sessionId: stage.index >= ShiftStage.badgeAssigned.index ? 'SES-1' : null,
    captureId: stage == ShiftStage.complete ? 'CAP-1' : null,
  );

  Future<void> pumpHome(WidgetTester tester, ShiftSession seeded) async {
    tester.view.physicalSize = const Size(390 * 2, 1500 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = InMemoryWorkflowStore();
    await store.save(seeded);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          ...signedInOverrides(
            personId: PresentationDataset.aditya,
            now: now,
            seed: seedForSession(seeded, now),
          ),
          workflowStoreProvider.overrideWithValue(store),
        ],
        child: const DoseBandApp(
          key: ValueKey('/home'),
          config: _dev,
          initialLocation: '/home',
        ),
      ),
    );
    // Decode the refinery photograph for real before capturing.
    final context = tester.element(find.byType(Scaffold).first);
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(BrandAssets.refineryBackdrop),
        context,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  final states = <String, ShiftSession>{
    'home-a-no-doseband': session(ShiftStage.noShift),
    'home-a-work-recorded': session(ShiftStage.contextSet),
    // Only the development simulation stops here: a real claim starts
    // monitoring in the same step, so B carries a simulated specimen.
    'home-b-assigned-simulated': ShiftSession(
      stage: ShiftStage.badgeAssigned,
      context: SimulationCatalog.demoContext(),
      badge: SimulationCatalog.specimens().first,
    ),
    'home-c-monitoring': session(ShiftStage.monitoring, startedAt: start),
    'home-d-final-scan': session(
      ShiftStage.awaitingScan,
      startedAt: start,
      endedAt: now,
    ),
    'home-e-complete': session(
      ShiftStage.complete,
      startedAt: start,
      endedAt: now,
    ),
    // The window runs backwards: the device clock moved while monitoring.
    'home-attention-untrusted-clock': session(
      ShiftStage.monitoring,
      startedAt: now.add(const Duration(hours: 3)),
    ),
  };

  for (final entry in states.entries) {
    testWidgets(entry.key, (tester) async {
      await pumpHome(tester, entry.value);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${entry.key}.png'),
      );
    });
  }

  // Corrective §44: History with nothing recorded yet.
  testWidgets('history-empty', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          ...signedInOverrides(personId: PresentationDataset.aditya, now: now),
          workflowStoreProvider.overrideWithValue(InMemoryWorkflowStore()),
        ],
        child: const DoseBandApp(
          key: ValueKey('/history'),
          config: _dev,
          initialLocation: '/history',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No records yet'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/history-empty.png'),
    );
  });
}
