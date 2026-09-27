import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env/environment.dart';
import '../../../core/time/clock.dart';
import '../../operations/application/access.dart';
import '../../operations/application/operations_repository.dart';
import '../../operations/domain/audit.dart';
import '../../operations/domain/organisation.dart';
import '../data/auth_session_store.dart';
import '../data/site_repository.dart';
import '../domain/auth_models.dart';
import '../domain/identity.dart';

/// The build's environment. Overridden at the root of the app and in tests, so
/// no screen reads configuration from a global.
final environmentConfigProvider = Provider<EnvironmentConfig>(
  (_) => throw UnimplementedError(
    'environmentConfigProvider must be overridden at the application root',
  ),
);

/// Where identities are checked. The presentation directory wherever
/// simulation is available; the organisation provider — NOT CONNECTED — in a
/// production build, which therefore cannot sign anyone in and says so.
final identityProviderProvider = Provider<IdentityProvider>((ref) {
  final config = ref.watch(environmentConfigProvider);
  return config.simulationAvailable
      ? PresentationIdentityProvider.shipped()
      : const NotConnectedIdentityProvider();
});

/// Whether the one-tap presentation account list may be offered. Derived from
/// the same single fact as simulation, so the two cannot disagree: never in
/// production.
final presentationAccessProvider = Provider<bool>(
  (ref) => ref.watch(environmentConfigProvider).simulationAvailable,
);

final authSessionStoreProvider = Provider<AuthSessionStore>(
  (_) => InMemoryAuthSessionStore(),
);

final siteRepositoryProvider = Provider<SiteRepository>(
  (_) => const SeededSiteRepository(),
);

final availableSitesProvider = Provider<List<Site>>(
  (ref) => ref.watch(siteRepositoryProvider).sites(),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// The signed-in person acting in their active role, or null. Every
/// operations service takes this; none takes a role from a screen.
final currentActorProvider = Provider<Actor?>((ref) {
  final s = ref.watch(authControllerProvider).session;
  return s == null ? null : Actor(personId: s.personId, role: s.activeRole);
});

/// Sign-in, restore, workspace switching and sign-out.
///
/// The role is never chosen: it is read from the person's directory record,
/// and a switch is accepted only to a role that record grants (§54).
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.unknown;

  AuthSessionStore get _store => ref.read(authSessionStoreProvider);

  /// Reads the stored session, re-checking it against the directory. Called
  /// once, by the splash screen.
  Future<void> restore() async {
    if (state.status != AuthStatus.unknown) return;
    final stored = await _store.load();
    if (stored == null) {
      state = AuthState.signedOut;
      return;
    }
    final directory = await ref.read(operationsProvider.future);
    final person = directory.person(stored.personId);
    if (person == null || !person.active) {
      await _store.clear();
      state = AuthState.signedOut;
      return;
    }
    final role = person.hasRole(stored.activeRole)
        ? stored.activeRole
        : person.roles.first;
    state = AuthState(
      status: AuthStatus.signedIn,
      session: _sessionFor(person, role),
    );
  }

  /// Checks the ID and password with the identity provider. Returns why it
  /// failed, or null on success. The password is passed through and dropped.
  Future<SignInFailure?> signIn({
    required String loginId,
    required String password,
  }) async {
    if (state.status == AuthStatus.signingIn) return null;
    state = const AuthState(status: AuthStatus.signingIn);
    final directory = await ref.read(operationsProvider.future);
    final outcome = await ref
        .read(identityProviderProvider)
        .signIn(
          loginId: loginId,
          password: password,
          isActive: (id) => directory.person(id)?.active ?? false,
        );
    switch (outcome) {
      case SignInRefused(:final failure):
        state = AuthState(status: AuthStatus.signedOut, failure: failure);
        return failure;
      case SignInAccepted(:final personId):
        return _establish(personId);
    }
  }

  /// One-tap sign-in to a presentation account. Refused unless the build
  /// offers presentation access — never in production.
  Future<SignInFailure?> signInAsPresentation(String personId) async {
    if (!ref.read(presentationAccessProvider)) {
      state = const AuthState(
        status: AuthStatus.signedOut,
        failure: SignInFailure.notConnected,
      );
      return SignInFailure.notConnected;
    }
    state = const AuthState(status: AuthStatus.signingIn);
    final directory = await ref.read(operationsProvider.future);
    if (!(directory.person(personId)?.active ?? false)) {
      state = const AuthState(
        status: AuthStatus.signedOut,
        failure: SignInFailure.accountSuspended,
      );
      return SignInFailure.accountSuspended;
    }
    return _establish(personId);
  }

  Future<SignInFailure?> _establish(String personId) async {
    final directory = await ref.read(operationsProvider.future);
    final person = directory.person(personId);
    if (person == null) {
      state = const AuthState(
        status: AuthStatus.signedOut,
        failure: SignInFailure.invalidCredentials,
      );
      return SignInFailure.invalidCredentials;
    }
    final session = _sessionFor(person, person.roles.first);
    await _store.save(
      StoredSession(personId: person.personId, activeRole: session.activeRole),
    );
    await _audit(AuditAction.signedIn, session);
    state = AuthState(status: AuthStatus.signedIn, session: session);
    return null;
  }

  /// Moves to another of the person's own workspaces.
  Future<void> switchWorkspace(AppRole role) async {
    final current = state.session;
    if (current == null || !current.roles.contains(role)) return;
    if (current.activeRole == role) return;
    final next = current.withRole(role);
    await _store.save(
      StoredSession(personId: next.personId, activeRole: next.activeRole),
    );
    await _audit(AuditAction.workspaceSwitched, next);
    state = AuthState(status: AuthStatus.signedIn, session: next);
  }

  Future<void> signOut() async {
    final current = state.session;
    await _store.clear();
    if (current != null) await _audit(AuditAction.signedOut, current);
    state = AuthState.signedOut;
  }

  AppSession _sessionFor(Person person, AppRole role) => AppSession(
    personId: person.personId,
    displayName: person.displayName,
    roles: person.roles,
    activeRole: role,
    source: ref.read(identityProviderProvider).source,
  );

  Future<void> _audit(AuditAction action, AppSession session) {
    final ids = ref.read(idGeneratorProvider);
    final now = ref.read(clockProvider);
    return ref
        .read(operationsProvider.notifier)
        .transact(
          (s) => (
            next: s.appendAudit(
              AuditEvent(
                eventId: ids.next('AUD'),
                at: now(),
                actorId: session.personId,
                actorRole: session.activeRole,
                action: action,
                subjectType: 'account',
                subjectId: session.personId,
                detail: action == AuditAction.workspaceSwitched
                    ? 'Now ${session.activeRole.label}'
                    : null,
              ),
            ),
            result: null,
          ),
        );
  }
}
