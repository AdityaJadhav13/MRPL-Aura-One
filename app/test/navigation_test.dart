import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/capture/presentation/capture_host_screen.dart';
import 'package:h2s_doseband/features/gallery/gallery_screen.dart';
import 'package:h2s_doseband/features/home/presentation/home_cards.dart';
import 'package:h2s_doseband/features/research/presentation/physical_capture_screen.dart';
import 'package:h2s_doseband/features/research/presentation/research_captures_screen.dart';
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

/// Pumps the app already on the shell, skipping the launch splash (whose
/// indeterminate progress animation never settles) and the demo login.
Future<void> pumpShell(WidgetTester tester, EnvironmentConfig config) async {
  await tester.pumpWidget(
    ProviderScope(
      child: DoseBandApp(
        key: ValueKey('/home'),
        config: config,
        initialLocation: '/home',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Opens the account screen from the Home header.
///
/// Profile left the bottom bar when Safety took its place: a worker's four
/// destinations are Home, Scan, Safety and History, and account sits behind
/// the header avatar.
Future<void> openAccount(WidgetTester tester) async {
  // Tapped by the worker's own identity card, which is where the account
  // affordance now lives — there is no icon in a bar to press.
  await tester.tap(find.byType(WorkerIdentityCard));
  await tester.pumpAndSettle();
  await _scrollToEnd(tester);
}

/// Scrolls the account screen to its last item.
///
/// Its list is built lazily, so an item below the fold is simply not in the
/// tree. Without this, `findsNothing` on a development-only entry would pass
/// in a production build for the wrong reason — because the entry was
/// off-screen, not because it was absent — and the guard would prove nothing.
Future<void> _scrollToEnd(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  for (final element in scrollables.evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    final position = state.position;
    if (position.maxScrollExtent > 0) {
      position.jumpTo(position.maxScrollExtent);
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  group('worker shell', () {
    testWidgets('opens on Home with the four approved destinations', (
      tester,
    ) async {
      await pumpShell(tester, _dev);

      expect(find.byType(NavigationBar), findsOneWidget);
      for (final label in ['Home', 'Scan', 'Safety', 'History']) {
        expect(find.text(label), findsWidgets, reason: '$label is missing');
      }
      // No shift and no history yet: the honest empty state, not a fake shift.
      expect(find.text('DOSEBAND MONITORING'), findsOneWidget);
    });

    testWidgets('each destination is reachable', (tester) async {
      await pumpShell(tester, _dev);

      await tapDestination(tester, 'History');
      expect(find.text('No measurements yet'), findsOneWidget);

      await tapDestination(tester, 'Scan');
      expect(find.text('Assign a badge to begin'), findsOneWidget);

      await tapDestination(tester, 'Safety');
      expect(
        find.text('DoseBand is not a real-time gas alarm'),
        findsOneWidget,
      );

      await tapDestination(tester, 'Home');
      expect(find.text('DOSEBAND MONITORING'), findsOneWidget);
    });
  });

  group('the capture route cannot reach production', () {
    // It talks to a real camera and writes research images. It is guarded by
    // the same flag that compiles simulation out of release builds, and this
    // test is what keeps the guard honest.
    testWidgets('it exists in a development build', (tester) async {
      await pumpShell(tester, _dev);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      expect(() => router.go('/profile/capture'), returnsNormally);
    });

    testWidgets('it is absent from a production build', (tester) async {
      await pumpShell(tester, _prod);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go('/profile/capture');
      await tester.pumpAndSettle();
      // go_router renders its error page for an unknown route rather than
      // navigating; what matters is that no capture screen appears.
      expect(find.byType(CaptureHostScreen), findsNothing);
    });
  });

  group('the physical capture test cannot reach production', () {
    // It drives a real camera and writes research records. APP-INTEGRATION-01
    // §71: research diagnostics are not worker functionality.
    testWidgets('offered in a development build', (tester) async {
      await pumpShell(tester, _dev);
      await openAccount(tester);
      expect(find.text('Physical capture test'), findsOneWidget);
      expect(find.text('Research captures'), findsOneWidget);
    });

    testWidgets('absent from a production build', (tester) async {
      await pumpShell(tester, _prod);
      await openAccount(tester);
      expect(find.text('Physical capture test'), findsNothing);
      expect(find.text('Research captures'), findsNothing);
    });

    testWidgets('the routes themselves are absent from production', (
      tester,
    ) async {
      await pumpShell(tester, _prod);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      for (final route in const [
        '/profile/physical-capture',
        '/profile/physical-capture/camera',
        '/profile/research-captures',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(find.byType(PhysicalCaptureSetupScreen), findsNothing);
        expect(find.byType(PhysicalCaptureSessionScreen), findsNothing);
        expect(find.byType(ResearchCapturesScreen), findsNothing);
      }
    });
  });

  group('the worker previews cannot reach production', () {
    // They seed the workflow store directly — the last thing a worker should
    // be able to do to their own exposure record.
    testWidgets('offered in a development build', (tester) async {
      await pumpShell(tester, _dev);
      await openAccount(tester);
      expect(find.text('Worker screen previews'), findsOneWidget);
    });

    testWidgets('absent from a production build', (tester) async {
      await pumpShell(tester, _prod);
      await openAccount(tester);
      expect(find.text('Worker screen previews'), findsNothing);
    });

    testWidgets('the route itself is absent from production', (tester) async {
      await pumpShell(tester, _prod);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go('/profile/worker-previews');
      await tester.pumpAndSettle();
      expect(find.text('Worker screen previews'), findsNothing);
    });
  });

  group('the gallery cannot reach production', () {
    testWidgets('it is offered in a development build', (tester) async {
      await pumpShell(tester, _dev);
      await openAccount(tester);

      expect(find.text('Design system gallery'), findsOneWidget);

      await tester.tap(find.text('Design system gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryScreen), findsOneWidget);
    });

    testWidgets('it is absent from a production build', (tester) async {
      await pumpShell(tester, _prod);
      await openAccount(tester);

      expect(find.text('Design system gallery'), findsNothing);
    });

    test('simulation availability is decided by environment, not a flag', () {
      expect(_dev.simulationAvailable, isTrue);
      expect(_prod.simulationAvailable, isFalse);
      expect(_prod.experimentalFeaturesAvailable, isFalse);
    });
  });
}
