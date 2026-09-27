import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../linalg/matrix.dart';
import 'badge_geometry.dart';

/// A correspondence between a known point on the badge and where it was
/// observed in the image.
@immutable
final class Correspondence {
  const Correspondence(this.badge, this.image);

  final PointMm badge;
  final PointPx image;
}

/// Why a homography could not be estimated or could not be trusted.
enum HomographyRejection {
  /// Fewer than four correspondences. There is no fourth corner to guess:
  /// a wrong homography produces a beautifully rectified image of the wrong
  /// region, which is undetectable downstream.
  insufficientCorrespondences,

  /// The correspondences are degenerate — collinear, coincident, or otherwise
  /// carrying less information than the eight degrees of freedom need.
  degenerateConfiguration,

  /// The estimate is numerically unreliable — the solve did not produce a
  /// usable value at all.
  illConditioned,

  /// The mapping is not a valid orientation-preserving planar transform.
  nonInvertible,
}

/// A plane-to-plane projective transform from badge millimetres to image
/// pixels, together with the evidence for trusting it.
@immutable
final class Homography {
  const Homography(this.matrix, {required this.nullSpaceMargin});

  /// Row-major 3x3, normalised so that `matrix.at(2, 2) == 1` where possible.
  final Matrix matrix;

  /// How cleanly the DLT solution is separated from the next-best one:
  /// the ratio of the second-smallest to the largest eigenvalue of `A^T A`.
  ///
  /// **Larger is better.** This is deliberately not a condition number. For a
  /// correct homography the smallest eigenvalue is essentially zero — that
  /// null space *is* the answer — so the usual largest-over-smallest ratio is
  /// enormous precisely when the fit is perfect. What actually distinguishes
  /// a good configuration from a degenerate one is whether the null space is
  /// one-dimensional, which is what this measures: a collinear or coincident
  /// arrangement drives it toward zero.
  final double nullSpaceMargin;

  /// The underlying projective map, on bare coordinates.
  ///
  /// The typed wrappers below exist because the direction of a homography is
  /// easy to lose track of, and mapping pixels with a millimetre transform
  /// produces plausible nonsense rather than an error.
  (double, double) mapXy(double x, double y) {
    final m = matrix;
    final w = m.at(2, 0) * x + m.at(2, 1) * y + m.at(2, 2);
    if (w == 0.0) {
      throw const SingularSystemException('point maps to infinity');
    }
    return (
      (m.at(0, 0) * x + m.at(0, 1) * y + m.at(0, 2)) / w,
      (m.at(1, 0) * x + m.at(1, 1) * y + m.at(1, 2)) / w,
    );
  }

  /// Badge millimetres to image pixels.
  PointPx mapMm(PointMm p) {
    final (x, y) = mapXy(p.x, p.y);
    return PointPx(x, y);
  }

  /// Image pixels to badge millimetres.
  ///
  /// Only meaningful on a homography obtained from [invert]; calling it on a
  /// forward transform is a direction error this signature is here to make
  /// visible.
  PointMm mapToMm(PointPx p) {
    final (x, y) = mapXy(p.x, p.y);
    return PointMm(x, y);
  }

  /// Root-mean-square distance, in pixels, between where each correspondence
  /// was observed and where this homography says it should be.
  ///
  /// This is the number that catches a bent badge: a curved surface is not a
  /// plane, and a planar transform fitted to it leaves a residual that a flat
  /// badge would not.
  double reprojectionRmsPx(List<Correspondence> correspondences) {
    var sum = 0.0;
    for (final c in correspondences) {
      final predicted = mapMm(c.badge);
      final dx = predicted.x - c.image.x;
      final dy = predicted.y - c.image.y;
      sum += dx * dx + dy * dy;
    }
    return math.sqrt(sum / correspondences.length);
  }

  /// The inverse transform, image pixels back to badge millimetres.
  Homography invert() {
    final m = matrix;
    final a = m.at(0, 0), b = m.at(0, 1), c = m.at(0, 2);
    final d = m.at(1, 0), e = m.at(1, 1), f = m.at(1, 2);
    final g = m.at(2, 0), h = m.at(2, 1), i = m.at(2, 2);

    final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    if (det.abs() < 1e-15) {
      throw const SingularSystemException('homography is not invertible');
    }

    final inv = Matrix.fromRows(<List<double>>[
      <double>[
        (e * i - f * h) / det,
        (c * h - b * i) / det,
        (b * f - c * e) / det,
      ],
      <double>[
        (f * g - d * i) / det,
        (a * i - c * g) / det,
        (c * d - a * f) / det,
      ],
      <double>[
        (d * h - e * g) / det,
        (b * g - a * h) / det,
        (a * e - b * d) / det,
      ],
    ]);
    return Homography(inv, nullSpaceMargin: nullSpaceMargin);
  }
}

/// The outcome of a homography estimate.
@immutable
final class HomographyEstimate {
  const HomographyEstimate.ok(this.homography)
    : rejection = null,
      detail = null;

  const HomographyEstimate.rejected(this.rejection, this.detail)
    : homography = null;

  final Homography? homography;
  final HomographyRejection? rejection;
  final String? detail;

  bool get isOk => rejection == null;
}

