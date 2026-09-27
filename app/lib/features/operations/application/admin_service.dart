import 'package:flutter/foundation.dart';

import '../../../core/domain/doseband.dart';
import '../../auth/domain/access_policy.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/audit.dart';
import '../domain/inventory.dart';
import '../domain/operations_snapshot.dart';
import '../domain/organisation.dart';
import 'access.dart';
import 'local_doseband_registry.dart';
import 'operations_repository.dart';
import 'worker_service.dart';

@immutable
final class AccountRow {
  const AccountRow({
    required this.person,
    required this.grants,
    required this.departmentName,
  });

  /// Directory data only: name, ID, roles, site, department, designation.
  /// Nothing about monitoring or exposure.
  final Person person;
  final List<ScopeGrant> grants;
  final String? departmentName;
}

@immutable
final class LotSummary {
  const LotSummary({
    required this.lot,
    required this.formulation,
    required this.counts,
  });

  final DoseBandLot lot;
  final SensorFormulation? formulation;

  /// Mutually exclusive buckets; they sum to [total].
  final Map<InventoryBucket, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);
}

/// One serialised band as the administrator sees it: its state, never who
/// holds it (§45, §59 — the DoseBand-to-person link is Class A).
@immutable
final class BandRow {
  const BandRow({required this.band, required this.bucket});

  final DoseBand band;
  final InventoryBucket bucket;
}

/// An audit event as the administrator sees it. For occupational actions the
/// person is withheld: administering the system is not occupational-exposure
/// access (§149).
@immutable
final class AdminAuditRow {
  const AdminAuditRow({
    required this.at,
    required this.action,
    required this.actor,
    required this.subject,
    required this.detail,
  });

  final DateTime at;
  final AuditAction action;
  final String actor;
  final String subject;
  final String? detail;
}

const Set<AuditAction> _occupational = {
  AuditAction.dosebandClaimed,
  AuditAction.preUseChecked,
  AuditAction.assignmentCancelled,
  AuditAction.monitoringStarted,
  AuditAction.monitoringEnded,
  AuditAction.monitoringInterrupted,
  AuditAction.dosebandReported,
  AuditAction.measurementRecorded,
  AuditAction.measurementSuperseded,
  AuditAction.reviewStateChanged,
  AuditAction.dispositionRecorded,
};

/// System and inventory administration (§44–§46). Holds no method that
/// returns a session, an assignment or a measurement record.
final class AdminView {
  AdminView(OperationsSnapshot snapshot, Actor actor)
    : _access = OperationsAccess(snapshot, actor) {
    _access.requireRole(AppRole.administrator);
  }

  final OperationsAccess _access;

  OperationsSnapshot get _s => _access.snapshot;

  List<AccountRow> accounts({String query = '', AppRole? role}) {
    _access.require(Permission.manageAccounts);
    final q = query.trim().toLowerCase();
    return [
      for (final p in _s.people)
        if ((role == null || p.hasRole(role)) &&
            (q.isEmpty ||
                p.displayName.toLowerCase().contains(q) ||
                p.personId.toLowerCase().contains(q) ||
                p.designation.toLowerCase().contains(q)))
          AccountRow(
            person: p,
            grants: _s.grants.where((g) => g.personId == p.personId).toList(),
            departmentName: _s.department(p.departmentId)?.name,
          ),
    ]..sort((a, b) => a.person.displayName.compareTo(b.person.displayName));
  }

  List<Team> get teams => _s.teams;

  String? nameOf(String personId) => _s.person(personId)?.displayName;

  List<OrgDepartment> get departments => _s.departments;

  List<SensorFormulation> get formulations => _s.formulations;

  List<LotSummary> lots(DateTime now) {
    _access.require(Permission.manageDoseBandInventory);
    return [
      for (final l in _s.lots)
        LotSummary(
          lot: l,
          formulation: _s.formulation(l.formulationId),
          counts: () {
            final c = <InventoryBucket, int>{};
            for (final b in _s.bands.values.where((b) => b.lotId == l.lotId)) {
              final k = DoseBandEligibility.bucketOf(_s, b, now);
              c[k] = (c[k] ?? 0) + 1;
            }
            return c;
          }(),
        ),
    ];
  }

  List<BandRow> bands(
    DateTime now, {
    String? lotId,
    String query = '',
    InventoryBucket? bucket,
  }) {
    _access.require(Permission.manageDoseBandInventory);
    final q = query.trim().toLowerCase();
    final out = <BandRow>[];
    for (final b in _s.bands.values) {
      if (lotId != null && b.lotId != lotId) continue;
      if (q.isNotEmpty && !b.dosebandId.toLowerCase().contains(q)) continue;
      final k = DoseBandEligibility.bucketOf(_s, b, now);
      if (bucket != null && k != bucket) continue;
      out.add(BandRow(band: b, bucket: k));
    }
    out.sort((a, b) => a.band.dosebandId.compareTo(b.band.dosebandId));
    return out;
  }

