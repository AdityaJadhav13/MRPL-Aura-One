// APP-INTEGRATION-01 §52–§54 — the whole path, through the app's own layers.
//
// ENCODED IMAGE BYTES
//   → decodeStill (the real decoder)
//   → CaptureController (the real orchestrator)
//   → package:measurement (fiducials, homography, ROIs, correction, features)
//   → Calibration (NoCalibration — the only one that exists)
//   → ResearchRecorder → CaptureArchive (real files on disk)
//   → archive read back, as after a restart.
//
// Only the camera hardware is replaced. Everything downstream of the bytes is
// production code.
//
// THIS IS NOT PHYSICAL VALIDATION. Every image here is a synthetic render.
// These tests prove the wiring carries the right data to the right place, so
// that tomorrow's unknowns are physical rather than "where did the image go".

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/geometry/geometry_assets.dart';
import 'package:h2s_doseband/features/capture/application/capture_controller.dart';
import 'package:h2s_doseband/features/capture/data/capture_archive.dart';
import 'package:h2s_doseband/features/capture/domain/badge_v1_references.dart';
import 'package:h2s_doseband/features/capture/domain/capture_outcome.dart';
import 'package:h2s_doseband/features/capture/domain/capture_port.dart';
import 'package:h2s_doseband/features/research/application/research_recorder.dart';
import 'package:h2s_doseband/features/research/domain/research_settings.dart';
import 'package:image/image.dart' as img;
import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

// ---------------------------------------------------------------- fixtures

/// A camera that returns encoded bytes and decodes them the way
/// `CameraPortImpl.captureStill` does. The decoder is the production one.
final class EncodedStillCamera implements CameraPort {
  EncodedStillCamera({required this.stillBytes, required this.preview});

  final Uint8List stillBytes;
  final RgbImage preview;

  final _frames = StreamController<PreviewFrame>.broadcast();
  DateTime _clock = DateTime.utc(2026, 9, 26, 10);

  @override
  Future<CameraCapabilities> open() async => const CameraCapabilities.unknown();

  @override
  Future<Map<String, String>> applyMeasurementSettings() async =>
      const <String, String>{};

  @override
  Stream<PreviewFrame> previewFrames() => _frames.stream;

  Future<void> emit(int count) async {
    for (var i = 0; i < count; i++) {
      _clock = _clock.add(const Duration(milliseconds: 150));
      _frames.add((image: preview, at: _clock));
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<CapturedStill> captureStill() async {
    final RgbImage image;
    try {
      image = decodeStill(stillBytes);
    } on FormatException catch (e) {
      // Mirrors CameraPortImpl: an undecodable still is a camera failure,
      // surfaced to the operator, never a measurement.
      throw CameraUnavailable('captured image could not be decoded: $e');
    }
    return (
      image: image,
      originalBytes: stillBytes,
      metadata: CaptureMetadata(
        capturedAt: _clock,
        deviceManufacturer: 'TestMaker',
        deviceModel: 'TestPhone',
        operatingSystem: 'test',
        appVersion: '0.1.0',
        capabilities: const CameraCapabilities.unknown(),
        cameraId: const CaptureField<String>.known('0'),
        imageWidth: CaptureField<int>.known(image.width),
        imageHeight: CaptureField<int>.known(image.height),
        orientationDegrees: const CaptureField<int>.known(0),
        torchOn: const CaptureField<bool>.known(false),
        focusLocked: const CaptureField<bool>.unavailable(),
        exposureLocked: const CaptureField<bool>.unavailable(),
        whiteBalanceLocked: const CaptureField<bool>.unsupported(),
        exposureCompensation: const CaptureField<double>.unavailable(),
        isoSensitivity: const CaptureField<int>.unsupported(),
        exposureTimeSeconds: const CaptureField<double>.unsupported(),
        requestedSettings: const <String, String>{},
      ),
    );
  }

  @override
  Future<void> close() async => _frames.close();
}

const _stillPxPerMm = 16.0;
const _downscale = 4;

RgbImage _render(
  BadgeGeometry geometry, {
  required double pxPerMm,
  required int width,
  required int height,
  double tx = 0,
  double ty = 0,
  Map<String, List<int>> colours = badgeV1Colours,
}) {
  final h = placeBadge(
    pixelsPerMm: pxPerMm,
    translateX: tx == 0 ? (width - geometry.widthMm * pxPerMm) / 2 : tx,
    translateY: ty == 0 ? (height - geometry.heightMm * pxPerMm) / 2 : ty,
    rotationRadians: 0.05,
  );
  return renderBadge(
    geometry: geometry,
    badgeToImage: h,
    width: width,
    height: height,
    colours: colours,
  );
}

Uint8List _jpeg(RgbImage image) {
  final out = img.Image(width: image.width, height: image.height);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      out.setPixelRgb(
        x,
        y,
        image.red(x, y),
        image.green(x, y),
        image.blue(x, y),
      );
    }
  }
  // The real camera returns JPEG, so the fixture does too: the decode path
  // under test is the lossy one the phone will actually exercise.
  return Uint8List.fromList(img.encodeJpg(out, quality: 95));
}

