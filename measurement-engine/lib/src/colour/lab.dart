import 'dart:math' as math;

import 'colour_types.dart';

// CIE constants, written as exact rationals rather than their decimal
// approximations so the two branches of f() meet continuously.
const double _delta = 6.0 / 29.0;
const double _deltaCubed = _delta * _delta * _delta; // 216/24389
const double _threeDeltaSquared = 3.0 * _delta * _delta;

double _f(double t) {
  if (t > _deltaCubed) return math.pow(t, 1.0 / 3.0).toDouble();
  return t / _threeDeltaSquared + 4.0 / 29.0;
}

double _fInverse(double t) {
  if (t > _delta) return t * t * t;
  return _threeDeltaSquared * (t - 4.0 / 29.0);
}

extension XyzToLab on Xyz {
  /// CIE XYZ to CIELAB against [white]. Directive s18.
  Lab toLab({ReferenceWhite white = d65TwoDegree}) {
    final fx = _f(x / white.xn);
    final fy = _f(y / white.yn);
    final fz = _f(z / white.zn);
    return Lab(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz));
  }
}

extension LabToXyz on Lab {
  Xyz toXyz({ReferenceWhite white = d65TwoDegree}) {
    final fy = (lStar + 16.0) / 116.0;
    final fx = fy + aStar / 500.0;
    final fz = fy - bStar / 200.0;
    return Xyz(
      white.xn * _fInverse(fx),
      white.yn * _fInverse(fy),
      white.zn * _fInverse(fz),
    );
  }
}
