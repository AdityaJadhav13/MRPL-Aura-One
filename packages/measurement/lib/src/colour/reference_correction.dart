import 'package:meta/meta.dart';

import '../linalg/matrix.dart';
import 'colour_types.dart';
import 'delta_e.dart';
import 'lab.dart';
import 'srgb.dart';

/// One printed reference patch: what we measured, and what it should be.
@immutable
final class ReferencePatch {
  const ReferencePatch({
    required this.id,
    required this.measured,
    required this.target,
  });

  final String id;

  /// What this patch looked like in this photograph, in linear RGB.
  final LinearRgb measured;

  /// What this patch is, in linear RGB.
  ///
  /// These must be the **measured** values of the actual print lot, not the
  /// printer's nominal RGB. Ink on this substrate is not what the design file
  /// said, and correcting toward a value the patch never had would bake that
  /// error into every measurement.
  final LinearRgb target;
}

/// The shape of the correction being fitted.
enum CorrectionForm {
  /// 3x3 linear map. Three degrees of freedom per output channel, no offset.
  linear3x3,

  /// 3x4 affine map — a 3x3 plus a constant term, fitted by appending a 1 to
  /// each observation. The offset absorbs flare and black-level lift, which a
  /// purely multiplicative model has to distort its gains to accommodate.
  affine3x4,
}

/// Why a correction could not be fitted.
enum CorrectionRejection {
  /// Fewer patches than the chosen form has parameters.
  insufficientPatches,

  /// The patch colours do not span the space: the normal equations are
  /// singular. Fitting anyway produces a matrix built from rounding error that
  /// will look perfectly reasonable.
  degeneratePatchSet,

  /// The normal equations are solvable but badly conditioned: the patches
  /// nearly fail to span the space.
  ///
  /// This is the dangerous case, and the reason it gets its own state. A
  /// singular system throws and is noticed. A merely ill-conditioned one
  /// returns a matrix with enormous coefficients that amplify sensor noise,
  /// fits its own patches beautifully, and is wrong everywhere else. A
  /// reference strip of mostly-neutral patches lands here.
  illConditioned,
}

/// How well the reference patches constrained the fit.
///
/// Reported whether the fit succeeded or not, because the conditioning is the
/// evidence for trusting the correction and a caller should be able to see it
/// either way.
@immutable
final class CorrectionConditioning {
  const CorrectionConditioning({
    required this.eigenvalues,
    required this.conditionNumber,
    required this.effectiveRank,
    required this.parameters,
  });

  /// Eigenvalues of `X^T X`, ascending.
  final List<double> eigenvalues;

  /// Largest over smallest eigenvalue. Large means the patches nearly fail to
  /// span the space; the fit will amplify noise along the poorly constrained
  /// direction.
  final double conditionNumber;

  /// Eigenvalues above a relative tolerance of the largest. Below
  /// [parameters], the patch set does not span the parameter space at all.
  final int effectiveRank;

  /// Number of parameters the chosen form requires.
  final int parameters;

  bool get isFullRank => effectiveRank >= parameters;

  Map<String, Object?> toJson() => <String, Object?>{
    'eigenvalues': eigenvalues,
    'condition_number': conditionNumber,
    'effective_rank': effectiveRank,
    'parameters': parameters,
    'is_full_rank': isFullRank,
  };
}

/// A fitted colour correction.
@immutable
final class ColourCorrection {
  const ColourCorrection({
    required this.form,
    required this.matrix,
    required this.fitPatchIds,
  });

  final CorrectionForm form;

  /// Row-major, `inputDimension x 3`. Applied as a row vector on the left.
  final Matrix matrix;

  /// Which patches were consumed by the fit. Recorded so that a validation
  /// run can be checked for overlap — see [ReferenceValidation].
  final List<String> fitPatchIds;

  LinearRgb apply(LinearRgb input) {
    final row = switch (form) {
      CorrectionForm.linear3x3 => <double>[input.r, input.g, input.b],
      CorrectionForm.affine3x4 => <double>[input.r, input.g, input.b, 1.0],
    };
    var r = 0.0, g = 0.0, b = 0.0;
    for (var i = 0; i < row.length; i++) {
      r += row[i] * matrix.at(i, 0);
      g += row[i] * matrix.at(i, 1);
      b += row[i] * matrix.at(i, 2);
    }
    return LinearRgb(r, g, b);
  }
}

/// The outcome of fitting a correction.
@immutable
final class CorrectionFit {
  const CorrectionFit.ok(this.correction, {this.conditioning})
    : rejection = null,
      detail = null;

  const CorrectionFit.rejected(this.rejection, this.detail, {this.conditioning})
    : correction = null;

  final ColourCorrection? correction;
  final CorrectionRejection? rejection;
  final String? detail;

  /// How well the reference patches constrained the fit. Null only when the
  /// fit failed before the normal equations were formed.
  final CorrectionConditioning? conditioning;

  bool get isOk => rejection == null;

