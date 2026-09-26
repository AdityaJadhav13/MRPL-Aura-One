// MEASUREMENT-INTEGRATION-02 — engine guarantees behind the real worker scan.
//
// Synthetic renders only. These prove the contracts hold, not that a camera
// will satisfy them.

import 'dart:io';

import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';
import 'package:test/test.dart';

BadgeGeometry get _v1 => BadgeGeometry.parse(
  File('geometry/badge-v1.geometry.json').readAsStringSync(),
);

Map<String, LinearRgb> _targets() => <String, LinearRgb>{
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

({RgbImage image, Homography h}) _render({
  Map<String, List<int>> colours = badgeV1Colours,
  double ppmm = 14,
  double tx = 70,
  double ty = 60,
  int w = 1000,
  int hgt = 700,
}) {
  final h = placeBadge(pixelsPerMm: ppmm, translateX: tx, translateY: ty);
  return (
    image: renderBadge(
      geometry: _v1,
      badgeToImage: h,
      width: w,
      height: hgt,
      colours: colours,
    ),
    h: h,
  );
}

AcquisitionQuality _quality({
  Map<String, List<int>> colours = badgeV1Colours,
  AcquisitionLimits limits = const AcquisitionLimits(),
}) {
  final g = _v1;
  final r = _render(colours: colours);
  final still = assessFrame(frame: r.image, geometry: g, limits: limits);
  final observation = observe(
    image: r.image,
    geometry: g,
    correspondences: fiducialCorrespondences(g, r.h),
    dataDomain: DataDomain.lab,
    referenceTargets: _targets(),
    fitPatchIds: _fit,
    holdoutPatchIds: _holdout,
  );
  return assessAcquisition(
    still: still,
    limits: limits,
    geometry: g,
    observation: observation,
  );
}

void main() {
  group('acquisition quality', () {
    test('a clean render is acceptable', () {
      final q = _quality();
      expect(q.acceptable, isTrue, reason: '${q.primaryFailure?.toJson()}');
      expect(q.byId('withheld_references')!.state, CheckState.pass);
    });

    test('never reports a check without a threshold as a pass', () {
      // §49: NOT VALIDATED is not PASS.
      for (final c in _quality().checks) {
        if (c.thresholdStatus == ThresholdStatus.none) {
          expect(c.state, isNot(CheckState.pass), reason: c.id);
          expect(c.blocksMeasurement, isFalse, reason: c.id);
        }
      }
    });

    test('deformation is measured, never gating', () {
      // G-07 stays honest: no rejection limit exists.
      final c = _quality().byId('deformation')!;
      expect(c.blocksMeasurement, isFalse);
      expect(c.state, isNot(CheckState.pass));
    });

    test(
      'collapsed references fail the acquisition as a reference failure',
      () {
        final flat = Map<String, List<int>>.of(badgeV1Colours);
        for (final id in [..._fit, ..._holdout]) {
          flat[id] = <int>[128, 128, 128];
        }
        final q = _quality(colours: flat);
        expect(q.acceptable, isFalse);
        expect(q.primaryFailure!.id, 'reference_fit');
        expect(q.refusalStatus, ResultStatus.referencePatchFailure);
        // The worker gets an instruction, not a metric.
        expect(q.primaryFailure!.workerAction, isNot(contains('ΔE')));
        expect(q.primaryFailure!.workerAction, isNotEmpty);
      },
    );

    test('a failed check carries its worker action; a pass carries none', () {
      final q = _quality(
        limits: const AcquisitionLimits(minimumPixelsPerMm: 30),
      );
      final scale = q.byId('scale')!;
      expect(scale.state, CheckState.fail);
      expect(scale.workerAction, 'Move closer to the badge.');
      expect(q.byId('target_found')!.workerAction, isEmpty);
    });

    test('agrees with assessFrame about readiness, in every case tried', () {
      // The report re-expresses assessFrame's single verdict one dimension at
      // a time. If they ever disagree, one of them has drifted.
      final g = _v1;
      final limitSets = <AcquisitionLimits>[
        const AcquisitionLimits(),
        const AcquisitionLimits(minimumPixelsPerMm: 30),
        const AcquisitionLimits(maximumPixelsPerMm: 5),
        const AcquisitionLimits(maximumCentreOffsetFraction: 0.001),
        const AcquisitionLimits(minimumLaplacianVariance: 1e9),
        const AcquisitionLimits(maximumLumaMean: 0.01),
        const AcquisitionLimits(maximumTiltRatio: 1.0),
      ];
      for (final limits in limitSets) {
        final r = _render();
        final still = assessFrame(frame: r.image, geometry: g, limits: limits);
        final q = assessAcquisition(still: still, limits: limits, geometry: g);
        const acquisitionChecks = <String>{
          'target_found',
          'scale',
          'framing',
          'perspective',
          'glare',
          'highlight_clipping',
          'exposure',
          'focus',
        };
        final reportReady = q.checks
            .where((c) => acquisitionChecks.contains(c.id))
            .every((c) => c.state == CheckState.pass);
        expect(
          reportReady,
          still.state.isReady,
          reason:
              'limits ${limits.minimumPixelsPerMm}…: report says '
              '$reportReady, assessFrame says ${still.state.name}',
        );
      }
    });

    test('serialises every check with its threshold status', () {
      final json = _quality().toJson();
      expect(json['schema'], 'doseband-acquisition-quality/1');
      for (final c in json['checks']! as List) {
        expect((c as Map).containsKey('threshold_status'), isTrue);
      }
    });
  });

  group('calibration activation', () {
    CalibrationPackage complete({
      DataDomain domain = DataDomain.lab,
      CalibrationValidationStatus status =
          CalibrationValidationStatus.validated,
      String? training = 'ds-train',
      String? validation = 'ds-val',
    }) => CalibrationPackage(
      calibrationId: 'C-1',
      version: '1',
      dataDomain: domain,
      geometryVersion: 'badge-v1-research',
      featureDefinitionVersion: featureDefinitionVersion,
      modelType: 'monotonic-lookup',
      createdAt: DateTime.utc(2026, 9, 26),
      formulationId: 'F-1',
      correctionMethod: 'affine3x4',
      batchApplicability: const <String>['B-1'],
      lowerQuantificationBound: 1,
      upperQuantificationBound: 50,
      evidenceReference: 'report-1',
      trainingDatasetReference: training,
      validationDatasetReference: validation,
      validationStatus: status,
    );

    test('a complete, validated package has no activation problems', () {
      // Test-only values. No such package exists for DoseBand.
      expect(calibrationActivationProblems(complete()), isEmpty);
    });

    test('an empty package lists every missing requirement', () {
      final codes = calibrationActivationProblems(
        CalibrationPackage(
          calibrationId: 'C-0',
          version: '0',
          dataDomain: DataDomain.lab,
          geometryVersion: 'badge-v1-research',
          featureDefinitionVersion: featureDefinitionVersion,
          modelType: 'x',
          createdAt: DateTime.utc(2026, 9, 26),
        ),
      ).map((r) => r.code);
      expect(
        codes,
        containsAll(<String>[
          'CALIBRATION_NOT_VALIDATED',
          'CALIBRATION_WITHOUT_EVIDENCE',
          'CALIBRATION_FORMULATION_UNSPECIFIED',
          'CALIBRATION_CORRECTION_METHOD_UNSPECIFIED',
          'CALIBRATION_RANGE_UNDEFINED',
          'CALIBRATION_BATCHES_UNSPECIFIED',
          'CALIBRATION_DATASETS_UNSPECIFIED',
        ]),
      );
    });

    test('a simulated package can never be activated', () {
      expect(
        calibrationActivationProblems(complete(domain: DataDomain.simulated))
            .map((r) => r.code),
        contains('CALIBRATION_FROM_SIMULATED_DATA'),
      );
    });

    test('validating on the training data is refused', () {
      expect(
        calibrationActivationProblems(
          complete(training: 'same', validation: 'same'),
        ).map((r) => r.code),
        contains('CALIBRATION_VALIDATED_ON_TRAINING_DATA'),
      );
    });

    test('a development-status package is not active', () {
      expect(
        calibrationActivationProblems(
          complete(status: CalibrationValidationStatus.development),
        ).map((r) => r.code),
        contains('CALIBRATION_NOT_VALIDATED'),
      );
    });
  });

  group('equivalent time-average concentration', () {
    Provenance prov() => const Provenance(
      algorithmVersion: 'test',
      geometryVersion: 'test',
      calibrationModelId: 'TEST',
      referenceProfileId: null,
      appVersion: 'test',
      deviceModel: 'test',
    );

    test('is D / T, labelled as a time average', () {
      // Hand-built Valid, test-only: no calibration produces one.
      final valid = Valid(
        dose: const Dose.ppmHours(8),
        uncertainty: const Uncertainty(halfWidth: 1, basis: 'test-only'),
        coverage: const Duration(hours: 4),
        provenance: prov(),
      );
      final c = equivalentAverageConcentration(
        valid,
        const Duration(hours: 4),
      )!;
      expect(c.ppm, closeTo(2.0, 1e-12));
      expect(c.label, contains('time-average'));
      expect(c.label.toLowerCase(), isNot(contains('current')));
      expect(c.label.toLowerCase(), isNot(contains('instant')));
    });

    test('is absent for any refusal', () {
      final refused = const NoCalibration().interpret(
        observe(
          image: _render().image,
          geometry: _v1,
          correspondences: fiducialCorrespondences(_v1, _render().h),
          dataDomain: DataDomain.lab,
          referenceTargets: _targets(),
          fitPatchIds: _fit,
          holdoutPatchIds: _holdout,
        ),
        appVersion: 't',
        deviceModel: 't',
      );
      expect(
        equivalentAverageConcentration(refused, const Duration(hours: 8)),
        isNull,
      );
    });

    test('is absent without a trusted duration', () {
      final valid = Valid(
        dose: const Dose.ppmHours(8),
        uncertainty: const Uncertainty(halfWidth: 1, basis: 'test-only'),
        coverage: const Duration(hours: 4),
        provenance: prov(),
      );
      expect(equivalentAverageConcentration(valid, null), isNull);
      expect(equivalentAverageConcentration(valid, Duration.zero), isNull);
    });
  });

  group('calibration dataset row', () {
    test('a row without a reference instrument has no usable label', () {
      const row = CalibrationRow(
        sampleId: 's',
        specimenId: 'P0-X1-01',
        captureId: 'c',
        trueIntegratedDosePpmH: 4,
      );
      // A dose with no instrument behind it is not a label. §56.
      expect(row.hasReferenceLabel, isFalse);
    });

    test('unmeasured fields serialise as null, never zero', () {
      final json = const CalibrationRow(
        sampleId: 's',
        specimenId: 'P0-X0-01',
        captureId: 'c',
      ).toJson();
      for (final k in <String>[
        'true_integrated_dose_ppm_h',
        'temperature_c',
        'relative_humidity_percent',
        'airflow_m_per_s',
        'exposure_duration_seconds',
      ]) {
        expect(json[k], isNull, reason: k);
      }
    });
  });
}
