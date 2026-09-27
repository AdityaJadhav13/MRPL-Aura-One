import 'package:measurement/measurement.dart';

import '../domain/badge_specimen.dart';
import '../domain/physical_badge.dart';
import '../domain/enterprise_value.dart';
import '../domain/permit_context.dart';
import '../domain/work_taxonomy.dart';
import '../domain/worker_identity.dart';
import '../domain/work_context.dart';
import '../domain/workflow_state.dart';
import 'simulation_catalog.dart';
import 'work_context_repository.dart';

/// Turns a [ShiftSession] into JSON and back.
///
/// The only thing that knows how a session is serialised — the seam's
/// contract (`workflow_store.dart`) exists so Phase 6 can swap the *medium*
/// (file to SQLite) without touching this shape, and so this shape can change
/// without touching the workflow.
///
/// ## Decoding refuses rather than repairs
///
/// Every `decode` returns null when the stored value is not something it can
/// faithfully reconstruct: wrong schema, missing field, unparseable date,
/// unknown badge, unknown enum. A partially-reconstructed session is worse
/// than no session — it would put a worker back into a monitored period whose
/// start time, badge or stage is a guess, and every one of those feeds a
/// number. The caller's fallback is [ShiftSession.none], which is honest: it
/// says the period was lost, and the worker starts again.
///
/// This is the same rule the measurement pipeline follows, applied to storage.
abstract final class SessionCodec {
  /// Bump whenever the encoded shape changes. A snapshot written by a
  /// different schema is discarded, not migrated: until there is a released
  /// version to migrate *from*, a migration path would be speculative code
  /// guarding against a case that has never existed.
  static const int schema = 4;

  /// Schemas this build can read. Each version is a strict superset of the
  /// one before — 3 added `physical_badge` and `capture_id`, 4 added
  /// `session_id` and `assignment_id`, all optional — so an older snapshot
  /// decodes unchanged. That is not speculative migration code; it is the
  /// absence of any change to read.
  static const Set<int> readable = <int>{2, 3, 4};

  // ---------------------------------------------------------------- encoding

  static Map<String, Object?> encode(ShiftSession s) => {
    'schema': schema,
    'stage': s.stage.name,
    'context': s.context == null ? null : _encodeContext(s.context!),
    // Badges are catalogue entries, so only the identity is stored and the
    // record is re-resolved on load. A badge's lot, expiry and declared
    // outcome belong to the catalogue (later: the database); copying them into
    // the session snapshot would let a stale duplicate outlive the source.
    'badge_id': s.badge?.badgeId,
    // A physical badge is stored in full. Unlike a catalogue specimen there is
    // nothing to re-resolve it from: this session is its only record, and a
    // restart mid-monitoring must not lose which badge is being worn.
    'physical_badge': s.physicalBadge?.toJson(),
    'capture_id': s.captureId,
    'session_id': s.sessionId,
    'assignment_id': s.assignmentId,
    'started_at': s.startedAt?.toIso8601String(),
    'ended_at': s.endedAt?.toIso8601String(),
    'result': s.result == null ? null : _encodeResult(s.result!),
  };

  static Map<String, Object?> _encodeContext(WorkContext c) => {
    'worker': _encodeWorker(c.worker),
    'site': {'id': c.site.id, 'name': c.site.name},
    // Taxonomy entries are configuration, so only the identifier is stored and
    // the entry is re-resolved on load — the same rule badges follow. An id the
    // configuration no longer offers is a refusal, not a dropped field.
    'department_id': c.department.id,
    'work_area_id': c.workArea.id,
    'shift_id': c.shift.id,
    'job': {
      'title': c.job.title,
      'work_order': c.job.workOrder,
      'supervisor': c.job.supervisor,
      'description': c.job.description,
    },
    'permit': {
      'reference': _encodeEnterprise(c.permit.reference),
      'type_id': c.permit.type?.id,
    },
    'jsa': {
      'reference': _encodeEnterprise(c.jsa.reference),
      'note': c.jsa.note,
    },
    'toolbox_talk': {
      'acknowledged_at': c.toolboxTalk.acknowledgedAt.toIso8601String(),
      'source': c.toolboxTalk.source.name,
      'reference': c.toolboxTalk.reference,
    },
  };

