@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// The worker journey, screen by screen.
///
/// Reviewed as one continuous product: every image here should look like a
/// part of the same application, and the measurement surfaces should be
/// visibly neutral where the workflow surfaces are MRPL green.
void main() {
  // A fixed start so nothing drifts with the wall clock.
  final started = DateTime(2026, 9, 25, 8, 4);

  ShiftSession session(ShiftStage stage) => ShiftSession(
    stage: stage,
    context: stage.index >= ShiftStage.contextSet.index
        ? SimulationCatalog.demoContext()
        : null,
    badge: stage.index >= ShiftStage.badgeAssigned.index
        ? SimulationCatalog.specimens().first
        : null,
    startedAt: stage.index >= ShiftStage.monitoring.index ? started : null,
    endedAt: stage.index >= ShiftStage.awaitingScan.index
        ? started.add(const Duration(hours: 7, minutes: 52))
        : null,
  );

  Future<void> pumpAt(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = InMemoryWorkflowStore();
    await store.save(session(ShiftStage.badgeAssigned));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          workflowStoreProvider.overrideWithValue(store),
        ],
        child: DoseBandApp(
          key: ValueKey(route),
          config: _dev,
          initialLocation: route,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  final journey = <String, String>{
    'worker-01-work-context': '/work-context',
    'worker-02-shift': '/shift',
    'worker-03-worker-identity': '/worker-identity',
    'worker-04-work-area': '/work-area',
    'worker-05-ptw': '/ptw',
    'worker-06-jsa': '/jsa',
    'worker-07-toolbox': '/toolbox',
    'worker-08-badge-assignment': '/assign',
    'worker-09-scan-badge-qr': '/scan-badge',
    'worker-10-prework': '/prework',
    'worker-12-traceability': '/traceability',
    'worker-13-history': '/history',
  };

  for (final entry in journey.entries) {
    testWidgets(entry.key, (tester) async {
      await pumpAt(tester, entry.value);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${entry.key}.png'),
      );
    });
  }

  testWidgets('worker-11-monitoring-active renders', (tester) async {
    // No pixel golden: the elapsed clock ticks. Asserted in widget tests.
    final store = InMemoryWorkflowStore();
    await store.save(
      ShiftSession(
        stage: ShiftStage.monitoring,
        context: SimulationCatalog.demoContext(),
        badge: SimulationCatalog.specimens().first,
        startedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    );
    tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          workflowStoreProvider.overrideWithValue(store),
        ],
        child: DoseBandApp(
          key: ValueKey('/active'),
          config: _dev,
          initialLocation: '/active',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
