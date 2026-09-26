import 'dart:convert';
import 'dart:typed_data';

import 'rgb_image.dart';

/// Binary PPM (Netpbm P6) reading and writing.
///
/// Fixtures are stored as P6 rather than PNG for one reason: the cross-language
/// golden vectors require Dart and Python to agree on the input pixels before
/// they can be said to agree on anything computed from them. P6 is a header
/// and raw bytes, so a twenty-line reader in either language is provably
/// equivalent. A PNG decoder is not something we can audit on both sides.
final class Ppm {
  const Ppm._();

  static RgbImage decode(Uint8List data) {
    var offset = 0;

    String nextToken() {
      // Skip whitespace and '#' comments, which may appear between any tokens.
      while (offset < data.length) {
        final byte = data[offset];
        if (byte == 0x23) {
          while (offset < data.length && data[offset] != 0x0A) {
            offset++;
          }
        } else if (byte == 0x20 ||
            byte == 0x09 ||
            byte == 0x0A ||
            byte == 0x0D) {
          offset++;
        } else {
          break;
        }
      }
      final start = offset;
      while (offset < data.length) {
        final byte = data[offset];
        if (byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D) break;
        offset++;
      }
      if (start == offset) throw const FormatException('truncated PPM header');
      return ascii.decode(data.sublist(start, offset));
    }

    final magic = nextToken();
    if (magic != 'P6') {
      throw FormatException('expected P6 PPM, found "$magic"');
    }
    final width = int.parse(nextToken());
    final height = int.parse(nextToken());
    final maxValue = int.parse(nextToken());
    if (maxValue != 255) {
      throw FormatException('only 8-bit PPM is supported, found max $maxValue');
    }
    // Exactly one whitespace byte separates the header from the raster.
    offset++;

    final expected = width * height * 3;
    if (data.length - offset < expected) {
      throw FormatException(
        'truncated PPM raster: expected $expected bytes, '
        'found ${data.length - offset}',
      );
    }
    return RgbImage(
      width,
      height,
      Uint8List.fromList(data.sublist(offset, offset + expected)),
    );
  }

  static Uint8List encode(RgbImage image) {
    final header = ascii.encode('P6\n${image.width} ${image.height}\n255\n');
    final out = Uint8List(header.length + image.bytes.length)
      ..setRange(0, header.length, header)
      ..setRange(
        header.length,
        header.length + image.bytes.length,
        image.bytes,
      );
    return out;
  }
}
