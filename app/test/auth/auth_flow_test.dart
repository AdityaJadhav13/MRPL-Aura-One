import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/buttons.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/core/router/route_gate.dart';
import 'package:h2s_doseband/core/router/router_gate.dart';
import 'package:h2s_doseband/core/time/clock.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/auth/data/auth_session_store.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/auth/domain/identity.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/operations/domain/audit.dart';
import 'package:h2s_doseband/main.dart';

import '../support/signed_in.dart';

/// PRODUCT BUILD v1 §54–§57, §105: sign-in against salted verifiers, role
/// from the directory, controlled workspace switching, session restore, and
/// a gate that keeps each person in their own workspace.
void main() {
  const dev = EnvironmentConfig(
    environment: AppEnvironment.dev,
    supabaseUrl: '',
    supabaseAnonKey: '',
  );
  const prod = EnvironmentConfig(
    environment: AppEnvironment.prod,
    supabaseUrl: '',
    supabaseAnonKey: '',
  );
  final now = DateTime(2026, 9, 27, 10, 30);

  // A cheap verifier for tests; the shipped ones cost 120 000 iterations.
  const testPassword = 'correct horse';
  final testVerifiers = {
    for (final p in PresentationDataset.people)
      p.personId: PasswordVerifier.derive(
        testPassword,
        p.personId.codeUnits,
        iterations: 10,
      ),
  };
  final testProvider = PresentationIdentityProvider(
    testVerifiers,
    verify: PresentationIdentityProvider.inline,
  );

  ProviderContainer container({
    EnvironmentConfig config = dev,
    AuthSessionStore? sessions,
    OperationsStore? ops,
    IdentityProvider? identity,
  }) => ProviderContainer(
    overrides: [
      environmentConfigProvider.overrideWithValue(config),
      clockProvider.overrideWithValue(() => now),
      idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
      operationsStoreProvider.overrideWithValue(
        ops ?? InMemoryOperationsStore(PresentationDataset.build(now)),
      ),
      authSessionStoreProvider.overrideWithValue(
        sessions ?? InMemoryAuthSessionStore(),
      ),
      if (identity != null || config.simulationAvailable)
        identityProviderProvider.overrideWithValue(identity ?? testProvider),
    ],
  );

  group('password verifiers', () {
    test('PBKDF2-HMAC-SHA256 matches the published test vector', () {
      final key = PasswordVerifier.pbkdf2('password', 'salt'.codeUnits, 1);
      expect(
        key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('a verifier accepts its password and nothing else', () {
      final v = PasswordVerifier.derive('s3cret', [1, 2, 3], iterations: 5);
      expect(v.matches('s3cret'), isTrue);
      expect(v.matches('s3creT'), isFalse);
      expect(v.matches(''), isFalse);
    });

    test(
      'the shipped directory holds a verifier for each presentation account',
      () {
        final shipped = PresentationIdentityProvider.shipped().verifiers;
        expect(
          shipped.keys.toSet(),
          PresentationDataset.people.map((p) => p.personId).toSet(),
        );
        // Each has its own salt.
        expect(shipped.values.map((v) => v.saltHex).toSet(), hasLength(6));
      },
    );

    test('no password appears in plaintext anywhere in lib/', () {
      // The former published demo password, and the obvious field shapes.
      final plaintext = RegExp(
        r"DoseBand@2026|password\s*[:=]\s*'[^']+'",
        caseSensitive: false,
      );
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is File &&
            f.path.endsWith('.dart') &&
            plaintext.hasMatch(f.readAsStringSync())) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('identity providers', () {
    Future<SignInOutcome> signIn(
      IdentityProvider p,
      String id,
      String pw, {
      bool active = true,
    }) => p.signIn(loginId: id, password: pw, isActive: (_) => active);

    test(
      'right ID and password are accepted; the ID is not case-sensitive',
      () async {
        expect(
          await signIn(testProvider, 'ct-45832', testPassword),
          isA<SignInAccepted>().having(
            (x) => x.personId,
            'person',
            PresentationDataset.aditya,
          ),
        );
      },
    );

    test('a wrong password and an unknown ID are the same refusal', () async {
      final wrong = await signIn(testProvider, 'CT-45832', 'nope');
      final unknown = await signIn(testProvider, 'X-00000', testPassword);
      expect(
        (wrong as SignInRefused).failure,
        SignInFailure.invalidCredentials,
      );
      expect(
        (unknown as SignInRefused).failure,
        SignInFailure.invalidCredentials,
      );
    });

    test('a suspended account is refused as suspended', () async {
      final r = await signIn(
        testProvider,
        'CT-45832',
        testPassword,
        active: false,
      );
      expect((r as SignInRefused).failure, SignInFailure.accountSuspended);
    });

    test('production has no presentation directory: not connected', () async {
      final c = container(config: prod);
      expect(
        c.read(identityProviderProvider),
        isA<NotConnectedIdentityProvider>(),
      );
      expect(c.read(presentationAccessProvider), isFalse);
      final failure = await c
          .read(authControllerProvider.notifier)
          .signIn(loginId: 'CT-45832', password: 'anything');
      expect(failure, SignInFailure.notConnected);
    });
  });

  group('auth controller', () {
    test(
      'sign-in takes the role from the directory, never from the user',
      () async {
        final sessions = InMemoryAuthSessionStore();
        final c = container(sessions: sessions);
        final failure = await c
            .read(authControllerProvider.notifier)
            .signIn(loginId: PresentationDataset.aman, password: testPassword);
        expect(failure, isNull);
        final s = c.read(authControllerProvider).session!;
        expect(s.activeRole, AppRole.supervisor);
        expect(s.roles, [AppRole.supervisor]);
        expect(s.canSwitchWorkspace, isFalse);

        final stored = (await sessions.load())!;
        expect(stored.personId, PresentationDataset.aman);
        expect(stored.activeRole, AppRole.supervisor);

        final audit = (await c.read(operationsProvider.future)).audit.last;
        expect(audit.action, AuditAction.signedIn);
      },
    );

    test(
      'a failed sign-in leaves nobody signed in and nothing stored',
      () async {
        final sessions = InMemoryAuthSessionStore();
        final c = container(sessions: sessions);
        final failure = await c
            .read(authControllerProvider.notifier)
            .signIn(loginId: PresentationDataset.aman, password: 'wrong');
        expect(failure, SignInFailure.invalidCredentials);
        expect(c.read(authControllerProvider).isSignedIn, isFalse);
        expect(await sessions.load(), isNull);
      },
    );

    test('a multi-role account switches only between its own roles', () async {
      final c = container();
      final auth = c.read(authControllerProvider.notifier);
      await auth.signIn(
        loginId: PresentationDataset.yashvi,
        password: testPassword,
      );
      expect(
        c.read(authControllerProvider).session!.activeRole,
        AppRole.management,
      );

      await auth.switchWorkspace(AppRole.administrator);
      expect(
        c.read(authControllerProvider).session!.activeRole,
        AppRole.administrator,
      );

      await auth.switchWorkspace(AppRole.hseOfficer);
      expect(
        c.read(authControllerProvider).session!.activeRole,
        AppRole.administrator,
        reason: 'HSE is not one of her roles',
      );
    });

    test(
      'a stored session is restored, re-checked against the directory',
      () async {
        final sessions = InMemoryAuthSessionStore(
          const StoredSession(
            personId: PresentationDataset.yashvi,
            activeRole: AppRole.administrator,
          ),
        );
        final c = container(sessions: sessions);
        await c.read(authControllerProvider.notifier).restore();
        final s = c.read(authControllerProvider).session!;
        expect(s.personId, PresentationDataset.yashvi);
        expect(s.activeRole, AppRole.administrator);
      },
    );

    test(
      'a stored role the person no longer holds falls back to their first',
      () async {
        final c = container(
          sessions: InMemoryAuthSessionStore(
            const StoredSession(
              personId: PresentationDataset.aditya,
              activeRole: AppRole.hseOfficer,
            ),
          ),
        );
        await c.read(authControllerProvider.notifier).restore();
        expect(
          c.read(authControllerProvider).session!.activeRole,
          AppRole.worker,
        );
      },
    );

    test('a stored session for an unknown person is discarded', () async {
      final sessions = InMemoryAuthSessionStore(
        const StoredSession(personId: 'GONE-1', activeRole: AppRole.worker),
      );
      final c = container(sessions: sessions);
      await c.read(authControllerProvider.notifier).restore();
      expect(c.read(authControllerProvider).status, AuthStatus.signedOut);
      expect(await sessions.load(), isNull);
    });

    test('sign-out forgets the stored session', () async {
      final sessions = InMemoryAuthSessionStore();
      final c = container(sessions: sessions);
      final auth = c.read(authControllerProvider.notifier);
      await auth.signIn(
        loginId: PresentationDataset.aditya,
        password: testPassword,
      );
      await auth.signOut();
      expect(c.read(authControllerProvider).isSignedIn, isFalse);
      expect(await sessions.load(), isNull);
    });

    test('presentation one-tap access is refused in production', () async {
      final c = container(config: prod);
      final failure = await c
          .read(authControllerProvider.notifier)
          .signInAsPresentation(PresentationDataset.aditya);
      expect(failure, isNotNull);
      expect(c.read(authControllerProvider).isSignedIn, isFalse);
    });

    test('the stored session file holds no credential', () async {
      final dir = await Directory.systemTemp.createTemp('auth');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/auth_session.json');
      final c = container(sessions: FileAuthSessionStore(file));
      await c
          .read(authControllerProvider.notifier)
          .signIn(loginId: PresentationDataset.aditya, password: testPassword);
      final raw = file.readAsStringSync();
      expect(raw, isNot(contains(testPassword)));
      expect(raw.toLowerCase(), isNot(contains('password')));
      expect(raw, contains(PresentationDataset.aditya));
    });
  });

  group('route gate', () {
    AuthState signedIn(String id, [AppRole? role]) => AuthState(
      status: AuthStatus.signedIn,
      session: presentationSession(id, role: role),
    );

    String? go(AuthState a, String to, {bool dev = true}) =>
        RouteGate.redirect(auth: a, location: to, devToolsAvailable: dev);

    test('signed out: everything leads to sign-in', () {
      expect(go(AuthState.signedOut, '/home'), '/sign-in');
      expect(go(AuthState.signedOut, '/hse/record'), '/sign-in');
      expect(go(AuthState.signedOut, '/sign-in'), isNull);
    });

    test('unknown yet: the splash resolves it and remembers the target', () {
      expect(go(AuthState.unknown, '/history'), '/splash?from=%2Fhistory');
    });

    test('a worker cannot open another workspace by address', () {
      final w = signedIn(PresentationDataset.aditya);
      expect(go(w, '/home'), isNull);
      expect(go(w, '/doseband/scan'), isNull);
      expect(go(w, '/hse'), '/home');
      expect(go(w, '/supervisor/team'), '/home');
      expect(go(w, '/management'), '/home');
      expect(go(w, '/admin/doseband'), '/home');
      expect(go(w, '/sign-in'), '/home');
    });

    test('each role stays in its own workspace', () {
      expect(go(signedIn(PresentationDataset.aman), '/home'), '/supervisor');
      expect(go(signedIn(PresentationDataset.samhita), '/admin'), '/hse');
      expect(go(signedIn(PresentationDataset.samhita), '/reporting'), isNull);
      expect(
        go(signedIn(PresentationDataset.yashvi), '/hse/record'),
        '/management',
      );
      expect(
        go(
          signedIn(PresentationDataset.yashvi, AppRole.administrator),
          '/management',
        ),
        '/admin',
        reason: 'the other role is a switch away, not an address away',
      );
    });

    test('developer tools exist only where the build offers them', () {
      expect(go(AuthState.signedOut, '/dev/components'), isNull);
      expect(
        go(AuthState.signedOut, '/dev/components', dev: false),
        '/sign-in',
      );
    });
  });

  group('screens', () {
    final signInButton = find.byWidgetPredicate(
      (w) => w is DoseBandButton && w.label == 'Sign in',
    );

    Future<ProviderContainer> pumpApp(
      WidgetTester tester, {
      EnvironmentConfig config = dev,
      AuthSessionStore? sessions,
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = container(config: config, sessions: sessions);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: DoseBandApp(config: config, gate: AuthRouterGate(c)),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('launch without a session lands on sign-in', (tester) async {
      await pumpApp(tester);
      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Employee or contractor ID'), findsOneWidget);
    });

    testWidgets('sign-in shows no credentials and no role picker', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.textContaining('DoseBand@'), findsNothing);
      expect(find.textContaining('CT-45832'), findsNothing);
      for (final role in AppRole.values) {
        expect(find.text(role.label), findsNothing, reason: role.name);
      }
    });

    testWidgets('wrong credentials are refused in words', (tester) async {
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField).at(0), 'CT-45832');
      await tester.enterText(find.byType(TextField).at(1), 'wrong');
      await tester.tap(signInButton);
      await tester.pumpAndSettle();
      expect(find.text('ID or password not recognised'), findsOneWidget);
    });

    testWidgets('a supervisor signs in and lands in the supervisor workspace', (
      tester,
    ) async {
      final c = await pumpApp(tester);
      await tester.enterText(
        find.byType(TextField).at(0),
        PresentationDataset.aman,
      );
      await tester.enterText(find.byType(TextField).at(1), testPassword);
      await tester.tap(signInButton);
      await tester.pumpAndSettle();
      expect(
        c.read(authControllerProvider).session!.activeRole,
        AppRole.supervisor,
      );
      expect(find.byType(TextField), findsNothing, reason: 'left sign-in');
    });

    testWidgets('a stored session skips sign-in', (tester) async {
      await pumpApp(
        tester,
        sessions: InMemoryAuthSessionStore(
          const StoredSession(
            personId: PresentationDataset.aditya,
            activeRole: AppRole.worker,
          ),
        ),
      );
      expect(find.text('Employee or contractor ID'), findsNothing);
    });

    testWidgets('presentation accounts are offered in development only', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Presentation accounts'), findsOneWidget);
    });

    testWidgets('production offers no presentation accounts and says why', (
      tester,
    ) async {
      await pumpApp(tester, config: prod);
      expect(find.text('Presentation accounts'), findsNothing);
      expect(
        find.text('Organisation sign-in is not connected'),
        findsOneWidget,
      );
    });
  });
}
