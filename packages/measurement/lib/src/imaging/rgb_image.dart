import 'dart:typed_data';

import '../colour/colour_types.dart';

/// An 8-bit RGB image held as a flat byte buffer.
///
/// Deliberately not tied to the `image` package: the analytical path should
/// depend on a decoder only where a decoder is genuinely needed, and the
/// cross-language golden vectors (see `golden/README.md`) require a format
/// whose bytes are unambiguous in both Dart and Python.
final class RgbImage {
  RgbImage(this.width, this.height, this.bytes)
    : assert(width > 0 && height > 0, 'image must have positive extent') {
    if (bytes.length != width * height * 3) {
      throw ArgumentError(
        'expected ${width * height * 3} bytes, got ${bytes.length}',
      );
    }
  }

  RgbImage.filled(this.width, this.height, int r, int g, int b)
    : bytes = Uint8List(width * height * 3) {
    for (var i = 0; i < width * height; i++) {
      bytes[i * 3] = r;
      bytes[i * 3 + 1] = g;
      bytes[i * 3 + 2] = b;
    }
  }

  final int width;
  final int height;
  final Uint8List bytes;

  bool contains(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  int red(int x, int y) => bytes[(y * width + x) * 3];
  int green(int x, int y) => bytes[(y * width + x) * 3 + 1];
  int blue(int x, int y) => bytes[(y * width + x) * 3 + 2];

  void setPixel(int x, int y, int r, int g, int b) {
    final i = (y * width + x) * 3;
    bytes[i] = r;
    bytes[i + 1] = g;
    bytes[i + 2] = b;
  }

  SrgbColor pixel(int x, int y) =>
      SrgbColor.fromBytes(red(x, y), green(x, y), blue(x, y));

  /// Rec. 709 luma from gamma-encoded channels, in [0, 1].
  ///
  /// Used for quality metrics only. It is a perceptual convenience, not a
  /// photometric quantity, and nothing in the measurement path may treat it
  /// as one.
  double luma(int x, int y) =>
      (0.2126 * red(x, y) + 0.7152 * green(x, y) + 0.0722 * blue(x, y)) / 255.0;

  /// Bilinear sample at a sub-pixel location.
  ///
  /// Returns null outside the image rather than clamping to the edge: a
  /// sample that falls off the frame is missing information, and silently
  /// substituting the nearest edge pixel would fabricate it.
  SrgbColor? sampleBilinear(double x, double y) {
    if (x < 0 || y < 0 || x > width - 1 || y > height - 1) return null;

    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1 > width - 1 ? x0 : x0 + 1;
    final y1 = y0 + 1 > height - 1 ? y0 : y0 + 1;
    final fx = x - x0;
    final fy = y - y0;

    double lerpChannel(int Function(int, int) channel) {
      final top = channel(x0, y0) * (1 - fx) + channel(x1, y0) * fx;
      final bottom = channel(x0, y1) * (1 - fx) + channel(x1, y1) * fx;
      return (top * (1 - fy) + bottom * fy) / 255.0;
    }

    return SrgbColor(lerpChannel(red), lerpChannel(green), lerpChannel(blue));
  }
}
