import 'package:flutter/foundation.dart';

import '../../auth/domain/access_policy.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/operations_snapshot.dart';
import '../domain/organisation.dart';

/// Who is asking: a person, acting in one of their roles.
@immutable
final class Actor {
  const Actor({required this.personId, required this.role});

  final String personId;
  final AppRole role;

  @override
  bool operator ==(Object other) =>
      other is Actor && other.personId == personId && other.role == role;

  @override
  int get hashCode => Object.hash(personId, role);
}

/// A request the policy refused. Typed, so a screen shows "you do not have
/// access to this" rather than a crash or an empty list that looks like "no
/// records".
final class AccessDenied implements Exception {
  const AccessDenied(this.reason);

  final String reason;

  @override
  String toString() => 'AccessDenied: $reason';
}

/// The authorisation model, evaluated against the operations store
/// (PRODUCT BUILD v1 §58, §106, §107).
///
/// ## Where this sits — and what it is not
///
/// **Local policy, SERVER ENFORCEMENT PENDING.** Every service call runs
/// through here, so a screen cannot fetch what the policy would refuse — the
/// check is below the UI, not in it. But it runs on the device that holds the
/// data; a central server re-checking every request is the target, and it
/// does not exist.
///
/// ## The actor is re-derived, never trusted
///
/// An [Actor] says "person P acting as role R". Nothing here takes that on
/// faith: the person must exist, be active, hold R in the directory *and* hold
/// a scope grant for R. A forged actor for a role the person does not have
/// gets nothing.
final class OperationsAccess {
  OperationsAccess(
    this.snapshot,
    this.actor, {
    this.policy = const DesignContractAccessPolicy(),
  });

  final OperationsSnapshot snapshot;
  final Actor actor;
  final AccessPolicy policy;

  Person? get person => snapshot.person(actor.personId);

  List<ScopeGrant> get _grants => snapshot.grants
      .where((g) => g.personId == actor.personId && g.role == actor.role)
      .toList();

  /// The actor really holds the role they claim.
  bool get isGenuine {
    final p = person;
    return p != null && p.active && p.hasRole(actor.role) && _grants.isNotEmpty;
  }

  void requireGenuine() {
    if (!isGenuine) {
      throw const AccessDenied(
        'This account does not hold the role it is acting in.',
      );
    }
  }

  void require(Permission permission) {
    requireGenuine();
    if (!policy.allows(actor.role, permission)) {
      throw AccessDenied(
        '${actor.role.label} accounts do not have "${permission.name}".',
      );
    }
  }

  void requireRole(AppRole role) {
    requireGenuine();
    if (actor.role != role) {
      throw AccessDenied('This is available to ${role.label} accounts only.');
    }
  }

  /// Workers whose identified occupational records (Class A) the actor may
  /// see. Empty for Management and Administrator, by design (§45, §58).
  Set<String> identifiedWorkers() {
    if (!isGenuine) return const {};
    if (policy.scopeFor(actor.role, DataClass.identifiedOccupational) == null) {
      return const {};
    }
    final out = <String>{};
    for (final g in _grants) {
      switch (g.scope) {
        case AccessScope.self:
          if (g.targetId == actor.personId) out.add(actor.personId);
        case AccessScope.team:
          // Both halves: the grant names the team, and the team names this
          // supervisor. A grant for someone else's team gives nothing.
          for (final t in snapshot.teams) {
            if (t.teamId == g.targetId && t.supervisorId == actor.personId) {
              out.addAll(t.memberIds);
            }
          }
        case AccessScope.department:
          for (final p in snapshot.people) {
            if (p.departmentId == g.targetId && p.hasRole(AppRole.worker)) {
              out.add(p.personId);
            }
          }
        case AccessScope.site:
          for (final p in snapshot.people) {
            if (p.siteId == g.targetId && p.hasRole(AppRole.worker)) {
              out.add(p.personId);
            }
          }
        case AccessScope.organization:
          // Organisation-wide identified access is never granted by
          // default (§147). A grant of it would have to be deliberate data.
          for (final p in snapshot.people) {
            if (p.hasRole(AppRole.worker)) out.add(p.personId);
          }
      }
    }
    return out;
  }

  bool canSeeWorker(String workerId) => identifiedWorkers().contains(workerId);

  void requireWorker(String workerId) {
    requireGenuine();
    if (!canSeeWorker(workerId)) {
      // Deliberately the same message whether the worker exists or not: the
      // refusal must not confirm that an identifier is real.
      throw const AccessDenied('This record is outside your access.');
    }
  }

  /// Sites the actor holds a site-scoped grant for.
  Set<String> grantedSites() => {
    for (final g in _grants)
      if (g.scope == AccessScope.site) g.targetId,
  };
}
