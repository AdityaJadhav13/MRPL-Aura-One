// APP-INTEGRATION-01 — engine-side guarantees the app depends on.
//
// Every test here uses synthetic renders. None of it is physical evidence and
// none of it may be cited as such: it proves that the wiring carries the right
// data, not that a camera will produce it.

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';
import 'package:test/test.dart';

BadgeGeometry get _v1 => BadgeGeometry.parse(
  File('geometry/badge-v1.geometry.json').readAsStringSync(),
);

Map<String, LinearRgb> get _targets => <String, LinearRgb>{
  for (final e in badgeV1Colours.entries)
    if (e.key.startsWith('REF-'))
      e.key: SrgbColor.fromBytes(e.value[0], e.value[1], e.value[2]).toLinear(),
};

const _fit = <String>[
  'REF-LIGHT',
  'REF-RED',
  'REF-GREEN',
  'REF-BLUE',
  'REF-CYAN',
  'REF-YELLOW',
];
const _holdout = <String>['REF-BLACK', 'REF-DARK', 'REF-MID', 'REF-MAGENTA'];

ResearchObservation _observeV1({DataDomain domain = DataDomain.lab}) {
  final geometry = _v1;
  final h = placeBadge(pixelsPerMm: 14, translateX: 70, translateY: 60);
  final image = renderBadge(
    geometry: geometry,
    badgeToImage: h,
    width: 1000,
    height: 700,
    colours: badgeV1Colours,
  );
  return observe(
    image: image,
    geometry: geometry,
    correspondences: fiducialCorrespondences(geometry, h),
    dataDomain: domain,
    referenceTargets: _targets,
    fitPatchIds: _fit,
    holdoutPatchIds: _holdout,
  );
}

final _metadata = CaptureMetadata(
  capturedAt: DateTime.utc(2026, 9, 26, 9),
  deviceManufacturer: 'test',
  deviceModel: 'test',
  operatingSystem: 'test',
  appVersion: 'test',
  capabilities: const CameraCapabilities.unknown(),
  cameraId: const CaptureField<String>.unavailable(),
  imageWidth: const CaptureField<int>.unavailable(),
  imageHeight: const CaptureField<int>.unavailable(),
  orientationDegrees: const CaptureField<int>.unavailable(),
  torchOn: const CaptureField<bool>.unavailable(),
  focusLocked: const CaptureField<bool>.unavailable(),
  exposureLocked: const CaptureField<bool>.unavailable(),
  whiteBalanceLocked: const CaptureField<bool>.unsupported(),
  exposureCompensation: const CaptureField<double>.unavailable(),
  isoSensitivity: const CaptureField<int>.unsupported(),
  exposureTimeSeconds: const CaptureField<double>.unsupported(),
  requestedSettings: const <String, String>{},
);

CalibrationPackage _package({
  DataDomain domain = DataDomain.lab,
  String geometry = 'badge-v1-research',
  String? featureDefinition,
}) => CalibrationPackage(
  calibrationId: 'TEST-ONLY',
  version: '0',
  dataDomain: domain,
  geometryVersion: geometry,
  featureDefinitionVersion: featureDefinition ?? featureDefinitionVersion,
  modelType: 'test-only',
  createdAt: DateTime.utc(2026, 9, 26),
);

