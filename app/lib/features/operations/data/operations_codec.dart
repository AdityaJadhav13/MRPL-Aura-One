import 'package:measurement/measurement.dart';

import '../../../core/domain/connectivity.dart';
import '../../../core/domain/doseband.dart';
import '../../../core/domain/monitoring_session.dart';
import '../../../core/domain/provenance.dart';
import '../../auth/domain/access_policy.dart';
import '../../auth/domain/auth_models.dart';
import '../../history/domain/measurement_record.dart';
import '../../workflow/data/session_codec.dart';
import '../../workflow/domain/badge_specimen.dart';
import '../../workflow/domain/physical_badge.dart';
import '../../workflow/domain/worker_identity.dart';
import '../domain/assignment.dart';
import '../domain/audit.dart';
import '../domain/inventory.dart';
import '../domain/operations_snapshot.dart';
import '../domain/organisation.dart';
import '../domain/review.dart';

/// JSON shape of the operations store.
///
/// Strict in the same way as `SessionCodec`: a snapshot that cannot be decoded
/// faithfully decodes to null — never to a partially filled store. A
/// measurement record with a guessed field is worse than a missing one.
abstract final class OperationsCodec {
  static const int schema = 1;

  // ================================================================= encode

  static Map<String, Object?> encode(OperationsSnapshot s) => {
    'schema': schema,
    'dataset_version': s.datasetVersion,
    'seeded_at': _date(s.seededAt),
    'people': [for (final p in s.people) _person(p)],
    'departments': [
      for (final d in s.departments)
        {'id': d.departmentId, 'name': d.name, 'site_id': d.siteId},
    ],
    'teams': [
      for (final t in s.teams)
        {
          'id': t.teamId,
          'name': t.name,
          'site_id': t.siteId,
          'department_id': t.departmentId,
          'supervisor_id': t.supervisorId,
          'member_ids': t.memberIds,
        },
    ],
    'grants': [
      for (final g in s.grants)
        {
          'person_id': g.personId,
          'role': g.role.name,
          'scope': g.scope.name,
          'target_id': g.targetId,
        },
    ],
    'formulations': [
      for (final f in s.formulations)
        {
          'id': f.formulationId,
          'name': f.name,
          'version': f.version,
          'validated': f.validated,
        },
    ],
    'lots': [for (final l in s.lots) _lot(l)],
    'bands': [for (final b in s.bands.values) _band(b)],
    'assignments': [for (final a in s.assignments) _assignment(a)],
    'sessions': [for (final x in s.sessions) _session(x)],
    'measurements': [for (final m in s.measurements) _measurement(m)],
    'reviews': [for (final r in s.reviews) _review(r)],
    'audit': [for (final e in s.audit) _audit(e)],
  };

  static String _date(DateTime d) => d.toUtc().toIso8601String();
  static String? _dateOrNull(DateTime? d) => d == null ? null : _date(d);

  static Map<String, Object?> _person(Person p) => {
    'id': p.personId,
    'name': p.displayName,
    'worker_type': p.workerType.name,
    'contractor_company': p.contractorCompany,
    'site_id': p.siteId,
    'department_id': p.departmentId,
    'designation': p.designation,
    'roles': [for (final r in p.roles) r.name],
    'default_work_area_id': p.defaultWorkAreaId,
    'default_shift_id': p.defaultShiftId,
    'photo_asset': p.photoAsset,
    'active': p.active,
    'provenance': p.provenance.name,
  };

  static Map<String, Object?> _lot(DoseBandLot l) => {
    'id': l.lotId,
    'formulation_id': l.formulationId,
    'geometry_version': l.geometryVersion,
    'received_on': _date(l.receivedOn),
    'expires_on': _dateOrNull(l.expiresOn),
    'supported': l.supportedConfiguration,
    'calibration_package_id': l.calibrationPackageId,
    'provenance': l.provenance.name,
  };

  static Map<String, Object?> _band(DoseBand b) => {
    'id': b.dosebandId,
    'lifecycle': b.lifecycle.name,
    'provenance': b.provenance.name,
    'lot_id': b.lotId,
    'formulation_id': b.formulationId,
    'expiry': _dateOrNull(b.expiry),
    'assignment_id': b.assignmentId,
    'calibration_applicability_id': b.calibrationApplicabilityId,
    'geometry_version': b.geometryVersion,
  };

