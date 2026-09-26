// How many reference patches does the badge actually need?
//
//   dart run tool/reference_design_experiment.dart
//
// Badge area is scarce. Every reference patch is area the chemistry does not
// get, so the number of patches should be justified by evidence rather than by
// caution.
//
// SYNTHETIC. This renders badge v1 under modelled per-channel illuminant
// gains. It answers the *algebraic* half of the question — rank, conditioning,
// and whether a correction generalises to colours withheld from its fit — and
// it cannot answer the physical half, because a modelled gain is exactly the
// distortion an affine correction is built to remove. Real illuminants have
// spectra; metamerism is not modelled here at all.
//
// The cross-illuminant numbers below are therefore an OPTIMISTIC bound.
// Dossier V0 supplies the real ones.

import 'dart:io';

import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

final BadgeGeometry geometry = BadgeGeometry.parse(
  File('geometry/badge-v1.geometry.json').readAsStringSync(),
);

/// Withheld from every candidate set, so each is scored on colours it has
/// never seen. One chromatic, one neutral.
const List<String> universalHoldout = <String>['REF-MAGENTA', 'REF-DARK'];

/// The candidate reference designs.
const Map<String, List<String>> candidateSets = <String, List<String>>{
  'BLACK + WHITE (QRsens two-point)': <String>['REF-BLACK', 'REF-LIGHT'],
  'NEUTRAL ONLY': <String>['REF-BLACK', 'REF-MID', 'REF-LIGHT'],
  'NEUTRAL + 2 CHROMATIC': <String>[
    'REF-BLACK',
    'REF-LIGHT',
    'REF-RED',
    'REF-BLUE',
  ],
  'NEUTRAL + 3 CHROMATIC': <String>[
    'REF-BLACK',
    'REF-LIGHT',
    'REF-RED',
    'REF-GREEN',
    'REF-BLUE',
  ],
  'FULL V1 (7 fitted)': <String>[
    'REF-BLACK',
    'REF-LIGHT',
    'REF-RED',
    'REF-GREEN',
    'REF-BLUE',
    'REF-CYAN',
    'REF-YELLOW',
  ],
};

const List<Illuminant> illuminants = <Illuminant>[
  Illuminant.neutral,
  Illuminant.warm,
  Illuminant.cool,
];

LinearRgb designTarget(String id) {
  final c = badgeV1Colours[id]!;
  return SrgbColor.fromBytes(c[0], c[1], c[2]).toLinear();
}

Map<String, LinearRgb> sampleUnder(Illuminant illuminant) {
  final h = placeBadge(
    pixelsPerMm: 14.0,
    translateX: 900 / 2 - 14.0 * geometry.widthMm / 2,
    translateY: 620 / 2 - 14.0 * geometry.heightMm / 2,
  );
  final image = renderBadge(
    geometry: geometry,
    badgeToImage: h,
    width: 900,
    height: 620,
    illuminant: illuminant,
    colours: badgeV1Colours,
    background: const <int>[96, 98, 102],
  );
  final detection = detectPrimaryFiducials(image, geometry);
  if (!detection.isOk) {
    stderr.writeln('detection failed under ${illuminant.name}');
    exit(1);
  }
  final pose = estimateHomography(<Correspondence>[
    for (final f in geometry.primaryFiducials)
      Correspondence(f.centreMm, detection.primaries[f.id]!.centroid),
  ]).homography!;

  return <String, LinearRgb>{
    for (final roi in geometry.ofKind(RoiKind.reference))
      roi.id: sampleRoi(
        image: image,
        badgeToImage: pose,
        roi: roi,
      ).trimmedMeanLinear,
  };
}

