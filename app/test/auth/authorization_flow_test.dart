import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/core/router/route_gate.dart';
import 'package:h2s_doseband/core/router/router_gate.dart';
import 'package:h2s_doseband/core/time/clock.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/auth/application/onboarding_controller.dart';
import 'package:h2s_doseband/features/auth/data/auth_session_store.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/auth/domain/identity.dart';
import 'package:h2s_doseband/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:h2s_doseband/features/auth/presentation/screens/site_selection_screen.dart';
import 'package:h2s_doseband/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:h2s_doseband/features/auth/presentation/widgets/selection_cards.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/workflow/domain/worker_identity.dart';
import 'package:h2s_doseband/main.dart';

import '../support/signed_in.dart';

/// Worker directive §26–§31, §53, §54: identity, then authorization.
/// Selecting a role or a site never grants it; a valid credential for the
/// wrong role is refused with its own message; invalid credentials are a
/// different failure; a multi-role account chooses only among its own.
void main() {
  const dev = EnvironmentConfig(
    environment: AppEnvironment.dev,
    supabaseUrl: '',
    supabaseAnonKey: '',
  );
  final now = DateTime(2026, 9, 27, 10, 30);

  // Cheap verifiers for tests; the shipped ones cost 120 000 iterations.
  const password = 'correct horse';
  final provider = PresentationIdentityProvider({
    for (final p in PresentationDataset.people)
      p.personId: PasswordVerifier.derive(
        password,
        p.personId.codeUnits,
        iterations: 10,
      ),
  }, verify: PresentationIdentityProvider.inline);

  ProviderContainer container({AuthSessionStore? sessions}) {
    final c = ProviderContainer(
      overrides: [
        environmentConfigProvider.overrideWithValue(dev),
        clockProvider.overrideWithValue(() => now),
        idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
        operationsStoreProvider.overrideWithValue(
          InMemoryOperationsStore(datasetWithRecord(now)),
        ),
        authSessionStoreProvider.overrideWithValue(
          sessions ?? InMemoryAuthSessionStore(),
        ),
        identityProviderProvider.overrideWithValue(provider),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('authentication, then authorization', () {
    test('Worker credentials + Worker role → the Worker workspace', () async {
      final c = container();
      final failure = await c
          .read(authControllerProvider.notifier)
          .signIn(
            loginId: PresentationDataset.aditya,
            password: password,
            requestedRole: AppRole.worker,
          );
      expect(failure, isNull);
      final s = c.read(authControllerProvider).session!;
      expect(s.activeRole, AppRole.worker);
      expect(s.activeRole.landingRoute, '/home');
    });

    for (final role in [
      AppRole.hseOfficer,
      AppRole.supervisor,
      AppRole.management,
      AppRole.administrator,
    ]) {
      test('Worker credentials + ${role.label} role → denied', () async {
        final sessions = InMemoryAuthSessionStore();
        final c = container(sessions: sessions);
        final failure = await c
            .read(authControllerProvider.notifier)
            .signIn(
              loginId: PresentationDataset.aditya,
              password: password,
              requestedRole: role,
            );
        expect(failure, SignInFailure.roleNotAuthorised);
        final state = c.read(authControllerProvider);
        expect(state.isSignedIn, isFalse);
        expect(state.session, isNull);
        expect(await sessions.load(), isNull, reason: 'nothing persisted');
      });
    }

    test('invalid credentials are an authentication failure, not a role '
        'mismatch — even with a role requested', () async {
      final c = container();
      final failure = await c
          .read(authControllerProvider.notifier)
          .signIn(
            loginId: PresentationDataset.aditya,
            password: 'wrong',
            requestedRole: AppRole.hseOfficer,
          );
      // Authorization is never evaluated for an unauthenticated request, so
      // the answer cannot reveal what roles an ID holds.
      expect(failure, SignInFailure.invalidCredentials);
    });

    test('the wrong account type is invalid credentials, revealing '
        'nothing', () async {
      final c = container();
      final failure = await c
          .read(authControllerProvider.notifier)
          .signIn(
            loginId: PresentationDataset.aditya, // a contractor
            password: password,
            accountType: WorkerType.employee,
          );
      expect(failure, SignInFailure.invalidCredentials);
    });

    test('a site the account is not assigned to is refused', () async {
      final c = container();
      final failure = await c
          .read(authControllerProvider.notifier)
          .signIn(
            loginId: PresentationDataset.aditya,
            password: password,
            requestedRole: AppRole.worker,
            siteId: 'corporate-office',
          );
      expect(failure, SignInFailure.siteNotAuthorised);
      expect(c.read(authControllerProvider).isSignedIn, isFalse);
    });

    test('the assigned site is accepted and kept with the session', () async {
      final sessions = InMemoryAuthSessionStore();
      final c = container(sessions: sessions);
      final failure = await c
          .read(authControllerProvider.notifier)
          .signIn(
            loginId: PresentationDataset.aditya,
            password: password,
            requestedRole: AppRole.worker,
            siteId: 'mangalore-refinery',
          );
      expect(failure, isNull);
      expect((await sessions.load())!.siteId, 'mangalore-refinery');
    });

    test('Remember me off keeps nothing on disk', () async {
      final sessions = InMemoryAuthSessionStore();
      final c = container(sessions: sessions);
      await c
          .read(authControllerProvider.notifier)
          .signIn(
            loginId: PresentationDataset.aditya,
            password: password,
            remember: false,
          );
      expect(c.read(authControllerProvider).isSignedIn, isTrue);
      expect(await sessions.load(), isNull);
    });
  });

  group('a multi-role account', () {
    test('without a requested role, it must choose among its own', () async {
      final c = container();
      final auth = c.read(authControllerProvider.notifier);
      await auth.signIn(
        loginId: PresentationDataset.yashvi,
        password: password,
      );
      final state = c.read(authControllerProvider);
      expect(state.awaitingRoleChoice, isTrue);
      expect(
        RouteGate.redirect(
          auth: state,
          location: '/management',
          devToolsAvailable: false,
        ),
        '/select-role',
        reason: 'no workspace opens before the choice',
      );

      // Not one of hers: refused, nothing changes.
      expect(await auth.confirmRole(AppRole.worker), isFalse);
      expect(c.read(authControllerProvider).awaitingRoleChoice, isTrue);

      expect(await auth.confirmRole(AppRole.administrator), isTrue);
      final after = c.read(authControllerProvider);
      expect(after.awaitingRoleChoice, isFalse);
      expect(after.session!.activeRole, AppRole.administrator);
    });

    test('a requested role it holds opens directly', () async {
      final c = container();
      await c
          .read(authControllerProvider.notifier)
          .signIn(
            loginId: PresentationDataset.yashvi,
            password: password,
            requestedRole: AppRole.administrator,
          );
      final state = c.read(authControllerProvider);
      expect(state.awaitingRoleChoice, isFalse);
      expect(state.session!.activeRole, AppRole.administrator);
    });

    test('a role it does not hold is refused', () async {
      final c = container();
      final failure = await c
          .read(authControllerProvider.notifier)
          .signIn(
            loginId: PresentationDataset.yashvi,
            password: password,
            requestedRole: AppRole.hseOfficer,
          );
      expect(failure, SignInFailure.roleNotAuthorised);
    });
  });

  group('the route gate', () {
    test('an unauthenticated deep link to Profile goes to sign-in', () {
      expect(
        RouteGate.redirect(
          auth: AuthState.signedOut,
          location: '/profile',
          devToolsAvailable: false,
        ),
        '/sign-in',
      );
      expect(
        RouteGate.redirect(
          auth: AuthState.signedOut,
          location: '/profile/settings',
          devToolsAvailable: false,
        ),
        '/sign-in',
      );
    });

    test('setup is open before sign-in and closed after', () {
      for (final path in ['/select-site', '/select-role']) {
        expect(
          RouteGate.redirect(
            auth: AuthState.signedOut,
            location: path,
            devToolsAvailable: false,
          ),
          isNull,
          reason: path,
        );
      }
      final worker = AuthState(
        status: AuthStatus.signedIn,
        session: presentationSession(PresentationDataset.aditya),
      );
      expect(
        RouteGate.redirect(
          auth: worker,
          location: '/select-site',
          devToolsAvailable: false,
        ),
        '/home',
      );
    });
  });

  group('screens', () {
    Future<ProviderContainer> pumpAt(
      WidgetTester tester,
      String location, {
      Size size = const Size(390, 844),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final c = container();
      // No stored session: signed out, so the gate is decided.
      await tester.runAsync(
        () => c.read(authControllerProvider.notifier).restore(),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: DoseBandApp(
              config: dev,
              gate: AuthRouterGate(c),
              initialLocation: location,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    Finder continueButton() => find.byWidgetPredicate(
      (w) => w is AuthPrimaryButton && w.label == 'Continue',
    );
    bool enabled(WidgetTester tester) =>
        tester.widget<AuthPrimaryButton>(continueButton()).onPressed != null;

    testWidgets('Select Site: Continue waits for a site; the choice is '
        'kept', (tester) async {
      final c = await pumpAt(tester, '/select-site');
      expect(find.byType(SiteSelectionScreen), findsOneWidget);
      expect(find.text('Select Site'), findsOneWidget);
      expect(enabled(tester), isFalse);

      await tester.tap(find.text('Mangalore Refinery'));
      await tester.pump();
      expect(enabled(tester), isTrue);
      expect(c.read(onboardingProvider).site!.id, 'mangalore-refinery');

      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(find.byType(RoleSelectionScreen), findsOneWidget);
      expect(c.read(onboardingProvider).site!.id, 'mangalore-refinery');
    });

    testWidgets('Select Your Role: Continue waits for a role; Worker '
        'credentials for HSE are refused in words', (tester) async {
      final c = await pumpAt(tester, '/select-site');
      await tester.tap(find.text('Mangalore Refinery'));
      await tester.pump();
      await tester.tap(continueButton());
      await tester.pumpAndSettle();

      expect(find.text('Select Your Role'), findsOneWidget);
      for (final role in AppRole.values) {
        expect(find.text(role.label), findsOneWidget, reason: role.name);
      }
      expect(enabled(tester), isFalse);
      await tester.tap(find.text('HSE Officer'));
      await tester.pump();
      expect(enabled(tester), isTrue);
      // Choosing did not sign anyone in, or grant anything.
      expect(c.read(authControllerProvider).isSignedIn, isFalse);

      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(find.text('Setting up as HSE Officer'), findsOneWidget);

      await tester.tap(find.text('Contractor'));
      await tester.enterText(
        find.byType(TextField).at(0),
        PresentationDataset.aditya,
      );
      await tester.enterText(find.byType(TextField).at(1), password);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AuthPrimaryButton && w.label == 'Sign In',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This account is not authorized for the selected role.'),
        findsOneWidget,
      );
      expect(
        find.text('Select your assigned role and try again.'),
        findsOneWidget,
      );
      // Nothing about which roles the account does hold.
      expect(find.textContaining('belongs to'), findsNothing);
      expect(find.text('Worker'), findsNothing);
      expect(c.read(authControllerProvider).isSignedIn, isFalse);
    });

    testWidgets('role cards stay usable at 200% text on a 320 phone', (
      tester,
    ) async {
      await pumpAt(
        tester,
        '/select-role',
        size: const Size(320, 568),
        textScale: 2,
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
      await tester.ensureVisible(find.byType(SelectableRoleCard).last);
      await tester.tap(find.byType(SelectableRoleCard).last);
      await tester.pump();
      expect(enabled(tester), isTrue);
    });

    testWidgets('Worker B cannot open Worker A’s record by link', (
      tester,
    ) async {
      final c = await pumpAt(tester, '/sign-in');
      await c
          .read(authControllerProvider.notifier)
          .signIn(loginId: PresentationDataset.lavitra, password: password);
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/history/record/CAP-TEST-1'); // Aditya's record
      await tester.pumpAndSettle();
      expect(find.textContaining('outside your access'), findsOneWidget);
      expect(find.text('DB-2609-0010'), findsNothing);
    });

    // Presentation Skip: Sign In -> Select Site -> Select Your Role ->
    // that role's workspace, as the presentation account holding the role.
    Future<void> skipTo(WidgetTester tester, String site, String role) async {
      await tester.tap(find.byType(AuthSkipButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(site));
      await tester.pump();
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(role));
      await tester.tap(find.text(role));
      await tester.pump();
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
    }

    testWidgets('Skip -> site -> Worker lands on the worker Home', (
      tester,
    ) async {
      final c = await pumpAt(tester, '/sign-in');
      await skipTo(tester, 'Mangalore Refinery', 'Worker');
      final session = c.read(authControllerProvider).session!;
      expect(session.personId, PresentationDataset.aditya);
      expect(session.activeRole, AppRole.worker);
      expect(find.text('NO DOSEBAND ASSIGNED'), findsOneWidget);
    });

    testWidgets('Skip -> site -> HSE Officer opens the HSE workspace', (
      tester,
    ) async {
      final c = await pumpAt(tester, '/sign-in');
      await skipTo(tester, 'Mangalore Refinery', 'HSE Officer');
      final session = c.read(authControllerProvider).session!;
      expect(session.personId, PresentationDataset.samhita);
      expect(session.activeRole, AppRole.hseOfficer);
    });

    testWidgets('Skip never invents an account for a site that has none', (
      tester,
    ) async {
      final c = await pumpAt(tester, '/sign-in');
      await skipTo(tester, 'Corporate Office', 'Worker');
      expect(c.read(authControllerProvider).isSignedIn, isFalse);
      expect(
        find.text('No presentation account for that choice'),
        findsOneWidget,
      );
    });
  });

  test('production offers no Skip', () async {
    final c = ProviderContainer(
      overrides: [
        environmentConfigProvider.overrideWithValue(
          const EnvironmentConfig(
            environment: AppEnvironment.prod,
            supabaseUrl: '',
            supabaseAnonKey: '',
          ),
        ),
        operationsStoreProvider.overrideWithValue(
          InMemoryOperationsStore(PresentationDataset.build(now)),
        ),
      ],
    );
    addTearDown(c.dispose);
    final failure = await c
        .read(authControllerProvider.notifier)
        .signInAsPresentationRole(
          role: AppRole.worker,
          siteId: 'mangalore-refinery',
        );
    expect(failure, SignInFailure.notConnected);
    expect(c.read(authControllerProvider).isSignedIn, isFalse);
  });
}
