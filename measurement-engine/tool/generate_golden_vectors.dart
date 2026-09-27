// Regenerates the cross-language golden vectors in `golden-vectors/`.
//
//   dart run tool/generate_golden_vectors.dart
//
// The Dart engine produces the expected values and the Python research stack
// must reproduce them. That ordering is deliberate and its limits are stated
// in golden-vectors/README.md: for the colour-difference cases the expected
// values carry independent provenance (the Sharma et al. published test set),
// so agreement there is corroboration rather than circularity. For the
// remaining cases the file is a *contract* — its job is to make an
// unannounced divergence between the two stacks impossible, not to prove
// either one correct on its own.
//
// Regenerating this file changes the contract. If a value moves, something in
// the feature definition moved with it, and `featureDefinitionVersion` must be
// bumped in the same commit.

import 'dart:convert';
import 'dart:io';

import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

const String _outputDirectory = 'golden-vectors';
const String _geometryPath = 'geometry/demo-badge-v0.geometry.json';

/// Patch ids used to fit the colour correction. Three chromatic plus the
/// white; the neutrals that are withheld cannot be in here.
const List<String> fitPatchIds = <String>[
  'REF-WHITE',
  'REF-RED',
  'REF-GREEN',
  'REF-BLUE',
];

/// Patch ids withheld from the fit, used only to test it.
const List<String> holdoutPatchIds = <String>['REF-BLACK', 'REF-GREY'];

/// The fixture scene: a tilted, rotated badge under a warm illuminant.
///
/// Tilted and rotated so the homography is a genuine projective transform
/// rather than a scale; warm so the colour correction has something real to
/// remove.
Homography get fixtureHomography => placeBadge(
  pixelsPerMm: 16.0,
  translateX: 62.0,
  translateY: 44.0,
  rotationRadians: 0.11,
  perspectiveX: 0.00085,
  perspectiveY: 0.00042,
);

const int fixtureWidth = 760;
const int fixtureHeight = 500;

