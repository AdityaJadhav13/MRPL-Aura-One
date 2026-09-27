import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../imaging/rgb_image.dart';
import 'badge_geometry.dart';
import 'geometry_validation.dart';
import 'homography.dart';

/// A connected dark region found in the image, with the shape statistics used
/// to decide whether it is a marker.
@immutable
final class Blob {
  const Blob({
    required this.centroid,
    required this.pixelCount,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Intensity-weighted centroid, in pixels, at sub-pixel precision.
  final PointPx centroid;

  final int pixelCount;
  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left + 1;
  int get height => bottom - top + 1;

  /// Proportion of the **axis-aligned** bounding box that is filled.
  ///
  /// Note the floor: a solid square rotated 45 degrees fills exactly **half**
  /// its axis-aligned bounding box, since the box grows by sqrt(2) on each
  /// side while the square does not. In general a square at angle θ gives
  /// `1 / (cosθ + sinθ)²`, which is 1.0 at 0 degrees and 0.5 at 45.
  ///
  /// So any acceptance threshold above 0.5 rejects genuine markers at some
  /// rotations, and does it silently — detection simply returns nothing. This
  /// was a real defect here: the threshold was 0.62 and detection failed
  /// completely between roughly 25 and 65 degrees while succeeding at 0, 17
  /// and 80. Finding M0B-4.
  double get fillRatio => pixelCount / (width * height);

  /// Longer side over shorter side. A square marker stays near 1 under
  /// moderate perspective.
  double get aspectRatio => width >= height ? width / height : height / width;

  /// Nominal side length, from the area rather than the bounding box, so a
  /// rotated square is not overstated.
  double get equivalentSide => math.sqrt(pixelCount.toDouble());
}

/// Shape acceptance limits.
///
/// **Provisional.** These are development values chosen to be defensible on
/// rendered fixtures. They have not been set from photographs of a printed
/// badge on a device matrix, and dossier V0 exists to set them.
@immutable
final class BlobFilter {
  const BlobFilter({
    this.minimumPixels = 40,
    this.maximumAreaFraction = 0.25,
    this.maximumAspectRatio = 2.2,
    this.minimumFillRatio = 0.42,
    this.provisional = true,
  });

  final int minimumPixels;

  /// A blob covering more than this fraction of the frame is background, a
  /// shadow or the edge of the table — not a marker.
  final double maximumAreaFraction;

  final double maximumAspectRatio;

  /// Must stay **below 0.5** — see [Blob.fillRatio]. A solid square rotated
  /// 45 degrees fills exactly half its axis-aligned bounding box, so a higher
  /// threshold makes detection fail silently over a band of rotations.
  /// Hollow rings and streaks sit far lower (0.03 to 0.37 in practice), so
  /// there is still ample separation.
  final double minimumFillRatio;
  final bool provisional;

  bool accepts(Blob blob, int imagePixels) =>
      blob.pixelCount >= minimumPixels &&
      blob.pixelCount <= imagePixels * maximumAreaFraction &&
      blob.aspectRatio <= maximumAspectRatio &&
      blob.fillRatio >= minimumFillRatio;
}

/// Why fiducial detection failed.
enum DetectionRejection {
  /// Fewer than four candidate markers survived shape filtering.
  insufficientCandidates,

  /// Four candidates exist but do not form a usable quadrilateral — they are
  /// collinear, or one lies inside the triangle of the others.
  degenerateArrangement,

  /// The orientation marker could not be told from the other three, so the
  /// badge's rotation is ambiguous. A square of identical markers has a
  /// four-fold ambiguity, and guessing produces a sharp rectification of a
  /// badge that is upside down.
  orientationAmbiguous,

  /// A marker was found, but it is not the size the geometry says it is.
  ///
  /// A partly covered marker still forms a blob, and its centroid sits at the
  /// centre of what remains rather than the centre of the marker. Half
  /// coverage of a 4 mm marker displaces it by about 1 mm of badge — enough to
  /// pull a neighbouring patch into an ROI, and the geometry cross-check does
  /// not catch it because the error is small enough that the secondary markers
  /// still land within their matching tolerance. Found by the adversarial
  /// suite. Finding M0C-1.
  markerSizeInconsistent,

  /// Four corners were identified, but the badge's other printed markers are
  /// not where that pose says they should be.
  ///
  /// This catches the detector's worst failure mode. When a corner marker is
  /// occluded, the largest-quadrilateral search happily substitutes some other
  /// blob and returns a **confident, wrong** pose. Benchmarking found exactly
  /// that: 100% "detection" with a corner placed 528 px from truth. A wrong
  /// pose is far worse than no pose, because everything downstream then
  /// measures the wrong part of the badge and nothing says so. Finding M0B-5.
  inconsistentWithGeometry,
}

/// The outcome of looking for the primary fiducials.
@immutable
final class FiducialDetection {
  const FiducialDetection.ok({
    required this.primaries,
    required this.allBlobs,
    required this.orientationMargin,
  }) : rejection = null,
       detail = null;

  const FiducialDetection.rejected(this.rejection, this.detail)
    : primaries = const <String, Blob>{},
      allBlobs = const <Blob>[],
      orientationMargin = 0;

  /// Detected primary markers, keyed by the geometry's fiducial id.
  final Map<String, Blob> primaries;

  /// Every blob that survived shape filtering, including the ones not
  /// identified as primaries. Secondary-marker matching uses these.
  final List<Blob> allBlobs;

  /// How much larger the orientation marker is than the next-largest primary,
  /// as a ratio of equivalent side lengths. Values near 1 mean the marker was
  /// not clearly distinguishable and the rotation is a guess.
  final double orientationMargin;

  final DetectionRejection? rejection;
  final String? detail;

  bool get isOk => rejection == null;
}

/// Computes an integral image of the luma plane, for O(1) window sums.
Float64List _integralLuma(RgbImage image) {
  final w = image.width, h = image.height;
  final integral = Float64List((w + 1) * (h + 1));
  for (var y = 0; y < h; y++) {
    var rowSum = 0.0;
    for (var x = 0; x < w; x++) {
      rowSum += image.luma(x, y);
      integral[(y + 1) * (w + 1) + (x + 1)] =
          integral[y * (w + 1) + (x + 1)] + rowSum;
    }
  }
  return integral;
}

/// Bradley–Roth adaptive threshold.
///
/// A global threshold fails on exactly the images we care about: a badge lit
/// from one side has a bright half and a dark half, and any single cut point
/// either loses markers in the shadow or floods the highlight. Bradley
/// compares each pixel to the mean of its own neighbourhood instead, which is
/// what makes it survive uneven illumination.
///
/// Returns true where the pixel is *darker* than its neighbourhood by more
/// than [tolerance], i.e. marker ink.
List<bool> adaptiveThreshold(
  RgbImage image, {
  int? windowPixels,
  double tolerance = 0.12,
}) {
  final w = image.width, h = image.height;
  final integral = _integralLuma(image);
  // The classic heuristic: a window about an eighth of the image width.
  final window = windowPixels ?? math.max(3, (w / 8).round());
  final half = window ~/ 2;

  final mask = List<bool>.filled(w * h, false);
  for (var y = 0; y < h; y++) {
    final y0 = math.max(0, y - half);
    final y1 = math.min(h - 1, y + half);
    for (var x = 0; x < w; x++) {
      final x0 = math.max(0, x - half);
      final x1 = math.min(w - 1, x + half);
      final count = (x1 - x0 + 1) * (y1 - y0 + 1);
      final sum =
          integral[(y1 + 1) * (w + 1) + (x1 + 1)] -
          integral[y0 * (w + 1) + (x1 + 1)] -
          integral[(y1 + 1) * (w + 1) + x0] +
          integral[y0 * (w + 1) + x0];
      final mean = sum / count;
      mask[y * w + x] = image.luma(x, y) < mean - tolerance;
    }
  }
  return mask;
}

/// Finds connected dark regions in [mask] and measures them.
///
/// Eight-connectivity, iterative flood fill — recursion would overflow the
/// stack on a large blob, which is a failure mode that only appears on real
/// photographs.
List<Blob> findBlobs(
  RgbImage image,
  List<bool> mask, {
  BlobFilter filter = const BlobFilter(),
}) {
  final w = image.width, h = image.height;
  final visited = List<bool>.filled(w * h, false);
  final blobs = <Blob>[];
  final stack = <int>[];

  for (var start = 0; start < w * h; start++) {
    if (!mask[start] || visited[start]) continue;

    stack
      ..clear()
      ..add(start);
    visited[start] = true;

    var count = 0;
    var left = w, top = h, right = -1, bottom = -1;
    var weightSum = 0.0, weightedX = 0.0, weightedY = 0.0;

    while (stack.isNotEmpty) {
      final index = stack.removeLast();
      final x = index % w;
      final y = index ~/ w;

      count++;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;

      // Weight by darkness, so the centroid is pulled toward the marker's
      // solid core rather than sitting at the middle of a ragged edge. This
      // is what gives sub-pixel precision.
      final weight = 1.0 - image.luma(x, y);
      weightSum += weight;
      weightedX += weight * (x + 0.5);
      weightedY += weight * (y + 0.5);

      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final n = ny * w + nx;
          if (mask[n] && !visited[n]) {
            visited[n] = true;
            stack.add(n);
          }
        }
      }
    }

    final blob = Blob(
      centroid: weightSum > 0
          ? PointPx(weightedX / weightSum, weightedY / weightSum)
          : PointPx((left + right) / 2 + 0.5, (top + bottom) / 2 + 0.5),
      pixelCount: count,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
    if (filter.accepts(blob, w * h)) blobs.add(blob);
  }
  return blobs;
}

/// Twice the signed area of the polygon: positive for counter-clockwise order
/// in a y-down image coordinate system.
double _signedArea(List<PointPx> points) {
  var total = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    total += a.x * b.y - b.x * a.y;
  }
  return total;
}