  /// Everything needed to know which correction produced a corrected value,
  /// and to apply it again.
  ///
  /// Added for APP-INTEGRATION-01 §49–§50: a capture record that stores
  /// corrected colours without the matrix that produced them cannot be
  /// re-examined once the correction method changes, and it will change —
  /// the method is chosen by physical evidence M0C has not yet collected.
  Map<String, Object?> toJson() => <String, Object?>{
    'ok': isOk,
    'form': correction?.form.name,
    'matrix': correction?.matrix.toRows(),
    'fit_patch_ids': correction?.fitPatchIds,
    'rejection': rejection?.name,
    'detail': detail,
    'conditioning': conditioning?.toJson(),
  };
}

/// Fits a colour correction by ordinary least squares. Directive s15.
///
/// Solves `M = (X^T X)^-1 X^T Y` — the normal-equation form of `M = X^+ Y`.
/// Both sides are in **linear** RGB; fitting in a gamma-encoded space is a
/// standard and silent error, because the transform being undone is linear in
/// light and not in code values.
///
/// The patches passed here are the *fit* set. They must not be the patches
/// used to validate the result: a correction checked on its own fit points
/// cannot report its own failure, which is the whole reason the withheld set
/// exists.
CorrectionFit fitCorrection(
  List<ReferencePatch> fitPatches, {
  CorrectionForm form = CorrectionForm.affine3x4,
  double maximumConditionNumber = 1.0e6,
  double rankTolerance = 1.0e-10,
}) {
  final parameters = form == CorrectionForm.linear3x3 ? 3 : 4;
  if (fitPatches.length < parameters) {
    return CorrectionFit.rejected(
      CorrectionRejection.insufficientPatches,
      '${form.name} needs at least $parameters patches, '
      'got ${fitPatches.length}',
    );
  }

  final x = Matrix(fitPatches.length, parameters);
  final y = Matrix(fitPatches.length, 3);
  for (var i = 0; i < fitPatches.length; i++) {
    final p = fitPatches[i];
    x.set(i, 0, p.measured.r);
    x.set(i, 1, p.measured.g);
    x.set(i, 2, p.measured.b);
    if (parameters == 4) x.set(i, 3, 1.0);
    y.set(i, 0, p.target.r);
    y.set(i, 1, p.target.g);
    y.set(i, 2, p.target.b);
  }

  final xt = x.transpose();
  final normal = xt.multiply(x);

  // Inspect the conditioning BEFORE solving. A singular system throws and is
  // noticed; a merely ill-conditioned one solves quietly and is wrong.
  final eigen = symmetricEigen(normal);
  final largest = eigen.values.last.abs();
  final smallest = eigen.values.first.abs();
  final conditionNumber = smallest <= 0 ? double.infinity : largest / smallest;
  final effectiveRank = largest <= 0
      ? 0
      : eigen.values.where((v) => v.abs() / largest > rankTolerance).length;

  final conditioning = CorrectionConditioning(
    eigenvalues: eigen.values,
    conditionNumber: conditionNumber,
    effectiveRank: effectiveRank,
    parameters: parameters,
  );

  if (!conditioning.isFullRank) {
    return CorrectionFit.rejected(
      CorrectionRejection.degeneratePatchSet,
      'reference patches span only ${conditioning.effectiveRank} of '
      '$parameters dimensions. Neutral patches are collinear in RGB: they '
      'constrain overall gain and say nothing about how the channels mix, '
      'which is exactly what an illuminant change does.',
      conditioning: conditioning,
    );
  }

  if (conditionNumber > maximumConditionNumber) {
    return CorrectionFit.rejected(
      CorrectionRejection.illConditioned,
      'normal equations have condition number '
      '${conditionNumber.toStringAsExponential(2)}, above the limit of '
      '${maximumConditionNumber.toStringAsExponential(2)}. The patches nearly '
      'fail to span the colour space, so the fitted matrix would amplify '
      'sensor noise along the poorly constrained direction.',
      conditioning: conditioning,
    );
  }

  final Matrix m;
  try {
    m = solve(normal, xt.multiply(y));
  } on SingularSystemException catch (e) {
    return CorrectionFit.rejected(
      CorrectionRejection.degeneratePatchSet,
      'normal equations are singular: ${e.message}',
      conditioning: conditioning,
    );
  }

  return CorrectionFit.ok(
    ColourCorrection(
      form: form,
      matrix: m,
      fitPatchIds: <String>[for (final p in fitPatches) p.id],
    ),
    conditioning: conditioning,
  );
}

