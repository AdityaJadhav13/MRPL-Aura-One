@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/design/brand_assets.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/auth/domain/identity.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/main.dart';

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

/// A controller showing a refused attempt, for the failure golden.
class _Refused extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.signedOut,
    failure: SignInFailure.invalidCredentials,
  );
}

/// A controller whose stored session is still being read, so the splash is
/// what is on screen.
class _Restoring extends AuthController {
  @override
  Future<void> restore() => Completer<void>().future;
}

/// Goldens for launch and sign-in (PRODUCT BUILD v1 §55, §56): white-first,
/// no gradient, no credential block, no role picker.
void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    String location, {
    EnvironmentConfig config = _dev,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool refused = false,
    bool restoring = false,
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentConfigProvider.overrideWithValue(config),
          operationsStoreProvider.overrideWithValue(
            InMemoryOperationsStore(
              PresentationDataset.build(DateTime(2026, 9, 27, 10, 30)),
            ),
          ),
          if (refused) authControllerProvider.overrideWith(_Refused.new),
          if (restoring) authControllerProvider.overrideWith(_Restoring.new),
        ],
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: DoseBandApp(
            key: ValueKey(location),
            config: config,
            initialLocation: location,
          ),
        ),
      ),
    );
    // Decode the brand photographs for real before capturing.
    final context = tester.element(find.byType(Scaffold).first);
    await tester.runAsync(
      () => Future.wait([
        precacheImage(const AssetImage(BrandAssets.refineryBackdrop), context),
        precacheImage(const AssetImage(BrandAssets.mrplLogo), context),
      ]),
    );
    await tester.pump();
  }

  testWidgets('splash', (tester) async {
    await pumpAt(tester, '/splash', restoring: true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-splash-light.png'),
    );
  });

  testWidgets('sign-in', (tester) async {
    await pumpAt(tester, '/sign-in');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-sign-in-light.png'),
    );
  });

  testWidgets('sign-in · refused', (tester) async {
    await pumpAt(tester, '/sign-in', refused: true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-sign-in-refused.png'),
    );
  });

  testWidgets('sign-in · production, not connected', (tester) async {
    await pumpAt(tester, '/sign-in', config: _prod);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-sign-in-not-connected.png'),
    );
  });

  testWidgets('sign-in · presentation accounts', (tester) async {
    await pumpAt(tester, '/sign-in');
    await tester.tap(find.text('Presentation accounts'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-presentation-accounts.png'),
    );
  });

  testWidgets('sign-in · compact 360 at 150% text', (tester) async {
    await pumpAt(
      tester,
      '/sign-in',
      size: const Size(360, 780),
      textScale: 1.5,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-sign-in-compact-large-text.png'),
    );
  });

  // Corrective §3A: the recovered splash at the edges of the size matrix.
  for (final (name, size, scale) in <(String, Size, double)>[
    ('auth-splash-320-text200', const Size(320, 568), 2),
    ('auth-splash-landscape-844x390', const Size(844, 390), 1),
    ('auth-splash-tablet-800x1280', const Size(800, 1280), 1),
  ]) {
    testWidgets('splash · $name', (tester) async {
      await pumpAt(
        tester,
        '/splash',
        restoring: true,
        size: size,
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }

  testWidgets('sign-in · 320 × 568', (tester) async {
    await pumpAt(tester, '/sign-in', size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-sign-in-320.png'),
    );
  });
}