/// The four candidates whose centroids enclose the largest quadrilateral.
///
/// The badge's corner fiducials are, by construction, its extreme points, and
/// extreme points are what maximise enclosed area. This is why identification
/// does not take the four *largest blobs*: a dark sensing window or a black
/// reference patch is routinely larger than a corner marker, and on badge v1
/// the sensing window is three times a corner marker's area.
///
/// The four points are sorted into angular order **before** the area is
/// measured. Without that, an index-ordered quadruple can describe a
/// self-intersecting bowtie whose shoelace area is smaller than the simple
/// quadrilateral on the same four points — so the true corners lose to a worse
/// set. This function was written without the sort, and that is exactly what
/// happened: three corners and a reference patch beat the four corners.
List<int> _largestQuadrilateral(List<PointPx> points) {
  if (points.length < 4) return const <int>[];
  var bestArea = -1.0;
  var best = const <int>[];
  for (var a = 0; a < points.length - 3; a++) {
    for (var b = a + 1; b < points.length - 2; b++) {
      for (var c = b + 1; c < points.length - 1; c++) {
        for (var d = c + 1; d < points.length; d++) {
          final quad = <PointPx>[points[a], points[b], points[c], points[d]];
          var cx = 0.0, cy = 0.0;
          for (final p in quad) {
            cx += p.x;
            cy += p.y;
          }
          cx /= 4;
          cy /= 4;
          quad.sort(
            (p, q) => math
                .atan2(p.y - cy, p.x - cx)
                .compareTo(math.atan2(q.y - cy, q.x - cx)),
          );
          final area = _signedArea(quad).abs();
          if (area > bestArea) {
            bestArea = area;
            best = <int>[a, b, c, d];
          }
        }
      }
    }
  }
  return best;
}

