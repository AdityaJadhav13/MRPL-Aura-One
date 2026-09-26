import 'dart:io';
import 'dart:math' as math;

import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

/// The committed research badge geometry, loaded from the repository.
/// Geometry is data; a test that restates a copy of it is testing a different
/// badge.
final BadgeGeometry badgeV1 = BadgeGeometry.parse(
  File('geometry/badge-v1.geometry.json').readAsStringSync(),
);

typedef Scene = ({RgbImage image, Homography homography, BadgeBend bend});

/// Renders badge v1 into a frame, with a pose and optional distortions.
///
/// The badge is centred in the frame by construction: [translateX] and
/// [translateY] offset it *from* the centre rather than positioning its
/// origin. Rotation is therefore about the badge centre, and a rotated badge
/// stays in frame — otherwise a rotation test fails for reasons that have
/// nothing to do with rotation, which is exactly what happened when this
/// helper positioned the origin instead.
Scene renderV1({
  BadgeGeometry? geometry,
  double pixelsPerMm = 14.0,
  double translateX = 0,
  double translateY = 0,
  double rotationRadians = 0.0,
  double perspectiveX = 0.0,
  double perspectiveY = 0.0,
  Illuminant illuminant = Illuminant.neutral,
  BadgeBend bend = BadgeBend.none,
  int width = 900,
  int height = 620,
}) {
  final g = geometry ?? badgeV1;
  final cx = g.widthMm / 2, cy = g.heightMm / 2;
  final cos = math.cos(rotationRadians), sin = math.sin(rotationRadians);

  // Solve for the translation that puts the badge centre at the frame centre.
  // The perspective terms make the map non-affine, so this is the value the
  // centre would take with no perspective; the residual offset is small for
  // the gentle tilts used in tests and keeps the badge comfortably in frame.
  final targetX = width / 2 + translateX;
  final targetY = height / 2 + translateY;
  final w = perspectiveX * cx + perspectiveY * cy + 1.0;
  final homography = placeBadge(
    pixelsPerMm: pixelsPerMm,
    translateX: targetX * w - pixelsPerMm * (cos * cx - sin * cy),
    translateY: targetY * w - pixelsPerMm * (sin * cx + cos * cy),
    rotationRadians: rotationRadians,
    perspectiveX: perspectiveX,
    perspectiveY: perspectiveY,
  );
  final image = renderBadge(
    geometry: g,
    badgeToImage: homography,
    width: width,
    height: height,
    illuminant: illuminant,
    colours: badgeV1Colours,
    background: const <int>[96, 98, 102],
    bend: bend,
  );
  return (image: image, homography: homography, bend: bend);
}

/// Separable box blur, standing in for defocus.
RgbImage blur(RgbImage source, int radius) {
  final out = RgbImage.filled(source.width, source.height, 0, 0, 0);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      var r = 0, g = 0, b = 0, n = 0;
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          final sx = x + dx, sy = y + dy;
          if (!source.contains(sx, sy)) continue;
          r += source.red(sx, sy);
          g += source.green(sx, sy);
          b += source.blue(sx, sy);
          n++;
        }
      }
      out.setPixel(x, y, r ~/ n, g ~/ n, b ~/ n);
    }
  }
  return out;
}

/// Multiplies brightness across the frame, standing in for a badge lit from
/// one side.
RgbImage applyIlluminationGradient(RgbImage source, double minimumFactor) {
  final out = RgbImage.filled(source.width, source.height, 0, 0, 0);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final factor =
          minimumFactor + (1 - minimumFactor) * (x / (source.width - 1));
      out.setPixel(
        x,
        y,
        (source.red(x, y) * factor).round().clamp(0, 255),
        (source.green(x, y) * factor).round().clamp(0, 255),
        (source.blue(x, y) * factor).round().clamp(0, 255),
      );
    }
  }
  return out;
}

/// Paints a flat patch over part of the frame.
void occlude(RgbImage image, PointPx centre, int radiusPx, int value) {
  for (
    var y = (centre.y - radiusPx).round();
    y <= (centre.y + radiusPx).round();
    y++
  ) {
    for (
      var x = (centre.x - radiusPx).round();
      x <= (centre.x + radiusPx).round();
      x++
    ) {
      if (image.contains(x, y)) image.setPixel(x, y, value, value, value);
    }
  }
}

/// Adds a bright, near-neutral specular blob.
void addGlare(RgbImage image, PointPx centre, double radiusPx) {
  // The core saturates completely, because that is what a real specular
  // highlight does and it is the case the pipeline has to refuse: a clipped
  // channel carries no recoverable information. A gentle falloff that never
  // reaches the rail is a bright patch, not a highlight.
  final core = radiusPx * 0.6;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final d = math.sqrt(
        math.pow(x - centre.x, 2) + math.pow(y - centre.y, 2),
      );
      if (d > radiusPx) continue;
      if (d <= core) {
        image.setPixel(x, y, 255, 255, 255);
        continue;
      }
      final strength = 1.0 - (d - core) / (radiusPx - core);
      int lift(int v) => (v + (255 - v) * strength).round().clamp(0, 255);
      image.setPixel(
        x,
        y,
        lift(image.red(x, y)),
        lift(image.green(x, y)),
        lift(image.blue(x, y)),
      );
    }
  }
}