/// A still and its matching ¼-scale preview, as the real port produces them.
///
/// Lossless by default: an ideal camera, so the optics-valid branch — and the
/// calibration behind it — is actually exercised. With [jpeg] the still goes
/// through the lossy encoding a phone produces, and on that path the withheld
/// REF-BLACK patch exceeds the provisional limit; see the test that records
/// it. The fixture is not chosen to hide that — both are tested.
({Uint8List still, RgbImage preview}) _pair(
  BadgeGeometry geometry, {
  Map<String, List<int>> colours = badgeV1Colours,
  bool jpeg = false,
}) {
  const w = 1600, h = 1200;
  final rendered = _render(
    geometry,
    pxPerMm: _stillPxPerMm,
    width: w,
    height: h,
    colours: colours,
  );
  return (
    still: jpeg ? _jpeg(rendered) : encodePng(rendered),
    preview: _render(
      geometry,
      pxPerMm: _stillPxPerMm / _downscale,
      width: w ~/ _downscale,
      height: h ~/ _downscale,
      colours: colours,
    ),
  );
}

CaptureController _controller(
  CameraPort port,
  BadgeGeometry geometry, {
  Calibration calibration = const NoCalibration(),
  bool background = false,
}) => CaptureController(
  port: port,
  geometry: geometry,
  referenceTargets: badgeV1ReferenceTargets(geometry),
  fitPatchIds: badgeV1FitPatchIds,
  holdoutPatchIds: badgeV1HoldoutPatchIds,
  appVersion: '0.1.0',
  previewDownscale: _downscale,
  calibration: calibration,
  autoCapture: false,
  evaluateInBackground: background,
);

const _settings = ResearchSettings(
  specimenId: 'P0-X1-01',
  seriesLevel: 'X1',
  batchId: 'B-TEST',
  formulationId: 'F-TEST',
  illuminationClass: 'bench',
);

/// Every string in [json], recursively, for claim scans.
Iterable<String> _strings(Object? json) sync* {
  if (json is String) yield json;
  if (json is Map) {
    for (final e in json.entries) {
      yield '${e.key}';
      yield* _strings(e.value);
    }
  }
  if (json is List) {
    for (final v in json) {
      yield* _strings(v);
    }
  }
}