/// Detects the primary fiducials of [geometry] in [image].
///
/// Strategy, and why: the badge is ours, so this is a bounded problem. The
/// four primaries are the largest square-ish dark blobs; the orientation
/// marker is deliberately printed larger than the other three (badge-v1 design
/// rule R2), which breaks the four-fold rotational ambiguity of a square
/// arrangement without needing an encoded marker.
///
/// That size trick is a design decision on probation. If the benchmark in
/// `research/fiducial-benchmark.md` selects ArUco or AprilTag, orientation
/// comes from the marker's identity instead and this function is replaced
/// rather than patched.
FiducialDetection detectPrimaryFiducials(
  RgbImage image,
  BadgeGeometry geometry, {
  BlobFilter filter = const BlobFilter(),
  double tolerance = 0.12,
  double minimumOrientationMargin = 1.06,
  int maximumCandidates = 40,
  List<double> windowFractions = const <double>[0.125, 0.0625, 0.25, 0.04],
  double secondaryToleranceMm = 1.5,
  double minimumSecondaryAgreement = 0.6,
  double minimumMarkerAreaRatio = 0.62,
  double maximumMarkerAreaRatio = 1.9,
}) {
  final primaries = geometry.primaryFiducials;
  if (primaries.length < 4) {
    return const FiducialDetection.rejected(
      DetectionRejection.insufficientCandidates,
      'geometry declares fewer than four primary fiducials',
    );
  }

  // Sweep the threshold window rather than fixing it, because the right
  // window is pinned between two constraints that pull in opposite
  // directions and neither is known before the badge is found:
  //
  //   * it must EXCEED the marker, or the marker's interior becomes its own
  //     local background and only a hollow outline survives;
  //   * it must be smaller than twice the badge's quiet zone, or the dark rim
  //     that adaptive thresholding produces against a dark background reaches
  //     inward far enough to merge with the corner markers, making the whole
  //     badge one connected component that the area filter then discards.
  //
  // Both depend on how large the badge is in frame, which is what detection
  // is trying to establish. A short sweep resolves the circularity; the first
  // window that yields a valid four-corner detection wins.
  //
  // This coupling is a property of adaptive-threshold blob detection, not of
  // this code, and it is one of the sharper arguments for a mature square
  // fiducial library. It is a named axis in research/fiducial-benchmark.md.
  FiducialDetection? lastFailure;
  for (final fraction in windowFractions) {
    final window = math.max(9, (image.width * fraction).round() | 1);
    final attempt = _detectWithWindow(
      image,
      geometry,
      primaries,
      filter: filter,
      tolerance: tolerance,
      window: window,
      minimumOrientationMargin: minimumOrientationMargin,
      maximumCandidates: maximumCandidates,
      secondaryToleranceMm: secondaryToleranceMm,
      minimumSecondaryAgreement: minimumSecondaryAgreement,
      minimumMarkerAreaRatio: minimumMarkerAreaRatio,
      maximumMarkerAreaRatio: maximumMarkerAreaRatio,
    );
    if (attempt.isOk) return attempt;
    lastFailure = attempt;
  }
  return lastFailure!;
}

