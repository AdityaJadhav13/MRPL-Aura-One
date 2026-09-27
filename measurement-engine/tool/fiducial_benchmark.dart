// Measures the custom DoseBand fiducial detector across a condition matrix.
//
//   dart run tool/fiducial_benchmark.dart
//
// Synthetic fixtures only. These numbers describe the detector on rendered
// badges under synthetic distortions; they say nothing about photographs, and
// the same harness must be re-run on dossier V0 images before any detector is
// selected. See research/fiducial-benchmark.md.

import 'dart:io';
import 'dart:math' as math;

import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

final BadgeGeometry geometry = BadgeGeometry.parse(
  File('geometry/badge-v1.geometry.json').readAsStringSync(),
);

({RgbImage image, Homography homography}) scene({
  double pixelsPerMm = 12.0,
  double rotationRadians = 0,
  double perspectiveX = 0,
  double perspectiveY = 0,
  double translateX = 0,
  double translateY = 0,
  Illuminant illuminant = Illuminant.neutral,
  int width = 900,
  int height = 700,
  List<int> background = const <int>[96, 98, 102],
}) {
  final cx = geometry.widthMm / 2, cy = geometry.heightMm / 2;
  final c = math.cos(rotationRadians), s = math.sin(rotationRadians);
  final w = perspectiveX * cx + perspectiveY * cy + 1.0;
  final h = placeBadge(
    pixelsPerMm: pixelsPerMm,
    translateX: (width / 2 + translateX) * w - pixelsPerMm * (c * cx - s * cy),
    translateY: (height / 2 + translateY) * w - pixelsPerMm * (s * cx + c * cy),
    rotationRadians: rotationRadians,
    perspectiveX: perspectiveX,
    perspectiveY: perspectiveY,
  );
  return (
    image: renderBadge(
      geometry: geometry,
      badgeToImage: h,
      width: width,
      height: height,
      illuminant: illuminant,
      colours: badgeV1Colours,
      background: background,
    ),
    homography: h,
  );
}

RgbImage blur(RgbImage src, int r) {
  final out = RgbImage.filled(src.width, src.height, 0, 0, 0);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      var rr = 0, gg = 0, bb = 0, n = 0;
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (!src.contains(x + dx, y + dy)) continue;
          rr += src.red(x + dx, y + dy);
          gg += src.green(x + dx, y + dy);
          bb += src.blue(x + dx, y + dy);
          n++;
        }
      }
      out.setPixel(x, y, rr ~/ n, gg ~/ n, bb ~/ n);
    }
  }
  return out;
}

RgbImage gradient(RgbImage src, double minimum) {
  final out = RgbImage.filled(src.width, src.height, 0, 0, 0);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final f = minimum + (1 - minimum) * (x / (src.width - 1));
      out.setPixel(
        x,
        y,
        (src.red(x, y) * f).round().clamp(0, 255),
        (src.green(x, y) * f).round().clamp(0, 255),
        (src.blue(x, y) * f).round().clamp(0, 255),
      );
    }
  }
  return out;
}

void glare(RgbImage image, double cx, double cy, double radius) {
  final core = radius * 0.6;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
      if (d > radius) continue;
      if (d <= core) {
        image.setPixel(x, y, 255, 255, 255);
        continue;
      }
      final t = 1.0 - (d - core) / (radius - core);
      int lift(int v) => (v + (255 - v) * t).round().clamp(0, 255);
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

/// Simulates worn or under-inked printing: markers fade toward the substrate.
RgbImage degradePrint(RgbImage src, double fade) {
  final out = RgbImage.filled(src.width, src.height, 0, 0, 0);
  final substrate = badgeV1Colours['substrate']!;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      int mix(int v, int s) => (v + (s - v) * fade).round().clamp(0, 255);
      out.setPixel(
        x,
        y,
        mix(src.red(x, y), substrate[0]),
        mix(src.green(x, y), substrate[1]),
        mix(src.blue(x, y), substrate[2]),
      );
    }
  }
  return out;
}

({bool ok, double errorPx, int micros}) trial(
  RgbImage image,
  Homography truth,
) {
  final watch = Stopwatch()..start();
  final detection = detectPrimaryFiducials(image, geometry);
  watch.stop();
  if (!detection.isOk) {
    return (ok: false, errorPx: double.nan, micros: watch.elapsedMicroseconds);
  }
  var worst = 0.0;
  for (final f in geometry.primaryFiducials) {
    final expected = truth.mapMm(f.centreMm);
    final found = detection.primaries[f.id]!.centroid;
    final d = math.sqrt(
      math.pow(found.x - expected.x, 2) + math.pow(found.y - expected.y, 2),
    );
    if (d > worst) worst = d;
  }
  return (ok: true, errorPx: worst, micros: watch.elapsedMicroseconds);
}

