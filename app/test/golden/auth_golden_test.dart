@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/design/brand_assets.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/auth/application/onboarding_controller.dart';
import 'package:h2s_doseband/features/auth/data/site_repository.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/auth/domain/identity.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/workflow/domain/worker_identity.dart';
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

/// A controller showing a refused attempt, for the failure goldens.
class _Refused extends AuthController {
  _Refused([this.failure = SignInFailure.invalidCredentials]);

  final SignInFailure failure;

  @override
  AuthState build() =>
      AuthState(status: AuthStatus.signedOut, failure: failure);
}

/// Setup already part-way or fully chosen.
class _Preset extends OnboardingController {
  _Preset(this.selection);

  final OnboardingSelection selection;

  @override
  OnboardingSelection build() => selection;
}

/// Stands in for the build-time presentation credentials; the real password
/// is never in source.
const PresentationCredentials _testCredentials = (
  loginId: 'CT-45832',
  accountType: WorkerType.contractor,
  password: 'presentation',
);

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
    SignInFailure? failure,
    bool restoring = false,
    bool prefilled = false,
    OnboardingSelection? setup,
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
          if (failure != null)
            authControllerProvider.overrideWith(() => _Refused(failure)),
          if (prefilled)
            presentationCredentialsProvider.overrideWithValue(
              _testCredentials,
            ),
          if (setup != null)
            onboardingProvider.overrideWith(() => _Preset(setup)),
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

  // Worker directive §62: the entry flow as a judge meets it.
  final refinery = const SeededSiteRepository().sites().first;

  testWidgets('sign-in · prefilled presentation account', (tester) async {
    await pumpAt(tester, '/sign-in', prefilled: true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-sign-in-prefilled.png'),
    );
  });

  testWidgets('select site · unselected', (tester) async {
    await pumpAt(tester, '/select-site');
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-select-site.png'),
    );
  });

  testWidgets('select site · selected', (tester) async {
    await pumpAt(
      tester,
      '/select-site',
      setup: OnboardingSelection(site: refinery),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-select-site-selected.png'),
    );
  });

  testWidgets('select role · unselected', (tester) async {
    await pumpAt(tester, '/select-role');
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-select-role.png'),
    );
  });

  testWidgets('select role · selected', (tester) async {
    await pumpAt(
      tester,
      '/select-role',
      setup: OnboardingSelection(site: refinery, role: AppRole.worker),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-select-role-selected.png'),
    );
  });

  testWidgets('sign-in · role mismatch in setup', (tester) async {
    await pumpAt(
      tester,
      '/sign-in',
      prefilled: true,
      failure: SignInFailure.roleNotAuthorised,
      setup: OnboardingSelection(site: refinery, role: AppRole.hseOfficer),
      size: const Size(390, 1100),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-sign-in-role-mismatch.png'),
    );
  });

  testWidgets('select role · 320 × 568 at 200% text', (tester) async {
    await pumpAt(
      tester,
      '/select-role',
      size: const Size(320, 568),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth-select-role-320-text200.png'),
    );
  });
}