void main() {
  final geometry = BadgeGeometry.parse(File(_geometryPath).readAsStringSync());
  final problems = geometry.validate();
  if (problems.isNotEmpty) {
    stderr.writeln('demo geometry is invalid: $problems');
    exit(1);
  }

  final directory = Directory(_outputDirectory);
  directory.createSync(recursive: true);

  // ---- the fixture image ----------------------------------------------
  final image = renderBadge(
    geometry: geometry,
    badgeToImage: fixtureHomography,
    width: fixtureWidth,
    height: fixtureHeight,
    illuminant: Illuminant.warm,
  );
  File('$_outputDirectory/demo-badge-v0.ppm')
      .writeAsBytesSync(Ppm.encode(image));

  // ---- scalar colour cases --------------------------------------------
  const scalarInputs = <double>[
    0.0,
    0.01,
    0.04045,
    0.05,
    0.2,
    0.5,
    0.735,
    0.9,
    1.0,
  ];

  const srgbTriples = <List<double>>[
    <double>[0.0, 0.0, 0.0],
    <double>[1.0, 1.0, 1.0],
    <double>[0.5, 0.5, 0.5],
    <double>[1.0, 0.0, 0.0],
    <double>[0.0, 1.0, 0.0],
    <double>[0.0, 0.0, 1.0],
    <double>[0.784313725490196, 0.35294117647058826, 0.6274509803921569],
    <double>[0.10196078431372549, 0.6666666666666666, 0.3137254901960784],
  ];

  // ---- the image-derived cases ----------------------------------------
  final correspondences = fiducialCorrespondences(geometry, fixtureHomography);
  final estimate = estimateHomography(correspondences);
  if (!estimate.isOk) {
    stderr.writeln(
      'fixture homography could not be recovered: '
      '${estimate.rejection} ${estimate.detail}',
    );
    exit(1);
  }
  final recovered = estimate.homography!;

  final roiIds = <String>['A1', 'B', ...fitPatchIds, ...holdoutPatchIds];
  final samples = <String, RoiSample>{
    for (final id in roiIds)
      id: sampleRoi(
        image: image,
        badgeToImage: recovered,
        roi: geometry.roiById(id)!,
      ),
  };

  LinearRgb printed(String id) {
    final c = demoBadgeColours[id]!;
    return SrgbColor.fromBytes(c[0], c[1], c[2]).toLinear();
  }

  ReferencePatch patch(String id) => ReferencePatch(
    id: id,
    measured: samples[id]!.trimmedMeanLinear,
    target: printed(id),
  );

  final fit = fitCorrection(<ReferencePatch>[
    for (final id in fitPatchIds) patch(id),
  ]);
  if (!fit.isOk) {
    stderr.writeln('fixture correction could not be fitted: ${fit.detail}');
    exit(1);
  }
  final validation = validateCorrection(
    correction: fit.correction!,
    holdoutPatches: <ReferencePatch>[
      for (final id in holdoutPatchIds) patch(id),
    ],
  );

  final correctedSensor = fit.correction!.apply(
    samples['A1']!.trimmedMeanLinear,
  );
  final quality = measureImageQuality(image);

  // ---- assemble --------------------------------------------------------
  final vectors = <String, Object?>{
    'schema': 'doseband-golden-vectors/1',
    'feature_definition_version': featureDefinitionVersion,
    'generated_by': 'packages/measurement/tool/generate_golden_vectors.dart',
    'data_domain': DataDomain.simulated.name,
    'disclosure': DataDomain.simulated.disclosure,
    'tolerances': <String, Object?>{
      'scalar_absolute': 1e-12,
      'colour_absolute': 1e-10,
      'delta_e_absolute': 1e-10,
      'homography_absolute': 1e-8,
      'statistics_absolute': 1e-10,
      'quality_absolute': 1e-10,
    },
    'fixture': <String, Object?>{
      'image': 'demo-badge-v0.ppm',
      'width': fixtureWidth,
      'height': fixtureHeight,
      'geometry': jsonDecode(File(_geometryPath).readAsStringSync()),
      'illuminant': <String, Object?>{
        'name': Illuminant.warm.name,
        'gain_r': Illuminant.warm.gainR,
        'gain_g': Illuminant.warm.gainG,
        'gain_b': Illuminant.warm.gainB,
      },
      'printed_colours_srgb8': demoBadgeColours,
      'samples_per_mm': 20.0,
      'trim_fraction': 0.1,
      'fit_patch_ids': fitPatchIds,
      'holdout_patch_ids': holdoutPatchIds,
    },
    'cases': <String, Object?>{
      'srgb_linearise': <Object?>[
        for (final v in scalarInputs)
          <String, Object?>{'input': v, 'expected': linearise(v)},
      ],
      'srgb_delinearise': <Object?>[
        for (final v in scalarInputs)
          <String, Object?>{'input': v, 'expected': delinearise(v)},
      ],
      'srgb_to_linear_to_xyz_to_lab': <Object?>[
        for (final t in srgbTriples)
          () {
            final linear = SrgbColor(t[0], t[1], t[2]).toLinear();
            final xyz = linear.toXyz();
            final lab = xyz.toLab();
            return <String, Object?>{
              'srgb': t,
              'linear': <double>[linear.r, linear.g, linear.b],
              'xyz': <double>[xyz.x, xyz.y, xyz.z],
              'lab': <double>[lab.lStar, lab.aStar, lab.bStar],
            };
          }(),
      ],
      'delta_e': <Object?>[
        for (var i = 0; i + 1 < srgbTriples.length; i++)
          () {
            final a = SrgbColor(
              srgbTriples[i][0],
              srgbTriples[i][1],
              srgbTriples[i][2],
            ).toLinear().toXyz().toLab();
            final b = SrgbColor(
              srgbTriples[i + 1][0],
              srgbTriples[i + 1][1],
              srgbTriples[i + 1][2],
            ).toLinear().toXyz().toLab();
            return <String, Object?>{
              'lab1': <double>[a.lStar, a.aStar, a.bStar],
              'lab2': <double>[b.lStar, b.aStar, b.bStar],
              'delta_e76': deltaE76(a, b),
              'delta_e00': deltaE2000(a, b),
            };
          }(),
      ],
      'qrsens_normalisation': () {
        const black = LinearRgb(0.021, 0.019, 0.023);
        const white = LinearRgb(0.712, 0.735, 0.690);
        const sensors = <List<double>>[
          <double>[0.310, 0.118, 0.352],
          <double>[0.500, 0.500, 0.500],
          <double>[0.021, 0.019, 0.023],
          <double>[0.712, 0.735, 0.690],
        ];
        List<Object?> run(BlackWhiteForm form) {
          final n = BlackWhiteNormaliser(
            form: form,
            black: black,
            white: white,
          );
          return <Object?>[
            for (final s in sensors)
              () {
                final r = n.apply(LinearRgb(s[0], s[1], s[2]));
                return <String, Object?>{
                  'sensor': s,
                  'ok': r.isOk,
                  'expected': r.isOk
                      ? <double>[r.value!.r, r.value!.g, r.value!.b]
                      : null,
                };
              }(),
          ];
        }

        return <String, Object?>{
          'black': <double>[black.r, black.g, black.b],
          'white': <double>[white.r, white.g, white.b],
          'equation_1': run(BlackWhiteForm.qrsensEquation1),
          'equation_2': run(BlackWhiteForm.qrsensEquation2),
        };
      }(),
      'homography': <String, Object?>{
        'correspondences': <Object?>[
          for (final c in correspondences)
            <String, Object?>{
              'badge_mm': <double>[c.badge.x, c.badge.y],
              'image_px': <double>[c.image.x, c.image.y],
            },
        ],
        'expected_matrix': recovered.matrix.toRows(),
        'expected_reprojection_rms_px': recovered.reprojectionRmsPx(
          correspondences,
        ),
      },
      'roi_statistics': <String, Object?>{
        for (final entry in samples.entries)
          entry.key: <String, Object?>{
            'requested_samples': entry.value.requestedSamples,
            'used_samples': entry.value.usedSamples,
            'trimmed_mean_linear': <double>[
              entry.value.trimmedMeanLinear.r,
              entry.value.trimmedMeanLinear.g,
              entry.value.trimmedMeanLinear.b,
            ],
            'median_linear': <double>[
              entry.value.medianLinear.r,
              entry.value.medianLinear.g,
              entry.value.medianLinear.b,
            ],
            'lab': <double>[
              entry.value.lab.lStar,
              entry.value.lab.aStar,
              entry.value.lab.bStar,
            ],
            'standard_deviation_linear': <double>[
              entry.value.linearR.standardDeviation,
              entry.value.linearG.standardDeviation,
              entry.value.linearB.standardDeviation,
            ],
          },
      },
      'reference_correction': <String, Object?>{
        'form': fit.correction!.form.name,
        'expected_matrix': fit.correction!.matrix.toRows(),
        'expected_corrected_sensor_a1': <double>[
          correctedSensor.r,
          correctedSensor.g,
          correctedSensor.b,
        ],
        'expected_holdout_residuals': <Object?>[
          for (final r in validation.residuals)
            <String, Object?>{
              'patch_id': r.patchId,
              'delta_e00': r.deltaE00,
              'delta_e76': r.deltaE76,
            },
        ],
        'expected_maximum_delta_e00': validation.maximumDeltaE00,
      },
      // ---- M0B additions -------------------------------------------------
      'correction_conditioning': () {
        // Three patch sets: well conditioned, all-neutral (rank deficient),
        // and near-collinear (ill conditioned). The conditioning numbers must
        // agree across languages, because they are what decides whether a
        // correction is applied at all.
        const sets = <String, List<List<double>>>{
          'spanning': <List<double>>[
            <double>[0.6038, 0.6038, 0.6038],
            <double>[0.5271, 0.0452, 0.0343],
            <double>[0.0452, 0.3419, 0.0802],
            <double>[0.0423, 0.0722, 0.4793],
          ],
          'all_neutral': <List<double>>[
            <double>[0.0091, 0.0091, 0.0091],
            <double>[0.0637, 0.0637, 0.0637],
            <double>[0.2159, 0.2159, 0.2159],
            <double>[0.6038, 0.6038, 0.6038],
          ],
          'near_collinear': <List<double>>[
            <double>[0.3000000, 0.3000000, 0.3000000],
            <double>[0.3500001, 0.3500000, 0.3499999],
            <double>[0.4000002, 0.4000000, 0.3999998],
            <double>[0.4500003, 0.4500000, 0.4499997],
          ],
        };
        final out = <String, Object?>{};
        for (final entry in sets.entries) {
          final patches = <ReferencePatch>[
            for (var i = 0; i < entry.value.length; i++)
              ReferencePatch(
                id: 'P$i',
                measured: LinearRgb(
                  entry.value[i][0],
                  entry.value[i][1],
                  entry.value[i][2],
                ),
                target: LinearRgb(
                  entry.value[i][0],
                  entry.value[i][1],
                  entry.value[i][2],
                ),
              ),
          ];
          final fit = fitCorrection(patches);
          out[entry.key] = <String, Object?>{
            'measured': entry.value,
            'expected_eigenvalues': fit.conditioning!.eigenvalues,
            // JSON has no representation for infinity, and a rank-deficient
            // set genuinely produces one. Null means "not finite", which is
            // itself the finding.
            'expected_condition_number':
                fit.conditioning!.conditionNumber.isFinite
                ? fit.conditioning!.conditionNumber
                : null,
            'expected_effective_rank': fit.conditioning!.effectiveRank,
            'expected_is_full_rank': fit.conditioning!.isFullRank,
            'expected_accepted': fit.isOk,
          };
        }
        return out;
      }(),
      'geometry_residuals': () {
        // Residual statistics over withheld control points. Supplied as bare
        // predicted/observed pairs: blob matching is detection, not
        // arithmetic, and only the arithmetic has to agree across languages.
        const expectedMm = <List<double>>[
          <double>[30.0, 8.0],
          <double>[30.0, 32.0],
          <double>[8.0, 20.0],
          <double>[52.0, 20.0],
          <double>[16.0, 22.0],
          <double>[44.0, 22.0],
        ];
        const predictedPx = <List<double>>[
          <double>[420.0, 112.0],
          <double>[420.0, 448.0],
          <double>[112.0, 280.0],
          <double>[728.0, 280.0],
          <double>[224.0, 308.0],
          <double>[616.0, 308.0],
        ];
        const observedPx = <List<double>>[
          <double>[421.7, 113.4],
          <double>[418.9, 446.2],
          <double>[112.3, 280.4],
          <double>[727.6, 279.5],
          <double>[225.9, 309.8],
          <double>[614.4, 306.9],
        ];
        final residuals = <ControlPointResidual>[
          for (var i = 0; i < expectedMm.length; i++)
            ControlPointResidual(
              fiducialId: 'C$i',
              expectedMm: PointMm(expectedMm[i][0], expectedMm[i][1]),
              predictedPx: PointPx(predictedPx[i][0], predictedPx[i][1]),
              observedPx: PointPx(observedPx[i][0], observedPx[i][1]),
            ),
        ];
        return <String, Object?>{
          'expected_mm': expectedMm,
          'predicted_px': predictedPx,
          'observed_px': observedPx,
          'expected_magnitudes_px': <double>[
            for (final r in residuals) r.magnitudePx,
          ],
        };
      }(),
      'monotonicity': () {
        // The Carpenter et al. 2017 CIELAB b* series: rises, falls from 30 to
        // 250 ppb, jumps at 400, then rises. Finding F-4.
        const doses = <double>[
          0,
          30,
          60,
          100,
          150,
          250,
          400,
          600,
          1000,
          1750,
          2500,
        ];
        const means = <double>[
          -15.72,
          -10.92,
          -11.44,
          -12.03,
          -12.49,
          -13.48,
          -1.63,
          -1.19,
          -0.46,
          0.81,
          1.78,
        ];
        const spread = 0.15;
        final levels = <DoseLevel>[
          for (var i = 0; i < doses.length; i++)
            DoseLevel(
              dose: doses[i],
              responses: <double>[
                means[i] - spread,
                means[i],
                means[i] + spread,
              ],
            ),
        ];
        final report = analyseMonotonicity(levels);
        return <String, Object?>{
          'doses': doses,
          'means': means,
          'replicate_offset': spread,
          'expected_spearman_rho': report.spearmanRho,
          'expected_direction': report.direction.name,
          'expected_significant_reversals': report.significantReversals,
          'expected_largest_reversal': report.largestReversal,
          'expected_monotonic_domain': <double>[
            report.monotonicDomain.$1,
            report.monotonicDomain.$2,
          ],
          'expected_minimum_separation_ratio':
              report.minimumSeparationRatio.isFinite
              ? report.minimumSeparationRatio
              : null,
        };
      }(),
      'image_quality': <String, Object?>{
        'expected_laplacian_variance': quality.laplacianVariance,
        'expected_high_clip_fraction': quality.highClipFraction,
        'expected_low_clip_fraction': quality.lowClipFraction,
        'expected_specular_fraction': quality.specularFraction,
        'expected_luma_mean': quality.luma.mean,
        'expected_luma_median': quality.luma.median,
      },
    },
  };

  File('$_outputDirectory/vectors.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(vectors)}\n',
  );

  stdout.writeln('wrote $_outputDirectory/vectors.json');
  stdout.writeln(
    'wrote $_outputDirectory/demo-badge-v0.ppm '
    '(${fixtureWidth}x$fixtureHeight)',
  );
  stdout.writeln('feature definition version: $featureDefinitionVersion');
  stdout.writeln('holdout maximum dE00: ${validation.maximumDeltaE00}');
}