  static Map<String, Object?> _assignment(DoseBandAssignment a) => {
    'id': a.assignmentId,
    'doseband_id': a.dosebandId,
    'worker_id': a.workerId,
    'session_id': a.sessionId,
    'claimed_at': _date(a.claimedAt),
    'state': a.state.name,
    'ended_at': _dateOrNull(a.endedAt),
    'cancel_reason': a.cancelReason,
    'pre_use': a.preUse == null
        ? null
        : {
            'outcome': a.preUse!.outcome.name,
            'checked_at': _date(a.preUse!.checkedAt),
            'optical': a.preUse!.opticalCheck.name,
            'capture_id': a.preUse!.captureId,
          },
  };

  static Map<String, Object?> _session(MonitoringSession s) => {
    'id': s.sessionId,
    'worker_id': s.workerId,
    'state': s.state.name,
    'provenance': s.provenance.name,
    'doseband_id': s.dosebandId,
    'assignment_id': s.assignmentId,
    'work_context_id': s.workContextId,
    'work': s.work == null
        ? null
        : {
            'site_id': s.work!.siteId,
            'site_name': s.work!.siteName,
            'department_id': s.work!.departmentId,
            'department_name': s.work!.departmentName,
            'work_area_id': s.work!.workAreaId,
            'work_area_name': s.work!.workAreaName,
            'shift_id': s.work!.shiftId,
            'shift_name': s.work!.shiftName,
            'activity': s.work!.activity,
          },
    'started_at': _dateOrNull(s.startedAt),
    'ended_at': _dateOrNull(s.endedAt),
    'measurement_id': s.measurementId,
    'sync_state': s.syncState.name,
  };

  static Map<String, Object?> _measurement(MeasurementRecord m) => {
    'id': m.id,
    'result': SessionCodec.encodeResult(m.result),
    'badge': switch (m.badge) {
      final PhysicalBadge p => {'physical': p.toJson()},
      final BadgeSpecimen s => {'specimen_id': s.badgeId},
      _ => throw StateError('unknown badge identity ${m.badge.runtimeType}'),
    },
    'context': SessionCodec.encodeContext(m.context),
    'started_at': _date(m.startedAt),
    'ended_at': _date(m.endedAt),
    'scanned_at': _date(m.scannedAt),
    'domain': m.domain.name,
    'capture_id': m.captureId,
    'worker_id': m.workerId,
    'session_id': m.sessionId,
    'supersedes_id': m.supersedesId,
    'supersession_reason': m.supersessionReason,
  };

  static Map<String, Object?> _review(HseReview r) => {
    'id': r.reviewId,
    'measurement_id': r.measurementId,
    'state': r.state.name,
    'opened_at': _date(r.openedAt),
    'updated_at': _date(r.updatedAt),
    'reviewer_id': r.reviewerId,
    'note': r.note,
    'disposition': r.disposition?.name,
  };

  static Map<String, Object?> _audit(AuditEvent e) => {
    'id': e.eventId,
    'at': _date(e.at),
    'actor_id': e.actorId,
    'actor_role': e.actorRole.name,
    'action': e.action.name,
    'subject_type': e.subjectType,
    'subject_id': e.subjectId,
    'detail': e.detail,
  };

  // ================================================================= decode

  static OperationsSnapshot? decode(Object? raw) {
    try {
      return _decode(raw);
    } on _Bad {
      return null;
    } on TypeError {
      return null;
    }
  }

