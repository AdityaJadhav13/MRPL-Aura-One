import 'package:meta/meta.dart';

import '../geometry/badge_geometry.dart';
import '../geometry/fiducial_detector.dart';
import '../geometry/geometry_validation.dart';
import '../geometry/homography.dart';
import '../imaging/rgb_image.dart';
import '../quality/image_quality.dart';

/// What to tell the worker right now.
///
/// Deliberately a small, ordered vocabulary of **actions**, not measurements.
/// A worker at the end of a shift needs to know which way to move the phone;
/// "Laplacian variance 41.2" is not that, and a number on screen invites
/// someone to decide for themselves that it is good enough.
enum GuidanceState {
  badgeNotFound,
  moveCloser,
  moveFarther,
  moveLeft,
  moveRight,
  moveUp,
  moveDown,
  holdParallel,
  reduceGlare,
  improveLighting,
  holdSteady,
  ready;

  /// Whether this state permits auto-capture to arm.
  bool get isReady => this == GuidanceState.ready;
}

/// Acquisition limits used to turn measurements into guidance.
///
/// **Every value here is provisional.** They are development thresholds chosen
/// to be defensible on rendered fixtures, not empirical ones set from
/// photographs on a device matrix. Dossier V0 exists to replace them, and
/// [provisional] is carried into every result so nothing downstream can mistake
/// a provisional pass for a validated one.
@immutable
final class AcquisitionLimits {
  const AcquisitionLimits({
    this.minimumPixelsPerMm = 8.0,
    this.maximumPixelsPerMm = 40.0,
    this.maximumCentreOffsetFraction = 0.16,
    this.maximumTiltRatio = 1.25,
    this.maximumHighClipFraction = 0.02,
    this.maximumSpecularFraction = 0.01,
    this.minimumLumaMean = 0.18,
    this.maximumLumaMean = 0.92,
    this.minimumLaplacianVariance = 1.0e-4,
    this.provisional = true,
  });

  /// Below this the badge is too small in frame to resolve the ROIs; above it
  /// the badge risks overflowing the frame and the threshold window stops
  /// exceeding the marker size.
  final double minimumPixelsPerMm;
  final double maximumPixelsPerMm;

  /// How far the badge centre may sit from the frame centre, as a fraction of
  /// frame width.
  final double maximumCentreOffsetFraction;

  /// Ratio of the longer to the shorter projected badge edge. A badge viewed
  /// square-on gives 1; foreshortening raises it.
  final double maximumTiltRatio;

  final double maximumHighClipFraction;
  final double maximumSpecularFraction;
  final double minimumLumaMean;
  final double maximumLumaMean;

  /// Sharpness floor. Scale-dependent, so it is only meaningful alongside the
  /// pixels-per-mm this frame achieved — which is why both are reported.
  final double minimumLaplacianVariance;

  final bool provisional;
}

/// One frame's assessment.
@immutable
final class GuidanceAssessment {
  const GuidanceAssessment({
    required this.state,
    required this.badgeFound,
    required this.limitsWereProvisional,
    this.pixelsPerMm,
    this.tiltRatio,
    this.centreOffsetFraction,
    this.quality,
    this.homography,
    this.detection,
  });

  final GuidanceState state;
  final bool badgeFound;

  /// True whenever [AcquisitionLimits.provisional] was set, which it is.
  final bool limitsWereProvisional;

  final double? pixelsPerMm;
  final double? tiltRatio;
  final double? centreOffsetFraction;
  final ImageQuality? quality;
  final Homography? homography;
  final FiducialDetection? detection;

  Map<String, Object?> toJson() => <String, Object?>{
    'state': state.name,
    'badge_found': badgeFound,
    'limits_were_provisional': limitsWereProvisional,
    'pixels_per_mm': pixelsPerMm,
    'tilt_ratio': tiltRatio,
    'centre_offset_fraction': centreOffsetFraction,
    'quality': quality?.toJson(),
  };
}

