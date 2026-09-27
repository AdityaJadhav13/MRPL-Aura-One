import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

/// A printed reference set: three neutrals and three chromatic patches.
///
/// Index 0 white, 1 black, 2 mid-grey, 3 red, 4 green, 5 blue.
///
/// The split used throughout this file fits on {white, red, green, blue} and
/// withholds {black, grey}. That is not arbitrary: the three neutrals are
/// collinear in RGB, so any fit set drawn only from them is rank-deficient
/// and is correctly refused (see the degenerate-patch-set test). A real
/// reference strip has to span the space, and the tests have to use one that
/// does.
const List<LinearRgb> _targets = <LinearRgb>[
  LinearRgb(0.85, 0.85, 0.85),
  LinearRgb(0.03, 0.03, 0.03),
  LinearRgb(0.45, 0.45, 0.45),
  LinearRgb(0.55, 0.12, 0.10),
  LinearRgb(0.10, 0.45, 0.15),
  LinearRgb(0.09, 0.14, 0.50),
];

/// Patch indices used to fit: white, red, green, blue.
const List<int> _fitSet = <int>[0, 3, 4, 5];

/// Patch indices withheld from every fit: black and mid-grey.
const List<int> _holdoutSet = <int>[1, 2];

/// A per-channel gain: what a change of illuminant colour temperature looks
/// like to a linear sensor, to first order.
LinearRgb _illuminate(LinearRgb c, double gr, double gg, double gb) =>
    LinearRgb(c.r * gr, c.g * gg, c.b * gb);

List<ReferencePatch> _patches(
  Iterable<int> indices,
  LinearRgb Function(LinearRgb) distort,
) => <ReferencePatch>[
  for (final i in indices)
    ReferencePatch(
      id: 'P$i',
      measured: distort(_targets[i]),
      target: _targets[i],
    ),
];