  static Map<String, Object?> _encodeWorker(WorkerIdentity w) => {
    'worker_id': w.workerId,
    'display_name': w.displayName,
    'worker_type': w.workerType.name,
    'source': w.source.name,
    'contractor_company': w.contractorCompany,
    'gate_pass': w.gatePass == null ? null : _encodeEnterprise(w.gatePass!),
  };

  /// Provenance travels with the value, always. A stored reference that lost
  /// its source on the way to disk would come back looking like any other
  /// string, which is precisely the confusion `EnterpriseValue` exists to make
  /// impossible.
  static Map<String, Object?> _encodeEnterprise(EnterpriseValue<String> v) => {
    'value': v.value,
    'source': v.source.name,
    'verified_at': v.verifiedAt?.toIso8601String(),
    'external_system': v.externalSystem,
    'external_reference': v.externalReference,
  };

  static Map<String, Object?> _encodeProvenance(Provenance p) => {
    'algorithm_version': p.algorithmVersion,
    'geometry_version': p.geometryVersion,
    'calibration_model_id': p.calibrationModelId,
    'reference_profile_id': p.referenceProfileId,
    'app_version': p.appVersion,
    'device_model': p.deviceModel,
  };

  static List<Map<String, Object?>> _encodeReasons(List<ReasonCode> rs) => [
    for (final r in rs) {'code': r.code, 'detail': r.detail},
  ];

  /// Exhaustive over [MeasurementResult]. Adding a variant to the sealed union
  /// makes this switch a compile error, which is the point: a result state that
  /// cannot be stored must not be addable by accident.
  static Map<String, Object?> _encodeResult(MeasurementResult r) {
    final base = {
      'status': r.status.name,
      'reasons': _encodeReasons(r.reasons),
      'provenance': _encodeProvenance(r.provenance),
    };
    return switch (r) {
      Valid(:final dose, :final uncertainty, :final coverage) => {
        ...base,
        'kind': 'valid',
        'dose_ppm_hours': dose.value,
        'uncertainty_half_width': uncertainty.halfWidth,
        'uncertainty_basis': uncertainty.basis,
        // Microseconds, not seconds: Duration's own resolution, so a restored
        // result is identical to the one that was computed rather than a
        // truncation of it. A measurement record that changes when it is
        // reloaded is not traceable, however small the change.
        'coverage_microseconds': coverage.inMicroseconds,
      },
      Censored(:final direction, :final bound) => {
        ...base,
        'kind': 'censored',
        'direction': direction.name,
        'bound_ppm_hours': bound?.value,
      },
      Refused() => {...base, 'kind': 'refused'},
    };
  }

  // ------------------------------------------------- shared record encoding

  /// The same encoders, for the operations store's measurement records, so a
  /// record and a session serialise a context or a result identically and
  /// one set of round-trip tests covers both.
  static Map<String, Object?> encodeContext(WorkContext c) => _encodeContext(c);

  static WorkContext? decodeContext(Object? raw) => _decodeContext(raw);

  static Map<String, Object?> encodeResult(MeasurementResult r) =>
      _encodeResult(r);

  static MeasurementResult? decodeResult(Object? raw) => _decodeResult(raw);

  static BadgeSpecimen? decodeSpecimen(Object? raw) => _decodeBadge(raw);

  // ---------------------------------------------------------------- decoding

