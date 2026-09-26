import 'package:flutter/foundation.dart';

/// Which identity route a person signed in through.
enum AuthUserType {
  employee('Employee'),
  contractor('Contractor');

  const AuthUserType(this.label);

  final String label;
}

/// Where a session's identity actually came from.
///
/// Only [demo] is reachable today. The other values exist so that the day a
/// real integration lands, a session that came from it is distinguishable from
/// one that did not — rather than every session looking equally authentic.
enum AuthSource {
  /// UI-only. **No identity verification occurred.**
  demo,

  /// A real organisational identity provider. Not connected.
  organizationIdentity,

  /// Gate-pass credential. Not connected.
  gatePass,
}

/// An application role.
///
/// **This is application role modelling, not an identity-provider mapping.**
/// Nothing here corresponds to a group, claim or entitlement in any MRPL
/// system; role-to-IAM mapping is a future integration.
enum AppRole {
  worker(
    'Worker',
    'Scan DoseBand, view your history and access safety information',
  ),
  hseOfficer(
    'HSE Officer',
    'Review records, manage workers and HSE operations',
  ),
  supervisor('Supervisor', 'Team monitoring and approvals'),
  management('Management', 'Reports, dashboards and oversight'),
  administrator('Administrator', 'System configuration and user management');

  const AppRole(this.label, this.description);

  final String label;
  final String description;

  /// Whether this role has a built interface yet.
  ///
  /// Worker, HSE officer and administrator have their own shells. Supervisor
  /// and management do not: they reach an honest placeholder rather than being
  /// dropped into somebody else's interface, which would show them a tool
  /// built for a different job and imply it was theirs.
  bool get hasImplementedWorkspace => switch (this) {
    AppRole.worker || AppRole.hseOfficer || AppRole.administrator => true,
    AppRole.supervisor || AppRole.management => false,
  };

  /// Where selecting this role lands.
  ///
  /// Declared here rather than in the screen so the role model and the routing
  /// cannot drift apart — adding a role is a compile error until its landing
  /// place is decided.
  String get landingRoute => switch (this) {
    AppRole.worker => '/home',
    AppRole.hseOfficer => '/hse',
    AppRole.administrator => '/admin',
    AppRole.supervisor || AppRole.management => '/workspace/$name',
  };
}

/// What kind of place a site is. Drives the card's icon.
enum SiteKind { refinery, office, retail, project, terminal }

/// A selectable work location.
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

  /// Free-text locality shown under the name, e.g. "Katipalla, Mangalore".
  final String locality;

  final SiteKind kind;

  /// A bundled photograph for the card's thumbnail.
  ///
  /// Null where no licensed image has been supplied for that site, in which
  /// case the card draws an illustrated plate for its [kind] instead. Supply
  /// an asset here and the card uses it with no other change.
  final String? imageAsset;

  @override
  bool operator ==(Object other) => other is Site && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A signed-in session.
///
/// [isDemo] is not decoration. A demo session must be visibly and
/// programmatically distinguishable from a real one everywhere it surfaces, so
/// that nothing downstream can treat an unverified identity as verified.
@immutable
final class AuthSession {
  const AuthSession({
    required this.userId,
    required this.displayName,
    required this.userType,
    required this.site,
    required this.role,
    required this.source,
    this.contractorCompany,
  });

  final String userId;
  final String displayName;
  final AuthUserType userType;
  final Site site;
  final AppRole role;
  final AuthSource source;
  final String? contractorCompany;

  /// True while no real identity provider has verified anything — which is
  /// every session today.
  bool get isDemo => source == AuthSource.demo;

  AuthSession copyWith({Site? site, AppRole? role}) => AuthSession(
    userId: userId,
    displayName: displayName,
    userType: userType,
    site: site ?? this.site,
    role: role ?? this.role,
    source: source,
    contractorCompany: contractorCompany,
  );
}

/// Progress through the authentication flow.
///
/// Site and role are chosen after sign-in, so a partially complete session is
/// a real state rather than a set of nullable fields on a session object.
@immutable
final class AuthState {
  const AuthState({this.identity, this.site, this.role});

  /// Set once sign-in (or skip) has produced an identity.
  final DemoIdentity? identity;
  final Site? site;
  final AppRole? role;

  bool get isSignedIn => identity != null;

  /// Complete enough to enter the application.
  AuthSession? get session {
    final i = identity;
    final s = site;
    final r = role;
    if (i == null || s == null || r == null) return null;
    return AuthSession(
      userId: i.userId,
      displayName: i.displayName,
      userType: i.userType,
      site: s,
      role: r,
      source: i.source,
      contractorCompany: i.contractorCompany,
    );
  }

  AuthState copyWith({
    DemoIdentity? identity,
    Site? site,
    AppRole? role,
    bool clear = false,
  }) {
    if (clear) return const AuthState();
    return AuthState(
      identity: identity ?? this.identity,
      site: site ?? this.site,
      role: role ?? this.role,
    );
  }
}

/// An identity produced without verifying anything.
///
/// Named for what it is. There is no `Identity` type for this to be mistaken
/// for, and there will not be one until something actually verifies a
/// credential.
@immutable
final class DemoIdentity {
  const DemoIdentity({
    required this.userId,
    required this.displayName,
    required this.userType,
    required this.source,
    this.contractorCompany,
  });

  final String userId;
  final String displayName;
  final AuthUserType userType;
  final AuthSource source;
  final String? contractorCompany;
}
