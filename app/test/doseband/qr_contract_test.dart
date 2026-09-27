import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/doseband/data/qr_codec.dart';
import 'package:h2s_doseband/features/doseband/domain/doseband_qr.dart';
import 'package:measurement/measurement.dart';

/// PRODUCT BUILD v1 §8, §116 — the QR contract and its decoder.
void main() {
  group('contract', () {
    test('encodes and parses a version-1 label', () {
      final raw = DoseBandQr.encode('DB-2609-0101');
      expect(raw, 'DOSEBAND:1:DB-2609-0101');
      expect(
        DoseBandQr.parse(raw),
        isA<QrDoseBand>()
            .having((q) => q.dosebandId, 'id', 'DB-2609-0101')
            .having((q) => q.version, 'version', 1),
      );
    });

    test('is tolerant of case and whitespace, not of shape', () {
      expect(DoseBandQr.parse('  doseband:1:db-2609-0101 '), isA<QrDoseBand>());
      expect(DoseBandQr.parse('DOSEBAND:1:DB-2609-101'), isA<QrMalformed>());
      expect(DoseBandQr.parse('DOSEBAND:1'), isA<QrMalformed>());
      expect(DoseBandQr.parse('DOSEBAND:one:DB-2609-0101'), isA<QrMalformed>());
      expect(DoseBandQr.parse('DOSEBAND:1:DB-2609-0101:x'), isA<QrMalformed>());
    });

    test('a newer label is "update the app", not "not a DoseBand"', () {
      expect(
        DoseBandQr.parse('DOSEBAND:2:DB-2609-0101'),
        isA<QrUnsupportedVersion>().having((q) => q.version, 'v', 2),
      );
    });

    test('other codes are recognised as not DoseBands', () {
      expect(DoseBandQr.parse('https://example.com'), isA<QrNotDoseBand>());
      expect(DoseBandQr.parse(''), isA<QrNotDoseBand>());
      expect(DoseBandQr.parse('WIFI:S:x;;'), isA<QrNotDoseBand>());
    });

    test('a typed serial is normalised or refused', () {
      expect(DoseBandQr.normaliseTyped('db-2609-0101'), 'DB-2609-0101');
      expect(DoseBandQr.normaliseTyped('DB 2609 0101'), 'DB-2609-0101');
      expect(DoseBandQr.normaliseTyped('2609-0101'), isNull);
      expect(DoseBandQr.normaliseTyped('hello'), isNull);
    });

    test('encoding refuses a malformed serial', () {
      expect(() => DoseBandQr.encode('X-1'), throwsArgumentError);
    });
  });

  group('codec', () {
    test('a rendered label decodes back to its payload', () {
      final raw = DoseBandQr.encode('DB-2609-0118');
      expect(QrCodec.decode(QrCodec.render(raw)), raw);
    });

    test('decodes a label placed in a larger, off-white scene', () {
      final label = QrCodec.render(DoseBandQr.encode('DB-2609-0007'), scale: 4);
      const w = 480, h = 360;
      final bytes = Uint8List(w * h * 3);
      for (var i = 0; i < w * h; i++) {
        bytes[i * 3] = 205;
        bytes[i * 3 + 1] = 200;
        bytes[i * 3 + 2] = 190;
      }
      const ox = 150, oy = 80;
      for (var y = 0; y < label.height; y++) {
        for (var x = 0; x < label.width; x++) {
          final s = (y * label.width + x) * 3;
          final d = ((y + oy) * w + (x + ox)) * 3;
          bytes[d] = label.bytes[s];
          bytes[d + 1] = label.bytes[s + 1];
          bytes[d + 2] = label.bytes[s + 2];
        }
      }
      expect(QrCodec.decode(RgbImage(w, h, bytes)), 'DOSEBAND:1:DB-2609-0007');
    });

    test('a frame with no code decodes to nothing, without throwing', () {
      expect(QrCodec.decode(RgbImage.filled(320, 240, 128, 128, 128)), isNull);
    });
  });
}
