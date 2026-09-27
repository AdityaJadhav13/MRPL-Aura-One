import 'dart:convert';

import '../../../core/domain/monitoring_session.dart';
import '../../operations/application/day_status.dart';
import '../../operations/application/hse_service.dart';
import '../../operations/domain/measurement_state.dart';

/// Report profiles (PRODUCT BUILD v1 §62). "Aligned" is a layout and
/// wording choice, never a certification: nothing here has been formally
/// established as meeting any OISD or DGMS requirement.
enum ReportProfile {
  internalHse('Internal HSE'),
  mrpl('MRPL'),
  oisdAligned('OISD-aligned'),
  dgmsAligned('DGMS-aligned'),
  custom('Custom');

  const ReportProfile(this.label);

  final String label;

  String get caveat => switch (this) {
    ReportProfile.oisdAligned || ReportProfile.dgmsAligned =>
      '$label is a report layout. It is not a statement of compliance; '
          'applicability has not been formally established.',
    _ => 'Report layout only. Not an authoritative organisational record.',
  };
}

/// Builds report files from the HSE view. Every function takes an [HseView]
/// — the scope-checked view — so an export cannot contain a record the
/// officer could not open on screen (§125).
///
/// ## Semantics that must survive export (§61)
///
/// The exposure column is [MeasurementStateText.exposureCell]: a number only
/// for a valid result; "No Reading — …", "Below Quantification",
/// "Above Range (> bound)", "Saturated" otherwise. Never 0, never blank.
abstract final class RegisterExport {
  static const List<String> registerColumns = [
    'record_id',
    'scanned_at',
    'worker_id',
    'worker_name',
    'department',
    'work_area',
    'shift',
    'doseband_id',
    'monitoring_start',
    'monitoring_end',
    'monitoring_minutes',
    'measurement_state',
    'exposure',
    'data_domain',
    'algorithm_version',
    'geometry_version',
    'calibration_model',
    'capture_id',
    'review_state',
    'disposition',
    'superseded',
  ];

  static String csv(List<List<String>> rows) =>
      rows.map((r) => r.map(_cell).join(',')).join('\n');

  static String _cell(String v) {
    final needs = v.contains(',') || v.contains('"') || v.contains('\n');
    return needs ? '"${v.replaceAll('"', '""')}"' : v;
  }

  static String _iso(DateTime? t) => t?.toUtc().toIso8601String() ?? '';

  /// The occupational exposure register — identified, restricted.
  static List<List<String>> register(List<RegisterRow> rows) => [
    registerColumns,
    for (final r in rows)
      () {
        final m = r.record;
        final p = m.result.provenance;
        final minutes = m.endedAt.isBefore(m.startedAt)
            ? ''
            : '${m.coverage.inMinutes}';
        return [
          m.id,
          _iso(m.scannedAt),
          r.person.personId,
          r.person.displayName,
          m.context.department.name,
          m.context.workArea.name,
          m.context.shift.name,
          m.badge.badgeId,
          _iso(m.startedAt),
          _iso(m.endedAt),
          minutes,
          MeasurementStateText.label(m.result.status),
          MeasurementStateText.exposureCell(m.result),
          m.domain.name,
          p.algorithmVersion,
          p.geometryVersion,
          p.calibrationModelId ?? 'none',
          m.captureId ?? '',
          r.review?.state.label ?? 'No review',
          r.review?.disposition?.label ?? '',
          r.isSuperseded ? 'yes' : 'no',
        ];
      }(),
  ];

  /// Periods that ended without a usable reading, and open exceptions.
  static List<List<String>> exceptions(
    List<OperationalException> items,
    String Function(String workerId) nameOf,
  ) => [
    ['at', 'worker_id', 'worker_name', 'exception', 'doseband_id', 'detail'],
    for (final e in items)
      [
        _iso(e.at),
        e.workerId,
        nameOf(e.workerId),
        e.kind.label,
        e.dosebandId ?? '',
        e.detail ?? '',
      ],
  ];

  /// Incomplete monitoring: sessions that did not reach a final read.
  static List<List<String>> incomplete(
    List<MonitoringSession> sessions,
    String Function(String workerId) nameOf,
  ) => [
    [
      'session_id',
      'worker_id',
      'worker_name',
      'doseband_id',
      'state',
      'started',
      'ended',
    ],
    for (final x in sessions)
      [
        x.sessionId,
        x.workerId,
        nameOf(x.workerId),
        x.dosebandId ?? '',
        x.state.label,
        _iso(x.startedAt),
        _iso(x.endedAt),
      ],
  ];

  /// The audit package manifest (§150): what the package contains and the
  /// boundaries it carries. No signature and no approval — none exists.
  static String auditPackage({
    required ReportProfile profile,
    required DateTime generatedAt,
    required String generatedBy,
    required List<RegisterRow> rows,
    required Map<String, Object?> extra,
  }) => const JsonEncoder.withIndent('  ').convert({
    'package': 'DoseBand audit package',
    'profile': profile.label,
    'profile_caveat': profile.caveat,
    'generated_at': _iso(generatedAt),
    'generated_by': generatedBy,
    'source': 'Operations records on one device; not a central server',
    'signed': false,
    'approvals': <Object>[],
    'methodology': {
      'quantity':
          'External cumulative H2S exposure, D = ∫C(t)dt, in ppm·h, '
          'only where a validated calibration applies',
      'calibration':
          'No validated calibration exists; quantitative results '
          'are not available',
      'no_reading_semantics':
          'No Reading, Below Quantification, Above Range '
          'and Saturated are states, never zero',
    },
    'records': [
      for (final r in rows)
        {
          'record_id': r.record.id,
          'worker_id': r.person.personId,
          'doseband_id': r.record.badge.badgeId,
          'state': MeasurementStateText.label(r.record.result.status),
          'exposure': MeasurementStateText.exposureCell(r.record.result),
          'algorithm_version': r.record.result.provenance.algorithmVersion,
          'calibration_model':
              r.record.result.provenance.calibrationModelId ?? 'none',
          'capture_id': r.record.captureId,
          'review_state': r.review?.state.name,
          'superseded': r.isSuperseded,
        },
    ],
    ...extra,
  });
}