  static OperationsSnapshot _decode(Object? raw) {
    final m = _map(raw);
    if (m['schema'] != schema) throw const _Bad();
    return OperationsSnapshot(
      datasetVersion: _str(m['dataset_version']),
      seededAt: _dt(m['seeded_at']),
      people: [for (final p in _list(m['people'])) _decodePerson(_map(p))],
      departments: [
        for (final d in _list(m['departments']).map(_map))
          OrgDepartment(
            departmentId: _str(d['id']),
            name: _str(d['name']),
            siteId: _str(d['site_id']),
          ),
      ],
      teams: [
        for (final t in _list(m['teams']).map(_map))
          Team(
            teamId: _str(t['id']),
            name: _str(t['name']),
            siteId: _str(t['site_id']),
            departmentId: _str(t['department_id']),
            supervisorId: _str(t['supervisor_id']),
            memberIds: [for (final x in _list(t['member_ids'])) _str(x)],
          ),
      ],
      grants: [
        for (final g in _list(m['grants']).map(_map))
          ScopeGrant(
            personId: _str(g['person_id']),
            role: _enum(AppRole.values, g['role']),
            scope: _enum(AccessScope.values, g['scope']),
            targetId: _str(g['target_id']),
          ),
      ],
      formulations: [
        for (final f in _list(m['formulations']).map(_map))
          SensorFormulation(
            formulationId: _str(f['id']),
            name: _str(f['name']),
            version: _str(f['version']),
            validated: f['validated'] as bool,
          ),
      ],
      lots: [for (final l in _list(m['lots'])) _decodeLot(_map(l))],
      bands: {
        for (final b in _list(m['bands']).map((x) => _decodeBand(_map(x))))
          b.dosebandId: b,
      },
      assignments: [
        for (final a in _list(m['assignments'])) _decodeAssignment(_map(a)),
      ],
      sessions: [for (final s in _list(m['sessions'])) _decodeSession(_map(s))],
      measurements: [
        for (final x in _list(m['measurements'])) _decodeMeasurement(_map(x)),
      ],
      reviews: [for (final r in _list(m['reviews'])) _decodeReview(_map(r))],
      audit: [for (final e in _list(m['audit'])) _decodeAudit(_map(e))],
    );
  }

  static Person _decodePerson(Map<String, Object?> p) {
    final roles = [for (final r in _list(p['roles'])) _enum(AppRole.values, r)];
    if (roles.isEmpty) throw const _Bad();
    return Person(
      personId: _str(p['id']),
      displayName: _str(p['name']),
      workerType: _enum(WorkerType.values, p['worker_type']),
      contractorCompany: _strOrNull(p['contractor_company']),
      siteId: _str(p['site_id']),
      departmentId: _str(p['department_id']),
      designation: _str(p['designation']),
      roles: roles,
      defaultWorkAreaId: _strOrNull(p['default_work_area_id']),
      defaultShiftId: _strOrNull(p['default_shift_id']),
      photoAsset: _strOrNull(p['photo_asset']),
      active: p['active'] as bool,
      provenance: _enum(RecordProvenance.values, p['provenance']),
    );
  }

  static DoseBandLot _decodeLot(Map<String, Object?> l) => DoseBandLot(
    lotId: _str(l['id']),
    formulationId: _str(l['formulation_id']),
    geometryVersion: _str(l['geometry_version']),
    receivedOn: _dt(l['received_on']),
    expiresOn: _dtOrNull(l['expires_on']),
    supportedConfiguration: l['supported'] as bool,
    calibrationPackageId: _strOrNull(l['calibration_package_id']),
    provenance: _enum(RecordProvenance.values, l['provenance']),
  );

  static DoseBand _decodeBand(Map<String, Object?> b) => DoseBand(
    dosebandId: _str(b['id']),
    lifecycle: _enum(DoseBandLifecycle.values, b['lifecycle']),
    provenance: _enum(RecordProvenance.values, b['provenance']),
    lotId: _strOrNull(b['lot_id']),
    formulationId: _strOrNull(b['formulation_id']),
    expiry: _dtOrNull(b['expiry']),
    assignmentId: _strOrNull(b['assignment_id']),
    calibrationApplicabilityId: _strOrNull(b['calibration_applicability_id']),
    geometryVersion: _strOrNull(b['geometry_version']),
  );

  static DoseBandAssignment _decodeAssignment(Map<String, Object?> a) {
    final pre = a['pre_use'];
    return DoseBandAssignment(
      assignmentId: _str(a['id']),
      dosebandId: _str(a['doseband_id']),
      workerId: _str(a['worker_id']),
      sessionId: _str(a['session_id']),
      claimedAt: _dt(a['claimed_at']),
      state: _enum(AssignmentState.values, a['state']),
      endedAt: _dtOrNull(a['ended_at']),
      cancelReason: _strOrNull(a['cancel_reason']),
      preUse: pre == null
          ? null
          : PreUseRecord(
              outcome: _enum(PreUseOutcome.values, _map(pre)['outcome']),
              checkedAt: _dt(_map(pre)['checked_at']),
              opticalCheck: _enum(
                OpticalCheckStatus.values,
                _map(pre)['optical'],
              ),
              captureId: _strOrNull(_map(pre)['capture_id']),
            ),
    );
  }

