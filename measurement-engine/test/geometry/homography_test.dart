import 'dart:math' as math;

import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

/// The four badge corners of a 40 x 25 mm badge, as a convenient test source.
const List<PointMm> _badgeCorners = <PointMm>[
  PointMm(3, 3),
  PointMm(37, 3),
  PointMm(37, 22),
  PointMm(3, 22),
];

List<Correspondence> _through(Matrix h, List<PointMm> source) {
  final transform = Homography(h, nullSpaceMargin: 1);
  return <Correspondence>[
    for (final p in source) Correspondence(p, transform.mapMm(p)),
  ];
}

Matrix _matrix(List<List<double>> rows) => Matrix.fromRows(rows);

void main() {
  group('homography estimation (directive s8)', () {
    test('recovers a pure scale and translation', () {
      final truth = _matrix(<List<double>>[
        <double>[12.0, 0.0, 100.0],
        <double>[0.0, 12.0, 50.0],
        <double>[0.0, 0.0, 1.0],
      ]);
      final estimate = estimateHomography(_through(truth, _badgeCorners));
      expect(estimate.isOk, isTrue);

      for (final p in _badgeCorners) {
        final expected = Homography(truth, nullSpaceMargin: 1).mapMm(p);
        final actual = estimate.homography!.mapMm(p);
        expect(actual.x, closeTo(expected.x, 1e-8));
        expect(actual.y, closeTo(expected.y, 1e-8));
      }
    });

    test('recovers a rotation', () {
      const angle = 0.37;
      final truth = _matrix(<List<double>>[
        <double>[9 * math.cos(angle), -9 * math.sin(angle), 220.0],
        <double>[9 * math.sin(angle), 9 * math.cos(angle), 180.0],
        <double>[0.0, 0.0, 1.0],
      ]);
      final correspondences = _through(truth, _badgeCorners);
      final estimate = estimateHomography(correspondences);
      expect(estimate.isOk, isTrue);
      expect(
        estimate.homography!.reprojectionRmsPx(correspondences),
        lessThan(1e-7),
      );
    });

    test('recovers a genuine perspective transform', () {
      // Non-zero bottom row: the badge is tilted away from the sensor plane.
      final truth = _matrix(<List<double>>[
        <double>[11.2, 0.9, 140.0],
        <double>[-0.7, 10.4, 95.0],
        <double>[0.0022, 0.0014, 1.0],
      ]);
      final correspondences = _through(truth, _badgeCorners);
      final estimate = estimateHomography(correspondences);
      expect(estimate.isOk, isTrue);
      expect(
        estimate.homography!.reprojectionRmsPx(correspondences),
        lessThan(1e-6),
      );

      // And it must hold for points that were not correspondences.
      final interior = const PointMm(20, 12);
      final expected = Homography(truth, nullSpaceMargin: 1).mapMm(interior);
      final actual = estimate.homography!.mapMm(interior);
      expect(actual.x, closeTo(expected.x, 1e-6));
      expect(actual.y, closeTo(expected.y, 1e-6));
    });

    test('inverts to map image pixels back to badge millimetres', () {
      final truth = _matrix(<List<double>>[
        <double>[11.2, 0.9, 140.0],
        <double>[-0.7, 10.4, 95.0],
        <double>[0.0022, 0.0014, 1.0],
      ]);
      final estimate = estimateHomography(_through(truth, _badgeCorners));
      final forward = estimate.homography!;
      final inverse = forward.invert();

      for (final p in <PointMm>[...(_badgeCorners), const PointMm(19, 11)]) {
        final px = forward.mapMm(p);
        final back = inverse.mapToMm(px);
        expect(back.x, closeTo(p.x, 1e-6));
        expect(back.y, closeTo(p.y, 1e-6));
      }
    });

    test('refuses fewer than four correspondences', () {
      final truth = _matrix(<List<double>>[
        <double>[10.0, 0.0, 0.0],
        <double>[0.0, 10.0, 0.0],
        <double>[0.0, 0.0, 1.0],
      ]);
      final estimate = estimateHomography(
        _through(truth, _badgeCorners.take(3).toList()),
      );
      expect(estimate.isOk, isFalse);
      expect(
        estimate.rejection,
        HomographyRejection.insufficientCorrespondences,
      );
      expect(estimate.homography, isNull);
    });

    test('refuses collinear correspondences', () {
      // Four fiducials that happen to lie on a line do not constrain a plane.
      // Solving anyway produces a transform that rectifies beautifully and is
      // wrong, which is undetectable further down the pipeline.
      final collinear = <Correspondence>[
        for (var i = 0; i < 4; i++)
          Correspondence(
            PointMm(5.0 * i, 5.0 * i),
            PointPx(50.0 * i, 50.0 * i),
          ),
      ];
      final estimate = estimateHomography(collinear);
      expect(estimate.isOk, isFalse);
      expect(estimate.rejection, HomographyRejection.degenerateConfiguration);
    });

    test('refuses coincident correspondences', () {
      final coincident = <Correspondence>[
        for (var i = 0; i < 4; i++)
          const Correspondence(PointMm(5, 5), PointPx(50, 50)),
      ];
      expect(estimateHomography(coincident).isOk, isFalse);
    });

    test('four correspondences always fit exactly, so the residual carries '
        'no information about planarity', () {
      // Eight equations, eight degrees of freedom. A homography can be fitted
      // through ANY four point correspondences with zero residual, including
      // four points that could not possibly lie on a common plane.
      //
      // This matters: `docs/computer-vision/pipeline.md` describes the
      // reprojection residual as the check that catches a bent badge. With a
      // bare four-fiducial layout it cannot, because it is identically zero.
      // Detecting non-planarity requires an over-determined fit.
      final truth = _matrix(<List<double>>[
        <double>[11.0, 0.0, 120.0],
        <double>[0.0, 11.0, 80.0],
        <double>[0.0, 0.0, 1.0],
      ]);
      final flat = _through(truth, _badgeCorners);
      final bent = <Correspondence>[
        flat[0],
        Correspondence(
          flat[1].badge,
          PointPx(flat[1].image.x + 4.0, flat[1].image.y - 2.5),
        ),
        Correspondence(
          flat[2].badge,
          PointPx(flat[2].image.x + 4.0, flat[2].image.y + 2.5),
        ),
        flat[3],
      ];
      final estimate = estimateHomography(bent);
      expect(estimate.isOk, isTrue);
      expect(
        estimate.homography!.reprojectionRmsPx(bent),
        lessThan(1e-8),
        reason: 'four points are always fitted exactly',
      );
    });

    test('reprojection error does reveal non-planarity once the fit is '
        'over-determined', () {
      final truth = _matrix(<List<double>>[
        <double>[11.0, 0.0, 120.0],
        <double>[0.0, 11.0, 80.0],
        <double>[0.0, 0.0, 1.0],
      ]);
      final points = <PointMm>[
        ..._badgeCorners,
        const PointMm(20, 3),
        const PointMm(20, 22),
      ];
      final flat = _through(truth, points);
      final flatEstimate = estimateHomography(flat);
      expect(flatEstimate.homography!.reprojectionRmsPx(flat), lessThan(1e-8));

      // Curl the badge along one axis: the mid-edge points bow out of plane.
      final bent = <Correspondence>[
        ...flat.take(4),
        Correspondence(
          flat[4].badge,
          PointPx(flat[4].image.x, flat[4].image.y - 6.0),
        ),
        Correspondence(
          flat[5].badge,
          PointPx(flat[5].image.x, flat[5].image.y + 6.0),
        ),
      ];
      final bentEstimate = estimateHomography(bent);
      expect(bentEstimate.isOk, isTrue);
      expect(
        bentEstimate.homography!.reprojectionRmsPx(bent),
        greaterThan(1.0),
        reason: 'a planar transform cannot fit a curved surface',
      );
    });

    test('is stable under Hartley normalisation with large pixel values', () {
      // Badge coordinates are single-digit millimetres; image coordinates are
      // thousands of pixels. Without normalisation the DLT design matrix mixes
      // the two scales and the solve is dominated by rounding.
      final truth = _matrix(<List<double>>[
        <double>[95.0, 1.2, 2400.0],
        <double>[-1.1, 94.0, 1750.0],
        <double>[0.0009, 0.0007, 1.0],
      ]);
      final correspondences = _through(truth, _badgeCorners);
      final estimate = estimateHomography(correspondences);
      expect(estimate.isOk, isTrue);
      expect(
        estimate.homography!.reprojectionRmsPx(correspondences),
        lessThan(1e-5),
      );
    });

    test('accepts more than four correspondences and fits them jointly', () {
      final truth = _matrix(<List<double>>[
        <double>[11.2, 0.9, 140.0],
        <double>[-0.7, 10.4, 95.0],
        <double>[0.0022, 0.0014, 1.0],
      ]);
      final many = _through(truth, <PointMm>[
        ..._badgeCorners,
        const PointMm(20, 3),
        const PointMm(20, 22),
      ]);
      final estimate = estimateHomography(many);
      expect(estimate.isOk, isTrue);
      expect(estimate.homography!.reprojectionRmsPx(many), lessThan(1e-6));
    });
  });

  group('linear algebra', () {
    test('symmetric eigen-decomposition reproduces a known spectrum', () {
      final a = Matrix.fromRows(<List<double>>[
        <double>[4, 1, 0],
        <double>[1, 3, 1],
        <double>[0, 1, 2],
      ]);
      final eigen = symmetricEigen(a);

      // Eigenvalues ascending, and their sum is the trace.
      expect(eigen.values[0], lessThan(eigen.values[1]));
      expect(eigen.values[1], lessThan(eigen.values[2]));
      expect(eigen.values.reduce((x, y) => x + y), closeTo(9.0, 1e-10));

      // A v = lambda v, for each pair.
      for (var i = 0; i < 3; i++) {
        final v = Matrix.fromRows(<List<double>>[
          for (final c in eigen.vectors.column(i)) <double>[c],
        ]);
        final av = a.multiply(v);
        for (var r = 0; r < 3; r++) {
          expect(av.at(r, 0), closeTo(eigen.values[i] * v.at(r, 0), 1e-9));
        }
      }
    });

    test('eigenvectors are unit length and sign-stabilised', () {
      final a = Matrix.fromRows(<List<double>>[
        <double>[2, -1],
        <double>[-1, 2],
      ]);
      final eigen = symmetricEigen(a);
      for (var i = 0; i < 2; i++) {
        final v = eigen.vectors.column(i);
        final norm = math.sqrt(v.fold<double>(0, (s, x) => s + x * x));
        expect(norm, closeTo(1.0, 1e-12));
        // The first significant component is positive, so two runs — or two
        // languages — cannot disagree merely about an arbitrary sign.
        expect(v.firstWhere((x) => x.abs() > 1e-12), greaterThan(0));
      }
    });

    test('solve refuses a singular system rather than returning a guess', () {
      final singular = Matrix.fromRows(<List<double>>[
        <double>[1, 2],
        <double>[2, 4],
      ]);
      final rhs = Matrix.fromRows(<List<double>>[
        <double>[1],
        <double>[2],
      ]);
      expect(
        () => solve(singular, rhs),
        throwsA(isA<SingularSystemException>()),
      );
    });

    test('solve handles a system needing a row swap', () {
      final a = Matrix.fromRows(<List<double>>[
        <double>[0, 1],
        <double>[1, 0],
      ]);
      final b = Matrix.fromRows(<List<double>>[
        <double>[3],
        <double>[7],
      ]);
      final x = solve(a, b);
      expect(x.at(0, 0), closeTo(7.0, 1e-12));
      expect(x.at(1, 0), closeTo(3.0, 1e-12));
    });
  });
}
