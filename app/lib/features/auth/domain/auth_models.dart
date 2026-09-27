import 'package:flutter/foundation.dart';

import 'identity.dart';

/// Where a session's identity actually came from.
///
/// [demo] is the presentation directory on this device. The others exist so
/// that a session from a real integration is distinguishable from one that
/// was not — rather than every session looking equally authentic.
enum AuthSource {
  /// The presentation accounts on this device. A password was checked, but
  /// against presentation accounts, not an organisation directory.
  demo,

  /// A real organisational identity provider. Not connected.
  organizationIdentity,

  /// Gate-pass credential. Not connected.
  gatePass,
}

/// An application role.
///
/// **Application role modelling, not an identity-provider mapping.** Nothing
/// here corresponds to a group, claim or entitlement in any MRPL system.
///
/// A role comes from the person's directory record; nobody chooses one at
/// sign-in (PRODUCT BUILD v1 §54). A person holding several roles switches
/// between them explicitly, and only between those.
enum AppRole {
  worker('Worker', 'DoseBand monitoring, history and safety information'),
  supervisor(
    'Supervisor',
    'Authorized team monitoring and operational exceptions',
  ),
  hseOfficer(
    'HSE Officer',
    'Occupational exposure review, HSE records and reviews',
  ),
  management(
    'Management',
    'De-identified monitoring summaries, trends and reports',
  ),
  administrator(
    'Administrator',
    'System, users, roles, DoseBand inventory and configuration',
  );

  const AppRole(this.label, this.description);

  final String label;
  final String description;

  /// The order the role cards are shown in, as in the approved Select Your
  /// Role screen.
  static const List<AppRole> selectionOrder = [
    AppRole.worker,
    AppRole.hseOfficer,
    AppRole.supervisor,
    AppRole.management,
    AppRole.administrator,
  ];

  /// Where this role's workspace starts. Declared here so the role model and
  /// the routing cannot drift apart.
  String get landingRoute => switch (this) {
    AppRole.worker => '/home',
    AppRole.supervisor => '/supervisor',
    AppRole.hseOfficer => '/hse',
    AppRole.management => '/management',
    AppRole.administrator => '/admin',
  };
}

/// What kind of place a site is. Drives a card's icon.
enum SiteKind { refinery, office, retail, project, terminal }

/// A work location.
@immutable
final class Site {
  const Site({
    required this.id,
    required this.name,
    required this.locality,
    required this.kind,
    this.imageAsset,
  });

  final String id;
  final String name;
  final String locality;
  final SiteKind kind;
  final String? imageAsset;

  @override
  bool operator ==(Object other) => other is Site && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A signed-in person, acting in one of their roles.
///
/// Holds **no credential**: not the password, not a token. Only who, and as
/// what — which is also all that is persisted for session restore.
@immutable
final class AppSession {
  const AppSession({
    required this.personId,
    required this.displayName,
    required this.roles,
    required this.activeRole,
    required this.source,
  });

  final String personId;
  final String displayName;

  /// Every role the directory grants, in workspace order.
  final List<AppRole> roles;

  /// The workspace in use. Always one of [roles].
  final AppRole activeRole;

  final AuthSource source;

  bool get canSwitchWorkspace => roles.length > 1;

  /// True for every session today: nothing verifies against an organisation.
  bool get isPresentation => source == AuthSource.demo;

  AppSession withRole(AppRole role) {
    if (!roles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'not granted to $personId');
    }
    return AppSession(
      personId: personId,
      displayName: displayName,
      roles: roles,
      activeRole: role,
      source: source,
    );
  }
}

enum AuthStatus {
  /// Not yet known: the stored session has not been read.
  unknown,
  signedOut,
  signingIn,
  signedIn,
}

@immutable
final class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.failure,
    this.awaitingRoleChoice = false,
  });

  static const AuthState unknown = AuthState(status: AuthStatus.unknown);
  static const AuthState signedOut = AuthState(status: AuthStatus.signedOut);

  final AuthStatus status;
  final AppSession? session;

  /// Why the last sign-in attempt failed, until the next attempt.
  final SignInFailure? failure;

  /// Signed in to an account with several roles, without having requested
  /// one: the person must choose among **their own** roles before any
  /// workspace opens. The route gate holds them on Select Your Role.
  final bool awaitingRoleChoice;

  bool get isSignedIn => status == AuthStatus.signedIn && session != null;
}
