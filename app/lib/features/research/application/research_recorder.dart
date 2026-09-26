import 'dart:io';
import 'dart:typed_data';

import 'package:measurement/measurement.dart';

import '../../capture/data/capture_archive.dart';
import '../../capture/domain/capture_outcome.dart';
import '../../workflow/domain/physical_badge.dart';
import '../../workflow/domain/work_context.dart';
import '../../workflow/domain/workflow_state.dart';
import '../domain/research_settings.dart';

/// One capture, archived.
typedef SavedCapture = ({
  String captureId,
  Directory directory,
  CaptureRecord record,
});

/// Turns a capture outcome into an archived research record.
///
/// ## Why this class exists
///
/// Before APP-INTEGRATION-01 the archive was complete and never called: every
/// capture on the development route was taken, processed, shown as one line
/// of text and discarded when the screen closed (G-01). This is the missing
/// wire.
///
/// **Both outcomes are archived.** A refused capture is evidence too — often
/// the more useful kind in M0C, because it shows what the reader rejects and
/// why. A dataset of acceptances alone cannot measure refusal.
final class ResearchRecorder {
  ResearchRecorder({
    required this.archive,
    required this.geometry,
    this.rectifiedPixelsPerMm = 10.0,
  });

  final CaptureArchive archive;
  final BadgeGeometry geometry;

  /// Resolution of the stored rectified view. Evidence only — the pipeline
  /// never reads it.
  final double rectifiedPixelsPerMm;

  Future<SavedCapture> save(
    CaptureOutcome outcome,
    ResearchSettings settings,
  ) async {
    if (!settings.isComplete) {
      // A capture with no specimen is a photograph of something, and nobody
      // can later say what. Refusing to save it is better than archiving it.
      throw ArgumentError('a research capture needs a specimen id');
    }
    return _write(outcome, recordFor(outcome, settings));
  }

  /// Archives a worker's scan of their physical badge. §76.
  ///
  /// Every attempt is archived — refused ones too — so that false rejections
  /// on real hardware can be counted, not guessed. The record carries the
  /// badge and the operational context rather than a research specimen: a
  /// worn badge is not a laboratory coupon, and its record should not look
  /// like one. §12.
  Future<SavedCapture> saveWorkerScan(
    CaptureOutcome outcome, {
    required PhysicalBadge badge,
    required ShiftSession session,
    required WorkContext context,
  }) {
    final record = _build(
      outcome,
      captureId: captureIdFor(
        specimenId: badge.badgeId,
        capturedAt: _metadataOf(outcome).capturedAt,
      ),
      conditions: CaptureConditions(
        illuminationClass: 'operational',
        approximateDistanceMm: null,
        approximateAngleDegrees: null,
        targetId: badge.badgeId,
        operatorNote: '',
      ),
      specimen: null,
      operationalContext: workerScanContext(
        badge: badge,
        session: session,
        context: context,
      ),
    );
    return _write(outcome, record);
  }

  Future<SavedCapture> _write(
    CaptureOutcome outcome,
    CaptureRecord record,
  ) async {
    final evidence = outcome.evidence;
    final derived = <String, Uint8List>{};
    final h = evidence.homography;
    if (h != null) {
      final rectified = rectifyBadge(
        image: evidence.still,
        badgeToImage: h,
        geometry: geometry,
        pixelsPerMm: rectifiedPixelsPerMm,
      );
      if (rectified != null) derived['rectified.png'] = encodePng(rectified);
    }

    final directory = await archive.write(
      record: record,
      originalBytes: evidence.originalBytes,
      derivedFiles: derived,
    );
    return (captureId: record.captureId, directory: directory, record: record);
  }

  /// The record for [outcome], without writing it. Exposed for tests.
  CaptureRecord recordFor(CaptureOutcome outcome, ResearchSettings settings) =>
      _build(
        outcome,
        captureId: captureIdFor(
          specimenId: settings.specimenId,
          capturedAt: _metadataOf(outcome).capturedAt,
        ),
        conditions: settings.toConditions(),
        specimen: settings.toSpecimen(),
        operationalContext: null,
      );

