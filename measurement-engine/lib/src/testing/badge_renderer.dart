import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../measurement.dart';

/// The printed colours of the artificial demo badge, as 8-bit sRGB.
///
/// These are **arbitrary and carry no chemical meaning**. They exist so the
/// deterministic pipeline has something to measure. The real badge's patch
/// values will be spectrophotometer measurements of an actual print lot.
const Map<String, List<int>> demoBadgeColours = <String, List<int>>{
  'substrate': <int>[235, 233, 228],
  'fiducial': <int>[18, 18, 18],
  'A1': <int>[150, 90, 160],
  'B': <int>[152, 92, 158],
  'E': <int>[120, 170, 120],
  'QR': <int>[30, 30, 30],
  // Deliberately NOT paper-white. A 242-level white patch has only ~5%
  // headroom, and a warm illuminant drives its red channel past the sensor
  // rail before anything else on the badge is in trouble. The correction then
  // loses its brightest anchor exactly when it is most needed.
  //
  // This was found by a test, not by reasoning: see the clipping test in
  // test/features/roi_sample_test.dart. Real reference targets leave the same
  // headroom for the same reason.
  'REF-WHITE': <int>[216, 216, 216],
  'REF-BLACK': <int>[26, 26, 26],
  'REF-GREY': <int>[128, 128, 128],
  'REF-RED': <int>[200, 60, 50],
  'REF-GREEN': <int>[60, 160, 80],
  'REF-BLUE': <int>[55, 75, 190],
};

/// The printed colours of the research badge V1.
///
/// **Arbitrary, and not frozen.** Real reference values must be measured on a
/// real print lot with a spectrophotometer; design-space values are not
/// physical colour ground truth (`research/dossier-v0.md` §15).
///
/// Two design rules are visible here:
///
/// - **REF-LIGHT is 205, not 245.** Design rule R3: a near-white patch clips
///   its red channel under a warm illuminant before anything else on the badge
///   is in trouble, which costs the colour correction its brightest anchor
///   exactly when it is most needed.
/// - **Six chromatic patches, not just neutrals.** Design rule R4: neutrals are
///   collinear in RGB and constrain gain but not channel mixing, and channel
///   mixing is precisely what an illuminant change does.
const Map<String, List<int>> badgeV1Colours = <String, List<int>>{
  // The substrate carries headroom for the same reason REF-LIGHT does
  // (design rule R3), and for a second reason: it is most of the badge's
  // area, so when it clips it dominates the frame's clipped-pixel fraction
  // and trips the acquisition gate even though no analytical region is
  // affected. A near-white badge stock would make every warm-lit capture
  // report glare.
  'substrate': <int>[225, 223, 219],
  'fiducial': <int>[16, 16, 16],
  'A1': <int>[150, 90, 160],
  'B': <int>[152, 92, 158],
  'E': <int>[120, 170, 120],
  'QR': <int>[28, 28, 28],
  'REF-BLACK': <int>[24, 24, 24],
  'REF-DARK': <int>[72, 72, 72],
  'REF-MID': <int>[128, 128, 128],
  'REF-LIGHT': <int>[205, 205, 205],
  'REF-RED': <int>[196, 62, 52],
  'REF-GREEN': <int>[62, 158, 82],
  'REF-BLUE': <int>[58, 78, 186],
  'REF-CYAN': <int>[60, 160, 170],
  'REF-MAGENTA': <int>[170, 66, 140],
  'REF-YELLOW': <int>[200, 180, 60],
};

/// A simulated out-of-plane bow, expressed as a displacement in canonical
/// badge space before the pose is applied.
///
/// A wristband curls about its short axis, so points near the middle of the
/// long axis are displaced most and the ends not at all. Modelled as a half
/// sine along x:
///
///     bent(x, y) = (x, y + amplitude * sin(pi * x / width))
///
/// This is **analytically invertible**, which is what lets the renderer stay
/// an inverse warp with no holes and no resampling artefacts. It is a
/// stand-in for a real bend, not a mechanical model of one, and it exists to
/// produce a residual signature that the geometry validation must be able to
/// see.
@immutable
final class BadgeBend {
  const BadgeBend(this.amplitudeMm);

  static const BadgeBend none = BadgeBend(0.0);

  final double amplitudeMm;

  bool get isFlat => amplitudeMm == 0.0;

  PointMm apply(PointMm p, double widthMm) => amplitudeMm == 0.0
      ? p
      : PointMm(p.x, p.y + amplitudeMm * math.sin(math.pi * p.x / widthMm));

  PointMm undo(PointMm p, double widthMm) => amplitudeMm == 0.0
      ? p
      : PointMm(p.x, p.y - amplitudeMm * math.sin(math.pi * p.x / widthMm));
}

/// A per-channel multiplicative gain applied in **linear light**, standing in
/// for a change of illuminant.
///
/// This is a first-order model of a colour-temperature change and is
/// deliberately simple: it is exactly the kind of distortion a fitted 3x3 or
/// affine correction should be able to remove, which makes it the right
/// stimulus for testing that the correction works. It is **not** a model of a
/// real illuminant's spectrum, and a correction that handles it is not
/// thereby shown to handle metamerism.
final class Illuminant {
  const Illuminant(this.name, this.gainR, this.gainG, this.gainB);

