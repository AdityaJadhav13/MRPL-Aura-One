import 'dart:io';

import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';
import 'package:test/test.dart';

BadgeGeometry get _geometry => BadgeGeometry.parse(
  File('geometry/demo-badge-v0.geometry.json').readAsStringSync(),
);

({RgbImage image, Homography homography}) _scene({
  Illuminant illuminant = Illuminant.neutral,
  double rotationRadians = 0.0,
  double perspectiveX = 0.0,
  double perspectiveY = 0.0,
  double pixelsPerMm = 16.0,
}) {
  final h = placeBadge(
    pixelsPerMm: pixelsPerMm,
    translateX: 60,
    translateY: 40,
    rotationRadians: rotationRadians,
    perspectiveX: perspectiveX,
    perspectiveY: perspectiveY,
  );
  final image = renderBadge(
    geometry: _geometry,
    badgeToImage: h,
    width: 800,
    height: 520,
    illuminant: illuminant,
  );
  return (image: image, homography: h);
}

/// Recovers the homography the way the pipeline will: from correspondences,
/// not from the renderer's own matrix.
Homography _recovered(Homography truth) {
  final estimate = estimateHomography(
    fiducialCorrespondences(_geometry, truth),
  );
  expect(estimate.isOk, isTrue);
  return estimate.homography!;
}