  CaptureRecord _build(
    CaptureOutcome outcome, {
    required String captureId,
    required CaptureConditions conditions,
    required ResearchSpecimen? specimen,
    required Map<String, Object?>? operationalContext,
  }) {
    final evidence = outcome.evidence;
    final metadata = _metadataOf(outcome);
    final result = switch (outcome) {
      CaptureObserved(:final result) => result,
      CaptureRefused(:final result) => result,
    };
    final firstReason = result is Refused && result.reasons.isNotEmpty
        ? result.reasons.first
        : null;
    final original = _originalFileName(evidence.originalBytes);

    switch (outcome) {
      case CaptureObserved(:final observation, :final geometryValidation):
        return CaptureRecord(
          captureId: captureId,
          dataDomain: observation.dataDomain,
          geometryVersion: geometry.version,
          featureDefinitionVersion: observation.featureVector.definitionVersion,
          algorithmVersion: algorithmVersion,
          conditions: conditions,
          metadata: metadata,
          previewAssessment: evidence.previewAssessment,
          stillAssessment: evidence.stillAssessment,
          outcome: 'observed',
          measurementStatus: result.status.name,
          originalImageFile: original,
          featureVector: observation.featureVector,
          geometryValidation: geometryValidation,
          stillQuality: evidence.stillQuality,
          refusalCode: firstReason?.code,
          refusalDetail: firstReason?.detail,
          specimen: specimen,
          observation: observation,
          correctionMethod: observation.correctionFit?.correction?.form.name,
          homography: evidence.homography?.matrix.toRows(),
          acquisitionQuality: outcome.quality,
          operationalContext: operationalContext,
        );
      case CaptureRefused():
        return CaptureRecord(
          captureId: captureId,
          // A refused photograph is still a photograph a camera took. Its
          // domain follows where it was taken: the bench or the workflow.
          dataDomain: operationalContext == null
              ? DataDomain.lab
              : DataDomain.field,
          geometryVersion: geometry.version,
          featureDefinitionVersion: featureDefinitionVersion,
          algorithmVersion: algorithmVersion,
          conditions: conditions,
          metadata: metadata,
          previewAssessment: evidence.previewAssessment,
          stillAssessment: evidence.stillAssessment,
          outcome: 'refused',
          measurementStatus: result.status.name,
          originalImageFile: original,
          stillQuality: evidence.stillQuality,
          refusalCode: firstReason?.code,
          refusalDetail: firstReason?.detail,
          specimen: specimen,
          homography: evidence.homography?.matrix.toRows(),
          acquisitionQuality: outcome.quality,
          operationalContext: operationalContext,
        );
    }
  }
}

CaptureMetadata _metadataOf(CaptureOutcome outcome) => switch (outcome) {
  CaptureObserved(:final metadata) => metadata,
  CaptureRefused(:final metadata) => metadata,
};

/// The operational context of a worker scan, as stored on its record.
///
/// Every value is copied as the session held it, with its provenance: the
/// worker identity is demonstration data in this prototype and says so, and
/// the badge was typed by hand and says so. Nothing is looked up or verified
/// here. §76, §97.
Map<String, Object?> workerScanContext({
  required PhysicalBadge badge,
  required ShiftSession session,
  required WorkContext context,
}) {
  final coverage = session.endedAt == null
      ? null
      : session.coverageAt(session.endedAt!);
  return <String, Object?>{
    'schema': 'doseband-worker-scan-context/1',
    'badge': badge.toJson(),
    'badge_identity_provenance': badge.identityProvenance,
    'worker_id': context.worker.workerId,
    'worker_name': context.worker.displayName,
    'worker_identity_source': context.worker.source.label,
    'site': context.site.name,
    'department': context.department.name,
    'work_area_id': context.workArea.id,
    'work_area': context.workArea.name,
    'shift': context.shift.name,
    'job': context.job.title,
    'permit_reference': context.permit.reference.value,
    'jsa_reference': context.jsa.reference.value,
    'monitoring_started_at': session.startedAt?.toUtc().toIso8601String(),
    'monitoring_ended_at': session.endedAt?.toUtc().toIso8601String(),
    // Null when the window is unknown or untrusted — a backwards clock never
    // becomes a duration.
    'monitored_seconds': coverage?.inSeconds,
  };
}

/// A capture id that sorts by time within a specimen and cannot collide.
///
/// Built from the capture's own timestamp — the one the camera path recorded
/// — rather than a fresh read of the clock, so the id and the record agree.
/// Millisecond resolution; the archive refuses to overwrite a directory, so
/// two captures inside one millisecond fail loudly rather than silently
/// replacing each other. §10.
String captureIdFor({
  required String specimenId,
  required DateTime capturedAt,
}) {
  final safe = specimenId.trim().replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
  final t = capturedAt.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${t.year}${two(t.month)}${two(t.day)}T'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}'
      '${t.millisecond.toString().padLeft(3, '0')}Z';
  return '${safe}__$stamp';
}

/// The camera returns JPEG on both platforms today, but the bytes are kept
/// exactly, so the name is decided by what they actually are.
String _originalFileName(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'original.png';
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return 'original.jpg';
  }
  return 'original.bin';
}