// ------------------------------------------------------------------- tests

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BadgeGeometry geometry;
  late Directory tmp;
  late CaptureArchive archive;

  setUpAll(() async {
    // The canonical geometry, through the app's own checksum-verified loader —
    // not a copy. §8.
    geometry = await GeometryAssets().load('badge-v1-research');
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('doseband-e2e-');
    archive = CaptureArchive(root: tmp);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  // =====================================================================
  // §53 — the full valid pipeline
  // =====================================================================

  // The worker's final capture evaluates the still on a background isolate
  // (it is taken at the camera's maximum resolution). Same still, same code:
  // the outcome must be identical to evaluating it inline.
  test('background evaluation gives the inline outcome', () async {
    Future<CaptureObserved> run({required bool background}) async {
      final pair = _pair(geometry);
      final port = EncodedStillCamera(
        stillBytes: pair.still,
        preview: pair.preview,
      );
      final controller = _controller(port, geometry, background: background);
      await controller.start();
      await port.emit(6);
      await controller.capture();
      final outcome = controller.state.outcome;
      await controller.dispose();
      expect(outcome, isA<CaptureObserved>(), reason: '$outcome');
      return outcome! as CaptureObserved;
    }

    final inline = await run(background: false);
    final isolate = await run(background: true);
    expect(isolate.result.status, inline.result.status);
    expect(
      isolate.observation.reprojectionRmsPx,
      inline.observation.reprojectionRmsPx,
    );
    for (final id in inline.observation.samples.keys) {
      final a = inline.observation.samples[id]!;
      final b = isolate.observation.samples[id]!;
      expect(b.usedSamples, a.usedSamples, reason: id);
      expect(b.trimmedMeanLinear.r, a.trimmedMeanLinear.r, reason: id);
      expect(b.trimmedMeanLinear.g, a.trimmedMeanLinear.g, reason: id);
      expect(b.trimmedMeanLinear.b, a.trimmedMeanLinear.b, reason: id);
    }
  });

  group('a valid capture, end to end', () {
    late CaptureObserved observed;
    late Uint8List stillBytes;

    setUp(() async {
      final pair = _pair(geometry);
      stillBytes = pair.still;
      final port = EncodedStillCamera(
        stillBytes: pair.still,
        preview: pair.preview,
      );
      final controller = _controller(port, geometry);
      await controller.start();
      await port.emit(6);

      // G-03 regression: on a ¼-scale preview, guidance must be able to
      // report ready. Before the fix it asked the operator to move closer
      // forever, because px/mm was judged on the wrong scale.
      expect(
        controller.state.guidance?.state,
        GuidanceState.ready,
        reason: 'preview guidance must be reachable on a downscaled frame',
      );

      await controller.capture();
      final outcome = controller.state.outcome;
      expect(outcome, isA<CaptureObserved>(), reason: '$outcome');
      observed = outcome! as CaptureObserved;
      await controller.dispose();
    });

    test('uses the canonical geometry', () {
      expect(
        observed.observation.featureVector.geometryVersion,
        'badge-v1-research',
      );
    });

    test('recovers a homography from the decoded still', () {
      expect(observed.evidence.homography, isNotNull);
      expect(observed.observation.reprojectionRmsPx, lessThan(2.0));
    });

    test('samples sensor, blank, expiry and every reference', () {
      final ids = observed.observation.samples.keys;
      expect(ids, containsAll(<String>['A1', 'B', 'E']));
      expect(
        ids,
        containsAll(<String>[...badgeV1FitPatchIds, ...badgeV1HoldoutPatchIds]),
      );
    });

    test('fits a correction and validates it on withheld patches', () {
      expect(observed.observation.correctionFit?.isOk, isTrue);
      final validation = observed.observation.referenceValidation!;
      expect(
        validation.residuals.map((r) => r.patchId),
        unorderedEquals(badgeV1HoldoutPatchIds),
      );
      // No withheld patch leaked into the fit. §37.
      expect(validation.leakedPatchIds, isEmpty);
    });

    test('carries the blank through to features', () {
      final names = observed.observation.featureVector.features
          .map((f) => f.name)
          .toSet();
      expect(names, contains('sensor_blank_delta_e00'));
      expect(names, contains('sensor_blank_delta_e76'));
      expect(names, contains('sensor_minus_blank_lab_l'));
    });

    test('refuses for lack of calibration, typed, never a number', () {
      final result = observed.result;
      expect(result, isA<Refused>());
      expect(result, isNot(isA<Valid>()));
      expect(result, isNot(isA<Censored>()));
      expect(result.status, ResultStatus.unsupportedCalibration);
      expect(
        (result as Refused).reasons.map((r) => r.code),
        contains('NO_CALIBRATION_MODEL'),
      );
      expect(result.provenance.calibrationModelId, isNull);
    });

    test('archives a complete, self-describing record', () async {
      final saved = await ResearchRecorder(
        archive: archive,
        geometry: geometry,
      ).save(observed, _settings);

      final dir = saved.directory;
      final record = jsonDecode(
        File('${dir.path}/record.json').readAsStringSync(),
      ) as Map<String, Object?>;

      expect(record['schema'], 'doseband-capture-record/3');
      expect(record['outcome'], 'observed');
      expect(record['measurement_status'], 'unsupportedCalibration');
      expect(record['data_domain'], 'lab');
      expect(record['geometry_version'], 'badge-v1-research');
      expect(record['algorithm_version'], algorithmVersion);
      expect(record['correction_method'], isNotNull);
      expect(record['homography_badge_mm_to_image_px'], isNotNull);

      final specimen = record['specimen']! as Map<String, Object?>;
      expect(specimen['specimen_id'], 'P0-X1-01');
      expect(specimen['series_level'], 'X1');
      expect(specimen['badge_id'], isNull);

      // §50: near-raw data, not just the derived features.
      final observation = record['observation']! as Map<String, Object?>;
      expect((observation['samples']! as Map).keys, contains('E'));
      expect(observation['correction_fit'], isNotNull);

      // §10: the original, byte for byte.
      final original = File('${dir.path}/${record['original_image_file']}');
      // Exactly the bytes supplied — the name follows what they are.
      expect(record['original_image_file'], 'original.png');
      expect(original.readAsBytesSync(), stillBytes);

      // The rectified evidence view.
      expect(File('${dir.path}/rectified.png').existsSync(), isTrue);
    });

    test('the archived record contains no dose and no fake quantity', () async {
      final saved = await ResearchRecorder(
        archive: archive,
        geometry: geometry,
      ).save(observed, _settings);
      final json = saved.record.toJson();
      for (final s in _strings(json)) {
        final lower = s.toLowerCase();
        expect(lower, isNot(contains('ppm·h')), reason: s);
        expect(lower, isNot(contains('dose_ppm')), reason: s);
        expect(lower, isNot(contains('exposure_ppm')), reason: s);
      }
    });

    test('survives a restart: a fresh archive reads it back', () async {
      // §30: capture → persist → relaunch → view. A new archive object over
      // the same directory is what a relaunched process sees.
      await ResearchRecorder(
        archive: archive,
        geometry: geometry,
      ).save(observed, _settings);

      final relaunched = CaptureArchive(root: tmp);
      final records = await relaunched.records();
      expect(records, hasLength(1));
      expect((records.single['specimen']! as Map)['specimen_id'], 'P0-X1-01');
      expect(await relaunched.incompleteCaptures(), isEmpty);
    });

    test('never silently overwrites a capture', () async {
      final recorder = ResearchRecorder(archive: archive, geometry: geometry);
      await recorder.save(observed, _settings);
      // Same outcome, same timestamp → same id. The archive must refuse.
      await expectLater(
        recorder.save(observed, _settings),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses to save a capture with no specimen id', () async {
      await expectLater(
        ResearchRecorder(
          archive: archive,
          geometry: geometry,
        ).save(observed, const ResearchSettings(specimenId: '   ')),
        throwsArgumentError,
      );
    });
  });

  // =====================================================================
  // §54 — failures, through the same orchestration
  // =====================================================================

  Future<CaptureOutcome?> runWith(
    Uint8List still,
    RgbImage preview, {
    Calibration calibration = const NoCalibration(),
    List<String>? errors,
  }) async {
    final port = EncodedStillCamera(stillBytes: still, preview: preview);
    final controller = _controller(port, geometry, calibration: calibration);
    await controller.start();
    await port.emit(3);
    await controller.capture();
    errors?.add(controller.state.error ?? '');
    final outcome = controller.state.outcome;
    await controller.dispose();
    return outcome;
  }

  group('failures are refusals, and refusals are evidence', () {
    test('undecodable bytes surface as a camera error, not a result', () async {
      final errors = <String>[];
      final outcome = await runWith(
        Uint8List.fromList(utf8.encode('this is not an image')),
        RgbImage.filled(400, 300, 60, 60, 60),
        errors: errors,
      );
      expect(outcome, isNull);
      expect(errors.single, contains('could not be decoded'));
    });

    test('no target in frame is refused, and saved as a refusal', () async {
      final empty = RgbImage.filled(1600, 1200, 64, 66, 70);
      final outcome = await runWith(
        _jpeg(empty),
        RgbImage.filled(400, 300, 64, 66, 70),
      );
      expect(outcome, isA<CaptureRefused>());
      final refused = outcome! as CaptureRefused;
      expect(refused.result, isNot(isA<Valid>()));
      expect(refused.result.status, ResultStatus.poorImage);

      final saved = await ResearchRecorder(
        archive: archive,
        geometry: geometry,
      ).save(refused, _settings);
      expect(saved.record.outcome, 'refused');
      expect(saved.record.refusalCode, isNotNull);
      expect(saved.record.featureVector, isNull);
      // The refused original is kept too: it is evidence of what the reader
      // rejects.
      expect(
        File('${saved.directory.path}/${saved.record.originalImageFile}')
            .existsSync(),
        isTrue,
      );
    });

    test('a badge cropped off the frame edge is refused', () async {
      final cropped = _render(
        geometry,
        pxPerMm: _stillPxPerMm,
        width: 1600,
        height: 1200,
        tx: -300,
        ty: 300,
      );
      final outcome = await runWith(
        _jpeg(cropped),
        RgbImage.filled(400, 300, 64, 66, 70),
      );
      expect(outcome, isA<CaptureRefused>(), reason: '$outcome');
    });

    test('a simulated calibration refuses a real capture', () async {
      // §19, end to end: even if a development calibration were configured,
      // it may not produce a number for a laboratory photograph.
      final pair = _pair(geometry);
      final outcome = await runWith(
        pair.still,
        pair.preview,
        calibration: _SimulatedDevelopmentCalibration(),
      );
      expect(outcome, isA<CaptureObserved>());
      final result = (outcome! as CaptureObserved).result;
      expect(result, isA<Refused>());
      expect(
        (result as Refused).reasons.map((r) => r.code),
        contains('SIMULATED_CALIBRATION_ON_REAL_CAPTURE'),
      );
    });

    test('JPEG compression alone fails the withheld black patch', () async {
      // A recorded pre-hardware finding. The same clean render, through the
      // lossy encoding a phone produces, gives withheld REF-BLACK ΔE00 ≈ 2.06
      // against a provisional limit of 2.0: the affine correction is fitted
      // on REF-LIGHT and the chromatics, so black is an extrapolation. The
      // capture is observed and archived, the acquisition is a reference
      // failure, and no calibration is consulted.
      //
      // Expect the physical phone to hit this. The limit and the fit/holdout
      // split are for M0C evidence to set — they are not tuned here.
      final pair = _pair(geometry, jpeg: true);
      final outcome = await runWith(pair.still, pair.preview);
      expect(outcome, isA<CaptureObserved>());
      final observed = outcome! as CaptureObserved;
      expect(observed.quality.acceptable, isFalse);
      expect(observed.quality.primaryFailure!.id, 'withheld_references');
      final worst = observed.observation.referenceValidation!.residuals.reduce(
        (a, b) => a.deltaE00 > b.deltaE00 ? a : b,
      );
      expect(worst.patchId, 'REF-BLACK');
      expect(observed.result.status, ResultStatus.referencePatchFailure);
      expect(observed.result, isNot(isA<Valid>()));

      final saved = await ResearchRecorder(
        archive: archive,
        geometry: geometry,
      ).save(observed, _settings);
      expect(saved.record.toJson()['acquisition_valid'], isFalse);
      expect(saved.record.originalImageFile, 'original.jpg');
    });

    test('collapsed references are recorded as a failed fit', () async {
      // Every reference printed the same grey: the correction has nothing to
      // fit to. The optics can still be observed, but the record must say
      // the correction failed rather than report corrected values.
      final flat = Map<String, List<int>>.of(badgeV1Colours);
      for (final id in [...badgeV1FitPatchIds, ...badgeV1HoldoutPatchIds]) {
        flat[id] = <int>[128, 128, 128];
      }
      final pair = _pair(geometry, colours: flat);
      final outcome = await runWith(pair.still, pair.preview);
      expect(outcome, isA<CaptureObserved>(), reason: '$outcome');
      final observation = (outcome! as CaptureObserved).observation;
      expect(observation.correctionFit?.isOk, isFalse);
      expect(observation.featureVector.correctedSensorLinear, isNull);
      final names = observation.featureVector.features.map((f) => f.name);
      expect(names.where((n) => n.startsWith('corrected_')), isEmpty);
    });
  });
}

/// A stand-in for a development calibration fitted to simulated data.
///
/// It would happily return a number — and it never gets the chance on a real
/// capture, because it respects `calibrationMismatch` as every real
/// calibration must.
final class _SimulatedDevelopmentCalibration implements Calibration {
  @override
  CalibrationPackage get package => CalibrationPackage(
    calibrationId: 'SIM-DEV-1',
    version: '0',
    dataDomain: DataDomain.simulated,
    geometryVersion: 'badge-v1-research',
    featureDefinitionVersion: featureDefinitionVersion,
    modelType: 'simulated',
    createdAt: DateTime.utc(2026, 9, 26),
  );

  @override
  MeasurementResult interpret(
    ResearchObservation observation, {
    required String appVersion,
    required String deviceModel,
    MeasurementContext context = MeasurementContext.none,
  }) {
    final mismatch = calibrationMismatch(
      package,
      observation,
      context: context,
    );
    final provenance = Provenance(
      algorithmVersion: algorithmVersion,
      geometryVersion: observation.featureVector.geometryVersion,
      calibrationModelId: null,
      referenceProfileId: null,
      appVersion: appVersion,
      deviceModel: deviceModel,
    );
    if (mismatch != null) {
      return Refused(
        status: ResultStatus.unsupportedCalibration,
        reasons: <ReasonCode>[mismatch],
        provenance: provenance,
      );
    }
    throw StateError('this test calibration must never reach a prediction');
  }
}