  static ShiftSession? decode(Object? raw) {
    if (raw is! Map) return null;
    if (!readable.contains(raw['schema'])) return null;

    final stage = _enumByName(ShiftStage.values, raw['stage']);
    if (stage == null) return null;

    final context = _decodeContext(raw['context']);
    if (context == null && raw['context'] != null) return null;

    final badge = _decodeBadge(raw['badge_id']);
    if (badge == null && raw['badge_id'] != null) return null;

    final physical = PhysicalBadge.fromJson(raw['physical_badge']);
    if (physical == null && raw['physical_badge'] != null) return null;
    // Both at once is a state no transition produces.
    if (badge != null && physical != null) return null;

    final captureId = raw['capture_id'];
    if (captureId != null && captureId is! String) return null;

    // Schema 4. Absent from older snapshots, which predate the operations
    // store; such a session simply has no organisational record to follow.
    final sessionId = raw['session_id'];
    if (sessionId != null && sessionId is! String) return null;
    final assignmentId = raw['assignment_id'];
    if (assignmentId != null && assignmentId is! String) return null;

    final startedAt = _decodeDate(raw['started_at']);
    if (startedAt == null && raw['started_at'] != null) return null;

    final endedAt = _decodeDate(raw['ended_at']);
    if (endedAt == null && raw['ended_at'] != null) return null;

    final result = _decodeResult(raw['result']);
    if (result == null && raw['result'] != null) return null;

    final session = ShiftSession(
      stage: stage,
      context: context,
      badge: badge,
      physicalBadge: physical,
      startedAt: startedAt,
      endedAt: endedAt,
      result: result,
      captureId: captureId as String?,
      sessionId: sessionId as String?,
      assignmentId: assignmentId as String?,
    );

    // A snapshot can be well-formed JSON and still describe a session that the
    // workflow could never have produced. Restoring one would put the UI in a
    // state its own transitions cannot reach.
    return _isCoherent(session) ? session : null;
  }

  /// What each stage requires to be present. Derived from the transitions in
  /// `ShiftSessionController`, which is the only writer.
  static bool _isCoherent(ShiftSession s) {
    final needsContext = s.stage.index >= ShiftStage.contextSet.index;
    final needsBadge = s.stage.index >= ShiftStage.badgeAssigned.index;
    final needsStart = s.stage.index >= ShiftStage.monitoring.index;
    final needsEnd = s.stage.index >= ShiftStage.awaitingScan.index;
    final needsResult = s.stage == ShiftStage.complete;

    if (needsContext && s.context == null) return false;
    if (needsBadge && s.assignedBadge == null) return false;
    if (needsStart && s.startedAt == null) return false;
    if (needsEnd && s.endedAt == null) return false;
    if (needsResult && s.result == null) return false;

    // Deliberately NOT checked: that `endedAt` follows `startedAt`. A backwards
    // window is exactly what a restore after a clock change looks like, and it
    // is a state the worker must be shown — the period is real and their badge
    // is still on them. Rejecting it here would delete the period and hide the
    // problem; keeping it lets `coverageAt` return null, the screens print
    // `- - -`, and the scan refuses. Refuse loudly, do not discard quietly.

    // The converse: a stage must not carry evidence of a later one.
    if (!needsStart && s.startedAt != null) return false;
    if (!needsEnd && s.endedAt != null) return false;
    if (!needsResult && s.result != null) return false;

    return true;
  }

  static const DemoWorkContextRepository _config = DemoWorkContextRepository();

  static WorkContext? _decodeContext(Object? raw) {
    if (raw is! Map) return null;

    final worker = _decodeWorker(raw['worker']);
    if (worker == null) return null;

    final siteRaw = raw['site'];
    if (siteRaw is! Map) return null;
    final siteId = _str(siteRaw['id']);
    final siteName = _str(siteRaw['name']);
    if (siteId == null || siteName == null) return null;

    // Configuration lookups. An unknown identifier means the stored context
    // refers to a department, area or shift this build does not have — the
    // entry cannot be reconstructed, so the session is refused rather than
    // restored with a gap where the provenance should be.
    final departmentId = _str(raw['department_id']);
    final workAreaId = _str(raw['work_area_id']);
    final shiftId = _str(raw['shift_id']);
    if (departmentId == null || workAreaId == null || shiftId == null) {
      return null;
    }
    final department = _config.departmentById(departmentId);
    final workArea = _config.workAreaById(workAreaId);
    final shift = _config.shiftById(shiftId);
    if (department == null || workArea == null || shift == null) return null;

    // An area belonging to another site would silently move the record.
    if (workArea.siteId != siteId) return null;

    final job = _decodeJob(raw['job']);
    final permit = _decodePermit(raw['permit']);
    final jsa = _decodeJsa(raw['jsa']);
    final toolbox = _decodeToolbox(raw['toolbox_talk']);
    if (job == null || permit == null || jsa == null || toolbox == null) {
      return null;
    }

    return WorkContext(
      worker: worker,
      site: SiteRef(id: siteId, name: siteName),
      department: department,
      workArea: workArea,
      shift: shift,
      job: job,
      permit: permit,
      jsa: jsa,
      toolboxTalk: toolbox,
    );
  }

