import 'package:flutter/foundation.dart';

/// A report template profile.
///
/// ## Why the wording is in the type
///
/// "OISD compliant" and "OISD-aligned template" are separated by a regulatory
/// determination nobody has made. The difference is one word in a label, and
/// a label is the easiest thing in a codebase to edit in a hurry.
///
/// So the permitted wording lives here, as data, with the caveat attached to
/// it. A screen renders [label] and [caveat] together; it does not get to
/// compose its own sentence about a regulator.
enum ReportTemplateProfile {
  internalHse(
    'Internal HSE',
    'An internal template. Not mapped to any external requirement.',
  ),

  organisation(
    'Organisation profile',
    'A configurable organisation template. Not approved by any '
        'organisation — DoseBand cannot obtain such approval on its own.',
  ),

  /// Designed with OISD in mind. **Not** a compliance claim.
  oisdAligned(
    'OISD-aligned',
    'Designed for future OISD mapping. Not yet verified against applicable '
        'OISD requirements, and not reviewed by OISD.',
  ),

  /// Designed with DGMS in mind. Applicability is itself unestablished.
  dgmsAligned(
    'DGMS-aligned',
    'Designed for future DGMS mapping. Applicability to this installation '
        'has not been established, and DGMS has not reviewed DoseBand.',
  ),

  custom('Custom', 'A user-defined selection of sections and fields.');

  const ReportTemplateProfile(this.label, this.caveat);

  /// The only permitted name for this profile.
  ///
  /// Note what is absent: no value here contains "compliant", "approved",
  /// "certified" or "verified". A test asserts that.
  final String label;

  /// Shown wherever [label] is, never separately. A profile name without its
  /// caveat is the claim this enum exists to prevent.
  final String caveat;

  /// Whether the profile names an external body, and therefore carries the
  /// heavier warning treatment.
  bool get referencesRegulator =>
      this == ReportTemplateProfile.oisdAligned ||
      this == ReportTemplateProfile.dgmsAligned;
}

/// A section a report may include.
enum ReportSection {
  workerIdentity('Worker identity'),
  workContext('Work context'),
  monitoring('Monitoring window'),
  badge('Badge and batch'),
  measurement('Measurement and validity'),
  quality('Capture quality'),
  calibration('Calibration and software versions'),
  hseReview('HSE review and disposition'),
  audit('Audit metadata'),
  methodology('Methodology and limitations');

  const ReportSection(this.label);

  final String label;
}

/// What a report can be produced as.
///
/// None of these works. The enum exists so the builder is designed around the
/// real vocabulary rather than retrofitted, and so
/// [ExportAvailability] can say plainly that nothing is connected.
enum ExportFormat {
  pdf('PDF'),
  csv('CSV'),
  auditPackage('Audit package');

  const ExportFormat(this.label);

  final String label;

  /// Always [ExportAvailability.notConnected] today. No exporter exists.
  ExportAvailability get availability => ExportAvailability.notConnected;
}

enum ExportAvailability {
  /// An exporter exists and produced a file.
  generated,

  /// The UI can show what a report would contain, and nothing more.
  previewOnly,

  /// No exporter exists at all.
  notConnected,
}

/// The filters a reporting screen may apply.
///
/// Held as one immutable object so a screen's filter state, a report
/// definition and an audit-package scope are all the same shape — a report is
/// a saved query, and it should not need a second vocabulary.
@immutable
final class ReportFilter {
  const ReportFilter({
    this.site,
    this.department,
    this.workArea,
    this.shift,
    this.workerId,
    this.isContractor,
    this.measurement,
    this.reviewState,
    this.badgeId,
    this.batchId,
    this.periodLabel = 'Last 7 days',
  });

  final String? site;
  final String? department;
  final String? workArea;
  final String? shift;
  final String? workerId;
  final bool? isContractor;
  final String? measurement;
  final String? reviewState;
  final String? badgeId;
  final String? batchId;

  /// A human label. Deliberately not a date range: no record store exists to
  /// query, so a precise range would imply a precision the data has not got.
  final String periodLabel;

  int get activeCount => [
    site,
    department,
    workArea,
    shift,
    workerId,
    isContractor,
    measurement,
    reviewState,
    badgeId,
    batchId,
  ].where((f) => f != null).length;

  ReportFilter copyWith({
    Object? site = _unset,
    Object? department = _unset,
    Object? workArea = _unset,
    Object? shift = _unset,
    Object? workerId = _unset,
    Object? isContractor = _unset,
    Object? measurement = _unset,
    Object? reviewState = _unset,
    Object? badgeId = _unset,
    Object? batchId = _unset,
    String? periodLabel,
  }) => ReportFilter(
    site: site == _unset ? this.site : site as String?,
    department: department == _unset ? this.department : department as String?,
    workArea: workArea == _unset ? this.workArea : workArea as String?,
    shift: shift == _unset ? this.shift : shift as String?,
    workerId: workerId == _unset ? this.workerId : workerId as String?,
    isContractor: isContractor == _unset
        ? this.isContractor
        : isContractor as bool?,
    measurement: measurement == _unset
        ? this.measurement
        : measurement as String?,
    reviewState: reviewState == _unset
        ? this.reviewState
        : reviewState as String?,
    badgeId: badgeId == _unset ? this.badgeId : badgeId as String?,
    batchId: batchId == _unset ? this.batchId : batchId as String?,
    periodLabel: periodLabel ?? this.periodLabel,
  );

  /// Sentinel so `copyWith` can distinguish "leave alone" from "clear".
  static const Object _unset = Object();
}

/// A configured report, as the builder assembles it.
@immutable
final class ReportDefinition {
  const ReportDefinition({
    required this.title,
    required this.profile,
    required this.filter,
    required this.sections,
  });

  final String title;
  final ReportTemplateProfile profile;
  final ReportFilter filter;
  final Set<ReportSection> sections;

  ReportDefinition copyWith({
    String? title,
    ReportTemplateProfile? profile,
    ReportFilter? filter,
    Set<ReportSection>? sections,
  }) => ReportDefinition(
    title: title ?? this.title,
    profile: profile ?? this.profile,
    filter: filter ?? this.filter,
    sections: sections ?? this.sections,
  );
}

/// What an audit package would contain.
@immutable
final class AuditPackageManifest {
  const AuditPackageManifest({
    required this.packageId,
    required this.createdAt,
    required this.createdBy,
    required this.periodLabel,
    required this.sections,
    required this.recordCount,
    required this.profile,
  });

  final String packageId;
  final DateTime createdAt;
  final String createdBy;
  final String periodLabel;
  final Set<ReportSection> sections;
  final int recordCount;
  final ReportTemplateProfile profile;

  /// Versions the package would pin, so a historical report stays
  /// reproducible. Calibration is deliberately absent-valued: there is none.
  Map<String, String> get versions => const {
    'App version': '0.1.0+1',
    'Algorithm version': 'sim-0',
    'Geometry version': 'badge-v1-research',
    'Feature definition': 'fdv-0.2.0-m0b',
    'Calibration version': 'None — no production calibration exists',
    'Report template version': 'rt-0.1.0',
  };

  /// No signature field exists, and none should be added until something can
  /// actually sign. A manifest that claims integrity it cannot demonstrate is
  /// worse than one that says nothing.
  String get signatureState => 'Not applicable — no signing service exists';
}
