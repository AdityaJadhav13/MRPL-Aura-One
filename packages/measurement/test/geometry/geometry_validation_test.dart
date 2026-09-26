import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';
import 'package:test/test.dart';

import '../support/badge_v1.dart';

/// Fits the pose from the four PRIMARY markers only, exactly as the pipeline
/// does. The secondary markers must stay out of the fit or they cannot
/// validate it.
Homography _poseFromPrimaries(Scene scene, {BadgeGeometry? geometry}) {
  final g = geometry ?? badgeV1;
  final estimate = estimateHomography(
    fiducialCorrespondences(
      g,
      scene.homography,
      bend: scene.bend,
      primariesOnly: true,
    ),
  );
  expect(estimate.isOk, isTrue);
  return estimate.homography!;
}

List<Blob> _blobs(Scene scene) =>
    detectPrimaryFiducials(scene.image, badgeV1).allBlobs;

void main() {
  group('the geometry supports deformation validation at all', () {
    test(
      'badge v1 carries withheld control points; the demo badge does not',
      () {
        expect(badgeV1.primaryFiducials, hasLength(4));
        expect(badgeV1.secondaryFiducials, hasLength(6));
        expect(badgeV1.supportsDeformationValidation, isTrue);

        final v0 = BadgeGeometry.parse(
          badgeV1.toJson().toString().isEmpty ? '' : _demoGeometry,
        );
        expect(v0.secondaryFiducials, isEmpty);
        expect(
          v0.supportsDeformationValidation,
          isFalse,
          reason:
              'a geometry without withheld markers cannot report '
              'deformation, and must not pretend to',
        );
      },
    );
  });

  group('a flat badge', () {
    test('leaves small residuals on the withheld control points', () {
      final scene = renderV1();
      final validation = validateGeometry(
        geometry: badgeV1,
        homography: _poseFromPrimaries(scene),
        detectedBlobs: _blobs(scene),
      );
      expect(validation.hasUsableRedundancy, isTrue);
      expect(validation.matchedControlPoints, 6);
      expect(validation.rmsPx, lessThan(2.0));
      expect(validation.rmsMm, lessThan(0.2));
    });

    test('shows no systematic residual gradient', () {
      final scene = renderV1();
      final validation = validateGeometry(
        geometry: badgeV1,
        homography: _poseFromPrimaries(scene),
        detectedBlobs: _blobs(scene),
      );
      expect(validation.longitudinalGradient.abs(), lessThan(0.05));
      expect(validation.transverseGradient.abs(), lessThan(0.05));
    });

    test('holds under perspective, which is a planar transform', () {
      final scene = renderV1(perspectiveX: 0.0014, perspectiveY: 0.0009);
      final validation = validateGeometry(
        geometry: badgeV1,
        homography: _poseFromPrimaries(scene),
        detectedBlobs: _blobs(scene),
      );
      expect(validation.matchedControlPoints, 6);
      expect(
        validation.rmsPx,
        lessThan(2.0),
        reason: 'perspective is exactly what a homography represents',
      );
    });
  });

  group('a bent badge', () {
    test('is invisible to the four fitting points and visible to the '
        'withheld ones', () {
      const bend = BadgeBend(1.6);
      final scene = renderV1(bend: bend);
      final correspondences = fiducialCorrespondences(
        badgeV1,
        scene.homography,
        bend: bend,
        primariesOnly: true,
      );
      final pose = estimateHomography(correspondences).homography!;

      // The four points the pose was fitted to: residual is zero by
      // construction, and says nothing at all.
      expect(pose.reprojectionRmsPx(correspondences), lessThan(1e-8));

      // The withheld points: this is where the bend shows up.
      final validation = validateGeometry(
        geometry: badgeV1,
        homography: pose,
        detectedBlobs: _blobs(scene),
      );
      expect(validation.rmsPx, greaterThan(5.0));
    });

    test('residual grows with bend amplitude', () {
      double rmsFor(double amplitude) {
        final bend = BadgeBend(amplitude);
        final scene = renderV1(bend: bend);
        return validateGeometry(
          geometry: badgeV1,
          homography: _poseFromPrimaries(scene),
          detectedBlobs: _blobs(scene),
        ).rmsPx;
      }

      final flat = rmsFor(0.0);
      final slight = rmsFor(0.5);
      final pronounced = rmsFor(1.6);
      expect(slight, greaterThan(flat));
      expect(pronounced, greaterThan(slight));
    });

    test('a cylindrical bend leaves a directional residual signature', () {
      // The bend is a half-sine along x, so residual magnitude should vary
      // systematically with position along the badge and far less across it.
      // Telling causes apart from the residual *pattern* is the open research
      // question this instrumentation exists to support.
      final scene = renderV1(bend: const BadgeBend(1.6));
      final validation = validateGeometry(
        geometry: badgeV1,
        homography: _poseFromPrimaries(scene),
        detectedBlobs: _blobs(scene),
      );
      expect(validation.residuals, hasLength(6));
      // Control points near the middle of the long axis move most.
      final middle = validation.residuals
          .firstWhere((r) => r.fiducialId == 'VAL-T')
          .magnitudePx;
      final edge = validation.residuals
          .firstWhere((r) => r.fiducialId == 'VAL-L')
          .magnitudePx;
      expect(middle, greaterThan(edge));
    });

    test('reports no pass or fail, because no tolerance exists yet', () {
      // Deliberate. What separates acceptable print and handling variation
      // from a badge that should be rejected is a physical quantity about a
      // badge that does not exist. Dossier V0 establishes it.
      final scene = renderV1(bend: const BadgeBend(1.6));
      final json = validateGeometry(
        geometry: badgeV1,
        homography: _poseFromPrimaries(scene),
        detectedBlobs: _blobs(scene),
      ).toJson();
      expect(json.keys, isNot(contains('passed')));
      expect(json.keys, isNot(contains('acceptable')));
      expect(json.keys, contains('rms_mm'));
    });
  });

  group('missing and corrupted control points', () {
    test(
      'an obscured control point is reported missing, not as a residual',
      () {
        final scene = renderV1();
        final pose = _poseFromPrimaries(scene);
        final target = scene.homography.mapMm(const PointMm(30, 8));
        occlude(scene.image, target, 22, 238);

        final validation = validateGeometry(
          geometry: badgeV1,
          homography: pose,
          detectedBlobs: _blobs(scene),
        );
        expect(validation.expectedControlPoints, 6);
        expect(validation.matchedControlPoints, lessThan(6));
        expect(
          validation.residuals.map((r) => r.fiducialId),
          isNot(contains('VAL-T')),
        );
      },
    );

    test('scale is reported so residuals can be read in millimetres', () {
      final near = renderV1(pixelsPerMm: 18.0);
      final far = renderV1(pixelsPerMm: 9.0);
      final a = validateGeometry(
        geometry: badgeV1,
        homography: _poseFromPrimaries(near),
        detectedBlobs: _blobs(near),
      );
      final b = validateGeometry(
        geometry: badgeV1,
        homography: _poseFromPrimaries(far),
        detectedBlobs: _blobs(far),
      );
      expect(a.pixelsPerMm, closeTo(18.0, 0.5));
      expect(b.pixelsPerMm, closeTo(9.0, 0.5));
    });
  });
}

const String _demoGeometry = '''
{"version":"demo","width_mm":40,"height_mm":25,
 "fiducials":[
  {"id":"A","centre_mm":[3,3],"size_mm":3,"orientation_marker":true},
  {"id":"B","centre_mm":[37,3],"size_mm":3},
  {"id":"C","centre_mm":[37,22],"size_mm":3},
  {"id":"D","centre_mm":[3,22],"size_mm":3}],
 "rois":[
  {"id":"A1","kind":"sensor","x_mm":6,"y_mm":6,"width_mm":6,"height_mm":6},
  {"id":"R1","kind":"reference","x_mm":14,"y_mm":6,"width_mm":4,"height_mm":4},
  {"id":"R2","kind":"reference","x_mm":20,"y_mm":6,"width_mm":4,"height_mm":4}]}
''';