/// Assesses one preview frame and says what the worker should do.
///
/// **This is guidance, not measurement.** A preview frame may be a different
/// resolution, a different crop and a different processing path from the still
/// the camera finally delivers, so nothing decided here may stand in for the
/// authoritative checks run on the captured image. Directive §11; the split is
/// enforced by this function returning a [GuidanceState] and never a
/// measurement result.
GuidanceAssessment assessFrame({
  required RgbImage frame,
  required BadgeGeometry geometry,
  AcquisitionLimits limits = const AcquisitionLimits(),
}) {
  final detection = detectPrimaryFiducials(frame, geometry);
  if (!detection.isOk) {
    return GuidanceAssessment(
      state: GuidanceState.badgeNotFound,
      badgeFound: false,
      limitsWereProvisional: limits.provisional,
      detection: detection,
    );
  }

  final estimate = estimateHomography(<Correspondence>[
    for (final f in geometry.primaryFiducials)
      Correspondence(f.centreMm, detection.primaries[f.id]!.centroid),
  ]);
  if (!estimate.isOk) {
    return GuidanceAssessment(
      state: GuidanceState.badgeNotFound,
      badgeFound: false,
      limitsWereProvisional: limits.provisional,
      detection: detection,
    );
  }
  final homography = estimate.homography!;

  final scale = estimatePixelsPerMm(geometry, homography);
  final corners = <PointPx>[
    homography.mapMm(const PointMm(0, 0)),
    homography.mapMm(PointMm(geometry.widthMm, 0)),
    homography.mapMm(PointMm(geometry.widthMm, geometry.heightMm)),
    homography.mapMm(PointMm(0, geometry.heightMm)),
  ];

  double edge(PointPx a, PointPx b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return (dx * dx + dy * dy);
  }

  // Opposite edges of a square-on badge project to equal lengths; tilt makes
  // one pair shorter than the other.
  final top = edge(corners[0], corners[1]);
  final bottom = edge(corners[3], corners[2]);
  final left = edge(corners[0], corners[3]);
  final right = edge(corners[1], corners[2]);
  final horizontal = (top > bottom ? top / bottom : bottom / top);
  final vertical = (left > right ? left / right : right / left);
  final tilt = horizontal > vertical ? horizontal : vertical;

  var cx = 0.0, cy = 0.0;
  for (final c in corners) {
    cx += c.x;
    cy += c.y;
  }
  cx /= 4;
  cy /= 4;
  final offsetX = (cx - frame.width / 2) / frame.width;
  final offsetY = (cy - frame.height / 2) / frame.width;
  final offset = offsetX.abs() > offsetY.abs() ? offsetX.abs() : offsetY.abs();

  final quality = measureImageQuality(frame);

  GuidanceAssessment at(GuidanceState state) => GuidanceAssessment(
    state: state,
    badgeFound: true,
    limitsWereProvisional: limits.provisional,
    pixelsPerMm: scale,
    tiltRatio: tilt,
    centreOffsetFraction: offset,
    quality: quality,
    homography: homography,
    detection: detection,
  );

  // Ordered so the worker is asked to fix one thing at a time, framing first:
  // moving the phone changes the lighting, so telling someone to reduce glare
  // before they have framed the badge wastes the instruction.
  if (scale < limits.minimumPixelsPerMm) return at(GuidanceState.moveCloser);
  if (scale > limits.maximumPixelsPerMm) return at(GuidanceState.moveFarther);

  if (offset > limits.maximumCentreOffsetFraction) {
    // Guidance names where the PHONE should move. A badge sitting right of
    // frame centre is centred by moving the phone right, toward it.
    if (offsetX.abs() >= offsetY.abs()) {
      return at(offsetX > 0 ? GuidanceState.moveRight : GuidanceState.moveLeft);
    }
    return at(offsetY > 0 ? GuidanceState.moveDown : GuidanceState.moveUp);
  }

  if (tilt > limits.maximumTiltRatio) return at(GuidanceState.holdParallel);

  if (quality.specularFraction > limits.maximumSpecularFraction ||
      quality.highClipFraction > limits.maximumHighClipFraction) {
    return at(GuidanceState.reduceGlare);
  }

  if (quality.luma.mean < limits.minimumLumaMean ||
      quality.luma.mean > limits.maximumLumaMean) {
    return at(GuidanceState.improveLighting);
  }

  if (!quality.laplacianVariance.isFinite ||
      quality.laplacianVariance < limits.minimumLaplacianVariance) {
    return at(GuidanceState.holdSteady);
  }

  return at(GuidanceState.ready);
}