/// Fits the most capable correction the reference patches actually support.
///
/// Tries [forms] in order and returns the first that fits and is adequately
/// conditioned. This is the "downgrade" path: a patch set that cannot support
/// an affine model may still support a plain 3x3, and a 3x3 honestly fitted is
/// worth more than an affine model fitted through noise.
///
/// If nothing fits, the rejection from the **last** attempt is returned, since
/// that is the simplest model tried and its failure is the most informative.
CorrectionFit fitBestConditionedCorrection(
  List<ReferencePatch> fitPatches, {
  List<CorrectionForm> forms = const <CorrectionForm>[
    CorrectionForm.affine3x4,
    CorrectionForm.linear3x3,
  ],
  double maximumConditionNumber = 1.0e6,
}) {
  CorrectionFit? last;
  for (final form in forms) {
    final fit = fitCorrection(
      fitPatches,
      form: form,
      maximumConditionNumber: maximumConditionNumber,
    );
    if (fit.isOk) return fit;
    last = fit;
  }
  return last ??
      const CorrectionFit.rejected(
        CorrectionRejection.insufficientPatches,
        'no correction form was attempted',
      );
}

/// How one withheld patch behaved after correction.
@immutable
final class PatchResidual {
  const PatchResidual({
    required this.patchId,
    required this.deltaE00,
    required this.deltaE76,
    required this.correctedLab,
    required this.targetLab,
  });

  final String patchId;
  final double deltaE00;
  final double deltaE76;
  final Lab correctedLab;
  final Lab targetLab;

  Map<String, Object?> toJson() => <String, Object?>{
    'patch_id': patchId,
    'delta_e00': deltaE00,
    'delta_e76': deltaE76,
    'corrected_lab': <double>[
      correctedLab.lStar,
      correctedLab.aStar,
      correctedLab.bStar,
    ],
    'target_lab': <double>[targetLab.lStar, targetLab.aStar, targetLab.bStar],
  };
}

/// The result of checking a fitted correction against patches it never saw.
///
/// This is the mechanism that lets the pipeline say "the colour correction
/// failed" instead of quietly producing corrected values that are wrong.
@immutable
final class ReferenceValidation {
  const ReferenceValidation({
    required this.residuals,
    required this.maximumDeltaE00,
    required this.meanDeltaE00,
    required this.threshold,
    required this.thresholdIsProvisional,
    required this.leakedPatchIds,
  });

  final List<PatchResidual> residuals;
  final double maximumDeltaE00;
  final double meanDeltaE00;

  /// The maximum tolerated dE00 on a withheld patch.
  final double threshold;

  /// Whether [threshold] is still a development placeholder.
  ///
  /// It is, and will be until dossier V0 photographs printed targets on a
  /// device matrix. A validation that passes against a provisional threshold
  /// has not been validated against anything.
  final bool thresholdIsProvisional;

  /// Patches that appear in both the fit set and the validation set.
  ///
  /// Non-empty means the validation is worthless — it is measuring how well
  /// the fit reproduced its own inputs. Treated as a failure rather than a
  /// warning.
  final List<String> leakedPatchIds;

  bool get passed =>
      leakedPatchIds.isEmpty &&
      residuals.isNotEmpty &&
      maximumDeltaE00 <= threshold;

  Map<String, Object?> toJson() => <String, Object?>{
    'maximum_delta_e00': maximumDeltaE00,
    'mean_delta_e00': meanDeltaE00,
    'threshold': threshold,
    'threshold_is_provisional': thresholdIsProvisional,
    'leaked_patch_ids': leakedPatchIds,
    'passed': passed,
    'residuals': residuals.map((r) => r.toJson()).toList(),
  };
}

/// Applies [correction] to patches withheld from its fit and measures how far
/// off they land. Directive s15.
///
/// [maximumDeltaE00] is **provisional**: a development placeholder, not an
/// empirical threshold. Directive s9 requires it to be labelled as such until
/// real photographs on real devices have set it.
ReferenceValidation validateCorrection({
  required ColourCorrection correction,
  required List<ReferencePatch> holdoutPatches,
  double maximumDeltaE00 = 2.0,
  bool thresholdIsProvisional = true,
}) {
  final fitIds = correction.fitPatchIds.toSet();
  final leaked = <String>[
    for (final p in holdoutPatches)
      if (fitIds.contains(p.id)) p.id,
  ];

  final residuals = <PatchResidual>[];
  for (final patch in holdoutPatches) {
    final corrected = correction.apply(patch.measured);
    final correctedLab = corrected.toXyz().toLab();
    final targetLab = patch.target.toXyz().toLab();
    residuals.add(
      PatchResidual(
        patchId: patch.id,
        deltaE00: deltaE2000(correctedLab, targetLab),
        deltaE76: deltaE76(correctedLab, targetLab),
        correctedLab: correctedLab,
        targetLab: targetLab,
      ),
    );
  }

  var maximum = 0.0;
  var sum = 0.0;
  for (final r in residuals) {
    if (r.deltaE00 > maximum) maximum = r.deltaE00;
    sum += r.deltaE00;
  }

  return ReferenceValidation(
    residuals: residuals,
    maximumDeltaE00: residuals.isEmpty ? double.nan : maximum,
    meanDeltaE00: residuals.isEmpty ? double.nan : sum / residuals.length,
    threshold: maximumDeltaE00,
    thresholdIsProvisional: thresholdIsProvisional,
    leakedPatchIds: leaked,
  );
}
