import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Gamma-encoded sRGB, channels normalised to [0, 1].
///
/// This is what a camera hands us. It is **not** a measurement: the phone has
/// already applied white balance, tone mapping and a transfer function before
/// the app sees a pixel. Nothing in this package may do colour arithmetic on
/// these values directly — see [SrgbColor.toLinear] and directive s16.
@immutable
final class SrgbColor {
  const SrgbColor(this.r, this.g, this.b);

  /// From 8-bit channel values as decoded from an image file.
  factory SrgbColor.fromBytes(int r, int g, int b) =>
      SrgbColor(r / 255.0, g / 255.0, b / 255.0);

  final double r;
  final double g;
  final double b;

  @override
  bool operator ==(Object other) =>
      other is SrgbColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'SrgbColor($r, $g, $b)';
}

/// Linear-light RGB in the sRGB primaries. Proportional to radiance.
///
/// Values may exceed [0, 1] after a colour correction is applied; clamping is
/// a presentation decision, not a measurement one, so it is not done here.
@immutable
final class LinearRgb {
  const LinearRgb(this.r, this.g, this.b);

  final double r;
  final double g;
  final double b;

  @override
  bool operator ==(Object other) =>
      other is LinearRgb && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'LinearRgb($r, $g, $b)';
}

/// CIE 1931 XYZ tristimulus values.
@immutable
final class Xyz {
  const Xyz(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  @override
  bool operator ==(Object other) =>
      other is Xyz && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Xyz($x, $y, $z)';
}

/// CIELAB coordinates against a stated reference white.
///
/// The reference white is not carried on the value: every conversion in this
/// package uses [d65TwoDegree], and a Lab value from any other white would be
/// a different quantity wearing the same name. If a second illuminant is ever
/// needed, it becomes a field here rather than an ambient assumption.
@immutable
final class Lab {
  const Lab(this.lStar, this.aStar, this.bStar);

  final double lStar;
  final double aStar;
  final double bStar;

  /// Chroma C*ab.
  double get chroma => math.sqrt(aStar * aStar + bStar * bStar);

  /// Hue angle h_ab in degrees, in [0, 360).
  double get hueDegrees {
    final h = math.atan2(bStar, aStar) * 180.0 / math.pi;
    return h < 0 ? h + 360.0 : h;
  }

  @override
  bool operator ==(Object other) =>
      other is Lab &&
      other.lStar == lStar &&
      other.aStar == aStar &&
      other.bStar == bStar;

  @override
  int get hashCode => Object.hash(lStar, aStar, bStar);

  @override
  String toString() => 'Lab($lStar, $aStar, $bStar)';
}

/// A reference white, as XYZ with Y = 1.
@immutable
final class ReferenceWhite {
  const ReferenceWhite(this.name, this.xn, this.yn, this.zn);

  final String name;
  final double xn;
  final double yn;
  final double zn;

  @override
  String toString() => name;
}

/// CIE D65, 2-degree standard observer, as realised by [linearRgbToXyzMatrix].
///
/// These are the **row sums** of that matrix — the XYZ that linear RGB
/// (1, 1, 1) actually maps to — rather than the rounded CIE table values.
/// Note the Y term: it is 1.0000001, not 1, because the published matrix is
/// quoted to seven decimal places and does not sum to unity exactly.
///
/// Taking the tidier value instead would leave sRGB white at L* = 99.9999...
/// with a small non-zero a*/b*, and that offset would then appear in every
/// delta-E the pipeline computes, on every patch, forever. A one-part-in-ten-
/// million bias is not a rounding curiosity when the quantity being compared
/// against it is a reference-patch residual of about 2 units.
///
/// `test/colour/conversion_test.dart` asserts that these stay equal to the
/// matrix row sums, so the two cannot drift apart unnoticed.
const ReferenceWhite d65TwoDegree = ReferenceWhite(
  'D65/2 (sRGB matrix realisation)',
  0.95047,
  1.0000001,
  1.08883,
);

/// sRGB (linear) to CIE XYZ, D65. IEC 61966-2-1 / directive s17.
const List<List<double>> linearRgbToXyzMatrix = <List<double>>[
  <double>[0.4124564, 0.3575761, 0.1804375],
  <double>[0.2126729, 0.7151522, 0.0721750],
  <double>[0.0193339, 0.1191920, 0.9503041],
];
