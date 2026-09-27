import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/auth/data/auth_session_store.dart';
import 'package:h2s_doseband/features/auth/presentation/screens/splash_screen.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/main.dart';

const _dev = EnvironmentConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

/// A stored session that cannot be read.
final class _Unreadable implements AuthSessionStore {
  @override
  Future<StoredSession?> load() async =>
      throw const FormatException('corrupt session file');
  @override
  Future<void> save(StoredSession session) async {}
  @override
  Future<void> clear() async {}
}

/// No stored session, found after [delay].
final class _Slow implements AuthSessionStore {
  _Slow(this.delay);
  final Duration delay;
  @override
  Future<StoredSession?> load() => Future.delayed(delay, () => null);
  @override
  Future<void> save(StoredSession session) async {}
  @override
  Future<void> clear() async {}
}

/// The recovered splash (corrective §3A) never holds a person on it.
void main() {
  Future<void> pumpSplash(WidgetTester tester, AuthSessionStore store) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(_dev),
          authSessionStoreProvider.overrideWithValue(store),
          operationsStoreProvider.overrideWithValue(
            InMemoryOperationsStore(
              PresentationDataset.build(DateTime(2026, 9, 27, 10, 30)),
            ),
          ),
        ],
        child: const DoseBandApp(config: _dev, initialLocation: '/splash'),
      ),
    );
  }

  testWidgets('an unreadable stored session goes to sign-in', (tester) async {
    await pumpSplash(tester, _Unreadable());
    await tester.pump();
    await tester.pump(SplashScreen.minimumShown);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('a tap while the session is read continues once it is', (
    tester,
  ) async {
    await pumpSplash(tester, _Slow(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.tap(find.byType(SplashScreen));
    await tester.pump(const Duration(milliseconds: 100));
    // Still reading: a tap cannot skip the session check.
    expect(find.byType(SplashScreen), findsOneWidget);
    // Read at 300 ms — well before the 1.4 s minimum — and the tap holds.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
    await tester.pump(SplashScreen.minimumShown);
  });

  testWidgets('without a tap it stays for the minimum', (tester) async {
    await pumpSplash(tester, _Slow(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(SplashScreen.minimumShown);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
  });
}
