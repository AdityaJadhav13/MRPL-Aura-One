import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'rgb_image.dart';

/// Decodes an encoded still (JPEG, PNG, …) into the engine's image type.
///
/// The `image` package is used for decoding **only**. Every measurement
/// afterwards runs on our own arithmetic, for the reason given in ADR-0003:
/// each numerical step in a measurement should be readable by the person
/// defending the measurement.
///
/// The original bytes are never re-encoded. Repeated JPEG compression of the
/// analytical image is exactly the kind of quiet degradation that directive
/// §11 forbids, so the caller keeps the bytes it was given and this function
/// only ever reads them.
RgbImage decodeStill(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('image bytes could not be decoded');
  }

  final out = RgbImage.filled(decoded.width, decoded.height, 0, 0, 0);
  for (var y = 0; y < decoded.height; y++) {
    for (var x = 0; x < decoded.width; x++) {
      final p = decoded.getPixel(x, y);
      out.setPixel(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt());
    }
  }
  return out;
}
