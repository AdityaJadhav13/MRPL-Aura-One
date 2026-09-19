import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/gallery/gallery_screen.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

const _prod = EnvironmentConfig(
  environment: AppEnvironment.prod,
  supabaseUrl: 'https://example.supabase.co',
  supabaseAnonKey: 'anon',
);

void main() {
  group('worker shell', () {
    testWidgets('opens on Home with the four approved destinations', (
      tester,
    ) async {
      await tester.pumpWidget(const DoseBandApp(config: _dev));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      for (final label in ['Home', 'Scan', 'History', 'Profile']) {
        expect(find.text(label), findsWidgets, reason: '$label is missing');
      }
      expect(find.text('Shift in progress'), findsOneWidget);
    });

    testWidgets('each destination is reachable', (tester) async {
      await tester.pumpWidget(const DoseBandApp(config: _dev));
      await tester.pumpAndSettle();

      Future<void> tapDestination(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tapDestination('History');
      expect(find.text('18 Sep · Day shift'), findsOneWidget);

      await tapDestination('Profile');
      expect(find.text('Sync'), findsOneWidget);

      await tapDestination('Home');
      expect(find.text('Shift in progress'), findsOneWidget);
    });

    testWidgets('history shows refusals, it does not hide them', (
      tester,
    ) async {
      // Omitting refused scans would misrepresent the coverage record, which is
      // the quiet omission that produces false reassurance at review time.
      await tester.pumpWidget(const DoseBandApp(config: _dev));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('History'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No reading'), findsWidgets);
      expect(find.text('Incomplete coverage'), findsOneWidget);
    });
  });

  group('the gallery cannot reach production', () {
    testWidgets('it is offered in a development build', (tester) async {
      await tester.pumpWidget(const DoseBandApp(config: _dev));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profile'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Design system gallery'), findsOneWidget);

      await tester.tap(find.text('Design system gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryScreen), findsOneWidget);
    });

    testWidgets('it is absent from a production build', (tester) async {
      await tester.pumpWidget(const DoseBandApp(config: _prod));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profile'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Design system gallery'), findsNothing);
    });

    test('simulation availability is decided by environment, not a flag', () {
      expect(_dev.simulationAvailable, isTrue);
      expect(_prod.simulationAvailable, isFalse);
      expect(_prod.experimentalFeaturesAvailable, isFalse);
    });
  });
}
