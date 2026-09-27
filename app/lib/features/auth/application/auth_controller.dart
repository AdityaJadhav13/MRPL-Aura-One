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
import '../../workflow/domain/worker_identity.dart';

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

/// The presentation sign-in, prefilled so a judge can press Sign In.
///
/// The password is **not in source control**: it is supplied at build time
/// (`--dart-define-from-file`, from a git-ignored file) and checked against
/// the salted verifier like any typed password. Null in production, and
/// wherever no password was supplied — the fields are then simply empty.
typedef PresentationCredentials = ({
  String loginId,
  WorkerType accountType,
  String password,
});

const String _presentationPassword = String.fromEnvironment(
  'DOSEBAND_PRESENTATION_PASSWORD',
);

final presentationCredentialsProvider = Provider<PresentationCredentials?>((
  ref,
) {
  if (!ref.watch(presentationAccessProvider)) return null;
  if (_presentationPassword.isEmpty) return null;
  return (
    loginId: 'CT-45832',
    accountType: WorkerType.contractor,
    password: _presentationPassword,
  );
});

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

  /// Whether this session is kept on disk (Remember Me). A restored session
  /// was, by definition.
  bool _remember = true;

  /// For Settings: whether the current session survives the app closing.
  bool get remembersSession => _remember;

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
    _remember = true;
    final role = person.hasRole(stored.activeRole)
        ? stored.activeRole
        : person.roles.first;
    state = AuthState(
      status: AuthStatus.signedIn,
      session: _sessionFor(person, role),
    );
  }

  /// Signs a person in.
  ///
  /// Authentication and authorization are separate steps, and fail with
  /// separate reasons:
  ///
  /// 1. **Identity** — the identity provider checks the ID and password.
  ///    An account-type mismatch (employee / contractor) is reported as
  ///    invalid credentials, so the form cannot be used to learn what kind
  ///    of account an ID is.
  /// 2. **Authorization** — only after the credentials are accepted: a
  ///    [requestedRole] must be one the directory grants the account, and a
  ///    [siteId] chosen during setup must be the account's assigned site.
  ///    Selecting a role never grants it.
  ///
  /// With no [requestedRole] the session opens in the account's first
  /// role; a person with several chooses among their own afterwards.
  /// [remember] decides whether the session survives the app closing.
  ///
  /// Enforced here, in the session layer, on this device. SERVER
  /// AUTHORIZATION ENFORCEMENT PENDING: there is no server to repeat it.
  ///
  /// The password is passed through and dropped; it is never stored or
  /// logged.
  Future<SignInFailure?> signIn({
    required String loginId,
    required String password,
    WorkerType? accountType,
    AppRole? requestedRole,
    String? siteId,
    bool remember = true,
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
        return _refuse(failure);
      case SignInAccepted(:final personId):
        final person = directory.person(personId);
        if (person == null ||
            (accountType != null && person.workerType != accountType)) {
          return _refuse(SignInFailure.invalidCredentials);
        }
        if (requestedRole != null && !person.hasRole(requestedRole)) {
          return _refuse(SignInFailure.roleNotAuthorised);
        }
        if (siteId != null && person.siteId != siteId) {
          return _refuse(SignInFailure.siteNotAuthorised);
        }
        return _establish(
          person,
          role: requestedRole ?? person.roles.first,
          siteId: siteId,
          remember: remember,
          chooseRole: requestedRole == null && person.roles.length > 1,
        );
    }
  }

  SignInFailure _refuse(SignInFailure failure) {
    state = AuthState(status: AuthStatus.signedOut, failure: failure);
    return failure;
  }

  Future<SignInFailure?> _establish(
    Person person, {
    required AppRole role,
    required bool remember,
    String? siteId,
    bool chooseRole = false,
  }) async {
    _remember = remember;
    final session = _sessionFor(person, role);
    if (remember) {
      await _store.save(
        StoredSession(
          personId: person.personId,
          activeRole: session.activeRole,
          siteId: siteId,
        ),
      );
    } else {
      // Not remembered: nothing on disk, and nothing left from before.
      await _store.clear();
    }
    await _audit(AuditAction.signedIn, session);
    state = AuthState(
      status: AuthStatus.signedIn,
      session: session,
      awaitingRoleChoice: chooseRole,
    );
    return null;
  }

  /// Completes sign-in for an account with several roles: opens [role]'s
  /// workspace, provided the account holds it. Returns false, and changes
  /// nothing, for a role the account does not hold.
  Future<bool> confirmRole(AppRole role) async {
    final current = state.session;
    if (current == null || !current.roles.contains(role)) return false;
    if (current.activeRole != role) {
      await switchWorkspace(role);
    }
    state = AuthState(status: AuthStatus.signedIn, session: state.session);
    return true;
  }

  /// Moves to another of the person's own workspaces.
  Future<void> switchWorkspace(AppRole role) async {
    final current = state.session;
    if (current == null || !current.roles.contains(role)) return;
    if (current.activeRole == role) return;
    final next = current.withRole(role);
    if (_remember) {
      final stored = await _store.load();
      await _store.save(
        StoredSession(
          personId: next.personId,
          activeRole: next.activeRole,
          siteId: stored?.siteId,
        ),
      );
    }
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