void main() {
  group('colour correction fit (directive s15)', () {
    test('recovers a per-channel illuminant gain', () {
      LinearRgb distort(LinearRgb c) => _illuminate(c, 1.18, 1.0, 0.76);

      final fit = fitCorrection(
        _patches(_fitSet, distort),
        form: CorrectionForm.affine3x4,
      );
      expect(fit.isOk, isTrue);

      // A patch the fit never saw must land close to its true value.
      final holdout = _patches(_holdoutSet, distort);
      final validation = validateCorrection(
        correction: fit.correction!,
        holdoutPatches: holdout,
      );
      expect(validation.leakedPatchIds, isEmpty);
      expect(validation.maximumDeltaE00, lessThan(1.0));
      expect(validation.passed, isTrue);
    });

    test('a 3x3 form needs 3 patches and an affine form needs 4', () {
      LinearRgb identity(LinearRgb c) => c;
      expect(
        fitCorrection(
          _patches(<int>[3, 4], identity),
          form: CorrectionForm.linear3x3,
        ).rejection,
        CorrectionRejection.insufficientPatches,
      );
      expect(
        fitCorrection(
          _patches(<int>[3, 4, 5], identity),
          form: CorrectionForm.affine3x4,
        ).rejection,
        CorrectionRejection.insufficientPatches,
      );
      expect(
        fitCorrection(
          _patches(<int>[3, 4, 5], identity),
          form: CorrectionForm.linear3x3,
        ).isOk,
        isTrue,
      );
    });

    test('refuses identical patches instead of fitting noise', () {
      final patches = <ReferencePatch>[
        for (var i = 0; i < 4; i++)
          ReferencePatch(
            id: 'P$i',
            measured: const LinearRgb(0.4, 0.4, 0.4),
            target: const LinearRgb(0.45, 0.45, 0.45),
          ),
      ];
      final fit = fitCorrection(patches);
      expect(fit.isOk, isFalse);
      expect(fit.rejection, CorrectionRejection.degeneratePatchSet);
      expect(fit.correction, isNull);
    });

    test('refuses an all-neutral reference strip', () {
      // This is the realistic version of the failure above, and it is worth
      // its own test because a step-wedge of greys looks like a perfectly
      // sensible reference strip to design. It is not: neutrals are collinear
      // in RGB, so they constrain overall gain and nothing about how the
      // channels mix. An illuminant change is exactly a change in how the
      // channels mix.
      //
      // This test caught a bad fixture in this very file.
      LinearRgb distort(LinearRgb c) => _illuminate(c, 1.18, 1.0, 0.76);
      final greysOnly = _patches(<int>[0, 1, 2], distort)
        ..add(
          ReferencePatch(
            id: 'P6',
            measured: distort(const LinearRgb(0.65, 0.65, 0.65)),
            target: const LinearRgb(0.65, 0.65, 0.65),
          ),
        );
      final fit = fitCorrection(greysOnly);
      expect(fit.isOk, isFalse);
      expect(fit.rejection, CorrectionRejection.degeneratePatchSet);
    });

    test('the offset term earns its place against a black-level lift', () {
      // Flare adds a constant to every channel. A purely multiplicative 3x3
      // cannot represent that, and has to distort its gains to compensate.
      LinearRgb distort(LinearRgb c) =>
          LinearRgb(c.r * 1.1 + 0.05, c.g * 1.0 + 0.05, c.b * 0.9 + 0.05);

      final linear = fitCorrection(
        _patches(_fitSet, distort),
        form: CorrectionForm.linear3x3,
      );
      final affine = fitCorrection(
        _patches(_fitSet, distort),
        form: CorrectionForm.affine3x4,
      );
      final holdout = _patches(_holdoutSet, distort);

      final linearResidual = validateCorrection(
        correction: linear.correction!,
        holdoutPatches: holdout,
      ).maximumDeltaE00;
      final affineResidual = validateCorrection(
        correction: affine.correction!,
        holdoutPatches: holdout,
      ).maximumDeltaE00;

      expect(affineResidual, lessThan(linearResidual));
    });
  });

  group('held-out validation (the part that can fail)', () {
    test('catches a correction fitted against the wrong reference profile', () {
      // The measured patches came from one print lot; the stored target
      // values describe another. The fit still succeeds — least squares
      // always succeeds — and only the withheld patches reveal it.
      LinearRgb distort(LinearRgb c) => _illuminate(c, 1.18, 1.0, 0.76);

      final fitPatches = _patches(_fitSet, distort);
      final fit = fitCorrection(fitPatches);
      expect(fit.isOk, isTrue);

      final wrongProfile = <ReferencePatch>[
        ReferencePatch(
          id: 'P1',
          measured: distort(_targets[1]),
          target: const LinearRgb(0.60, 0.10, 0.40),
        ),
        ReferencePatch(
          id: 'P2',
          measured: distort(_targets[2]),
          target: const LinearRgb(0.70, 0.60, 0.05),
        ),
      ];

      final validation = validateCorrection(
        correction: fit.correction!,
        holdoutPatches: wrongProfile,
      );
      expect(validation.passed, isFalse);
      expect(validation.maximumDeltaE00, greaterThan(2.0));
    });

    test('treats a patch used in the fit as leakage, not as a pass', () {
      LinearRgb distort(LinearRgb c) => _illuminate(c, 1.18, 1.0, 0.76);
      final fit = fitCorrection(_patches(_fitSet, distort));

      final validation = validateCorrection(
        correction: fit.correction!,
        // P3 (red) was in the fit set; P1 (black) was not.
        holdoutPatches: _patches(<int>[3, 1], distort),
      );
      expect(validation.leakedPatchIds, contains('P3'));
      // Even though the residuals are small, this is not a pass: the check
      // is measuring how well the fit reproduced its own input.
      expect(validation.maximumDeltaE00, lessThan(1.0));
      expect(validation.passed, isFalse);
    });

    test('an empty holdout set never passes', () {
      LinearRgb identity(LinearRgb c) => c;
      final fit = fitCorrection(_patches(_fitSet, identity));
      final validation = validateCorrection(
        correction: fit.correction!,
        holdoutPatches: const <ReferencePatch>[],
      );
      expect(validation.passed, isFalse);
      expect(validation.maximumDeltaE00.isNaN, isTrue);
    });

    test('carries the provisional flag so a pass cannot be overstated', () {
      LinearRgb identity(LinearRgb c) => c;
      final fit = fitCorrection(_patches(_fitSet, identity));
      final validation = validateCorrection(
        correction: fit.correction!,
        holdoutPatches: _patches(_holdoutSet, identity),
      );
      expect(validation.passed, isTrue);
      expect(
        validation.thresholdIsProvisional,
        isTrue,
        reason: 'no photograph of a real badge has set this threshold yet',
      );
    });
  });
}
