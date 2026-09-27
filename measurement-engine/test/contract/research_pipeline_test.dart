import 'dart:io';

import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';
import 'package:test/test.dart';

BadgeGeometry get _geometry => BadgeGeometry.parse(
  File('geometry/demo-badge-v0.geometry.json').readAsStringSync(),
);

Map<String, LinearRgb> get _targets => <String, LinearRgb>{
  for (final entry in demoBadgeColours.entries)
    entry.key: SrgbColor.fromBytes(
      entry.value[0],
      entry.value[1],
      entry.value[2],
    ).toLinear(),
};

const List<String> _fit = <String>[
  'REF-WHITE',
  'REF-RED',
  'REF-GREEN',
  'REF-BLUE',
];
const List<String> _holdout = <String>['REF-BLACK', 'REF-GREY'];

ResearchObservation _observe({
  Illuminant illuminant = Illuminant.warm,
  DataDomain domain = DataDomain.simulated,
}) {
  final geometry = _geometry;
  final homography = placeBadge(
    pixelsPerMm: 16.0,
    translateX: 62,
    translateY: 44,
    rotationRadians: 0.11,
    perspectiveX: 0.00085,
    perspectiveY: 0.00042,
  );
  final image = renderBadge(
    geometry: geometry,
    badgeToImage: homography,
    width: 760,
    height: 500,
    illuminant: illuminant,
  );
  return observe(
    image: image,
    geometry: geometry,
    correspondences: fiducialCorrespondences(geometry, homography),
    dataDomain: domain,
    referenceTargets: _targets,
    fitPatchIds: _fit,
    holdoutPatchIds: _holdout,
  );
}

