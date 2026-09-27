import 'dart:typed_data';

import 'package:measurement/measurement.dart';
import 'package:zxing2/qrcode.dart';

/// QR encode and decode, in pure Dart (no platform plugin, so it runs in an
/// isolate, in tests and on every platform the app builds for).
abstract final class QrCodec {
  /// Finds and decodes a QR code in [image], or null when there is none —
  /// the normal answer for most preview frames.
  static String? decode(RgbImage image) {
    final n = image.width * image.height;
    final argb = Int32List(n);
    final b = image.bytes;
    for (var i = 0; i < n; i++) {
      argb[i] =
          0xFF000000 | (b[i * 3] << 16) | (b[i * 3 + 1] << 8) | b[i * 3 + 2];
    }
    final source = RGBLuminanceSource(image.width, image.height, argb);
    for (final binarizer in <Binarizer Function(LuminanceSource)>[
      HybridBinarizer.new,
      GlobalHistogramBinarizer.new,
    ]) {
      try {
        return QRCodeReader()
            .decode(
              BinaryBitmap(binarizer(source)),
              hints: DecodeHints()..put(DecodeHintType.tryHarder),
            )
            .text;
      } on ReaderException {
        continue;
      }
    }
    return null;
  }

  /// The module matrix for [text]: `true` is a dark module. Medium error
  /// correction — enough for a label that is scuffed or partly shadowed.
  static List<List<bool>> modules(String text) {
    final code = Encoder.encode(text, ErrorCorrectionLevel.m);
    final m = code.matrix!;
    return [
      for (var y = 0; y < m.height; y++)
        [for (var x = 0; x < m.width; x++) m.get(x, y) == 1],
    ];
  }

  /// Renders [text] as an RGB image: [scale] pixels per module and a
  /// four-module quiet zone. For label sheets and tests.
  static RgbImage render(String text, {int scale = 8}) {
    final m = modules(text);
    const quiet = 4;
    final size = (m.length + quiet * 2) * scale;
    final bytes = Uint8List(size * size * 3)
      ..fillRange(0, size * size * 3, 255);
    for (var y = 0; y < m.length; y++) {
      for (var x = 0; x < m.length; x++) {
        if (!m[y][x]) continue;
        for (var dy = 0; dy < scale; dy++) {
          for (var dx = 0; dx < scale; dx++) {
            final px = (x + quiet) * scale + dx;
            final py = (y + quiet) * scale + dy;
            final i = (py * size + px) * 3;
            bytes[i] = bytes[i + 1] = bytes[i + 2] = 0;
          }
        }
      }
    }
    return RgbImage(size, size, bytes);
  }
}
