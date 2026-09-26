import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'badge_geometry.dart';
import 'fiducial_detector.dart';
import 'homography.dart';

/// Where one withheld marker actually landed, against where the pose says it
/// should have.
@immutable
final class ControlPointResidual {
  const ControlPointResidual({
    required this.fiducialId,
    required this.expectedMm,
    required this.predictedPx,
    required this.observedPx,
  });

  final String fiducialId;
  final PointMm expectedMm;
  final PointPx predictedPx;
  final PointPx observedPx;

  double get dx => observedPx.x - predictedPx.x;
  double get dy => observedPx.y - predictedPx.y;
  double get magnitudePx => math.sqrt(dx * dx + dy * dy);

  Map<String, Object?> toJson() => <String, Object?>{
    'fiducial_id': fiducialId,
    'expected_mm': <double>[expectedMm.x, expectedMm.y],
    'predicted_px': <double>[predictedPx.x, predictedPx.y],
    'observed_px': <double>[observedPx.x, observedPx.y],
    'dx_px': dx,
    'dy_px': dy,
    'magnitude_px': magnitudePx,
  };
}

/// The result of checking a pose against markers it was not fitted to.
///
/// This is the only thing in the pipeline that can say anything about whether
/// the badge was flat. The residual of the four primaries is zero by
/// construction — eight equations, eight degrees of freedom — so it is not
/// reported here at all, to remove the temptation to read meaning into it.
/// See `docs/computer-vision/pipeline.md` §2.1.
@immutable
final class GeometryValidation {
  const GeometryValidation({
    required this.residuals,
    required this.expectedControlPoints,
    required this.rmsPx,
    required this.maximumPx,
    required this.medianPx,
    required this.pixelsPerMm,
    required this.longitudinalGradient,
    required this.transverseGradient,
    required this.outlierRatio,
  });

  final List<ControlPointResidual> residuals;

  /// How many secondary markers the geometry declares. Fewer matched than
  /// declared means markers were missed, obscured or corrupted.
  final int expectedControlPoints;

  final double rmsPx;
  final double maximumPx;
  final double medianPx;

  /// Scale of the rectified badge, so residuals can be expressed in
  /// millimetres and compared across capture distances.
  final double pixelsPerMm;

  /// Slope of residual magnitude against canonical x, in px per mm.
  ///
  /// A cylindrical bend about the short axis — the shape a wristband takes —
  /// should show a systematic gradient along one axis and not the other.
  /// A near-zero gradient with a high RMS points instead at print scale error
  /// or a mis-detected marker.
  final double longitudinalGradient;

  /// Slope of residual magnitude against canonical y, in px per mm.
  final double transverseGradient;

  /// Fraction of control points whose residual exceeds three times the median.
  ///
  /// One large residual among small ones is a corrupted or mis-matched marker,
  /// which is a local problem. Uniformly elevated residuals are a global
  /// problem — deformation or scale. The two need different responses, so they
  /// are reported separately rather than averaged into one number.
  final double outlierRatio;

  int get matchedControlPoints => residuals.length;

  double get rmsMm => pixelsPerMm > 0 ? rmsPx / pixelsPerMm : double.nan;
  double get maximumMm =>
      pixelsPerMm > 0 ? maximumPx / pixelsPerMm : double.nan;

  /// Whether enough markers matched for the residual pattern to mean anything.
  bool get hasUsableRedundancy => residuals.length >= 3;

  Map<String, Object?> toJson() => <String, Object?>{
    'expected_control_points': expectedControlPoints,
    'matched_control_points': matchedControlPoints,
    'rms_px': rmsPx,
    'rms_mm': rmsMm,
    'maximum_px': maximumPx,
    'maximum_mm': maximumMm,
    'median_px': medianPx,
    'pixels_per_mm': pixelsPerMm,
    'longitudinal_gradient_px_per_mm': longitudinalGradient,
    'transverse_gradient_px_per_mm': transverseGradient,
    'outlier_ratio': outlierRatio,
    'has_usable_redundancy': hasUsableRedundancy,
    'residuals': residuals.map((r) => r.toJson()).toList(),
  };
}

