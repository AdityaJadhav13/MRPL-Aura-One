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
import 'package:h2s_doseband/features/workflow/domain/badge_specimen.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

BadgeSpecimen _badge() => SimulationCatalog.specimens().first;

/// Worker Home in each of its states.
///
/// This is the visual review artefact for the Home rebuild. The point is to be
/// able to look at all of them together and confirm the *architecture* does not
/// move between states — hero, identity, shift, context, monitoring, action,
/// strip, quick actions, in that order, every time. Only the content and the
/// offered action change.
///
/// Rendered at 390 x 1500 so the whole dashboard is in one image. That is
/// taller than any phone; the "does it fit a real screen" question is answered
/// by the overflow tests in `test/home/home_states_test.dart`, not here.
void main() {
  /// Fixed instants, so the goldens do not drift with the wall clock.
  final start = DateTime(2026, 9, 25, 8, 4);

  ShiftSession session(
    ShiftStage stage, {
    DateTime? startedAt,
    DateTime? endedAt,
  }) => ShiftSession(
    stage: stage,
    context: stage.index >= ShiftStage.contextSet.index
        ? SimulationCatalog.demoContext()
        : null,
    badge: stage.index >= ShiftStage.badgeAssigned.index ? _badge() : null,
    startedAt: startedAt,
    endedAt: endedAt,
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
          workflowStoreProvider.overrideWithValue(store),
          // Pinned. Home renders today's date, so without this the golden
          // bakes in whatever day it was generated and fails at the next
          // midnight.
          clockProvider.overrideWithValue(() => start),
        ],
        child: DoseBandApp(
          key: ValueKey('/home'),
          config: _dev,
          initialLocation: '/home',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  final states = <String, ShiftSession>{
    'home-01-no-context': session(ShiftStage.noShift),
    'home-03-awaiting-badge': session(ShiftStage.contextSet),
    'home-04-badge-assigned': session(ShiftStage.badgeAssigned),
    'home-06-ready-for-dosimetry': session(ShiftStage.readyForDosimetry),
    'home-08-scan-required': session(
      ShiftStage.awaitingScan,
      startedAt: start,
      endedAt: start.add(const Duration(hours: 7, minutes: 52)),
    ),
    // The window runs backwards: the device clock moved while monitoring.
    // A fixed instant far in the future, so the window runs backwards
    // against any `now` and the rendered "Started 08:00" does not drift.
    // Deriving it from `DateTime.now()` made this golden change every minute.
    'home-10-untrusted-clock': session(
      ShiftStage.monitoring,
      startedAt: DateTime(2099, 1, 1, 8),
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

  testWidgets('home-07-monitoring-active', (tester) async {
    // No pixel golden, but the elapsed figure is now deterministic: both the
    // start instant and the clock come from `start`, so "3 h 42 min" is a
    // property of the inputs rather than of when the suite happened to run.
    await pumpHome(
      tester,
      session(
        ShiftStage.monitoring,
        startedAt: start.subtract(const Duration(hours: 3, minutes: 42)),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('MONITORING ACTIVE'), findsOneWidget);
    expect(find.text('3 h 42 min'), findsOneWidget);
  });
}
