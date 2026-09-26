import 'dart:math' as math;

import 'package:measurement/measurement.dart';

import 'package:test/test.dart';

import '../support/badge_v1.dart';

void main() {
  group('adaptive threshold', () {
    test(
      'survives a strong illumination gradient that defeats a global cut',
      () {
        // A badge lit from one side. Any single global threshold either loses
        // the markers in the shadow or floods the highlight; Bradley compares
        // each pixel to its own neighbourhood instead.
        final image = RgbImage.filled(200, 120, 0, 0, 0);
        for (var y = 0; y < 120; y++) {
          for (var x = 0; x < 200; x++) {
            final ramp = (40 + 200 * x / 200).round().clamp(0, 255);
            image.setPixel(x, y, ramp, ramp, ramp);
          }
        }
        // Two markers: one in the dark end, one in the bright end. Each is 40%
        // darker than its own local background.
        void mark(int cx, int cy) {
          for (var y = cy - 6; y <= cy + 6; y++) {
            for (var x = cx - 6; x <= cx + 6; x++) {
              final v = (image.red(x, y) * 0.35).round();
              image.setPixel(x, y, v, v, v);
            }
          }
        }

        mark(30, 60);
        mark(170, 60);

        final mask = adaptiveThreshold(image);
        expect(mask[60 * 200 + 30], isTrue, reason: 'marker in the shadow');
        expect(mask[60 * 200 + 170], isTrue, reason: 'marker in the highlight');
        expect(mask[60 * 200 + 100], isFalse, reason: 'background is not ink');
      },
    );
  });

  group('the Bradley window constraint', () {
    test('a marker larger than the threshold window is detected as a ring, '
        'not a square', () {
      // Bradley compares each pixel to its own neighbourhood. If the marker is
      // larger than that neighbourhood, the marker's interior becomes its own
      // local background and only the edges survive thresholding.
      //
      // This is a real constraint, not a curiosity: the window is set from the
      // image width, and the marker's size in pixels depends on how close the
      // phone is held. The two are coupled, and an over-close capture breaks
      // detection in a way that looks like a shape-filter failure.
      //
      // It is also a concrete axis on which ArUco and AprilTag should be
      // compared — see research/fiducial-benchmark.md.
      final image = RgbImage.filled(80, 80, 240, 240, 240);
      for (var y = 30; y < 50; y++) {
        for (var x = 30; x < 50; x++) {
          image.setPixel(x, y, 20, 20, 20);
        }
      }

      // Window smaller than the 20 px marker: hollow.
      final tooSmall = findBlobs(
        image,
        adaptiveThreshold(image, windowPixels: 9),
        filter: const BlobFilter(minimumFillRatio: 0.0),
      );
      expect(tooSmall, isNotEmpty);
      expect(
        tooSmall.first.fillRatio,
        lessThan(0.8),
        reason: 'the interior is lost, leaving an outline',
      );

      // Window comfortably larger: solid.
      final adequate = findBlobs(
        image,
        adaptiveThreshold(image, windowPixels: 41),
      );
      expect(adequate, hasLength(1));
      expect(adequate.first.fillRatio, greaterThan(0.95));
    });
  });

  group('the rotated-square fill-ratio floor', () {
    test('a solid square rotated 45 degrees fills half its bounding box', () {
      // Not a quirk of this implementation — it is geometry. The axis-aligned
      // bounding box of a square at angle θ has side s(cosθ + sinθ), so the
      // fill ratio is 1/(cosθ + sinθ)²: 1.0 at 0 degrees, 0.5 at 45.
      //
      // Any acceptance threshold above 0.5 therefore rejects genuine markers
      // over a band of rotations, and does so silently. This test exists
      // because that defect was real here.
      for (final angle in <double>[0.0, 0.3, math.pi / 4, 0.9]) {
        final image = RgbImage.filled(200, 200, 240, 240, 240);
        const half = 30.0;
        final c = math.cos(-angle), sn = math.sin(-angle);
        for (var y = 0; y < 200; y++) {
          for (var x = 0; x < 200; x++) {
            final dx = x - 100.0, dy = y - 100.0;
            final u = c * dx - sn * dy, v = sn * dx + c * dy;
            if (u.abs() <= half && v.abs() <= half) {
              image.setPixel(x, y, 20, 20, 20);
            }
          }
        }
        final blobs = findBlobs(
          image,
          adaptiveThreshold(image, windowPixels: 141),
          filter: const BlobFilter(minimumFillRatio: 0.0),
        );
        expect(blobs, hasLength(1), reason: 'angle $angle');
        final predicted = 1.0 / math.pow(math.cos(angle) + math.sin(angle), 2);
        expect(
          blobs.single.fillRatio,
          closeTo(predicted, 0.05),
          reason: 'angle $angle',
        );
        // And the default filter must accept it.
        expect(
          const BlobFilter().accepts(blobs.single, 200 * 200),
          isTrue,
          reason: 'the default filter must not reject a marker at $angle',
        );
      }
    });

    test('the default fill threshold stays below the 0.5 floor', () {
      expect(const BlobFilter().minimumFillRatio, lessThan(0.5));
    });
  });

  group('blob measurement', () {
    test('finds a square and measures its shape', () {
      final image = RgbImage.filled(80, 80, 240, 240, 240);
      for (var y = 30; y < 50; y++) {
        for (var x = 30; x < 50; x++) {
          image.setPixel(x, y, 20, 20, 20);
        }
      }
      // The window must exceed the marker — see the constraint test below.
      final blobs = findBlobs(
        image,
        adaptiveThreshold(image, windowPixels: 41),
      );
      expect(blobs, hasLength(1));
      final blob = blobs.single;
      expect(blob.centroid.x, closeTo(40.0, 0.5));
      expect(blob.centroid.y, closeTo(40.0, 0.5));
      expect(blob.aspectRatio, closeTo(1.0, 0.1));
      expect(blob.fillRatio, greaterThan(0.9));
    });

    test('rejects a shape that is not marker-like', () {
      // A long thin streak: a cable, a shadow edge, a scratch.
      final image = RgbImage.filled(120, 120, 240, 240, 240);
      for (var y = 58; y < 62; y++) {
        for (var x = 10; x < 110; x++) {
          image.setPixel(x, y, 20, 20, 20);
        }
      }
      expect(
        findBlobs(image, adaptiveThreshold(image, windowPixels: 61)),
        isEmpty,
      );
    });
  });

  group('primary fiducial detection on badge v1', () {
    test('finds and correctly identifies all four corners', () {
      final scene = renderV1();
      final detection = detectPrimaryFiducials(scene.image, badgeV1);
      expect(detection.isOk, isTrue, reason: '${detection.detail}');
      expect(
        detection.primaries.keys,
        containsAll(<String>['FID-TL', 'FID-TR', 'FID-BR', 'FID-BL']),
      );

      // Each detected centroid must land on the true projected position.
      for (final fiducial in badgeV1.primaryFiducials) {
        final truth = scene.homography.mapMm(fiducial.centreMm);
        final found = detection.primaries[fiducial.id]!.centroid;
        expect(
          math.sqrt(
            math.pow(found.x - truth.x, 2) + math.pow(found.y - truth.y, 2),
          ),
          lessThan(1.5),
          reason: '${fiducial.id} centroid',
        );
      }
    });

    test('is not fooled by dark regions larger than the markers', () {
      // Badge v1's sensing window is 11 x 9 mm against 4-5 mm corner markers,
      // so it covers roughly five times a marker's area. Identifying "the
      // four largest dark blobs" would pick it. Identification uses the four
      // candidates enclosing the largest quadrilateral instead, and this test
      // is why that distinction exists.
      final scene = renderV1();
      final detection = detectPrimaryFiducials(scene.image, badgeV1);
      expect(detection.isOk, isTrue, reason: '${detection.detail}');

      final largest = (List<Blob>.of(
        detection.allBlobs,
      )..sort((a, b) => b.pixelCount.compareTo(a.pixelCount))).first;
      final identified = detection.primaries.values.toList();

      expect(
        identified.any((b) => identical(b, largest)),
        isFalse,
        reason: 'the largest dark region must not be taken for a corner',
      );
      expect(
        identified.every((b) => b.pixelCount < largest.pixelCount),
        isTrue,
        reason: 'and every corner marker should in fact be smaller than it',
      );

      // Every identified corner must sit at a real corner.
      for (final fiducial in badgeV1.primaryFiducials) {
        final truth = scene.homography.mapMm(fiducial.centreMm);
        final found = detection.primaries[fiducial.id]!.centroid;
        expect(
          math.sqrt(
            math.pow(found.x - truth.x, 2) + math.pow(found.y - truth.y, 2),
          ),
          lessThan(2.0),
          reason: fiducial.id,
        );
      }
    });

    test('survives rotation', () {
      // A square frame with room to spare: a badge rotated 45 degrees needs a
      // bounding box larger than the badge itself, and running out of frame
      // would fail this test for a reason unrelated to rotation.
      for (final angle in <double>[0.0, 0.3, 0.8, -0.5, 1.4]) {
        final scene = renderV1(
          rotationRadians: angle,
          pixelsPerMm: 10.0,
          width: 800,
          height: 700,
        );
        final detection = detectPrimaryFiducials(scene.image, badgeV1);
        expect(
          detection.isOk,
          isTrue,
          reason: 'angle $angle: ${detection.detail}',
        );
        expect(detection.primaries, hasLength(4));
      }
    });

    test('survives perspective', () {
      final scene = renderV1(perspectiveX: 0.0016, perspectiveY: 0.0011);
      final detection = detectPrimaryFiducials(scene.image, badgeV1);
      expect(detection.isOk, isTrue, reason: '${detection.detail}');

      // And the recovered pose must be good enough to use.
      final estimate = estimateHomography(<Correspondence>[
        for (final f in badgeV1.primaryFiducials)
          Correspondence(f.centreMm, detection.primaries[f.id]!.centroid),
      ]);
      expect(estimate.isOk, isTrue);
      final centre = estimate.homography!.mapMm(const PointMm(27, 17.5));
      final truth = scene.homography.mapMm(const PointMm(27, 17.5));
      expect(
        math.sqrt(
          math.pow(centre.x - truth.x, 2) + math.pow(centre.y - truth.y, 2),
        ),
        lessThan(2.0),
      );
    });

    test('survives scale variation', () {
      for (final scale in <double>[8.0, 12.0, 20.0]) {
        final scene = renderV1(pixelsPerMm: scale);
        final detection = detectPrimaryFiducials(scene.image, badgeV1);
        expect(
          detection.isOk,
          isTrue,
          reason: 'at $scale px/mm: ${detection.detail}',
        );
      }
    });

    test('survives moderate defocus', () {
      final scene = renderV1();
      final detection = detectPrimaryFiducials(blur(scene.image, 2), badgeV1);
      expect(detection.isOk, isTrue, reason: '${detection.detail}');
      expect(detection.primaries, hasLength(4));
    });

    test('survives uneven illumination across the badge', () {
      final scene = renderV1();
      final lit = applyIlluminationGradient(scene.image, 0.45);
      final detection = detectPrimaryFiducials(lit, badgeV1);
      expect(detection.isOk, isTrue, reason: '${detection.detail}');
    });

    test('refuses when a corner marker is occluded, rather than substituting '
        'another blob', () {
      // The detector's worst failure mode, found by benchmarking rather than
      // by reasoning. With a corner covered, the largest-quadrilateral search
      // happily promotes some other blob and returns a pose that fits its own
      // four points perfectly — 100% "detection" with a corner 528 px from
      // truth. A wrong pose is far worse than no pose, because everything
      // downstream then measures the wrong part of the badge and nothing says
      // so.
      //
      // The cross-check against markers withheld from the fit is what catches
      // it. Finding M0B-5.
      for (final fiducial in badgeV1.primaryFiducials) {
        final scene = renderV1();
        final corner = scene.homography.mapMm(fiducial.centreMm);
        occlude(scene.image, corner, 28, 225);

        final detection = detectPrimaryFiducials(scene.image, badgeV1);
        expect(detection.isOk, isFalse, reason: 'occluded ${fiducial.id}');
        expect(
          detection.rejection,
          anyOf(
            DetectionRejection.inconsistentWithGeometry,
            DetectionRejection.markerSizeInconsistent,
            DetectionRejection.insufficientCandidates,
            DetectionRejection.orientationAmbiguous,
            DetectionRejection.degenerateArrangement,
          ),
        );
      }
    });

    test('the geometry cross-check needs withheld markers to work at all', () {
      // A geometry with no secondary markers cannot run the cross-check, and
      // must not pretend it did. This is the demo badge's situation.
      final noSecondaries = BadgeGeometry(
        version: badgeV1.version,
        widthMm: badgeV1.widthMm,
        heightMm: badgeV1.heightMm,
        fiducials: badgeV1.primaryFiducials,
        rois: badgeV1.rois,
      );
      expect(noSecondaries.supportsDeformationValidation, isFalse);

      final scene = renderV1(geometry: noSecondaries);
      expect(detectPrimaryFiducials(scene.image, noSecondaries).isOk, isTrue);
    });

    test('refuses when the orientation marker cannot be told apart', () {
      // All four corners the same size: a square arrangement then has a
      // four-fold rotational ambiguity, and guessing produces a beautifully
      // rectified upside-down badge.
      final uniform = BadgeGeometry(
        version: badgeV1.version,
        widthMm: badgeV1.widthMm,
        heightMm: badgeV1.heightMm,
        fiducials: <FiducialDefinition>[
          for (final f in badgeV1.fiducials)
            FiducialDefinition(
              id: f.id,
              centreMm: f.centreMm,
              sizeMm: f.role == FiducialRole.primary ? 4.0 : f.sizeMm,
              orientationMarker: f.orientationMarker,
              role: f.role,
            ),
        ],
        rois: badgeV1.rois,
      );
      final scene = renderV1(geometry: uniform);
      final detection = detectPrimaryFiducials(scene.image, uniform);
      expect(detection.isOk, isFalse);
      expect(detection.rejection, DetectionRejection.orientationAmbiguous);
    });

    test('refuses a blank frame', () {
      final detection = detectPrimaryFiducials(
        RgbImage.filled(400, 300, 200, 200, 200),
        badgeV1,
      );
      expect(detection.isOk, isFalse);
      expect(detection.rejection, DetectionRejection.insufficientCandidates);
    });

    test('reports the orientation margin as evidence, not as a boolean', () {
      final scene = renderV1();
      final detection = detectPrimaryFiducials(scene.image, badgeV1);
      // FID-TL is 5.0 mm against 4.0 mm, so the side ratio should be near 1.25.
      expect(detection.orientationMargin, greaterThan(1.1));
      expect(detection.orientationMargin, lessThan(1.5));
    });
  });
}
