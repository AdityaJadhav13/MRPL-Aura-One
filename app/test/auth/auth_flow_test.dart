import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/product_navigation.dart';
import 'package:h2s_doseband/core/env/environment.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/auth/data/demo_account.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/auth/presentation/screens/role_workspace_placeholder.dart';
import 'package:h2s_doseband/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:h2s_doseband/features/auth/presentation/screens/site_selection_screen.dart';
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

late ProviderContainer container;

/// Scrolls [finder] into view, then taps it.
///
/// The sign-in panel is taller than a 390x844 viewport once the demo-access
/// card is included, so controls below the primary button are off-screen at
/// the start. A bare `tap` there silently misses.
Future<void> tapScrolled(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> pumpAuth(
  WidgetTester tester,
  String location, {
  EnvironmentConfig config = _dev,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  container = ProviderContainer(
    overrides: [environmentConfigProvider.overrideWithValue(config)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  await tester.pump(const Duration(milliseconds: 400));
}

AuthState get authState => container.read(authControllerProvider);

void main() {
  group('splash', () {
    testWidgets('shows the corporate identity and the product', (tester) async {
      await pumpAuth(tester, '/splash');
      expect(
        find.text('Mangalore Refinery\nand Petrochemicals Limited'),
        findsOneWidget,
      );
      expect(find.text('DoseBand'), findsOneWidget);
      expect(find.text('OCCUPATIONAL EXPOSURE MONITORING'), findsOneWidget);
      expect(find.text('Safe People\nSustainable Operations'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    });

    testWidgets('advances to sign-in on its own', (tester) async {
      await pumpAuth(tester, '/splash');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('the development skip control', () {
    for (final location in <String>[
      '/splash',
      '/sign-in',
      '/select-site',
      '/select-role',
    ]) {
      testWidgets('$location · present in a development build', (tester) async {
        await pumpAuth(tester, location);
        expect(find.text('Skip'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      });

      testWidgets('$location · ABSENT in a production build', (tester) async {
        // The guarantee that matters: a shipped build cannot bypass sign-in.
        await pumpAuth(tester, location, config: _prod);
        expect(find.text('Skip'), findsNothing);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      });
    }

    testWidgets('skipping creates an obviously synthetic demo session', (
      tester,
    ) async {
      await pumpAuth(tester, '/sign-in');
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      final session = authState.session;
      expect(session, isNotNull);
      expect(session!.isDemo, isTrue);
      expect(session.source, AuthSource.demo);
      expect(session.userId, 'DEMO-USER');
      expect(session.displayName, 'Demo User');
    });
  });

  group('sign in', () {
    testWidgets('defaults to Employee and switches to Contractor', (
      tester,
    ) async {
      await pumpAuth(tester, '/sign-in');
      expect(find.text('User ID / Employee ID'), findsOneWidget);
      expect(find.text('Contractor Company'), findsNothing);

      await tester.tap(find.text('Contractor'));
      await tester.pumpAndSettle();

      expect(find.text('Worker / Contractor ID'), findsOneWidget);
      expect(find.text('Contractor Company'), findsOneWidget);
    });

    testWidgets('refuses an empty form and names every missing field', (
      tester,
    ) async {
      await pumpAuth(tester, '/sign-in');
      await tapScrolled(tester, find.widgetWithText(FilledButton, 'Sign In'));

      expect(find.text('Enter your User ID or Employee ID'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(find.byType(SiteSelectionScreen), findsNothing);
      expect(authState.isSignedIn, isFalse);
    });

    testWidgets('a contractor must also name their company', (tester) async {
      await pumpAuth(tester, '/sign-in');
      await tester.tap(find.text('Contractor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'C-1001');
      await tester.enterText(find.byType(TextField).last, 'secret');
      await tapScrolled(tester, find.widgetWithText(FilledButton, 'Sign In'));

      expect(find.text('Enter your contractor company'), findsOneWidget);
      expect(authState.isSignedIn, isFalse);
    });

    testWidgets('the demo account advances to site selection', (tester) async {
      await pumpAuth(tester, '/sign-in');
      await tapScrolled(tester, find.text('Use demo credentials'));
      await tapScrolled(tester, find.widgetWithText(FilledButton, 'Sign In'));

      expect(find.byType(SiteSelectionScreen), findsOneWidget);
      expect(authState.identity!.userId, DemoAccount.workerId);
      expect(authState.identity!.displayName, DemoAccount.displayName);
      expect(
        authState.identity!.contractorCompany,
        DemoAccount.contractorCompany,
      );
      // Unverified, and the session says so.
      expect(authState.identity!.source, AuthSource.demo);
    });

    testWidgets('a complete form with the wrong values is refused', (
      tester,
    ) async {
      await pumpAuth(tester, '/sign-in');
      await tester.enterText(find.byType(TextField).first, 'EMP-2087');
      await tester.enterText(find.byType(TextField).last, 'whatever');
      await tapScrolled(tester, find.widgetWithText(FilledButton, 'Sign In'));

      expect(find.byType(SiteSelectionScreen), findsNothing);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(authState.isSignedIn, isFalse);
      expect(
        find.textContaining('Demo credentials do not match'),
        findsOneWidget,
      );
    });

    testWidgets('a refusal blames the demo account, not an organisation', (
      tester,
    ) async {
      // MRPL was never queried. Saying "your MRPL account is invalid" would
      // be an invention, on the screen where a user is most likely to
      // believe a claim about their identity.
      await pumpAuth(tester, '/sign-in');
      await tester.enterText(find.byType(TextField).first, 'EMP-2087');
      await tester.enterText(find.byType(TextField).last, 'whatever');
      await tapScrolled(tester, find.widgetWithText(FilledButton, 'Sign In'));

      final notice = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .where((t) => t.contains('do not match'))
          .single;
      expect(notice, isNot(contains('mrpl')));
      expect(notice, isNot(contains('account is invalid')));
    });

    testWidgets('the demo-fill control populates every field', (tester) async {
      await pumpAuth(tester, '/sign-in');
      await tapScrolled(tester, find.text('Use demo credentials'));

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      final values = fields.map((f) => f.controller?.text).toList();
      expect(values, contains(DemoAccount.workerId));
      expect(values, contains(DemoAccount.contractorCompany));
      expect(values, contains(DemoAccount.password));
      // It also switches the segmented control, because the demo account is a
      // contractor and a half-filled form is worse than none.
      expect(find.text('Contractor Company'), findsOneWidget);
    });

    testWidgets('the demo credentials are shown, labelled as demo', (
      tester,
    ) async {
      await pumpAuth(tester, '/sign-in');
      expect(find.text('DEMO ACCESS'), findsOneWidget);
      expect(find.text(DemoAccount.workerId), findsOneWidget);
      expect(find.text(DemoAccount.password), findsOneWidget);
    });

    testWidgets('the password is never retained anywhere', (tester) async {
      await pumpAuth(tester, '/sign-in');
      await tapScrolled(tester, find.text('Use demo credentials'));
      await tapScrolled(tester, find.widgetWithText(FilledButton, 'Sign In'));

      final identity = authState.identity!;
      expect(identity.userId, isNot(contains(DemoAccount.password)));
      expect(identity.displayName, isNot(contains(DemoAccount.password)));
      expect(identity.contractorCompany, isNot(contains(DemoAccount.password)));
    });

    testWidgets('password visibility toggles', (tester) async {
      await pumpAuth(tester, '/sign-in');
      TextField passwordField() =>
          tester.widgetList<TextField>(find.byType(TextField)).last;

      expect(passwordField().obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(passwordField().obscureText, isFalse);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expect(passwordField().obscureText, isTrue);
    });

    testWidgets('gate pass and password recovery say they are not connected', (
      tester,
    ) async {
      await pumpAuth(tester, '/sign-in');

      await tapScrolled(tester, find.text('Sign in with Gate Pass QR'));
      expect(find.text('Gate Pass sign-in'), findsOneWidget);
      expect(find.text('Gate pass · NOT CONNECTED'), findsOneWidget);
      // It must not claim a pass was read or an identity established.
      expect(find.textContaining('cannot read or verify'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();

      await tapScrolled(tester, find.text('Forgot password?'));
      expect(find.text('Password recovery'), findsOneWidget);
      expect(
        find.text('Organisation identity · NOT CONNECTED'),
        findsOneWidget,
      );
      // It must not claim anything was sent.
      final sheetText = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .join(' ');
      expect(sheetText, isNot(contains('email sent')));
      expect(sheetText, isNot(contains('check your inbox')));
      expect(sheetText, contains('nothing has been sent'));
    });
  });

  group('site selection', () {
    testWidgets('renders the configured sites', (tester) async {
      await pumpAuth(tester, '/select-site');
      for (final name in <String>[
        'Mangalore Refinery',
        'Corporate Office',
        'MRPL Retail (HiQ)',
        'Projects Site',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('Continue is disabled until a site is chosen', (tester) async {
      await pumpAuth(tester, '/select-site');
      FilledButton button() =>
          tester.widget<FilledButton>(find.byType(FilledButton));

      expect(button().onPressed, isNull);

      await tester.tap(find.text('Mangalore Refinery'));
      await tester.pumpAndSettle();

      expect(authState.site?.id, 'mangalore-refinery');
      expect(button().onPressed, isNotNull);
    });

    testWidgets('choosing a site advances to role selection', (tester) async {
      await pumpAuth(tester, '/select-site');
      await tester.tap(find.text('Corporate Office'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Select Your Role'), findsOneWidget);
      expect(authState.site?.id, 'corporate-office');
    });
  });

  group('role selection', () {
    testWidgets('Continue is disabled until a role is chosen', (tester) async {
      await pumpAuth(tester, '/select-role');
      FilledButton button() =>
          tester.widget<FilledButton>(find.byType(FilledButton));

      expect(button().onPressed, isNull);
      await tester.tap(find.text('Worker'));
      await tester.pumpAndSettle();
      expect(authState.role, AppRole.worker);
      expect(button().onPressed, isNotNull);
    });

    testWidgets('every role in the model is offered', (tester) async {
      await pumpAuth(tester, '/select-role');
      for (final role in AppRole.values) {
        expect(find.text(role.label), findsOneWidget);
      }
    });

    testWidgets('Worker enters the existing worker shell', (tester) async {
      await pumpAuth(tester, '/select-role');
      await tester.tap(find.text('Worker'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingNavigationBar), findsOneWidget);
    });

    testWidgets('an unbuilt role reaches an honest placeholder, not the '
        'worker UI', (tester) async {
      await pumpAuth(tester, '/select-role');
      await tester.tap(find.text('Supervisor'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(RoleWorkspacePlaceholder), findsOneWidget);
      expect(find.text('Supervisor workspace'), findsOneWidget);
      expect(
        find.textContaining('Interface under development'),
        findsOneWidget,
      );
      expect(find.byType(FloatingNavigationBar), findsNothing);
    });
  });

  group('the whole flow', () {
    testWidgets('splash to sign-in to site to role to the worker shell', (
      tester,
    ) async {
      await pumpAuth(tester, '/splash');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);

      await tapScrolled(tester, find.text('Use demo credentials'));
      await tapScrolled(tester, find.widgetWithText(FilledButton, 'Sign In'));

      await tester.tap(find.text('Mangalore Refinery'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Worker'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingNavigationBar), findsOneWidget);

      final session = authState.session!;
      expect(session.userId, DemoAccount.workerId);
      expect(session.site.id, 'mangalore-refinery');
      expect(session.role, AppRole.worker);
      expect(session.isDemo, isTrue);
    });
  });

  group('responsive and accessible', () {
    for (final width in <double>[360, 390, 430]) {
      for (final location in <String>[
        '/splash',
        '/sign-in',
        '/select-site',
        '/select-role',
      ]) {
        testWidgets('$location fits ${width.toInt()} wide', (tester) async {
          await pumpAuth(tester, location, size: Size(width, 780));
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
        });
      }
    }

    for (final location in <String>[
      '/sign-in',
      '/select-site',
      '/select-role',
    ]) {
      testWidgets('$location survives 200% text', (tester) async {
        await pumpAuth(
          tester,
          location,
          size: const Size(360, 780),
          textScale: 2.0,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the keyboard does not break sign-in', (tester) async {
      await pumpAuth(tester, '/sign-in');
      // Simulate the inset the keyboard imposes.
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('selection state is exposed to assistive technology', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpAuth(tester, '/select-role');

      expect(
        tester.getSemantics(find.text('Worker')),
        matchesSemantics(
          label:
              'Worker. Scan DoseBand, view your history and access '
              'safety information',
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.text('Worker'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Worker')),
        matchesSemantics(
          label:
              'Worker. Scan DoseBand, view your history and access '
              'safety information',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
