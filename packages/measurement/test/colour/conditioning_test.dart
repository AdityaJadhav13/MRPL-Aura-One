import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

ReferencePatch _patch(
  String id,
  List<double> srgb8,
  LinearRgb Function(LinearRgb) distort,
) {
  final target = SrgbColor.fromBytes(
    srgb8[0].toInt(),
    srgb8[1].toInt(),
    srgb8[2].toInt(),
  ).toLinear();
  return ReferencePatch(id: id, measured: distort(target), target: target);
}

LinearRgb _warm(LinearRgb c) => LinearRgb(c.r * 1.18, c.g, c.b * 0.76);

/// Badge v1's reference set: four neutrals plus six chromatic patches.
const Map<String, List<double>> _v1References = <String, List<double>>{
  'REF-BLACK': <double>[24, 24, 24],
  'REF-DARK': <double>[72, 72, 72],
  'REF-MID': <double>[128, 128, 128],
  'REF-LIGHT': <double>[205, 205, 205],
  'REF-RED': <double>[196, 62, 52],
  'REF-GREEN': <double>[62, 158, 82],
  'REF-BLUE': <double>[58, 78, 186],
  'REF-CYAN': <double>[60, 160, 170],
  'REF-MAGENTA': <double>[170, 66, 140],
  'REF-YELLOW': <double>[200, 180, 60],
};

List<ReferencePatch> _patches(Iterable<String> ids) => <ReferencePatch>[
  for (final id in ids) _patch(id, _v1References[id]!, _warm),
];

void main() {
  group('reference matrix conditioning (design rule R4)', () {
    test('badge v1 reference set is full rank and well conditioned', () {
      final fit = fitCorrection(
        _patches(<String>['REF-LIGHT', 'REF-RED', 'REF-GREEN', 'REF-BLUE']),
      );
      expect(fit.isOk, isTrue, reason: fit.detail);
      final c = fit.conditioning!;
      expect(c.isFullRank, isTrue);
      expect(c.effectiveRank, 4);
      expect(c.conditionNumber, lessThan(1e6));
    });

    test('an all-neutral strip is rank deficient and is refused', () {
      // The finding that made R4 a design rule. Neutrals lie on the RGB
      // diagonal: they constrain overall gain and say nothing about how the
      // channels mix, which is exactly what an illuminant change does.
      final fit = fitCorrection(
        _patches(<String>['REF-BLACK', 'REF-DARK', 'REF-MID', 'REF-LIGHT']),
      );
      expect(fit.isOk, isFalse);
      expect(fit.rejection, CorrectionRejection.degeneratePatchSet);
      expect(fit.conditioning!.isFullRank, isFalse);
      expect(fit.detail, contains('collinear'));
    });

    test(
      'near-collinear patches are refused as ill conditioned, not solved',
      () {
        // The dangerous case. A singular system throws and is noticed; a merely
        // ill-conditioned one returns a matrix with enormous coefficients that
        // reproduces its own patches beautifully and is wrong everywhere else.
        const base = LinearRgb(0.30, 0.30, 0.30);
        final patches = <ReferencePatch>[
          for (var i = 0; i < 5; i++)
            ReferencePatch(
              id: 'N$i',
              measured: LinearRgb(
                base.r + i * 0.05 + i * 1e-7,
                base.g + i * 0.05,
                base.b + i * 0.05 - i * 1e-7,
              ),
              target: LinearRgb(
                base.r + i * 0.05,
                base.g + i * 0.05,
                base.b + i * 0.05,
              ),
            ),
        ];
        final fit = fitCorrection(patches);
        expect(fit.isOk, isFalse);
        expect(
          fit.rejection,
          anyOf(
            CorrectionRejection.illConditioned,
            CorrectionRejection.degeneratePatchSet,
          ),
        );
        expect(fit.conditioning, isNotNull);
      },
    );

    test('conditioning is reported even when the fit succeeds', () {
      final fit = fitCorrection(
        _patches(<String>['REF-LIGHT', 'REF-RED', 'REF-GREEN', 'REF-BLUE']),
      );
      expect(fit.conditioning, isNotNull);
      expect(fit.conditioning!.eigenvalues, hasLength(4));
      expect(fit.conditioning!.parameters, 4);
    });

    test('a stricter limit rejects a set the default accepts', () {
      final patches = _patches(<String>[
        'REF-LIGHT',
        'REF-RED',
        'REF-GREEN',
        'REF-BLUE',
      ]);
      expect(fitCorrection(patches).isOk, isTrue);
      expect(
        fitCorrection(patches, maximumConditionNumber: 1.0).rejection,
        CorrectionRejection.illConditioned,
      );
    });
  });

  group('downgrade rather than fit through noise', () {
    test('falls back to a simpler form when the richer one is unsupported', () {
      // Three chromatic patches cannot support a 4-parameter affine model,
      // but they can support a plain 3x3. An honest 3x3 beats an affine model
      // fitted through noise.
      final patches = _patches(<String>['REF-RED', 'REF-GREEN', 'REF-BLUE']);
      expect(
        fitCorrection(patches, form: CorrectionForm.affine3x4).rejection,
        CorrectionRejection.insufficientPatches,
      );

      final best = fitBestConditionedCorrection(patches);
      expect(best.isOk, isTrue, reason: best.detail);
      expect(best.correction!.form, CorrectionForm.linear3x3);
    });

    test('prefers the richer form when the patches support it', () {
      final best = fitBestConditionedCorrection(
        _patches(<String>['REF-LIGHT', 'REF-RED', 'REF-GREEN', 'REF-BLUE']),
      );
      expect(best.isOk, isTrue);
      expect(best.correction!.form, CorrectionForm.affine3x4);
    });

    test('refuses outright when no form is supportable', () {
      final best = fitBestConditionedCorrection(
        _patches(<String>['REF-BLACK', 'REF-DARK', 'REF-MID', 'REF-LIGHT']),
      );
      expect(best.isOk, isFalse);
      expect(best.correction, isNull);
      expect(best.conditioning, isNotNull);
    });
  });

  group('the whole badge v1 reference set in use', () {
    test('fits on six and validates on four withheld patches', () {
      const fitIds = <String>[
        'REF-LIGHT',
        'REF-RED',
        'REF-GREEN',
        'REF-BLUE',
        'REF-CYAN',
        'REF-YELLOW',
      ];
      const holdoutIds = <String>[
        'REF-BLACK',
        'REF-DARK',
        'REF-MID',
        'REF-MAGENTA',
      ];

      final fit = fitCorrection(_patches(fitIds));
      expect(fit.isOk, isTrue, reason: fit.detail);

      final validation = validateCorrection(
        correction: fit.correction!,
        holdoutPatches: _patches(holdoutIds),
      );
      expect(validation.leakedPatchIds, isEmpty);
      expect(
        validation.passed,
        isTrue,
        reason: 'max dE00 was ${validation.maximumDeltaE00}',
      );
    });
  });
}