void main() {
  group('ROI sampling (directive s12)', () {
    test('reads the printed colour of a patch back through the geometry', () {
      final scene = _scene();
      final sample = sampleRoi(
        image: scene.image,
        badgeToImage: _recovered(scene.homography),
        roi: _geometry.roiById('REF-RED')!,
      );

      final expected = SrgbColor.fromBytes(200, 60, 50).toLinear();
      expect(sample.trimmedMeanLinear.r, closeTo(expected.r, 0.01));
      expect(sample.trimmedMeanLinear.g, closeTo(expected.g, 0.01));
      expect(sample.trimmedMeanLinear.b, closeTo(expected.b, 0.01));
      expect(sample.usableFraction, closeTo(1.0, 1e-9));
      expect(sample.roiId, 'REF-RED');
      expect(sample.kind, RoiKind.reference);
    });

    test('is invariant to rotation and perspective', () {
      // The whole point of recovering geometry: the same patch must read the
      // same regardless of how the phone was held.
      final flat = _scene();
      final tilted = _scene(
        rotationRadians: 0.21,
        perspectiveX: 0.0012,
        perspectiveY: 0.0008,
      );

      final a = sampleRoi(
        image: flat.image,
        badgeToImage: _recovered(flat.homography),
        roi: _geometry.roiById('REF-GREEN')!,
      );
      final b = sampleRoi(
        image: tilted.image,
        badgeToImage: _recovered(tilted.homography),
        roi: _geometry.roiById('REF-GREEN')!,
      );

      expect(b.lab.lStar, closeTo(a.lab.lStar, 1.0));
      expect(deltaE2000(a.lab, b.lab), lessThan(1.5));
    });

    test('the sample count is independent of image resolution', () {
      // Sampling happens on a canonical grid in millimetres, so the number of
      // observations is a property of the feature definition, not of the
      // phone's sensor.
      final small = _scene(pixelsPerMm: 10.0);
      final large = _scene(pixelsPerMm: 20.0);
      final a = sampleRoi(
        image: small.image,
        badgeToImage: _recovered(small.homography),
        roi: _geometry.roiById('A1')!,
      );
      final b = sampleRoi(
        image: large.image,
        badgeToImage: _recovered(large.homography),
        roi: _geometry.roiById('A1')!,
      );
      expect(a.requestedSamples, b.requestedSamples);
    });

    test('erosion keeps the neighbouring patch out of the statistic', () {
      // REF-WHITE and REF-BLACK are 0.5 mm apart. Without the erosion margin
      // a small geometry error drags one into the other, and the mean lands
      // between two colours that both exist on the badge.
      final scene = _scene();
      final sample = sampleRoi(
        image: scene.image,
        badgeToImage: _recovered(scene.homography),
        roi: _geometry.roiById('REF-WHITE')!,
      );
      expect(
        sample.linearR.interquartileRange,
        lessThan(0.01),
        reason: 'a patch should read as one colour, not two',
      );
    });

    test('excludes clipped samples instead of averaging them in', () {
      final scene = _scene();
      // Blow out a horizontal band across the sensor window.
      for (var y = 150; y < 190; y++) {
        for (var x = 0; x < scene.image.width; x++) {
          scene.image.setPixel(x, y, 255, 255, 255);
        }
      }
      final sample = sampleRoi(
        image: scene.image,
        badgeToImage: _recovered(scene.homography),
        roi: _geometry.roiById('A1')!,
      );
      expect(sample.exclusions[SampleExclusion.clipped], greaterThan(0));
      expect(sample.usableFraction, lessThan(1.0));
      // The surviving samples still read the true patch colour.
      final expected = SrgbColor.fromBytes(150, 90, 160).toLinear();
      expect(sample.trimmedMeanLinear.r, closeTo(expected.r, 0.02));
    });

    test('counts samples that fall outside the frame rather than clamping', () {
      final h = placeBadge(
        pixelsPerMm: 16.0,
        translateX: -120, // push the left of the badge off-frame
        translateY: 40,
      );
      final image = renderBadge(
        geometry: _geometry,
        badgeToImage: h,
        width: 400,
        height: 520,
      );
      final sample = sampleRoi(
        image: image,
        badgeToImage: h,
        roi: _geometry.roiById('A1')!,
      );
      expect(sample.exclusions[SampleExclusion.outOfFrame], greaterThan(0));
      expect(sample.usableFraction, lessThan(1.0));
    });

    test('throws rather than returning a value when nothing is usable', () {
      final h = placeBadge(
        pixelsPerMm: 16.0,
        translateX: 5000,
        translateY: 5000,
      );
      final image = RgbImage.filled(400, 300, 100, 100, 100);
      expect(
        () => sampleRoi(
          image: image,
          badgeToImage: h,
          roi: _geometry.roiById('A1')!,
        ),
        throwsA(isA<EmptyRoiException>()),
      );
    });

    test('a paper-white reference patch would clip under a warm illuminant', () {
      // Why the demo badge's white patch is 216 and not 242. This test renders
      // the badge with a paper-white patch and shows that every sample in it
      // is lost to clipping, which would leave the colour correction without
      // its brightest anchor.
      final h = placeBadge(pixelsPerMm: 16.0, translateX: 60, translateY: 40);
      final image = renderBadge(
        geometry: _geometry,
        badgeToImage: h,
        width: 800,
        height: 520,
        illuminant: Illuminant.warm,
        colours: <String, List<int>>{
          ...demoBadgeColours,
          'REF-WHITE': <int>[242, 242, 242],
        },
      );
      expect(
        () => sampleRoi(
          image: image,
          badgeToImage: _recovered(h),
          roi: _geometry.roiById('REF-WHITE')!,
        ),
        throwsA(isA<EmptyRoiException>()),
      );

      // The badge as actually specified survives the same illuminant.
      final withHeadroom = renderBadge(
        geometry: _geometry,
        badgeToImage: h,
        width: 800,
        height: 520,
        illuminant: Illuminant.warm,
      );
      final sample = sampleRoi(
        image: withHeadroom,
        badgeToImage: _recovered(h),
        roi: _geometry.roiById('REF-WHITE')!,
      );
      expect(sample.usableFraction, closeTo(1.0, 1e-9));
    });

    test('carries the provisional-guard flag through to the sample', () {
      final scene = _scene();
      final sample = sampleRoi(
        image: scene.image,
        badgeToImage: _recovered(scene.homography),
        roi: _geometry.roiById('B')!,
      );
      expect(
        sample.guardsWereProvisional,
        isTrue,
        reason: 'these thresholds have not been set from real photographs',
      );
    });
  });

  group('the illuminant problem these primitives exist to solve', () {
    test('an illuminant change moves a raw patch reading well beyond the '
        'reference-validation threshold', () {
      // This is the SmART-Form field result in miniature: the same badge,
      // different light, a different answer. Without correction the shift is
      // far larger than the 2.0 dE00 a reference validation would allow.
      final neutral = _scene();
      final warm = _scene(illuminant: Illuminant.warm);

      final a = sampleRoi(
        image: neutral.image,
        badgeToImage: _recovered(neutral.homography),
        roi: _geometry.roiById('A1')!,
      );
      final b = sampleRoi(
        image: warm.image,
        badgeToImage: _recovered(warm.homography),
        roi: _geometry.roiById('A1')!,
      );
      expect(deltaE2000(a.lab, b.lab), greaterThan(5.0));
    });

    test('a correction fitted on the reference patches removes it, and the '
        'withheld patches confirm that', () {
      final warm = _scene(illuminant: Illuminant.warm);
      final homography = _recovered(warm.homography);

      LinearRgb read(String id) => sampleRoi(
        image: warm.image,
        badgeToImage: homography,
        roi: _geometry.roiById(id)!,
      ).trimmedMeanLinear;

      LinearRgb printed(String id) {
        final c = demoBadgeColours[id]!;
        return SrgbColor.fromBytes(c[0], c[1], c[2]).toLinear();
      }

      ReferencePatch patch(String id) =>
          ReferencePatch(id: id, measured: read(id), target: printed(id));

      // Fit on four spanning patches; withhold two neutrals.
      final fit = fitCorrection(<ReferencePatch>[
        patch('REF-WHITE'),
        patch('REF-RED'),
        patch('REF-GREEN'),
        patch('REF-BLUE'),
      ]);
      expect(fit.isOk, isTrue);

      final validation = validateCorrection(
        correction: fit.correction!,
        holdoutPatches: <ReferencePatch>[patch('REF-BLACK'), patch('REF-GREY')],
      );
      expect(validation.leakedPatchIds, isEmpty);
      expect(
        validation.passed,
        isTrue,
        reason: 'residual was ${validation.maximumDeltaE00}',
      );

      // And the sensor patch now reads close to its printed colour.
      final corrected = fit.correction!.apply(read('A1'));
      expect(
        deltaE2000(corrected.toXyz().toLab(), printed('A1').toXyz().toLab()),
        lessThan(2.0),
      );
    });
  });
}
