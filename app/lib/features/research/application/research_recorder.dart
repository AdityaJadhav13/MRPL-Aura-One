import 'dart:io';
import 'dart:typed_data';

import 'package:measurement/measurement.dart';

import '../../capture/data/capture_archive.dart';
import '../../capture/domain/capture_outcome.dart';
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

    final record = recordFor(outcome, settings);
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
  CaptureRecord recordFor(CaptureOutcome outcome, ResearchSettings settings) {
    final evidence = outcome.evidence;
    final metadata = switch (outcome) {
      CaptureObserved(:final metadata) => metadata,
      CaptureRefused(:final metadata) => metadata,
    };
    final result = switch (outcome) {
      CaptureObserved(:final result) => result,
      CaptureRefused(:final result) => result,
    };
    final firstReason = result is Refused && result.reasons.isNotEmpty
        ? result.reasons.first
        : null;

    final captureId = captureIdFor(
      specimenId: settings.specimenId,
      capturedAt: metadata.capturedAt,
    );
    final original = _originalFileName(evidence.originalBytes);

    switch (outcome) {
      case CaptureObserved(:final observation, :final geometryValidation):
        return CaptureRecord(
          captureId: captureId,
          dataDomain: observation.dataDomain,
          geometryVersion: geometry.version,
          featureDefinitionVersion: observation.featureVector.definitionVersion,
          algorithmVersion: algorithmVersion,
          conditions: settings.toConditions(),
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
          specimen: settings.toSpecimen(),
          observation: observation,
          correctionMethod: observation.correctionFit?.correction?.form.name,
          homography: evidence.homography?.matrix.toRows(),
        );
      case CaptureRefused():
        return CaptureRecord(
          captureId: captureId,
          // A refused photograph of a physical specimen is still laboratory
          // data: the camera took it, and it describes a real refusal.
          dataDomain: DataDomain.lab,
          geometryVersion: geometry.version,
          featureDefinitionVersion: featureDefinitionVersion,
          algorithmVersion: algorithmVersion,
          conditions: settings.toConditions(),
          metadata: metadata,
          previewAssessment: evidence.previewAssessment,
          stillAssessment: evidence.stillAssessment,
          outcome: 'refused',
          measurementStatus: result.status.name,
          originalImageFile: original,
          stillQuality: evidence.stillQuality,
          refusalCode: firstReason?.code,
          refusalDetail: firstReason?.detail,
          specimen: settings.toSpecimen(),
          homography: evidence.homography?.matrix.toRows(),
        );
    }
  }
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