/// Estimates a homography from four or more correspondences by the normalised
/// Direct Linear Transform. Directive s8.
///
/// Hartley normalisation (translate to centroid, scale to mean distance
/// sqrt(2)) is applied before the solve and undone afterwards. It is not
/// optional: without it the DLT design matrix mixes pixel-scale and
/// millimetre-scale quantities and the solution is dominated by rounding.
///
/// [minimumNullSpaceMargin] guards against a rank-deficient configuration —
/// fiducials that are collinear, coincident, or otherwise carry less
/// information than the eight degrees of freedom need. It is a numerical
/// threshold rather than an empirical one: a well-formed four-corner
/// arrangement scores many orders of magnitude above it.
HomographyEstimate estimateHomography(
  List<Correspondence> correspondences, {
  double minimumNullSpaceMargin = 1e-9,
}) {
  if (correspondences.length < 4) {
    return HomographyEstimate.rejected(
      HomographyRejection.insufficientCorrespondences,
      'need at least 4 correspondences, got ${correspondences.length}',
    );
  }

  final badgeNorm = _normalise(
    correspondences.map((c) => PointPx(c.badge.x, c.badge.y)).toList(),
  );
  final imageNorm = _normalise(correspondences.map((c) => c.image).toList());
  if (badgeNorm == null || imageNorm == null) {
    return const HomographyEstimate.rejected(
      HomographyRejection.degenerateConfiguration,
      'all points are coincident',
    );
  }

  final n = correspondences.length;
  final a = Matrix(2 * n, 9);
  for (var i = 0; i < n; i++) {
    final s = badgeNorm.points[i];
    final d = imageNorm.points[i];
    final r0 = 2 * i;
    final r1 = r0 + 1;

    a.set(r0, 0, -s.x);
    a.set(r0, 1, -s.y);
    a.set(r0, 2, -1.0);
    a.set(r0, 6, s.x * d.x);
    a.set(r0, 7, s.y * d.x);
    a.set(r0, 8, d.x);

    a.set(r1, 3, -s.x);
    a.set(r1, 4, -s.y);
    a.set(r1, 5, -1.0);
    a.set(r1, 6, s.x * d.y);
    a.set(r1, 7, s.y * d.y);
    a.set(r1, 8, d.y);
  }

  final ata = a.transpose().multiply(a);
  final eigen = symmetricEigen(ata);

  final largest = eigen.values.last.abs();
  if (largest < 1e-300) {
    return const HomographyEstimate.rejected(
      HomographyRejection.degenerateConfiguration,
      'design matrix is entirely zero',
    );
  }

  // Two nearly-zero eigenvalues means the null space is not one-dimensional:
  // the correspondences do not pin down a unique transform. This is what a
  // collinear or coincident fiducial arrangement looks like numerically.
  final margin = eigen.values[1].abs() / largest;
  if (margin < minimumNullSpaceMargin) {
    return HomographyEstimate.rejected(
      HomographyRejection.degenerateConfiguration,
      'null space is not one-dimensional (margin $margin); correspondences '
      'are collinear, coincident or otherwise degenerate',
    );
  }

  final h = eigen.vectors.column(0);
  final hNorm = Matrix.fromRows(<List<double>>[
    <double>[h[0], h[1], h[2]],
    <double>[h[3], h[4], h[5]],
    <double>[h[6], h[7], h[8]],
  ]);

  // Undo normalisation: H = T_image^-1 * H_norm * T_badge
  final Matrix denormalised;
  try {
    final imageTransformInverse = Homography(
      imageNorm.transform,
      nullSpaceMargin: 1,
    ).invert().matrix;
    denormalised = imageTransformInverse
        .multiply(hNorm)
        .multiply(badgeNorm.transform);
  } on SingularSystemException catch (e) {
    return HomographyEstimate.rejected(
      HomographyRejection.nonInvertible,
      e.message,
    );
  }

  final scale = denormalised.at(2, 2);
  if (scale.abs() < 1e-15) {
    return const HomographyEstimate.rejected(
      HomographyRejection.nonInvertible,
      'homography has a vanishing scale term',
    );
  }
  final scaled = Matrix(3, 3);
  for (var r = 0; r < 3; r++) {
    for (var c = 0; c < 3; c++) {
      scaled.set(r, c, denormalised.at(r, c) / scale);
    }
  }

  final result = Homography(scaled, nullSpaceMargin: margin);
  try {
    result.invert();
  } on SingularSystemException catch (e) {
    return HomographyEstimate.rejected(
      HomographyRejection.nonInvertible,
      e.message,
    );
  }

  return HomographyEstimate.ok(result);
}

({List<PointPx> points, Matrix transform})? _normalise(List<PointPx> points) {
  final n = points.length;
  var cx = 0.0, cy = 0.0;
  for (final p in points) {
    cx += p.x;
    cy += p.y;
  }
  cx /= n;
  cy /= n;

  var meanDistance = 0.0;
  for (final p in points) {
    final dx = p.x - cx;
    final dy = p.y - cy;
    meanDistance += math.sqrt(dx * dx + dy * dy);
  }
  meanDistance /= n;
  // Every point sits on the centroid: there is no spread to normalise, and no
  // transform to recover.
  if (meanDistance < 1e-12) return null;

  final s = math.sqrt(2) / meanDistance;
  final transform = Matrix.fromRows(<List<double>>[
    <double>[s, 0, -s * cx],
    <double>[0, s, -s * cy],
    <double>[0, 0, 1],
  ]);
  final normalised = <PointPx>[
    for (final p in points) PointPx(s * (p.x - cx), s * (p.y - cy)),
  ];
  return (points: normalised, transform: transform);
}
