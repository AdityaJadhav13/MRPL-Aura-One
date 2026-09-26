import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env/environment.dart';
import '../data/demo_auth_repository.dart';
import '../data/site_repository.dart';
import '../domain/auth_demo_config.dart';
import '../domain/auth_models.dart';

/// The build's environment. Overridden at the root of the app and in tests, so
/// no screen reads configuration from a global.
final environmentConfigProvider = Provider<EnvironmentConfig>(
  (_) => throw UnimplementedError(
    'environmentConfigProvider must be overridden at the application root',
  ),
);

/// What the authentication flow may do in this build.
final authDemoConfigProvider = Provider<AuthDemoConfig>(
  (ref) => AuthDemoConfig.fromEnvironment(ref.watch(environmentConfigProvider)),
);

final siteRepositoryProvider = Provider<SiteRepository>(
  (_) => const SeededSiteRepository(),
);

final demoAuthRepositoryProvider = Provider<DemoAuthRepository>(
  (_) => const DemoAuthRepository(),
);

/// The selectable sites.
final availableSitesProvider = Provider<List<Site>>(
  (ref) => ref.watch(siteRepositoryProvider).sites(),
);

/// Progress through sign-in → site → role.
///
/// Synchronous: nothing here awaits anything, because nothing here talks to
/// anything. When a real identity provider arrives this becomes async and the
/// screens gain a loading state; until then a spinner would be theatre.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  DemoAuthRepository get _repository => ref.read(demoAuthRepositoryProvider);

  /// Validates the form and, if complete, records a demo identity.
  ///
  /// The password is passed in, checked for emptiness inside the repository,
  /// and never retained: it is not stored on the state, the identity or the
  /// session.
  DemoAuthResult submitSignIn({
    required AuthUserType userType,
    required String userId,
    required String password,
    String contractorCompany = '',
  }) {
    final result = _repository.signIn(
      userType: userType,
      userId: userId,
      password: password,
      contractorCompany: contractorCompany,
    );
    if (result is DemoAuthAccepted) {
      state = state.copyWith(identity: result.identity);
    }
    return result;
  }

  /// Bypasses sign-in with an obviously synthetic identity.
  ///
  /// Callers are responsible for checking [AuthDemoConfig.allowSkip] first; the
  /// screens do not render the control at all when it is false.
  void skipAuthentication() {
    final sites = ref.read(availableSitesProvider);
    state = AuthState(
      identity: _repository.skipIdentity(),
      site: sites.isEmpty ? null : sites.first,
      role: AppRole.worker,
    );
  }

  void selectSite(Site site) => state = state.copyWith(site: site);

  void selectRole(AppRole role) => state = state.copyWith(role: role);

  void signOut() => state = state.copyWith(clear: true);
}
