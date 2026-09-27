import 'dart:convert';
import 'dart:io';

import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

/// Verifies that this engine still reproduces `golden-vectors/vectors.json`.
///
/// The same file is checked from the other side by
/// `golden-vectors/check_parity.py`. Because both stacks are compared against
/// one authoritative set of expected values, agreement with the file implies
/// agreement with each other — and a change to either that moves a number
/// fails here, in CI, rather than showing up much later as an unexplained bias
/// in a fitted model.
///
/// If a value here legitimately changes, the feature definition changed with
/// it: regenerate the vectors **and** bump `featureDefinitionVersion` in the
/// same commit, so that a calibration model fitted against the old arithmetic
/// is refused rather than quietly misapplied.
const String _goldenDirectory = 'golden-vectors';

Map<String, Object?> get _vectors =>
    jsonDecode(File('$_goldenDirectory/vectors.json').readAsStringSync())
        as Map<String, Object?>;

List<double> _doubles(Object? value) =>
    (value! as List).cast<num>().map((n) => n.toDouble()).toList();

void main() {
  final vectors = _vectors;
  final tolerances = vectors['tolerances']! as Map<String, Object?>;
  final cases = vectors['cases']! as Map<String, Object?>;
  final fixture = vectors['fixture']! as Map<String, Object?>;

  double tolerance(String name) => (tolerances[name]! as num).toDouble();

  void expectClose(
    List<double> actual,
    List<double> expected,
    double tol,
    String label,
  ) {
    expect(actual.length, expected.length, reason: '$label length');
    for (var i = 0; i < actual.length; i++) {
      expect(actual[i], closeTo(expected[i], tol), reason: '$label[$i]');
    }
  }

  group('golden vectors: contract metadata', () {
    test('schema and feature definition match this build', () {
      expect(vectors['schema'], 'doseband-golden-vectors/1');
      expect(
        vectors['feature_definition_version'],
        featureDefinitionVersion,
        reason:
            'the vectors were generated against a different feature '
            'definition; regenerate them and bump the version together',
      );
    });

    test('the fixture is declared simulated', () {
      expect(vectors['data_domain'], DataDomain.simulated.name);
      expect(vectors['disclosure'], DataDomain.simulated.disclosure);
    });
  });

  group('golden vectors: scalar colour', () {
    test('sRGB linearisation', () {
      for (final c
          in (cases['srgb_linearise']! as List).cast<Map<String, Object?>>()) {
        expect(
          linearise((c['input']! as num).toDouble()),
          closeTo(
            (c['expected']! as num).toDouble(),
            tolerance('scalar_absolute'),
          ),
        );
      }
    });

    test('sRGB delinearisation', () {
      for (final c
          in (cases['srgb_delinearise']! as List)
              .cast<Map<String, Object?>>()) {
        expect(
          delinearise((c['input']! as num).toDouble()),
          closeTo(
            (c['expected']! as num).toDouble(),
            tolerance('scalar_absolute'),
          ),
        );
      }
    });
  });

  group('golden vectors: colour space chain', () {
    test('sRGB to linear to XYZ to CIELAB', () {
      final tol = tolerance('colour_absolute');
      for (final c
          in (cases['srgb_to_linear_to_xyz_to_lab']! as List)
              .cast<Map<String, Object?>>()) {
        final srgb = _doubles(c['srgb']);
        final linear = SrgbColor(srgb[0], srgb[1], srgb[2]).toLinear();
        final xyz = linear.toXyz();
        final lab = xyz.toLab();

        expectClose(
          <double>[linear.r, linear.g, linear.b],
          _doubles(c['linear']),
          tol,
          'linear',
        );
        expectClose(
          <double>[xyz.x, xyz.y, xyz.z],
          _doubles(c['xyz']),
          tol,
          'xyz',
        );
        expectClose(
          <double>[lab.lStar, lab.aStar, lab.bStar],
          _doubles(c['lab']),
          tol,
          'lab',
        );
      }
    });

    test('colour difference', () {
      final tol = tolerance('delta_e_absolute');
      for (final c
          in (cases['delta_e']! as List).cast<Map<String, Object?>>()) {
        final l1 = _doubles(c['lab1']);
        final l2 = _doubles(c['lab2']);
        final a = Lab(l1[0], l1[1], l1[2]);
        final b = Lab(l2[0], l2[1], l2[2]);
        expect(
          deltaE76(a, b),
          closeTo((c['delta_e76']! as num).toDouble(), tol),
        );
        expect(
          deltaE2000(a, b),
          closeTo((c['delta_e00']! as num).toDouble(), tol),
        );
      }
    });
  });

  group('golden vectors: QRsens normalisation', () {
    test('both published forms', () {
      final qr = cases['qrsens_normalisation']! as Map<String, Object?>;
      final black = _doubles(qr['black']);
      final white = _doubles(qr['white']);
      final tol = tolerance('colour_absolute');

      for (final entry in <String, BlackWhiteForm>{
        'equation_1': BlackWhiteForm.qrsensEquation1,
        'equation_2': BlackWhiteForm.qrsensEquation2,
      }.entries) {
        final normaliser = BlackWhiteNormaliser(
          form: entry.value,
          black: LinearRgb(black[0], black[1], black[2]),
          white: LinearRgb(white[0], white[1], white[2]),
        );
        for (final c in (qr[entry.key]! as List).cast<Map<String, Object?>>()) {
          final s = _doubles(c['sensor']);
          final result = normaliser.apply(LinearRgb(s[0], s[1], s[2]));
          expect(result.isOk, c['ok']);
          if (result.isOk) {
            expectClose(
              <double>[result.value!.r, result.value!.g, result.value!.b],
              _doubles(c['expected']),
              tol,
              '${entry.key} corrected',
            );
          }
        }
      }
    });
  });

  group('golden vectors: geometry', () {
    test('homography recovered from the stored correspondences', () {
      final hom = cases['homography']! as Map<String, Object?>;
      final tol = tolerance('homography_absolute');

      final correspondences = <Correspondence>[
        for (final c
            in (hom['correspondences']! as List).cast<Map<String, Object?>>())
          Correspondence(
            PointMm(_doubles(c['badge_mm'])[0], _doubles(c['badge_mm'])[1]),
            PointPx(_doubles(c['image_px'])[0], _doubles(c['image_px'])[1]),
          ),
      ];

      final estimate = estimateHomography(correspondences);
      expect(estimate.isOk, isTrue);

      final expectedRows = (hom['expected_matrix']! as List)
          .map((r) => _doubles(r))
          .toList();
      for (var r = 0; r < 3; r++) {
        expectClose(
          estimate.homography!.matrix.row(r),
          expectedRows[r],
          tol,
          'homography row $r',
        );
      }
      expect(
        estimate.homography!.reprojectionRmsPx(correspondences),
        closeTo((hom['expected_reprojection_rms_px']! as num).toDouble(), tol),
      );
    });
  });

  group('golden vectors: M0B mathematics', () {
    test('correction conditioning', () {
      final tol = tolerance('statistics_absolute');
      final all = cases['correction_conditioning']! as Map<String, Object?>;
      for (final entry in all.entries) {
        final expected = entry.value! as Map<String, Object?>;
        final measured = (expected['measured']! as List)
            .map((r) => _doubles(r))
            .toList();
        final patches = <ReferencePatch>[
          for (var i = 0; i < measured.length; i++)
            ReferencePatch(
              id: 'P$i',
              measured: LinearRgb(
                measured[i][0],
                measured[i][1],
                measured[i][2],
              ),
              target: LinearRgb(measured[i][0], measured[i][1], measured[i][2]),
            ),
        ];
        final fit = fitCorrection(patches);
        final conditioning = fit.conditioning!;

        expectClose(
          conditioning.eigenvalues,
          _doubles(expected['expected_eigenvalues']),
          tol,
          '${entry.key} eigenvalues',
        );
        expect(
          conditioning.effectiveRank,
          expected['expected_effective_rank'],
          reason: '${entry.key} rank',
        );
        expect(
          conditioning.isFullRank,
          expected['expected_is_full_rank'],
          reason: '${entry.key} full rank',
        );
        expect(
          fit.isOk,
          expected['expected_accepted'],
          reason: '${entry.key} accepted',
        );

        final expectedCondition = expected['expected_condition_number'];
        if (expectedCondition == null) {
          expect(
            conditioning.conditionNumber.isFinite,
            isFalse,
            reason:
                '${entry.key}: null means not finite, which is the '
                'finding',
          );
        } else {
          final value = (expectedCondition as num).toDouble();
          expect(
            conditioning.conditionNumber,
            closeTo(value, value.abs() * 1e-9 + tol),
          );
        }
      }
    });

    test('geometry residual magnitudes', () {
      final geometry = cases['geometry_residuals']! as Map<String, Object?>;
      final expectedMm = (geometry['expected_mm']! as List)
          .map((r) => _doubles(r))
          .toList();
      final predicted = (geometry['predicted_px']! as List)
          .map((r) => _doubles(r))
          .toList();
      final observed = (geometry['observed_px']! as List)
          .map((r) => _doubles(r))
          .toList();

      final actual = <double>[
        for (var i = 0; i < expectedMm.length; i++)
          ControlPointResidual(
            fiducialId: 'C$i',
            expectedMm: PointMm(expectedMm[i][0], expectedMm[i][1]),
            predictedPx: PointPx(predicted[i][0], predicted[i][1]),
            observedPx: PointPx(observed[i][0], observed[i][1]),
          ).magnitudePx,
      ];
      expectClose(
        actual,
        _doubles(geometry['expected_magnitudes_px']),
        tolerance('homography_absolute'),
        'residual magnitudes',
      );
    });

    test('monotonicity of the Carpenter b* series', () {
      final mono = cases['monotonicity']! as Map<String, Object?>;
      final tol = tolerance('statistics_absolute');
      final doses = _doubles(mono['doses']);
      final means = _doubles(mono['means']);
      final offset = (mono['replicate_offset']! as num).toDouble();

      final report = analyseMonotonicity(<DoseLevel>[
        for (var i = 0; i < doses.length; i++)
          DoseLevel(
            dose: doses[i],
            responses: <double>[means[i] - offset, means[i], means[i] + offset],
          ),
      ]);

      expect(
        report.spearmanRho,
        closeTo((mono['expected_spearman_rho']! as num).toDouble(), tol),
      );
      expect(report.direction.name, mono['expected_direction']);
      expect(
        report.significantReversals,
        mono['expected_significant_reversals'],
      );
      expect(
        report.largestReversal,
        closeTo((mono['expected_largest_reversal']! as num).toDouble(), tol),
      );
      final domain = _doubles(mono['expected_monotonic_domain']);
      expect(report.monotonicDomain.$1, closeTo(domain[0], tol));
      expect(report.monotonicDomain.$2, closeTo(domain[1], tol));

      final expectedSeparation = mono['expected_minimum_separation_ratio'];
      if (expectedSeparation == null) {
        expect(report.minimumSeparationRatio.isFinite, isFalse);
      } else {
        expect(
          report.minimumSeparationRatio,
          closeTo((expectedSeparation as num).toDouble(), tol),
        );
      }
    });
  });

  group('golden vectors: the shared fixture image', () {
    late RgbImage image;
    late BadgeGeometry geometry;
    late Homography homography;
    late Map<String, RoiSample> samples;

    setUpAll(() {
      image = Ppm.decode(
        File('$_goldenDirectory/${fixture['image']}').readAsBytesSync(),
      );
      geometry = BadgeGeometry.fromJson(
        fixture['geometry']! as Map<String, Object?>,
      );

      final hom = cases['homography']! as Map<String, Object?>;
      final correspondences = <Correspondence>[
        for (final c
            in (hom['correspondences']! as List).cast<Map<String, Object?>>())
          Correspondence(
            PointMm(_doubles(c['badge_mm'])[0], _doubles(c['badge_mm'])[1]),
            PointPx(_doubles(c['image_px'])[0], _doubles(c['image_px'])[1]),
          ),
      ];
      homography = estimateHomography(correspondences).homography!;

      samples = <String, RoiSample>{
        for (final id
            in (cases['roi_statistics']! as Map<String, Object?>).keys)
          id: sampleRoi(
            image: image,
            badgeToImage: homography,
            roi: geometry.roiById(id)!,
            samplesPerMm: (fixture['samples_per_mm']! as num).toDouble(),
            trimFraction: (fixture['trim_fraction']! as num).toDouble(),
          ),
      };
    });

    test('the fixture image has the declared dimensions', () {
      expect(image.width, fixture['width']);
      expect(image.height, fixture['height']);
    });

    test('ROI statistics', () {
      final tol = tolerance('statistics_absolute');
      final expectedAll = cases['roi_statistics']! as Map<String, Object?>;
      for (final entry in expectedAll.entries) {
        final expected = entry.value! as Map<String, Object?>;
        final sample = samples[entry.key]!;
        expect(
          sample.requestedSamples,
          expected['requested_samples'],
          reason: '${entry.key} requested',
        );
        expect(
          sample.usedSamples,
          expected['used_samples'],
          reason: '${entry.key} used',
        );
        expectClose(
          <double>[
            sample.trimmedMeanLinear.r,
            sample.trimmedMeanLinear.g,
            sample.trimmedMeanLinear.b,
          ],
          _doubles(expected['trimmed_mean_linear']),
          tol,
          '${entry.key} trimmed mean',
        );
        expectClose(
          <double>[sample.lab.lStar, sample.lab.aStar, sample.lab.bStar],
          _doubles(expected['lab']),
          tol,
          '${entry.key} lab',
        );
        expectClose(
          <double>[
            sample.linearR.standardDeviation,
            sample.linearG.standardDeviation,
            sample.linearB.standardDeviation,
          ],
          _doubles(expected['standard_deviation_linear']),
          tol,
          '${entry.key} sd',
        );
      }
    });

    test('reference correction and held-out residuals', () {
      final correction = cases['reference_correction']! as Map<String, Object?>;
      final tol = tolerance('statistics_absolute');
      final printed = fixture['printed_colours_srgb8']! as Map<String, Object?>;

      LinearRgb targetOf(String id) {
        final c = (printed[id]! as List).cast<num>();
        return SrgbColor.fromBytes(
          c[0].toInt(),
          c[1].toInt(),
          c[2].toInt(),
        ).toLinear();
      }

      ReferencePatch patch(String id) => ReferencePatch(
        id: id,
        measured: samples[id]!.trimmedMeanLinear,
        target: targetOf(id),
      );

      final fit = fitCorrection(<ReferencePatch>[
        for (final id in (fixture['fit_patch_ids']! as List).cast<String>())
          patch(id),
      ]);
      expect(fit.isOk, isTrue);
      expect(fit.correction!.form.name, correction['form']);

      final expectedRows = (correction['expected_matrix']! as List)
          .map((r) => _doubles(r))
          .toList();
      for (var r = 0; r < expectedRows.length; r++) {
        expectClose(
          fit.correction!.matrix.row(r),
          expectedRows[r],
          tol,
          'correction row $r',
        );
      }

      final corrected = fit.correction!.apply(samples['A1']!.trimmedMeanLinear);
      expectClose(
        <double>[corrected.r, corrected.g, corrected.b],
        _doubles(correction['expected_corrected_sensor_a1']),
        tol,
        'corrected A1',
      );

      final validation = validateCorrection(
        correction: fit.correction!,
        holdoutPatches: <ReferencePatch>[
          for (final id
              in (fixture['holdout_patch_ids']! as List).cast<String>())
            patch(id),
        ],
      );
      final expectedResiduals =
          (correction['expected_holdout_residuals']! as List)
              .cast<Map<String, Object?>>();
      expect(validation.residuals.length, expectedResiduals.length);
      for (var i = 0; i < expectedResiduals.length; i++) {
        expect(
          validation.residuals[i].patchId,
          expectedResiduals[i]['patch_id'],
        );
        expect(
          validation.residuals[i].deltaE00,
          closeTo(
            (expectedResiduals[i]['delta_e00']! as num).toDouble(),
            tolerance('delta_e_absolute'),
          ),
        );
      }
      expect(
        validation.maximumDeltaE00,
        closeTo(
          (correction['expected_maximum_delta_e00']! as num).toDouble(),
          tolerance('delta_e_absolute'),
        ),
      );

      // And the correction actually did its job on this fixture.
      expect(validation.passed, isTrue);
      expect(validation.leakedPatchIds, isEmpty);
    });

    test('image quality', () {
      final expected = cases['image_quality']! as Map<String, Object?>;
      final tol = tolerance('quality_absolute');
      final quality = measureImageQuality(image);

      expect(
        quality.laplacianVariance,
        closeTo(
          (expected['expected_laplacian_variance']! as num).toDouble(),
          tol,
        ),
      );
      expect(
        quality.highClipFraction,
        closeTo(
          (expected['expected_high_clip_fraction']! as num).toDouble(),
          tol,
        ),
      );
      expect(
        quality.lowClipFraction,
        closeTo(
          (expected['expected_low_clip_fraction']! as num).toDouble(),
          tol,
        ),
      );
      expect(
        quality.specularFraction,
        closeTo(
          (expected['expected_specular_fraction']! as num).toDouble(),
          tol,
        ),
      );
      expect(
        quality.luma.mean,
        closeTo((expected['expected_luma_mean']! as num).toDouble(), tol),
      );
      expect(
        quality.luma.median,
        closeTo((expected['expected_luma_median']! as num).toDouble(), tol),
      );
    });
  });
}
