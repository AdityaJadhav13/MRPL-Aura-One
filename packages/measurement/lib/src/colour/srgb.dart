import 'dart:math' as math;

import 'colour_types.dart';

/// Removes the sRGB transfer function, taking gamma-encoded values to
/// linear light. Directive s16.
///
/// Every colour computation in this package happens after this step. Fitting a
/// correction, averaging an ROI or computing a ratio on gamma-encoded values is
/// a silent error: the numbers stay plausible and stop meaning anything
/// proportional to reflectance.
double linearise(double channel) {
  // The transfer function is defined on [0, 1] but is odd-symmetric in
  // practice; a correction can push a channel slightly negative, and folding
  // that to zero would quietly bias a mean.
  final sign = channel < 0 ? -1.0 : 1.0;
  final c = channel.abs();
  if (c <= 0.04045) return sign * (c / 12.92);
  return sign * math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// Re-applies the sRGB transfer function. Used for presentation and for
/// round-trip tests, never in the measurement path.
double delinearise(double channel) {
  final sign = channel < 0 ? -1.0 : 1.0;
  final c = channel.abs();
  if (c <= 0.0031308) return sign * (c * 12.92);
  return sign * (1.055 * math.pow(c, 1.0 / 2.4).toDouble() - 0.055);
}

extension SrgbConversion on SrgbColor {
  LinearRgb toLinear() => LinearRgb(linearise(r), linearise(g), linearise(b));
}

extension LinearRgbConversion on LinearRgb {
  SrgbColor toSrgb() =>
      SrgbColor(delinearise(r), delinearise(g), delinearise(b));

  /// Linear RGB to CIE XYZ under D65. Directive s17.
  Xyz toXyz() {
    const m = linearRgbToXyzMatrix;
    return Xyz(
      m[0][0] * r + m[0][1] * g + m[0][2] * b,
      m[1][0] * r + m[1][1] * g + m[1][2] * b,
      m[2][0] * r + m[2][1] * g + m[2][2] * b,
    );
  }
}