void main() {
  // ===================================================================
  // G-04 · specimen identity
  // ===================================================================

  group('research specimen identity', () {
    test('round-trips through JSON', () {
      const specimen = ResearchSpecimen(
        specimenId: 'P0-X1-01',
        badgeId: 'DB-000123',
        batchId: 'B-7',
        formulationId: 'F-bi-01',
        seriesLevel: 'X1',
      );
      final back = ResearchSpecimen.fromJson(specimen.toJson());
      expect(back.specimenId, 'P0-X1-01');
      expect(back.badgeId, 'DB-000123');
      expect(back.batchId, 'B-7');
      expect(back.formulationId, 'F-bi-01');
      expect(back.seriesLevel, 'X1');
    });

    test('specimen and badge identity are separate fields', () {
      // §12: overloading badge_id to carry a laboratory coupon id is how a
      // coupon ends up looking like an issued badge in a report.
      const specimen = ResearchSpecimen(specimenId: 'P0-X0-01');
      final json = specimen.toJson();
      expect(json['specimen_id'], 'P0-X0-01');
      expect(json['badge_id'], isNull);
    });

    test('a series level carries no dose', () {
      // §42: X1 is an intended ordering, not a known exposure.
      final json = const ResearchSpecimen(
        specimenId: 'P0-X3-01',
        seriesLevel: 'X3',
      ).toJson();
      for (final key in json.keys) {
        expect(key, isNot(contains('dose')));
        expect(key, isNot(contains('ppm')));
      }
    });

    test('the record carries specimen, observation and correction method', () {
      final observation = _observeV1();
      final record = CaptureRecord(
        captureId: 'c-1',
        dataDomain: DataDomain.lab,
        geometryVersion: 'badge-v1-research',
        featureDefinitionVersion: featureDefinitionVersion,
        algorithmVersion: algorithmVersion,
        conditions: const CaptureConditions(
          illuminationClass: 'bench',
          approximateDistanceMm: null,
          approximateAngleDegrees: null,
          targetId: 'sheet-1',
          operatorNote: '',
        ),
        metadata: _metadata,
        previewAssessment: null,
        stillAssessment: null,
        outcome: 'observed',
        originalImageFile: 'original.jpg',
        specimen: const ResearchSpecimen(specimenId: 'P0-X2-01'),
        observation: observation,
        correctionMethod: observation.correctionFit?.correction?.form.name,
      );
      final json = record.toJson();
      expect(json['schema'], 'doseband-capture-record/2');
      expect((json['specimen']! as Map)['specimen_id'], 'P0-X2-01');
      expect(json['correction_method'], isNotNull);
      // §50: the near-raw ROI statistics survive, not just derived features.
      final samples = (json['observation']! as Map)['samples']! as Map;
      expect(samples.keys, containsAll(<String>['A1', 'B', 'REF-RED']));
    });
  });

  // ===================================================================
  // G-06 · expiry ROI
  // ===================================================================

  group('expiry region', () {
    test('is sampled and stored', () {
      final observation = _observeV1();
      expect(observation.samples.keys, contains('E'));
    });

    test('produces no feature and no expiry claim', () {
      // §25: its optical state is recorded; nothing interprets it, because no
      // ageing chemistry has been validated.
      final names = observation(_observeV1());
      expect(names.where((n) => n.contains('expir')), isEmpty);
      expect(names.where((n) => n.startsWith('e_')), isEmpty);
    });
  });

  // ===================================================================
  // §49–§50 · the correction method is recorded
  // ===================================================================

  test('the fitted correction is serialised with its form and matrix', () {
    final fit = _observeV1().correctionFit!;
    final json = fit.toJson();
    expect(json['ok'], isTrue);
    expect(json['form'], anyOf('linear3x3', 'affine3x4'));
    expect((json['matrix']! as List), isNotEmpty);
    expect(json['fit_patch_ids'], _fit);
    expect(json['conditioning'], isNotNull);
  });

  // ===================================================================
  // G-05 · calibration interface
  // ===================================================================

  group('calibration', () {
    test('NoCalibration refuses a valid optical acquisition', () {
      final result = const NoCalibration().interpret(
        _observeV1(),
        appVersion: 'test',
        deviceModel: 'test',
      );
      expect(result, isA<Refused>());
      expect(result.status, ResultStatus.unsupportedCalibration);
      expect(result.provenance.calibrationModelId, isNull);
      expect(
        (result as Refused).reasons.map((r) => r.code),
        contains('NO_CALIBRATION_MODEL'),
      );
    });

    test('NoCalibration never produces a quantity, in any domain', () {
      // G-11: Valid's calibration-id guard is an assert, gone in release
      // builds. This is the check that holds regardless.
      for (final domain in DataDomain.values) {
        final result = const NoCalibration().interpret(
          _observeV1(domain: domain),
          appVersion: 'test',
          deviceModel: 'test',
        );
        expect(result, isNot(isA<Valid>()), reason: domain.name);
        expect(result, isNot(isA<Censored>()), reason: domain.name);
      }
    });

    test('a simulated calibration may not interpret a real capture', () {
      // §19: the rule that keeps development calibration out of physical
      // research.
      final mismatch = calibrationMismatch(
        _package(domain: DataDomain.simulated),
        _observeV1(domain: DataDomain.lab),
      );
      expect(mismatch?.code, 'SIMULATED_CALIBRATION_ON_REAL_CAPTURE');

      expect(
        calibrationMismatch(
          _package(domain: DataDomain.simulated),
          _observeV1(domain: DataDomain.field),
        )?.code,
        'SIMULATED_CALIBRATION_ON_REAL_CAPTURE',
      );
    });

    test('a calibration is bound to its geometry', () {
      final mismatch = calibrationMismatch(
        _package(geometry: 'some-other-badge'),
        _observeV1(),
      );
      expect(mismatch?.code, 'CALIBRATION_GEOMETRY_MISMATCH');
    });

    test('a calibration is bound to its feature definition', () {
      final mismatch = calibrationMismatch(
        _package(featureDefinition: 'fdv-something-else'),
        _observeV1(),
      );
      expect(mismatch?.code, 'CALIBRATION_FEATURE_DEFINITION_MISMATCH');
    });

    test('a compatible package passes the compatibility check', () {
      expect(calibrationMismatch(_package(), _observeV1()), isNull);
    });

    test('an unestablished bound serialises as null, never zero', () {
      final json = _package().toJson();
      expect(json['lower_quantification_bound_ppm_h'], isNull);
      expect(json['upper_quantification_bound_ppm_h'], isNull);
      expect(json['evidence_reference'], isNull);
    });
  });

  // ===================================================================
  // §22 · colour pipeline boundary failures
  // ===================================================================
  //
  // The engine's colour maths is verified in isolation (Sharma et al.,
  // published primaries, 394 parity comparisons). These tests cover the
  // *boundary* — encoded bytes through decodeStill into a sample — where
  // byte range, double gamma and channel order go wrong.

  group('encoded image to linear sample', () {
    RgbImage decodeSolid(int r, int g, int b) {
      final image = img.Image(width: 32, height: 32);
      img.fill(image, color: img.ColorRgb8(r, g, b));
      return decodeStill(Uint8List.fromList(img.encodePng(image)));
    }

    test('bytes arrive in 0–255, not 0–1', () {
      final decoded = decodeSolid(200, 100, 50);
      expect(decoded.red(10, 10), 200);
      expect(decoded.green(10, 10), 100);
      expect(decoded.blue(10, 10), 50);
    });

    test('bytes are normalised to 0–1 exactly once', () {
      // Dividing by 255 twice would give 0.003; not at all would give 200.
      final c = decodeSolid(200, 100, 50).pixel(10, 10);
      expect(c.r, closeTo(200 / 255, 1e-12));
    });

    test('channel order survives decoding', () {
      // A BGR/RGB swap would put 50 where 200 belongs.
      final decoded = decodeSolid(200, 100, 50);
      expect(decoded.red(0, 0), 200);
      expect(decoded.blue(0, 0), 50);
    });

    test('linearisation is applied exactly once', () {
      // sRGB 128 is linear ~0.2158. Missing linearisation gives ~0.502;
      // applying it twice gives ~0.0382.
      final linear = SrgbColor.fromBytes(128, 128, 128).toLinear();
      expect(linear.r, closeTo(0.2158, 0.001));
      expect(linear.r, isNot(closeTo(0.502, 0.05)));
      expect(linear.r, isNot(closeTo(0.0382, 0.01)));
    });

    test('Lab is computed from linear light, not gamma-encoded values', () {
      // Mid-grey sRGB 119 is L* ≈ 50. Feeding gamma-encoded values into the
      // XYZ matrix instead gives L* ≈ 76.
      final lab = SrgbColor.fromBytes(119, 119, 119).toLinear().toXyz().toLab();
      expect(lab.lStar, closeTo(50.0, 0.5));
    });
  });
  // ===================================================================
  // §10, §14 · rectified evidence view
  // ===================================================================

  group('rectified view', () {
    test('puts each fiducial at its canonical position', () {
      final geometry = _v1;
      final h = placeBadge(
        pixelsPerMm: 14,
        translateX: 90,
        translateY: 70,
        rotationRadians: 0.2,
        perspectiveX: 0.0006,
      );
      final photo = renderBadge(
        geometry: geometry,
        badgeToImage: h,
        width: 1100,
        height: 800,
        colours: badgeV1Colours,
      );
      const ppmm = 8.0;
      final rectified = rectifyBadge(
        image: photo,
        badgeToImage: h,
        geometry: geometry,
        pixelsPerMm: ppmm,
      )!;
      expect(rectified.width, (geometry.widthMm * ppmm).round());
      expect(rectified.height, (geometry.heightMm * ppmm).round());

      for (final f in geometry.fiducials) {
        final x = (f.centreMm.x * ppmm).floor();
        final y = (f.centreMm.y * ppmm).floor();
        // Fiducials are printed near-black; the substrate is near-white.
        expect(rectified.red(x, y), lessThan(60), reason: f.id);
      }
    });

    test('leaves area outside the photograph black, never invented', () {
      final geometry = _v1;
      // Most of the badge hangs off the left edge of this frame.
      final h = placeBadge(pixelsPerMm: 14, translateX: -500, translateY: 60);
      final photo = renderBadge(
        geometry: geometry,
        badgeToImage: h,
        width: 800,
        height: 700,
        colours: badgeV1Colours,
      );
      final rectified = rectifyBadge(
        image: photo,
        badgeToImage: h,
        geometry: geometry,
      )!;
      expect(rectified.red(2, 2), 0);
      expect(rectified.green(2, 2), 0);
      expect(rectified.blue(2, 2), 0);
    });

    test('encodes losslessly', () {
      final image = RgbImage.filled(4, 3, 12, 200, 99);
      final back = decodeStill(encodePng(image));
      expect(back.red(1, 1), 12);
      expect(back.green(1, 1), 200);
      expect(back.blue(1, 1), 99);
    });
  });
}

List<String> observation(ResearchObservation o) =>
    o.featureVector.features.map((f) => f.name).toList();
