import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

import '../support/badge_v1.dart';

GuidanceAssessment _assess(Scene scene) =>
    assessFrame(frame: scene.image, geometry: badgeV1);

void main() {
  group('guidance reads as actions, not measurements', () {
    test('a well-framed badge is ready', () {
      final assessment = _assess(renderV1());
      expect(assessment.state, GuidanceState.ready);
      expect(assessment.badgeFound, isTrue);
      expect(assessment.state.isReady, isTrue);
    });

    test('every state is an instruction a worker can act on', () {
      // Directive §8: do not expose raw technical metrics to ordinary
      // workers. The vocabulary is the contract; a state named after a metric
      // would leak one.
      for (final state in GuidanceState.values) {
        expect(state.name, isNot(contains('variance')));
        expect(state.name, isNot(contains('laplacian')));
        expect(state.name, isNot(contains('residual')));
        expect(state.name, isNot(contains('homography')));
      }
    });

    test('carries the provisional flag so a pass cannot be overstated', () {
      expect(_assess(renderV1()).limitsWereProvisional, isTrue);
    });
  });

  group('framing', () {
    test('too far away asks the worker to move closer', () {
      final assessment = _assess(renderV1(pixelsPerMm: 5.0));
      expect(
        assessment.state,
        anyOf(GuidanceState.moveCloser, GuidanceState.badgeNotFound),
      );
    });

    test('too close asks the worker to move farther', () {
      final scene = renderV1(pixelsPerMm: 45.0, width: 2900, height: 2000);
      final assessment = assessFrame(frame: scene.image, geometry: badgeV1);
      expect(
        assessment.state,
        anyOf(GuidanceState.moveFarther, GuidanceState.badgeNotFound),
      );
    });

    test('an off-centre badge is steered toward the middle', () {
      // Scale chosen so the badge still fits the frame when offset; a badge
      // running off the edge loses corners and fails for a different reason.
      GuidanceAssessment offset({double x = 0, double y = 0}) =>
          _assess(renderV1(pixelsPerMm: 9.0, translateX: x, translateY: y));

      final right = offset(x: 170);
      expect(
        right.state,
        GuidanceState.moveRight,
        reason:
            'a badge right of centre is centred by moving the phone '
            'toward it',
      );

      final left = offset(x: -170);
      expect(left.state, GuidanceState.moveLeft);

      final down = offset(y: 165);
      expect(down.state, GuidanceState.moveDown);

      final up = offset(y: -165);
      expect(up.state, GuidanceState.moveUp);
    });

    test('a tilted badge is asked to be held parallel', () {
      final assessment = _assess(
        renderV1(perspectiveX: 0.0055, perspectiveY: 0.0),
      );
      expect(assessment.state, GuidanceState.holdParallel);
      expect(assessment.tiltRatio, greaterThan(1.25));
    });

    test('an empty frame reports the badge as not found', () {
      final assessment = assessFrame(
        frame: RgbImage.filled(600, 400, 180, 180, 180),
        geometry: badgeV1,
      );
      expect(assessment.state, GuidanceState.badgeNotFound);
      expect(assessment.badgeFound, isFalse);
      expect(assessment.homography, isNull);
    });
  });

  group('lighting', () {
    test('a specular highlight asks the worker to reduce glare', () {
      final scene = renderV1();
      addGlare(scene.image, PointPx(scene.image.width / 2, 210), 150);
      expect(_assess(scene).state, GuidanceState.reduceGlare);
    });

    test('a dim frame asks for better lighting', () {
      final scene = renderV1();
      final dim = RgbImage.filled(
        scene.image.width,
        scene.image.height,
        0,
        0,
        0,
      );
      for (var y = 0; y < scene.image.height; y++) {
        for (var x = 0; x < scene.image.width; x++) {
          dim.setPixel(
            x,
            y,
            (scene.image.red(x, y) * 0.12).round(),
            (scene.image.green(x, y) * 0.12).round(),
            (scene.image.blue(x, y) * 0.12).round(),
          );
        }
      }
      final assessment = assessFrame(frame: dim, geometry: badgeV1);
      expect(
        assessment.state,
        anyOf(GuidanceState.improveLighting, GuidanceState.badgeNotFound),
      );
    });

    test('framing is corrected before lighting', () {
      // Moving the phone changes the lighting, so asking someone to reduce
      // glare before they have framed the badge wastes the instruction.
      final scene = renderV1(pixelsPerMm: 9.0, translateX: 170);
      // Glare over the middle of the badge, not over its corners: the point
      // is that framing wins over lighting, not that the badge disappears.
      addGlare(scene.image, PointPx(scene.image.width / 2, 300), 95);
      expect(_assess(scene).state, GuidanceState.moveRight);
    });
  });

  group('the preview/still boundary', () {
    test('assessment yields guidance and never a measurement result', () {
      // Directive §11: a preview frame may differ from the still in
      // resolution, crop, exposure and colour pipeline, so nothing decided
      // here may stand in for the checks run on the captured image. The type
      // has nowhere to put a result.
      final json = _assess(renderV1()).toJson();
      expect(json.keys, isNot(contains('dose')));
      expect(json.keys, isNot(contains('result')));
      expect(json.keys, contains('state'));
    });
  });
}