  Map<InventoryBucket, int> totals(DateTime now) {
    final t = <InventoryBucket, int>{};
    for (final l in lots(now)) {
      for (final e in l.counts.entries) {
        t[e.key] = (t[e.key] ?? 0) + e.value;
      }
    }
    return t;
  }

  List<AdminAuditRow> audit({int limit = 200}) {
    _access.require(Permission.viewSystemAudit);
    final rows = [
      for (final e in _s.audit)
        AdminAuditRow(
          at: e.at,
          action: e.action,
          actor: _occupational.contains(e.action)
              ? '${e.actorRole.label} (identity withheld)'
              : '${_s.person(e.actorId)?.displayName ?? e.actorId} '
                    '(${e.actorRole.label})',
          subject:
              _occupational.contains(e.action) && e.subjectType != 'doseband'
              ? e.subjectType
              : '${e.subjectType} ${e.subjectId}',
          detail: _occupational.contains(e.action) ? null : e.detail,
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return rows.take(limit).toList();
  }

  String get datasetVersion => _s.datasetVersion;
  DateTime get seededAt => _s.seededAt;
  int get auditEventCount => _s.audit.length;
}

/// Inventory and account writes.
final class AdminCommands {
  AdminCommands({
    required this.repository,
    required this.actor,
    required this.ids,
    required this.now,
  });

  final OperationsRepository repository;
  final Actor actor;
  final IdGenerator ids;
  final DateTime Function() now;

  /// Takes a band out of service, through the lifecycle policy. A band in use
  /// cannot be disposed of from here: its period has to end first.
  Future<void> setBandCondition({
    required String dosebandId,
    required DoseBandLifecycle to,
  }) => repository.transact((s) {
    OperationsAccess(s, actor)
      ..requireRole(AppRole.administrator)
      ..require(Permission.manageDoseBandInventory);
    const allowed = {
      DoseBandLifecycle.damaged,
      DoseBandLifecycle.lost,
      DoseBandLifecycle.invalid,
      DoseBandLifecycle.expired,
      DoseBandLifecycle.disposed,
    };
    if (!allowed.contains(to)) {
      throw OperationRefused('Inventory cannot set ${to.label}.');
    }
    final band = s.bands[dosebandId];
    if (band == null) throw const OperationRefused('Unknown DoseBand.');
    final next = band.advanceTo(to);
    if (next == null) {
      throw OperationRefused(
        '${band.lifecycle.label} cannot become ${to.label}.',
      );
    }
    return (
      next: s
          .withBand(next)
          .appendAudit(
            AuditEvent(
              eventId: ids.next('AUD'),
              at: now(),
              actorId: actor.personId,
              actorRole: actor.role,
              action: AuditAction.inventoryChanged,
              subjectType: 'doseband',
              subjectId: dosebandId,
              detail: '${band.lifecycle.label} → ${next.lifecycle.label}',
            ),
          ),
      result: null,
    );
  });

  /// Suspends or restores an account. The administrator cannot suspend their
  /// own account from here — that would lock the last administrator out.
  Future<void> setAccountActive({
    required String personId,
    required bool active,
  }) => repository.transact((s) {
    OperationsAccess(s, actor)
      ..requireRole(AppRole.administrator)
      ..require(Permission.manageAccounts);
    if (personId == actor.personId) {
      throw const OperationRefused('You cannot suspend your own account.');
    }
    final p = s.person(personId);
    if (p == null) throw const OperationRefused('Unknown account.');
    final updated = Person(
      personId: p.personId,
      displayName: p.displayName,
      workerType: p.workerType,
      contractorCompany: p.contractorCompany,
      siteId: p.siteId,
      departmentId: p.departmentId,
      designation: p.designation,
      roles: p.roles,
      defaultWorkAreaId: p.defaultWorkAreaId,
      defaultShiftId: p.defaultShiftId,
      photoAsset: p.photoAsset,
      active: active,
      provenance: p.provenance,
    );
    return (
      next: s
          .copyWith(
            people: [
              for (final x in s.people) x.personId == personId ? updated : x,
            ],
          )
          .appendAudit(
            AuditEvent(
              eventId: ids.next('AUD'),
              at: now(),
              actorId: actor.personId,
              actorRole: actor.role,
              action: AuditAction.accountChanged,
              subjectType: 'account',
              subjectId: personId,
              detail: active ? 'Account restored' : 'Account suspended',
            ),
          ),
      result: null,
    );
  });
}