  static MonitoringSession _decodeSession(Map<String, Object?> s) {
    final w = s['work'];
    return MonitoringSession(
      sessionId: _str(s['id']),
      workerId: _str(s['worker_id']),
      state: _enum(MonitoringSessionState.values, s['state']),
      provenance: _enum(RecordProvenance.values, s['provenance']),
      dosebandId: _strOrNull(s['doseband_id']),
      assignmentId: _strOrNull(s['assignment_id']),
      workContextId: _strOrNull(s['work_context_id']),
      work: w == null
          ? null
          : WorkSummary(
              siteId: _str(_map(w)['site_id']),
              siteName: _str(_map(w)['site_name']),
              departmentId: _str(_map(w)['department_id']),
              departmentName: _str(_map(w)['department_name']),
              workAreaId: _strOrNull(_map(w)['work_area_id']),
              workAreaName: _strOrNull(_map(w)['work_area_name']),
              shiftId: _strOrNull(_map(w)['shift_id']),
              shiftName: _strOrNull(_map(w)['shift_name']),
              activity: _strOrNull(_map(w)['activity']),
            ),
      startedAt: _dtOrNull(s['started_at']),
      endedAt: _dtOrNull(s['ended_at']),
      measurementId: _strOrNull(s['measurement_id']),
      syncState: _enum(SyncState.values, s['sync_state']),
    );
  }

  static MeasurementRecord _decodeMeasurement(Map<String, Object?> m) {
    final result = SessionCodec.decodeResult(m['result']);
    final context = SessionCodec.decodeContext(m['context']);
    if (result == null || context == null) throw const _Bad();
    final badgeRaw = _map(m['badge']);
    final physical = badgeRaw['physical'];
    final specimen = badgeRaw['specimen_id'];
    final badge = physical != null
        ? PhysicalBadge.fromJson(physical)
        : SessionCodec.decodeSpecimen(specimen);
    if (badge == null) throw const _Bad();
    final supersedes = _strOrNull(m['supersedes_id']);
    final reason = _strOrNull(m['supersession_reason']);
    if ((supersedes == null) != (reason == null)) throw const _Bad();
    return MeasurementRecord(
      id: _str(m['id']),
      result: result,
      badge: badge,
      context: context,
      startedAt: _dt(m['started_at']),
      endedAt: _dt(m['ended_at']),
      scannedAt: _dt(m['scanned_at']),
      domain: _enum(DataDomain.values, m['domain']),
      captureId: _strOrNull(m['capture_id']),
      workerId: _strOrNull(m['worker_id']),
      sessionId: _strOrNull(m['session_id']),
      supersedesId: supersedes,
      supersessionReason: reason,
    );
  }

  static HseReview _decodeReview(Map<String, Object?> r) => HseReview(
    reviewId: _str(r['id']),
    measurementId: _str(r['measurement_id']),
    state: _enum(ReviewState.values, r['state']),
    openedAt: _dt(r['opened_at']),
    updatedAt: _dt(r['updated_at']),
    reviewerId: _strOrNull(r['reviewer_id']),
    note: _strOrNull(r['note']),
    disposition: r['disposition'] == null
        ? null
        : _enum(ReviewDisposition.values, r['disposition']),
  );

  static AuditEvent _decodeAudit(Map<String, Object?> e) => AuditEvent(
    eventId: _str(e['id']),
    at: _dt(e['at']),
    actorId: _str(e['actor_id']),
    actorRole: _enum(AppRole.values, e['actor_role']),
    action: _enum(AuditAction.values, e['action']),
    subjectType: _str(e['subject_type']),
    subjectId: _str(e['subject_id']),
    detail: _strOrNull(e['detail']),
  );

  // ---------------------------------------------------------------- helpers

  static Map<String, Object?> _map(Object? v) =>
      v is Map ? v.cast<String, Object?>() : throw const _Bad();

  static List<Object?> _list(Object? v) =>
      v is List ? v.cast<Object?>() : throw const _Bad();

  static String _str(Object? v) =>
      v is String && v.isNotEmpty ? v : throw const _Bad();

  static String? _strOrNull(Object? v) => v == null ? null : _str(v);

  static DateTime _dt(Object? v) =>
      DateTime.tryParse(_str(v))?.toLocal() ?? (throw const _Bad());

  static DateTime? _dtOrNull(Object? v) => v == null ? null : _dt(v);

  static T _enum<T extends Enum>(List<T> values, Object? name) =>
      values.where((x) => x.name == name).firstOrNull ?? (throw const _Bad());
}

final class _Bad implements Exception {
  const _Bad();
}
