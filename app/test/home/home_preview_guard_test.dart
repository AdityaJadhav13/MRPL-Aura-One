import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/dev/home_state_preview.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

const _prod = EnvironmentConfig(
  environment: AppEnvironment.prod,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// The Home state preview seeds the workflow store directly, which is exactly
/// the kind of tool that must never reach a worker. These tests are what keep
/// the guard honest.
void main() {
  group('the Home state preview cannot reach production', () {
    test('no start route is honoured in a production build', () {
      expect(HomeStatePreview.initialRoute(_prod), isNull);
    });

    test('seeding is a no-op in a production build', () async {
      final store = InMemoryWorkflowStore();
      await HomeStatePreview.seed(_prod, store);
      expect((await store.load()).stage, ShiftStage.noShift);
    });

    test('seeding is a no-op in development without the define', () async {
      // The defines are absent when running the test suite, so this also
      // pins that an unset define changes nothing.
      final store = InMemoryWorkflowStore();
      await HomeStatePreview.seed(_dev, store);
      expect((await store.load()).stage, ShiftStage.noShift);
      expect(HomeStatePreview.initialRoute(_dev), isNull);
    });

    test('the documented state names are the ones reviewers will type', () {
      expect(
        HomeStatePreview.names,
        containsAll(<String>[
          'no-context',
          'monitoring',
          'scan-required',
          'untrusted-clock',
        ]),
      );
    });

    test('simulation availability is what gates it', () {
      expect(_dev.simulationAvailable, isTrue);
      expect(_prod.simulationAvailable, isFalse);
    });
  });
}
