import 'dart:math' as math;

import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

import 'badge_v1.dart';

/// One adversarial scene and what the detector must never do with it.
typedef AdversarialCase = ({
  String id,
  String description,
  RgbImage image,
  Homography truth,
});

void _fillRect(RgbImage image, int x0, int y0, int w, int h, List<int> rgb) {
  for (var y = y0; y < y0 + h; y++) {
    for (var x = x0; x < x0 + w; x++) {
      if (image.contains(x, y)) image.setPixel(x, y, rgb[0], rgb[1], rgb[2]);
    }
  }
}

void _square(RgbImage image, PointPx centre, double side, List<int> rgb) {
  final half = side / 2;
  _fillRect(
    image,
    (centre.x - half).round(),
    (centre.y - half).round(),
    side.round(),
    side.round(),
    rgb,
  );
}

const List<int> _ink = <int>[16, 16, 16];
List<int> get _substrate => badgeV1Colours['substrate']!;

/// The permanent wrong-pose regression set.
///
/// Finding M0B-5 was that the detector could return a **confident, wrong**
/// pose: with a corner occluded it promoted another blob and reported 100%
/// detection with a corner 528 px from truth. Everything downstream then
/// samples the wrong part of the badge, and nothing says so.
///
/// These cases exist to keep that fixed. They are generated deterministically
/// rather than committed as image files: the generator plus the expected
/// verdict *is* the fixture, it is diffable, it costs no repository weight,
/// and it can be re-rendered at any scale. `tool/dump_adversarial.dart` writes
/// them out as PPM when someone needs to look at them.
///
/// The required property is **not** "always detect". It is:
///
///   refuse, or be right — never plausibly wrong.
List<AdversarialCase> adversarialCases() {
  final cases = <AdversarialCase>[];

  // 1. Each primary marker missing in turn, painted over with substrate.
  for (final fiducial in badgeV1.primaryFiducials) {
    final scene = renderV1();
    final centre = scene.homography.mapMm(fiducial.centreMm);
    _square(scene.image, centre, 90, _substrate);
    cases.add((
      id: 'missing-${fiducial.id}',
      description: '${fiducial.id} painted over with substrate',
      image: scene.image,
      truth: scene.homography,
    ));
  }

  // 2. A marker half covered — detectable as a blob, but the wrong shape and
  //    the wrong centroid.
  for (final fiducial in <String>['FID-TL', 'FID-BR']) {
    final scene = renderV1();
    final f = badgeV1.fiducials.firstWhere((x) => x.id == fiducial);
    final centre = scene.homography.mapMm(f.centreMm);
    _fillRect(
      scene.image,
      (centre.x - 45).round(),
      (centre.y - 45).round(),
      90,
      45,
      _substrate,
    );
    cases.add((
      id: 'half-$fiducial',
      description: '$fiducial half covered',
      image: scene.image,
      truth: scene.homography,
    ));
  }

  // 3. A decoy square the size of a corner marker, printed outside the badge
  //    where it would enlarge the quadrilateral.
  for (final offset in <PointPx>[
    const PointPx(-120, -90),
    const PointPx(120, 90),
  ]) {
    final scene = renderV1();
    final corner = scene.homography.mapMm(const PointMm(8, 8));
    _square(
      scene.image,
      PointPx(corner.x + offset.x, corner.y + offset.y),
      70,
      _ink,
    );
    cases.add((
      id: 'decoy-square-${offset.x.round()}-${offset.y.round()}',
      description: 'a marker-sized square outside the badge',
      image: scene.image,
      truth: scene.homography,
    ));
  }

  // 4. A missing marker AND a decoy positioned to replace it. The specific
  //    trap M0B-5 fell into.
  {
    final scene = renderV1();
    final f = badgeV1.primaryFiducials.firstWhere((x) => x.id == 'FID-BL');
    final centre = scene.homography.mapMm(f.centreMm);
    _square(scene.image, centre, 90, _substrate);
    _square(scene.image, PointPx(centre.x + 70, centre.y - 55), 56, _ink);
    cases.add((
      id: 'decoy-replacing-missing-corner',
      description: 'FID-BL removed and a decoy offered nearby',
      image: scene.image,
      truth: scene.homography,
    ));
  }

  // 5. Dark rectangles in the background, as a bench edge or printed matter
  //    would appear.
  {
    final scene = renderV1();
    _fillRect(scene.image, 20, 20, 60, 60, _ink);
    _fillRect(scene.image, scene.image.width - 80, 20, 60, 60, _ink);
    _fillRect(scene.image, 20, scene.image.height - 80, 60, 60, _ink);
    _fillRect(
      scene.image,
      scene.image.width - 80,
      scene.image.height - 80,
      60,
      60,
      _ink,
    );
    cases.add((
      id: 'background-squares',
      description: 'four dark squares in the background, outside the badge',
      image: scene.image,
      truth: scene.homography,
    ));
  }

  // 6. Printed text on the badge: many small dark blobs.
  {
    final scene = renderV1();
    final origin = scene.homography.mapMm(const PointMm(12, 21));
    for (var i = 0; i < 14; i++) {
      _fillRect(
        scene.image,
        (origin.x + i * 18).round(),
        origin.y.round(),
        11,
        16,
        _ink,
      );
    }
    cases.add((
      id: 'printed-text',
      description: 'a row of glyph-sized dark blobs on the badge',
      image: scene.image,
      truth: scene.homography,
    ));
  }

  // 7. Badge partly outside the frame.
  for (final shift in <double>[-260, 260]) {
    final scene = renderV1(translateX: shift);
    cases.add((
      id: 'cropped-${shift.round()}',
      description: 'badge running off the edge of the frame',
      image: scene.image,
      truth: scene.homography,
    ));
  }

  // 8. Glare directly over a corner marker.
  {
    final scene = renderV1();
    final corner = scene.homography.mapMm(const PointMm(52, 8));
    addGlare(scene.image, corner, 90);
    cases.add((
      id: 'glare-over-corner',
      description: 'specular highlight covering FID-TR',
      image: scene.image,
      truth: scene.homography,
    ));
  }

  // 9. Rotation combined with decoys — the fill-ratio floor and the decoy
  //    trap at once.
  {
    final scene = renderV1(rotationRadians: math.pi / 4, pixelsPerMm: 9.0);
    _square(scene.image, const PointPx(80, 80), 60, _ink);
    _square(scene.image, PointPx(scene.image.width - 80.0, 80), 60, _ink);
    cases.add((
      id: 'rotated-with-decoys',
      description: 'badge at 45 degrees with marker-sized decoys in frame',
      image: scene.image,
      truth: scene.homography,
    ));
  }

  // 10. A hand-like occluder across one edge.
  {
    final scene = renderV1();
    final corner = scene.homography.mapMm(const PointMm(8, 32));
    _fillRect(
      scene.image,
      (corner.x - 120).round(),
      (corner.y - 40).round(),
      200,
      160,
      <int>[150, 120, 100],
    );
    cases.add((
      id: 'occluder-across-corner',
      description: 'a skin-toned block across the bottom-left corner',
      image: scene.image,
      truth: scene.homography,
    ));
  }

  return cases;
}