  static const Illuminant neutral = Illuminant('neutral', 1.0, 1.0, 1.0);
  static const Illuminant warm = Illuminant('warm', 1.18, 1.0, 0.76);
  static const Illuminant cool = Illuminant('cool', 0.86, 1.0, 1.22);

  final String name;
  final double gainR;
  final double gainG;
  final double gainB;

  SrgbColor apply(SrgbColor input) {
    final linear = input.toLinear();
    return LinearRgb(
      linear.r * gainR,
      linear.g * gainG,
      linear.b * gainB,
    ).toSrgb();
  }
}

/// Renders the badge described by [geometry] into an image of the given size,
/// placed by [badgeToImage].
///
/// Rendering is an **inverse warp**: for each output pixel, map back into
/// canonical badge millimetres and look up what is there. That leaves no holes
/// and no resampling artefacts, and it means the fixture's geometry is exactly
/// the homography recorded alongside it rather than an approximation of it.
RgbImage renderBadge({
  required BadgeGeometry geometry,
  required Homography badgeToImage,
  required int width,
  required int height,
  Illuminant illuminant = Illuminant.neutral,
  Map<String, List<int>> colours = demoBadgeColours,
  List<int> background = const <int>[64, 66, 70],
  BadgeBend bend = BadgeBend.none,
}) {
  final image = RgbImage.filled(
    width,
    height,
    background[0],
    background[1],
    background[2],
  );
  final imageToBadge = badgeToImage.invert();

  SrgbColor? colourAtMm(PointMm p) {
    if (p.x < 0 ||
        p.y < 0 ||
        p.x > geometry.widthMm ||
        p.y > geometry.heightMm) {
      return null;
    }
    for (final f in geometry.fiducials) {
      final half = f.sizeMm / 2;
      if ((p.x - f.centreMm.x).abs() <= half &&
          (p.y - f.centreMm.y).abs() <= half) {
        final c = colours['fiducial']!;
        return SrgbColor.fromBytes(c[0], c[1], c[2]);
      }
    }
    for (final roi in geometry.rois) {
      if (roi.containsMm(p)) {
        final c = colours[roi.id];
        if (c == null) continue;
        return SrgbColor.fromBytes(c[0], c[1], c[2]);
      }
    }
    final c = colours['substrate']!;
    return SrgbColor.fromBytes(c[0], c[1], c[2]);
  }

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      // Sample at the pixel centre.
      // Inverse warp: pixel -> (bent) badge space -> true printed position.
      final bentPoint = imageToBadge.mapToMm(PointPx(x + 0.5, y + 0.5));
      final badgePoint = bend.undo(bentPoint, geometry.widthMm);
      final colour = colourAtMm(badgePoint);
      if (colour == null) continue;
      final lit = illuminant.apply(colour);
      image.setPixel(x, y, _toByte(lit.r), _toByte(lit.g), _toByte(lit.b));
    }
  }
  return image;
}

int _toByte(double channel) {
  final v = (channel * 255.0).round();
  return v < 0 ? 0 : (v > 255 ? 255 : v);
}

/// Builds a homography placing the badge in frame with a given scale,
/// translation, rotation and out-of-plane tilt.
Homography placeBadge({
  required double pixelsPerMm,
  required double translateX,
  required double translateY,
  double rotationRadians = 0.0,
  double perspectiveX = 0.0,
  double perspectiveY = 0.0,
}) {
  final c = math.cos(rotationRadians);
  final s = math.sin(rotationRadians);
  return Homography(
    Matrix.fromRows(<List<double>>[
      <double>[pixelsPerMm * c, -pixelsPerMm * s, translateX],
      <double>[pixelsPerMm * s, pixelsPerMm * c, translateY],
      <double>[perspectiveX, perspectiveY, 1.0],
    ]),
    nullSpaceMargin: double.infinity,
  );
}

/// The four fiducial centres as correspondences under [badgeToImage].
///
/// This stands in for the fiducial *detector*, which is not part of M0A. The
/// detector is a separate problem, and giving the geometry stage exact
/// correspondences here keeps the two concerns testable apart: a failure in
/// these tests is a failure of the geometry maths, never of blob detection.
List<Correspondence> fiducialCorrespondences(
  BadgeGeometry geometry,
  Homography badgeToImage, {
  BadgeBend bend = BadgeBend.none,
  bool primariesOnly = false,
}) {
  final source = primariesOnly ? geometry.primaryFiducials : geometry.fiducials;
  return <Correspondence>[
    for (final f in source)
      Correspondence(
        // Pairs the marker's TRUE printed position with where a bent badge
        // actually puts it in the image. That mismatch is the whole point: it
        // is what a deformation check has to detect.
        f.centreMm,
        badgeToImage.mapMm(bend.apply(f.centreMm, geometry.widthMm)),
      ),
  ];
}