FiducialDetection _detectWithWindow(
  RgbImage image,
  BadgeGeometry geometry,
  List<FiducialDefinition> primaries, {
  required BlobFilter filter,
  required double tolerance,
  required int window,
  required double minimumOrientationMargin,
  required int maximumCandidates,
  required double secondaryToleranceMm,
  required double minimumSecondaryAgreement,
  required double minimumMarkerAreaRatio,
  required double maximumMarkerAreaRatio,
}) {
  final mask = adaptiveThreshold(
    image,
    tolerance: tolerance,
    windowPixels: window,
  );
  final blobs = findBlobs(image, mask, filter: filter);
  if (blobs.length < 4) {
    return FiducialDetection.rejected(
      DetectionRejection.insufficientCandidates,
      'only ${blobs.length} blob(s) survived shape filtering '
      'at window ${window}px',
    );
  }

  // Cap the search so the O(n^4) selection stays bounded on a cluttered frame.
  // The corner markers are never the smallest things detected, so keeping the
  // largest candidates cannot lose them.
  final searchSet =
      (List<Blob>.of(blobs)
            ..sort((a, b) => b.pixelCount.compareTo(a.pixelCount)))
          .take(maximumCandidates)
          .toList();

  final quadIndices = _largestQuadrilateral(<PointPx>[
    for (final b in searchSet) b.centroid,
  ]);
  if (quadIndices.length != 4) {
    return const FiducialDetection.rejected(
      DetectionRejection.degenerateArrangement,
      'no four candidates enclose a quadrilateral',
    );
  }
  final candidates = <Blob>[for (final i in quadIndices) searchSet[i]];

  // Order them cyclically around their own centroid.
  var cx = 0.0, cy = 0.0;
  for (final b in candidates) {
    cx += b.centroid.x;
    cy += b.centroid.y;
  }
  cx /= 4;
  cy /= 4;

  candidates.sort(
    (a, b) => math
        .atan2(a.centroid.y - cy, a.centroid.x - cx)
        .compareTo(math.atan2(b.centroid.y - cy, b.centroid.x - cx)),
  );

  final ordered = <PointPx>[for (final b in candidates) b.centroid];
  final area = _signedArea(ordered).abs();
  // A genuine quadrilateral encloses a meaningful area relative to its own
  // extent. Collinear points enclose almost none.
  var spread = 0.0;
  for (var i = 0; i < 4; i++) {
    for (var j = i + 1; j < 4; j++) {
      final dx = ordered[i].x - ordered[j].x;
      final dy = ordered[i].y - ordered[j].y;
      spread = math.max(spread, dx * dx + dy * dy);
    }
  }
  if (spread <= 0 || area / spread < 0.15) {
    return FiducialDetection.rejected(
      DetectionRejection.degenerateArrangement,
      'the four candidates do not enclose a usable quadrilateral',
    );
  }

  // Which candidate is the orientation marker? The largest one, provided it is
  // clearly larger than the next.
  final bySize = List<Blob>.of(candidates)
    ..sort((a, b) => b.equivalentSide.compareTo(a.equivalentSide));
  final margin = bySize[1].equivalentSide == 0
      ? 0.0
      : bySize[0].equivalentSide / bySize[1].equivalentSide;
  if (margin < minimumOrientationMargin) {
    return FiducialDetection.rejected(
      DetectionRejection.orientationAmbiguous,
      'orientation marker is only ${margin.toStringAsFixed(3)}x the next '
      'largest; rotation cannot be resolved',
    );
  }

  final orientationIndex = candidates.indexOf(bySize.first);

  // The geometry's primaries, in the same cyclic sense, starting from its own
  // orientation marker.
  final geometryOrder = List<FiducialDefinition>.of(primaries);
  var gx = 0.0, gy = 0.0;
  for (final f in geometryOrder) {
    gx += f.centreMm.x;
    gy += f.centreMm.y;
  }
  gx /= geometryOrder.length;
  gy /= geometryOrder.length;
  geometryOrder.sort(
    (a, b) => math
        .atan2(a.centreMm.y - gy, a.centreMm.x - gx)
        .compareTo(math.atan2(b.centreMm.y - gy, b.centreMm.x - gx)),
  );

  final geometryOrientationIndex = geometryOrder.indexWhere(
    (f) => f.orientationMarker,
  );
  if (geometryOrientationIndex < 0) {
    return const FiducialDetection.rejected(
      DetectionRejection.orientationAmbiguous,
      'geometry declares no primary orientation marker',
    );
  }

  // Both lists are ordered by angle in the same (image y-down) sense, so
  // aligning the orientation markers aligns everything.
  final matched = <String, Blob>{};
  for (var i = 0; i < 4; i++) {
    final geometryFiducial = geometryOrder[(geometryOrientationIndex + i) % 4];
    final blob = candidates[(orientationIndex + i) % 4];
    matched[geometryFiducial.id] = blob;
  }

  // Cross-check the pose against markers that had no say in it. A corner
  // substituted for an occluded one produces a pose that fits its own four
  // points perfectly and puts everything else in the wrong place.
  final secondaries = geometry.secondaryFiducials;
  {
    final estimate = estimateHomography(<Correspondence>[
      for (final f in primaries)
        if (matched.containsKey(f.id))
          Correspondence(f.centreMm, matched[f.id]!.centroid),
    ]);
    if (!estimate.isOk) {
      return const FiducialDetection.rejected(
        DetectionRejection.degenerateArrangement,
        'the identified corners do not yield a usable pose',
      );
    }

    final scale = estimatePixelsPerMm(geometry, estimate.homography!);

    // Does each marker have the area its declared size implies? A partly
    // covered marker does not, and its centroid is displaced by roughly half
    // the missing extent.
    //
    // The expected area is computed by projecting the marker's own square
    // through the pose, NOT from a single global pixels-per-mm. Under
    // perspective a marker on the far side of the badge is legitimately
    // smaller, and a global scale would reject it for being exactly what it
    // should be.
    for (final f in primaries) {
      final blob = matched[f.id];
      if (blob == null) continue;
      final half = f.sizeMm / 2;
      final projected = <PointPx>[
        estimate.homography!.mapMm(
          PointMm(f.centreMm.x - half, f.centreMm.y - half),
        ),
        estimate.homography!.mapMm(
          PointMm(f.centreMm.x + half, f.centreMm.y - half),
        ),
        estimate.homography!.mapMm(
          PointMm(f.centreMm.x + half, f.centreMm.y + half),
        ),
        estimate.homography!.mapMm(
          PointMm(f.centreMm.x - half, f.centreMm.y + half),
        ),
      ];
      final expectedArea = _signedArea(projected).abs() / 2.0;
      if (expectedArea <= 0) continue;
      final ratio = blob.pixelCount / expectedArea;
      if (ratio < minimumMarkerAreaRatio || ratio > maximumMarkerAreaRatio) {
        return FiducialDetection.rejected(
          DetectionRejection.markerSizeInconsistent,
          '${f.id} covers ${(ratio * 100).toStringAsFixed(0)}% of the area its '
          '${f.sizeMm} mm size implies; it is probably partly covered, and a '
          'partly covered marker reports a displaced centre',
        );
      }
    }

    if (secondaries.length < 3) {
      return FiducialDetection.ok(
        primaries: matched,
        allBlobs: blobs,
        orientationMargin: margin,
      );
    }
    final tolerancePx = math.max(4.0, secondaryToleranceMm * scale);
    var agreeing = 0;
    for (final f in secondaries) {
      final predicted = estimate.homography!.mapMm(f.centreMm);
      for (final blob in blobs) {
        final dx = blob.centroid.x - predicted.x;
        final dy = blob.centroid.y - predicted.y;
        if (math.sqrt(dx * dx + dy * dy) <= tolerancePx) {
          agreeing++;
          break;
        }
      }
    }

    final required = (secondaries.length * minimumSecondaryAgreement).ceil();
    if (agreeing < required) {
      return FiducialDetection.rejected(
        DetectionRejection.inconsistentWithGeometry,
        'only $agreeing of ${secondaries.length} secondary markers are where '
        'this pose predicts (needed $required); one of the identified corners '
        'is probably not a corner',
      );
    }
  }

  return FiducialDetection.ok(
    primaries: matched,
    allBlobs: blobs,
    orientationMargin: margin,
  );
}