  static WorkerIdentity? _decodeWorker(Object? raw) {
    if (raw is! Map) return null;
    final workerId = _str(raw['worker_id']);
    final displayName = _str(raw['display_name']);
    final type = _enumByName(WorkerType.values, raw['worker_type']);
    final source = _enumByName(EnterpriseDataSource.values, raw['source']);
    if (workerId == null ||
        displayName == null ||
        type == null ||
        source == null) {
      return null;
    }

    final company = raw['contractor_company'];
    if (company != null && company is! String) return null;

    final gatePassRaw = raw['gate_pass'];
    final gatePass = _decodeEnterprise(gatePassRaw);
    if (gatePassRaw != null && gatePass == null) return null;

    final identity = WorkerIdentity(
      workerId: workerId,
      displayName: displayName,
      workerType: type,
      source: source,
      contractorCompany: company as String?,
      gatePass: gatePass,
    );

    // A contractor with no company, or an employee carrying one, describes a
    // worker the form could not have produced.
    return identity.contractorCompanyIsCoherent ? identity : null;
  }

  static JobContext? _decodeJob(Object? raw) {
    if (raw is! Map) return null;
    final title = _str(raw['title']);
    if (title == null) return null;
    for (final key in ['work_order', 'supervisor', 'description']) {
      final v = raw[key];
      if (v != null && v is! String) return null;
    }
    return JobContext(
      title: title,
      workOrder: raw['work_order'] as String?,
      supervisor: raw['supervisor'] as String?,
      description: raw['description'] as String?,
    );
  }

  static PtwReference? _decodePermit(Object? raw) {
    if (raw is! Map) return null;
    final reference = _decodeEnterprise(raw['reference']);
    if (reference == null) return null;

    final typeId = raw['type_id'];
    if (typeId != null && typeId is! String) return null;
    PtwType? type;
    if (typeId is String) {
      type = _config.permitTypeById(typeId);
      // The category was recorded, so losing it would quietly change what the
      // stored context says.
      if (type == null) return null;
    }
    return PtwReference(reference: reference, type: type);
  }

  static JsaReference? _decodeJsa(Object? raw) {
    if (raw is! Map) return null;
    final reference = _decodeEnterprise(raw['reference']);
    if (reference == null) return null;
    final note = raw['note'];
    if (note != null && note is! String) return null;
    return JsaReference(reference: reference, note: note as String?);
  }

  static ToolboxTalkAcknowledgement? _decodeToolbox(Object? raw) {
    if (raw is! Map) return null;
    final at = _decodeDate(raw['acknowledged_at']);
    final source = _enumByName(EnterpriseDataSource.values, raw['source']);
    if (at == null || source == null) return null;
    final reference = raw['reference'];
    if (reference != null && reference is! String) return null;
    return ToolboxTalkAcknowledgement(
      acknowledgedAt: at,
      source: source,
      reference: reference as String?,
    );
  }

  /// Rebuilds a value with its provenance, or refuses.
  ///
  /// The verification fields are checked against the source in both
  /// directions, which is the whole point of the type surviving a round trip:
  ///
  /// * a value claiming [EnterpriseDataSource.organizationIntegration] without
  ///   the system, reference and timestamp that back it up is refused — it
  ///   would restore as "Verified" while nothing had ever verified it;
  /// * a demo or manual value *carrying* verification fields is refused too,
  ///   because that combination cannot be constructed by the domain and means
  ///   the record was edited or corrupted.
  ///
  /// Either way a typed-in permit number cannot come back from storage looking
  /// like one an MRPL system confirmed.
  static EnterpriseValue<String>? _decodeEnterprise(Object? raw) {
    if (raw is! Map) return null;
    final value = _str(raw['value']);
    final source = _enumByName(EnterpriseDataSource.values, raw['source']);
    if (value == null || source == null) return null;

    final verifiedAtRaw = raw['verified_at'];
    final system = raw['external_system'];
    final reference = raw['external_reference'];
    if (system != null && system is! String) return null;
    if (reference != null && reference is! String) return null;

    if (source.isVerified) {
      final verifiedAt = _decodeDate(verifiedAtRaw);
      if (verifiedAt == null || system is! String || reference is! String) {
        return null;
      }
      return EnterpriseValue.verified(
        value: value,
        verifiedAt: verifiedAt,
        externalSystem: system,
        externalReference: reference,
      );
    }

    if (verifiedAtRaw != null || system != null || reference != null) {
      return null;
    }
    return switch (source) {
      EnterpriseDataSource.demo => EnterpriseValue.demo(value),
      EnterpriseDataSource.manualEntry => EnterpriseValue.manual(value),
      EnterpriseDataSource.organizationIntegration => null,
    };
  }

