import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

void main() {
  group('sRGB transfer function', () {
    test('the published constants are very slightly discontinuous at the '
        'knee, and by no more than that', () {
      // IEC 61966-2-1 rounds the breakpoint to 0.04045 and the slope to 12.92,
      // which do not meet exactly: the two branches differ by ~2.3e-9 there.
      // This is a property of the standard, not a defect here. The test pins
      // the size of the step so that a genuine error — a wrong exponent, a
      // wrong offset — cannot hide inside "it's approximately continuous".
      const knee = 0.04045;
      final gap = (linearise(knee + 1e-12) - linearise(knee - 1e-12)).abs();
      expect(gap, lessThan(1e-8));
      expect(gap, greaterThan(0.0));
    });

    test('maps the endpoints exactly', () {
      expect(linearise(0.0), 0.0);
      expect(linearise(1.0), closeTo(1.0, 1e-12));
    });

    test('round-trips', () {
      for (var i = 0; i <= 255; i++) {
        final encoded = i / 255.0;
        expect(delinearise(linearise(encoded)), closeTo(encoded, 1e-12));
      }
    });

    test('is odd-symmetric, so a negative channel is not folded to zero', () {
      // A fitted colour correction can push a channel slightly negative.
      // Clamping there would quietly bias every mean computed afterwards.
      expect(linearise(-0.5), closeTo(-linearise(0.5), 1e-15));
      expect(linearise(-0.02), closeTo(-linearise(0.02), 1e-15));
    });

    test('is not the identity — a naive implementation would pass everything '
        'else', () {
      // Guards against someone "simplifying" linearise() to a no-op: mid-grey
      // is the value where the gamma encoding matters most.
      expect(linearise(0.5), closeTo(0.21404114, 1e-8));
      expect(linearise(0.5), isNot(closeTo(0.5, 0.01)));
    });
  });

  group('linear RGB to XYZ to CIELAB', () {
    test('sRGB white is exactly L*=100, a*=0, b*=0', () {
      final lab = const SrgbColor(1, 1, 1).toLinear().toXyz().toLab();
      expect(lab.lStar, closeTo(100.0, 1e-9));
      expect(lab.aStar, closeTo(0.0, 1e-9));
      expect(lab.bStar, closeTo(0.0, 1e-9));
    });

    test('sRGB black is L*=0, a*=0, b*=0', () {
      final lab = const SrgbColor(0, 0, 0).toLinear().toXyz().toLab();
      expect(lab.lStar, closeTo(0.0, 1e-12));
      expect(lab.aStar, closeTo(0.0, 1e-12));
      expect(lab.bStar, closeTo(0.0, 1e-12));
    });

    test('the reference white is the row sum of the RGB-to-XYZ matrix', () {
      // If these drift apart, white stops landing on the neutral axis and
      // every delta-E in the pipeline acquires a constant offset.
      var sx = 0.0, sy = 0.0, sz = 0.0;
      for (var c = 0; c < 3; c++) {
        sx += linearRgbToXyzMatrix[0][c];
        sy += linearRgbToXyzMatrix[1][c];
        sz += linearRgbToXyzMatrix[2][c];
      }
      expect(sx, closeTo(d65TwoDegree.xn, 1e-12));
      expect(sy, closeTo(d65TwoDegree.yn, 1e-12));
      expect(sz, closeTo(d65TwoDegree.zn, 1e-12));

      // And specifically: Y does not sum to 1, so the reference white must
      // not claim it does.
      expect(sy, isNot(closeTo(1.0, 1e-9)));
    });

    test('primary red matches the published sRGB value', () {
      final xyz = const SrgbColor(1, 0, 0).toLinear().toXyz();
      expect(xyz.x, closeTo(0.4124564, 1e-7));
      expect(xyz.y, closeTo(0.2126729, 1e-7));
      expect(xyz.z, closeTo(0.0193339, 1e-7));

      final lab = xyz.toLab();
      expect(lab.lStar, closeTo(53.2408, 1e-3));
      expect(lab.aStar, closeTo(80.0925, 1e-3));
      expect(lab.bStar, closeTo(67.2032, 1e-3));
    });

    test('Lab round-trips through XYZ', () {
      const samples = <Lab>[
        Lab(50, 20, -30),
        Lab(90, -5, 5),
        Lab(10, 0, 0),
        Lab(0, 0, 0),
      ];
      for (final lab in samples) {
        final back = lab.toXyz().toLab();
        expect(back.lStar, closeTo(lab.lStar, 1e-9));
        expect(back.aStar, closeTo(lab.aStar, 1e-9));
        expect(back.bStar, closeTo(lab.bStar, 1e-9));
      }
    });

    test('the f() branches meet continuously', () {
      const delta = 6.0 / 29.0;
      const t = delta * delta * delta;
      final below = Xyz(
        d65TwoDegree.xn * (t - 1e-12),
        d65TwoDegree.yn * (t - 1e-12),
        d65TwoDegree.zn * (t - 1e-12),
      ).toLab();
      final above = Xyz(
        d65TwoDegree.xn * (t + 1e-12),
        d65TwoDegree.yn * (t + 1e-12),
        d65TwoDegree.zn * (t + 1e-12),
      ).toLab();
      expect(below.lStar, closeTo(above.lStar, 1e-6));
    });

    test('chroma and hue are derived consistently', () {
      const lab = Lab(50, 3, 4);
      expect(lab.chroma, closeTo(5.0, 1e-12));
      expect(const Lab(50, 1, 0).hueDegrees, closeTo(0.0, 1e-12));
      expect(const Lab(50, 0, 1).hueDegrees, closeTo(90.0, 1e-12));
      expect(const Lab(50, -1, 0).hueDegrees, closeTo(180.0, 1e-12));
      // Hue wraps. QRsens had to hard-code an offset around this
      // discontinuity; anything using hue as a feature must handle it.
      expect(const Lab(50, 0, -1).hueDegrees, closeTo(270.0, 1e-12));
    });
  });
}