/// Largest pairwise dE00 for one patch across illuminants. This is the metric
/// that is comparable across ALL methods, including raw and the two-point
/// correction, because it asks "does the same patch read the same under
/// different light" rather than "how close is it to a design value".
double crossIlluminantSpread(List<Lab> perIlluminant) {
  var worst = 0.0;
  for (var i = 0; i < perIlluminant.length; i++) {
    for (var j = i + 1; j < perIlluminant.length; j++) {
      final d = deltaE2000(perIlluminant[i], perIlluminant[j]);
      if (d > worst) worst = d;
    }
  }
  return worst;
}

void main() {
  final samples = <Illuminant, Map<String, LinearRgb>>{
    for (final i in illuminants) i: sampleUnder(i),
  };

  stdout.writeln('Reference design experiment — SYNTHETIC illuminant gains.');
  stdout.writeln('Holdout (never fitted): ${universalHoldout.join(', ')}');
  stdout.writeln('');
  stdout.writeln(
    '| Reference set | Patches | Form | Rank | Condition | '
    'Holdout cross-illuminant dE00 (max) |',
  );
  stdout.writeln('|---|---|---|---|---|---|');

  // Baseline: no correction at all.
  {
    final spreads = <double>[
      for (final id in universalHoldout)
        crossIlluminantSpread(<Lab>[
          for (final i in illuminants) samples[i]![id]!.toXyz().toLab(),
        ]),
    ];
    stdout.writeln(
      '| RAW (no correction) | 0 | - | - | - | '
      '${spreads.reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} |',
    );
  }

  for (final entry in candidateSets.entries) {
    final ids = entry.value;
    final isTwoPoint = ids.length == 2;

    String rank = '-';
    String condition = '-';
    String form = isTwoPoint ? 'QRsens B/W' : '-';
    final correctedPerHoldout = <String, List<Lab>>{
      for (final id in universalHoldout) id: <Lab>[],
    };
    var failed = '';

    for (final illuminant in illuminants) {
      final measured = samples[illuminant]!;

      if (isTwoPoint) {
        final normaliser = BlackWhiteNormaliser(
          form: BlackWhiteForm.qrsensEquation2,
          black: measured[ids[0]]!,
          white: measured[ids[1]]!,
        );
        for (final id in universalHoldout) {
          final result = normaliser.apply(measured[id]!);
          if (!result.isOk) {
            failed = 'degenerate references';
            continue;
          }
          correctedPerHoldout[id]!.add(result.value!.toXyz().toLab());
        }
        continue;
      }

      final fit = fitBestConditionedCorrection(<ReferencePatch>[
        for (final id in ids)
          ReferencePatch(
            id: id,
            measured: measured[id]!,
            target: designTarget(id),
          ),
      ]);
      if (!fit.isOk) {
        failed = fit.rejection!.name;
        rank = '${fit.conditioning?.effectiveRank ?? '-'}';
        condition = fit.conditioning == null
            ? '-'
            : (fit.conditioning!.conditionNumber.isFinite
                  ? fit.conditioning!.conditionNumber.toStringAsExponential(1)
                  : 'inf');
        continue;
      }
      form = fit.correction!.form.name;
      rank = '${fit.conditioning!.effectiveRank}';
      condition = fit.conditioning!.conditionNumber.toStringAsExponential(1);

      for (final id in universalHoldout) {
        correctedPerHoldout[id]!.add(
          fit.correction!.apply(measured[id]!).toXyz().toLab(),
        );
      }
    }

    final String spreadCell;
    if (failed.isNotEmpty) {
      spreadCell = 'REFUSED ($failed)';
    } else {
      final worst = universalHoldout
          .map((id) => crossIlluminantSpread(correctedPerHoldout[id]!))
          .reduce((a, b) => a > b ? a : b);
      spreadCell = worst.toStringAsFixed(2);
    }

    stdout.writeln(
      '| ${entry.key} | ${ids.length} | $form | $rank | $condition | '
      '$spreadCell |',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'Cross-illuminant spread is the max pairwise dE00 for a HELD-OUT patch '
    'across the three illuminants. Lower is better. Absolute colour accuracy '
    'is NOT reported: the targets are design-space values, not measured print.',
  );
}