void report(String condition, List<({bool ok, double errorPx, int micros})> t) {
  final detected = t.where((r) => r.ok).toList();
  final rate = detected.length / t.length;
  final worst = detected.isEmpty
      ? double.nan
      : detected.map((r) => r.errorPx).reduce(math.max);
  final median = (t.map((r) => r.micros).toList()..sort())[t.length ~/ 2];
  stdout.writeln(
    '| ${condition.padRight(34)} | ${t.length.toString().padLeft(5)} '
    '| ${(rate * 100).toStringAsFixed(0).padLeft(5)}% '
    '| ${detected.isEmpty ? "  n/a" : worst.toStringAsFixed(2).padLeft(5)} '
    '| ${(median / 1000).toStringAsFixed(0).padLeft(5)} |',
  );
}

void main() {
  stdout.writeln(
    '| Condition                           | Cases | Found '
    '| Worst centroid err (px) | Median ms |',
  );
  stdout.writeln('|---|---|---|---|---|');

  report('nominal', <({bool ok, double errorPx, int micros})>[
    for (final ppm in <double>[10, 12, 14, 16])
      trial(scene(pixelsPerMm: ppm).image, scene(pixelsPerMm: ppm).homography),
  ]);

  report('rotation 0 to 90 deg', <({bool ok, double errorPx, int micros})>[
    for (var i = 0; i <= 12; i++)
      () {
        final a = i * math.pi / 24;
        final s = scene(rotationRadians: a);
        return trial(s.image, s.homography);
      }(),
  ]);

  report('perspective (tilt)', <({bool ok, double errorPx, int micros})>[
    for (final p in <double>[0.0005, 0.001, 0.002, 0.003, 0.004])
      () {
        final s = scene(perspectiveX: p, perspectiveY: p * 0.6);
        return trial(s.image, s.homography);
      }(),
  ]);

  report('scale 8 to 20 px/mm', <({bool ok, double errorPx, int micros})>[
    for (final ppm in <double>[8, 10, 12, 14, 16, 18, 20])
      () {
        // Size the frame to the badge. A fixed frame would clip the badge at
        // the larger scales and the sweep would measure framing, not scale.
        final width = (geometry.widthMm * ppm * 1.25).round();
        final height = (geometry.heightMm * ppm * 1.9).round();
        final s = scene(pixelsPerMm: ppm, width: width, height: height);
        return trial(s.image, s.homography);
      }(),
  ]);

  report('defocus (box blur r=1..4)', <({bool ok, double errorPx, int micros})>[
    for (final r in <int>[1, 2, 3, 4])
      () {
        final s = scene();
        return trial(blur(s.image, r), s.homography);
      }(),
  ]);

  report('uneven illumination', <({bool ok, double errorPx, int micros})>[
    for (final m in <double>[0.7, 0.55, 0.4, 0.3, 0.2])
      () {
        final s = scene();
        return trial(gradient(s.image, m), s.homography);
      }(),
  ]);

  report('glare over the badge', <({bool ok, double errorPx, int micros})>[
    for (final r in <double>[60, 100, 140, 180])
      () {
        final s = scene();
        glare(s.image, s.image.width / 2, s.image.height / 2, r);
        return trial(s.image, s.homography);
      }(),
  ]);

  report('one corner occluded', <({bool ok, double errorPx, int micros})>[
    for (final f in geometry.primaryFiducials)
      () {
        final s = scene();
        final p = s.homography.mapMm(f.centreMm);
        for (var y = (p.y - 28).round(); y <= (p.y + 28).round(); y++) {
          for (var x = (p.x - 28).round(); x <= (p.x + 28).round(); x++) {
            if (s.image.contains(x, y)) {
              s.image.setPixel(x, y, 225, 223, 219);
            }
          }
        }
        return trial(s.image, s.homography);
      }(),
  ]);

  report('print degradation (fade)', <({bool ok, double errorPx, int micros})>[
    for (final f in <double>[0.2, 0.4, 0.6, 0.8])
      () {
        final s = scene();
        return trial(degradePrint(s.image, f), s.homography);
      }(),
  ]);

  report('dark background', <({bool ok, double errorPx, int micros})>[
    for (final bg in <List<int>>[
      <int>[10, 10, 10],
      <int>[40, 40, 40],
      <int>[96, 98, 102],
      <int>[200, 200, 200],
    ])
      () {
        final s = scene(background: bg);
        return trial(s.image, s.homography);
      }(),
  ]);

  report('warm / cool illuminant', <({bool ok, double errorPx, int micros})>[
    for (final i in <Illuminant>[
      Illuminant.neutral,
      Illuminant.warm,
      Illuminant.cool,
    ])
      () {
        final s = scene(illuminant: i);
        return trial(s.image, s.homography);
      }(),
  ]);
}
