import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/main.dart';

void main() {
  const dev = EnvironmentConfig(
    environment: AppEnvironment.dev,
    supabaseUrl: '',
    supabaseAnonKey: '',
  );
  const prod = EnvironmentConfig(
    environment: AppEnvironment.prod,
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'anon',
  );

  testWidgets('shows the resolved environment', (tester) async {
    await tester.pumpWidget(const DoseBandApp(config: dev));
    expect(find.text('dev'), findsOneWidget);
    expect(find.text('not configured'), findsOneWidget);
  });

  testWidgets('simulation is never available in production', (tester) async {
    await tester.pumpWidget(const DoseBandApp(config: prod));
    expect(find.text('compiled out'), findsOneWidget);
    expect(find.text('available'), findsNothing);
  });

  test('simulation availability is decided by environment, not by a flag', () {
    expect(dev.simulationAvailable, isTrue);
    expect(prod.simulationAvailable, isFalse);
    expect(prod.experimentalFeaturesAvailable, isFalse);
  });
}