void main() {
  group('M0A produces observations, never exposures', () {
    test('the observation type has no dose, and no field for one', () {
      final observation = _observe();
      // Enumerated rather than asserted in prose: if a dose field is ever
      // added to this type, this test is where it has to be justified.
      expect(observation.toJson().keys, isNot(contains('dose')));
      expect(observation.toJson().keys, isNot(contains('dose_ppm_h')));
      expect(
        observation.featureVector.toJson().keys,
        isNot(contains('dose_ppm_h')),
      );
    });

    test('converting an observation to a result always refuses', () {
      final observation = _observe();
      final result = refuseForLackOfCalibration(
        observation,
        appVersion: '0.1.0',
        deviceModel: 'test',
      );

      expect(result, isA<Refused>());
      expect(result.status, ResultStatus.unsupportedCalibration);
      expect(result.status.carriesDose, isFalse);
      expect(result.provenance.calibrationModelId, isNull);
      expect(
        result.reasons.map((r) => r.code),
        containsAll(<String>['NO_CALIBRATION_MODEL', 'DATA_DOMAIN']),
      );
    });

    test('the refusal discloses the data domain it came from', () {
      final result = refuseForLackOfCalibration(
        _observe(),
        appVersion: '0.1.0',
        deviceModel: 'test',
      );
      expect(
        result.reasons.map((r) => r.detail).join(' '),
        contains('SIMULATED — NOT A REAL H2S MEASUREMENT'),
      );
    });

    test('a simulated domain may never produce a worker-facing dose', () {
      expect(DataDomain.simulated.mayProduceWorkerFacingDose, isFalse);
      expect(DataDomain.lab.mayProduceWorkerFacingDose, isFalse);
      expect(DataDomain.field.mayProduceWorkerFacingDose, isTrue);
    });

    test('the data domain is required and travels onto the feature vector', () {
      final observation = _observe(domain: DataDomain.simulated);
      expect(observation.dataDomain, DataDomain.simulated);
      expect(observation.featureVector.dataDomain, DataDomain.simulated);
      expect(
        observation.toJson()['disclosure'],
        DataDomain.simulated.disclosure,
      );
    });
  });

  group('what an observation does contain', () {
    test(
      'a versioned feature vector tied to the geometry that produced it',
      () {
        final observation = _observe();
        expect(
          observation.featureVector.definitionVersion,
          featureDefinitionVersion,
        );
        expect(observation.featureVector.geometryVersion, 'demo-badge-v0');
      },
    );

    test('raw features survive alongside corrected ones', () {
      // Directive s13: the uncorrected values must remain so a future
      // correction can be re-derived without re-photographing the badge.
      final observation = _observe();
      expect(observation.featureVector['sensor_linear_r'], isNotNull);
      expect(observation.featureVector['corrected_linear_r'], isNotNull);
      expect(observation.featureVector.rawSensorLinear, isNotNull);
      expect(observation.featureVector.correctedSensorLinear, isNotNull);
      expect(
        observation.featureVector['sensor_linear_r'],
        isNot(closeTo(observation.featureVector['corrected_linear_r']!, 1e-6)),
        reason:
            'under a warm illuminant the correction must actually change '
            'the value',
      );
    });

    test('the held-out reference patches passed on this fixture', () {
      final observation = _observe();
      expect(observation.referenceValidation, isNotNull);
      expect(observation.referenceValidation!.leakedPatchIds, isEmpty);
      expect(observation.referenceValidation!.passed, isTrue);
      expect(observation.referenceValidation!.thresholdIsProvisional, isTrue);
    });

    test('blank-relative features are computed where a blank exists', () {
      final observation = _observe();
      expect(observation.featureVector['sensor_blank_delta_e00'], isNotNull);
      expect(observation.featureVector['sensor_minus_blank_lab_l'], isNotNull);
    });

    test('image quality is reported per axis with no combined score', () {
      final observation = _observe();
      final quality = observation.toJson()['quality']! as Map<String, Object?>;
      expect(quality.keys, contains('laplacian_variance'));
      expect(quality.keys, isNot(contains('score')));
    });

    test('duplicate feature names are rejected', () {
      expect(
        () => FeatureVector(
          definitionVersion: featureDefinitionVersion,
          dataDomain: DataDomain.simulated,
          geometryVersion: 'v',
          features: const <Feature>[Feature('x', 1), Feature('x', 2)],
          rawSensorLinear: const LinearRgb(0, 0, 0),
        ),
        throwsArgumentError,
      );
    });
  });

  group('observation refuses rather than guessing', () {
    test('refuses when the geometry cannot be recovered', () {
      final geometry = _geometry;
      final image = RgbImage.filled(400, 300, 128, 128, 128);
      expect(
        () => observe(
          image: image,
          geometry: geometry,
          // Collinear: no plane is determined.
          correspondences: <Correspondence>[
            for (var i = 0; i < 4; i++)
              Correspondence(
                PointMm(3.0 + 5 * i, 3.0 + 5 * i),
                PointPx(50.0 + 20 * i, 50.0 + 20 * i),
              ),
          ],
          dataDomain: DataDomain.simulated,
          referenceTargets: _targets,
          fitPatchIds: _fit,
          holdoutPatchIds: _holdout,
        ),
        throwsA(isA<ObservationFailure>()),
      );
    });

    test('refuses when a reference target is missing', () {
      final geometry = _geometry;
      final homography = placeBadge(
        pixelsPerMm: 16.0,
        translateX: 62,
        translateY: 44,
      );
      final image = renderBadge(
        geometry: geometry,
        badgeToImage: homography,
        width: 760,
        height: 500,
      );
      final incomplete = Map<String, LinearRgb>.of(_targets)..remove('REF-RED');
      expect(
        () => observe(
          image: image,
          geometry: geometry,
          correspondences: fiducialCorrespondences(geometry, homography),
          dataDomain: DataDomain.simulated,
          referenceTargets: incomplete,
          fitPatchIds: _fit,
          holdoutPatchIds: _holdout,
        ),
        throwsA(isA<ObservationFailure>()),
      );
    });

    test('refuses when a region cannot be read at all', () {
      final geometry = _geometry;
      // Badge placed almost entirely outside the frame.
      final homography = placeBadge(
        pixelsPerMm: 16.0,
        translateX: -600,
        translateY: 44,
      );
      final image = RgbImage.filled(760, 500, 128, 128, 128);
      expect(
        () => observe(
          image: image,
          geometry: geometry,
          correspondences: fiducialCorrespondences(geometry, homography),
          dataDomain: DataDomain.simulated,
          referenceTargets: _targets,
          fitPatchIds: _fit,
          holdoutPatchIds: _holdout,
        ),
        throwsA(isA<ObservationFailure>()),
      );
    });
  });
}
