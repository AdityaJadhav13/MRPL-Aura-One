import 'package:flutter/foundation.dart';

import '../../../core/domain/provenance.dart';
import '../../auth/domain/access_policy.dart';
import '../../auth/domain/auth_models.dart';
import '../../workflow/domain/worker_identity.dart';

/// One person known to the organisation directory (PRODUCT BUILD v1 §29, §92).
///
/// Company-authoritative: nothing on this type is editable by the person it
/// describes. A correction goes through whoever administers the directory —
/// today, the presentation dataset; eventually, the organisation's identity
/// system, which is NOT CONNECTED.
///
/// Carries no credential. Passwords live in the identity directory as salted
/// hashes and never reach this record, the operations store or the session.
@immutable
final class Person {
  const Person({
    required this.personId,
    required this.displayName,
    required this.workerType,
    required this.siteId,
    required this.departmentId,
    required this.designation,
    required this.roles,
    required this.provenance,
    this.contractorCompany,
    this.defaultWorkAreaId,
    this.defaultShiftId,
    this.photoAsset,
    this.active = true,
  });

  /// The organisation identifier — employee or contractor ID. Also the login
  /// identifier for a presentation account.
  final String personId;
  final String displayName;
  final WorkerType workerType;
  final String? contractorCompany;
  final String siteId;
  final String departmentId;
  final String designation;

  /// Granted roles, in the order the workspaces are offered. The first is the
  /// workspace a sign-in lands in. Never empty: the codec refuses a person
  /// without one, and the dataset test asserts it.
  final List<AppRole> roles;

  final String? defaultWorkAreaId;
  final String? defaultShiftId;

  /// An approved photograph bundled with the app, or null. Null renders
  /// initials — no generated or stock portrait is ever substituted (§30).
  final String? photoAsset;

  final bool active;
  final RecordProvenance provenance;

  bool hasRole(AppRole role) => roles.contains(role);

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// An explicit supervisory team (§146: same department is not authorisation).
@immutable
final class Team {
  const Team({
    required this.teamId,
    required this.name,
    required this.siteId,
    required this.departmentId,
    required this.supervisorId,
    required this.memberIds,
  });

  final String teamId;
  final String name;
  final String siteId;
  final String departmentId;
  final String supervisorId;
  final List<String> memberIds;
}

/// A grant of one role over one scope (§58, §106).
///
/// The relational shape a server would hold: *who* may act *as what* over
/// *which* part of the organisation. Holding it as data, not as `if` checks
/// in screens, is what lets the policy tests exercise it directly.
@immutable
final class ScopeGrant {
  const ScopeGrant({
    required this.personId,
    required this.role,
    required this.scope,
    required this.targetId,
  });

  final String personId;
  final AppRole role;
  final AccessScope scope;

  /// The team id, site id or organisation id the grant covers. For
  /// [AccessScope.self], the person's own id.
  final String targetId;
}

/// A department, as the operations store names it.
@immutable
final class OrgDepartment {
  const OrgDepartment({
    required this.departmentId,
    required this.name,
    required this.siteId,
  });

  final String departmentId;
  final String name;
  final String siteId;
}