  /// Re-resolves the badge from the catalogue. An id that is no longer offered
  /// — a catalogue edit between runs, or a snapshot from another build —
  /// discards the session rather than inventing a specimen for it.
  static BadgeSpecimen? _decodeBadge(Object? raw) {
    if (raw is! String) return null;
    for (final s in SimulationCatalog.specimens()) {
      if (s.badgeId == raw) return s;
    }
    return null;
  }

  static MeasurementResult? _decodeResult(Object? raw) {
    if (raw is! Map) return null;
    final status = _enumByName(ResultStatus.values, raw['status']);
    final provenance = _decodeProvenance(raw['provenance']);
    final reasons = _decodeReasons(raw['reasons']);
    if (status == null || provenance == null || reasons == null) return null;

    switch (raw['kind']) {
      case 'valid':
        final dose = _num(raw['dose_ppm_hours']);
        final half = _num(raw['uncertainty_half_width']);
        final basis = _str(raw['uncertainty_basis']);
        final micros = raw['coverage_microseconds'];
        if (dose == null ||
            dose < 0 ||
            half == null ||
            basis == null ||
            micros is! int ||
            micros < 0) {
          return null;
        }
        // Valid asserts a calibration model is present; a snapshot without one
        // is not a valid result, whatever it says it is.
        if (provenance.calibrationModelId == null) return null;
        if (!status.carriesDose) return null;
        return Valid(
          dose: Dose.ppmHours(dose),
          uncertainty: Uncertainty(halfWidth: half, basis: basis),
          coverage: Duration(microseconds: micros),
          provenance: provenance,
          warnings: reasons,
        );

      case 'censored':
        final direction = _enumByName(CensorDirection.values, raw['direction']);
        if (direction == null || reasons.isEmpty || !status.isCensored) {
          return null;
        }
        final bound = raw['bound_ppm_hours'] == null
            ? null
            : _num(raw['bound_ppm_hours']);
        if (raw['bound_ppm_hours'] != null && (bound == null || bound < 0)) {
          return null;
        }
        return Censored(
          status: status,
          direction: direction,
          bound: bound == null ? null : Dose.ppmHours(bound),
          reasons: reasons,
          provenance: provenance,
        );

      case 'refused':
        if (reasons.isEmpty || !status.isRefusal) return null;
        return Refused(
          status: status,
          reasons: reasons,
          provenance: provenance,
        );

      default:
        return null;
    }
  }

  static Provenance? _decodeProvenance(Object? raw) {
    if (raw is! Map) return null;
    final algorithm = _str(raw['algorithm_version']);
    final geometry = _str(raw['geometry_version']);
    final appVersion = _str(raw['app_version']);
    final device = _str(raw['device_model']);
    if (algorithm == null ||
        geometry == null ||
        appVersion == null ||
        device == null) {
      return null;
    }
    final cal = raw['calibration_model_id'];
    final ref = raw['reference_profile_id'];
    if (cal != null && cal is! String) return null;
    if (ref != null && ref is! String) return null;

    return Provenance(
      algorithmVersion: algorithm,
      geometryVersion: geometry,
      calibrationModelId: cal as String?,
      referenceProfileId: ref as String?,
      appVersion: appVersion,
      deviceModel: device,
    );
  }

  static List<ReasonCode>? _decodeReasons(Object? raw) {
    if (raw is! List) return null;
    final out = <ReasonCode>[];
    for (final item in raw) {
      if (item is! Map) return null;
      final code = _str(item['code']);
      if (code == null) return null;
      final detail = item['detail'];
      if (detail != null && detail is! String) return null;
      out.add(ReasonCode(code, detail: detail as String?));
    }
    return out;
  }

  // ------------------------------------------------------------------ atoms

  static String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

  static double? _num(Object? v) => v is num ? v.toDouble() : null;

  static DateTime? _decodeDate(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