double _median(List<double> values) {
  if (values.isEmpty) return double.nan;
  final sorted = List<double>.of(values)..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// Ordinary least-squares slope of `y` on `x`. Zero when `x` has no spread.
double _slope(List<double> x, List<double> y) {
  if (x.length < 2) return 0.0;
  final meanX = x.reduce((a, b) => a + b) / x.length;
  final meanY = y.reduce((a, b) => a + b) / y.length;
  var numerator = 0.0, denominator = 0.0;
  for (var i = 0; i < x.length; i++) {
    final dx = x[i] - meanX;
    numerator += dx * (y[i] - meanY);
    denominator += dx * dx;
  }
  return denominator == 0 ? 0.0 : numerator / denominator;
}

/// Estimates the rectified scale of the badge under [homography], in pixels
/// per canonical millimetre.
///
/// Taken as the geometric mean of the two edge scales so that a perspective
/// foreshortening in one direction does not halve the reported figure.
double estimatePixelsPerMm(BadgeGeometry geometry, Homography homography) {
  final origin = homography.mapMm(const PointMm(0, 0));
  final alongX = homography.mapMm(PointMm(geometry.widthMm, 0));
  final alongY = homography.mapMm(PointMm(0, geometry.heightMm));

  final xScale =
      math.sqrt(
        math.pow(alongX.x - origin.x, 2) + math.pow(alongX.y - origin.y, 2),
      ) /
      geometry.widthMm;
  final yScale =
      math.sqrt(
        math.pow(alongY.x - origin.x, 2) + math.pow(alongY.y - origin.y, 2),
      ) /
      geometry.heightMm;
  return math.sqrt(xScale * yScale);
}

/// Validates [homography] against the secondary markers it was **not** fitted
/// to. Directive §8.
///
/// [searchRadiusMm] bounds how far from its predicted position a control point
/// may be found. It is a matching tolerance, not a quality threshold: a marker
/// further away than this is treated as missing rather than as a large
/// residual, because beyond some distance "the marker moved" and "that is a
/// different marker" become indistinguishable.
///
/// **No pass/fail threshold is applied here, and that is deliberate.** What
/// separates acceptable print and handling variation from a badge that should
/// be rejected is a physical quantity about a badge that does not exist yet.
/// Dossier V0 photographs deliberately curved targets to establish it. Until
/// then this function measures and reports; it does not judge.
GeometryValidation validateGeometry({
  required BadgeGeometry geometry,
  required Homography homography,
  required List<Blob> detectedBlobs,
  double searchRadiusMm = 2.0,
}) {
  final pixelsPerMm = estimatePixelsPerMm(geometry, homography);
  final searchRadiusPx = searchRadiusMm * pixelsPerMm;

  final secondaries = geometry.secondaryFiducials;
  final residuals = <ControlPointResidual>[];
  final claimed = <Blob>{};

  for (final fiducial in secondaries) {
    final PointPx predicted;
    try {
      predicted = homography.mapMm(fiducial.centreMm);
    } on Object {
      continue;
    }

    Blob? best;
    var bestDistance = double.infinity;
    for (final blob in detectedBlobs) {
      if (claimed.contains(blob)) continue;
      final dx = blob.centroid.x - predicted.x;
      final dy = blob.centroid.y - predicted.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = blob;
      }
    }

    if (best == null || bestDistance > searchRadiusPx) continue;
    claimed.add(best);
    residuals.add(
      ControlPointResidual(
        fiducialId: fiducial.id,
        expectedMm: fiducial.centreMm,
        predictedPx: predicted,
        observedPx: best.centroid,
      ),
    );
  }

  final magnitudes = <double>[for (final r in residuals) r.magnitudePx];
  final rms = magnitudes.isEmpty
      ? double.nan
      : math.sqrt(
          magnitudes.map((m) => m * m).reduce((a, b) => a + b) /
              magnitudes.length,
        );
  final maximum = magnitudes.isEmpty ? double.nan : magnitudes.reduce(math.max);
  final median = _median(magnitudes);

  final outliers = magnitudes.isEmpty || median <= 0
      ? 0.0
      : magnitudes.where((m) => m > 3 * median).length / magnitudes.length;

  return GeometryValidation(
    residuals: residuals,
    expectedControlPoints: secondaries.length,
    rmsPx: rms,
    maximumPx: maximum,
    medianPx: median,
    pixelsPerMm: pixelsPerMm,
    longitudinalGradient: _slope(<double>[
      for (final r in residuals) r.expectedMm.x,
    ], magnitudes),
    transverseGradient: _slope(<double>[
      for (final r in residuals) r.expectedMm.y,
    ], magnitudes),
    outlierRatio: outliers,
  );
}
