import 'dart:math' as math;

import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

import '../support/adversarial.dart';
import '../support/badge_v1.dart';

void main() {
  group('the detector must refuse, or be right — never plausibly wrong', () {
    // Finding M0B-5: the failure mode that matters is not a missed badge, it
    // is a confident wrong pose. A refusal costs the worker one retake. A
    // wrong pose puts a number on their health record that was measured from
    // the wrong part of the badge, and nothing downstream can tell.
    //
    // So this suite asserts a one-sided property. It never requires detection
    // to succeed.
    const tolerancePx = 4.0;

    for (final adversarial in adversarialCases()) {
      test('${adversarial.id}: ${adversarial.description}', () {
        final detection = detectPrimaryFiducials(adversarial.image, badgeV1);
        if (!detection.isOk) return; // Refusing is always acceptable.

        for (final fiducial in badgeV1.primaryFiducials) {
          final truth = adversarial.truth.mapMm(fiducial.centreMm);
          final found = detection.primaries[fiducial.id]!.centroid;
          final error = math.sqrt(
            math.pow(found.x - truth.x, 2) + math.pow(found.y - truth.y, 2),
          );
          expect(
            error,
            lessThan(tolerancePx),
            reason:
                'detection claimed success but placed ${fiducial.id} '
                '${error.toStringAsFixed(1)} px from truth. A confident wrong '
                'pose is the failure this suite exists to prevent.',
          );
        }
      });
    }

    test('the set covers every adversarial family', () {
      final ids = adversarialCases().map((c) => c.id).toList();
      expect(ids, hasLength(greaterThanOrEqualTo(14)));
      for (final family in <String>[
        'missing-',
        'half-',
        'decoy-square-',
        'decoy-replacing-missing-corner',
        'background-squares',
        'printed-text',
        'cropped-',
        'glare-over-corner',
        'rotated-with-decoys',
        'occluder-across-corner',
      ]) {
        expect(
          ids.any((id) => id.startsWith(family)),
          isTrue,
          reason: 'missing adversarial family: $family',
        );
      }
    });

    test('a clean badge is still detected, so the suite is not vacuous', () {
      // Guards against "fixing" the adversarial suite by making the detector
      // refuse everything.
      final scene = renderV1();
      expect(detectPrimaryFiducials(scene.image, badgeV1).isOk, isTrue);
    });
  });
}
