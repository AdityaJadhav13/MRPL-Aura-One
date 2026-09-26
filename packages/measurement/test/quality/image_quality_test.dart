import 'dart:math' as math;

import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

/// A checkerboard: maximum high-frequency content.
RgbImage _checkerboard(int size, int cell, {int low = 40, int high = 210}) {
  final image = RgbImage.filled(size, size, low, low, low);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final on = ((x ~/ cell) + (y ~/ cell)).isEven;
      final v = on ? high : low;
      image.setPixel(x, y, v, v, v);
    }
  }
  return image;
}

/// A separable box blur, as a stand-in for defocus.
RgbImage _blur(RgbImage source, int radius) {
  final out = RgbImage.filled(source.width, source.height, 0, 0, 0);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      var r = 0, g = 0, b = 0, n = 0;
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          final sx = x + dx, sy = y + dy;
          if (!source.contains(sx, sy)) continue;
          r += source.red(sx, sy);
          g += source.green(sx, sy);
          b += source.blue(sx, sy);
          n++;
        }
      }
      out.setPixel(x, y, r ~/ n, g ~/ n, b ~/ n);
    }
  }
  return out;
}

void main() {
  group('sharpness (variance of the Laplacian)', () {
    test('a flat field has essentially zero variance', () {
      final q = measureImageQuality(RgbImage.filled(64, 64, 128, 128, 128));
      expect(q.laplacianVariance, closeTo(0.0, 1e-12));
    });

    test('a checkerboard scores far above a flat field', () {
      final sharp = measureImageQuality(_checkerboard(64, 4));
      expect(sharp.laplacianVariance, greaterThan(0.01));
    });

    test('blurring monotonically reduces it', () {
      final sharp = _checkerboard(64, 4);
      final v0 = measureImageQuality(sharp).laplacianVariance;
      final v1 = measureImageQuality(_blur(sharp, 1)).laplacianVariance;
      final v2 = measureImageQuality(_blur(sharp, 3)).laplacianVariance;
      expect(v1, lessThan(v0));
      expect(v2, lessThan(v1));
    });

    test(
      'is scale-dependent, which is why a threshold on it needs the scale',
      () {
        // The same scene photographed with larger features scores differently.
        // A bare "variance > N" gate would therefore pass or fail on how close
        // the phone was held, which is why the geometry stage has to supply
        // pixels-per-millimetre alongside it.
        final fine = measureImageQuality(_checkerboard(64, 2))
            .laplacianVariance;
        final coarse = measureImageQuality(_checkerboard(64, 8))
            .laplacianVariance;
        expect(fine, isNot(closeTo(coarse, coarse * 0.2)));
      },
    );

    test(
      'is not-a-number when the region is too small to have an interior',
      () {
        // Reporting zero here would be indistinguishable from a perfectly flat
        // image, which is a very different statement.
        final q = measureImageQuality(
          RgbImage.filled(8, 8, 100, 100, 100),
          region: const PixelRect(0, 0, 2, 2),
        );
        expect(q.laplacianVariance.isNaN, isTrue);
      },
    );
  });

  group('clipping', () {
    test('counts blown highlights', () {
      final image = RgbImage.filled(10, 10, 128, 128, 128);
      for (var x = 0; x < 10; x++) {
        image.setPixel(x, 0, 255, 255, 255);
      }
      final q = measureImageQuality(image);
      expect(q.highClipFraction, closeTo(0.1, 1e-12));
      expect(q.lowClipFraction, closeTo(0.0, 1e-12));
    });

    test('counts crushed shadows', () {
      final image = RgbImage.filled(10, 10, 128, 128, 128);
      for (var x = 0; x < 10; x++) {
        image.setPixel(x, 0, 0, 0, 0);
        image.setPixel(x, 1, 0, 0, 0);
      }
      final q = measureImageQuality(image);
      expect(q.lowClipFraction, closeTo(0.2, 1e-12));
    });

    test('a single clipped channel is enough', () {
      // A clipped red channel carries no recoverable information even if
      // green and blue are perfectly exposed.
      final image = RgbImage.filled(4, 4, 255, 100, 100);
      final q = measureImageQuality(image);
      expect(q.highClipFraction, closeTo(1.0, 1e-12));
    });
  });

  group('specular highlights', () {
    test('bright and neutral counts as specular', () {
      final image = RgbImage.filled(10, 10, 100, 100, 100);
      for (var x = 0; x < 10; x++) {
        image.setPixel(x, 5, 250, 250, 250);
      }
      final q = measureImageQuality(image, clipHigh: 1.1);
      expect(q.specularFraction, closeTo(0.1, 1e-12));
    });

    test('bright but saturated does not', () {
      // A brightly lit red patch is not a reflection of the light source.
      final image = RgbImage.filled(10, 10, 250, 20, 20);
      final q = measureImageQuality(image, clipHigh: 1.1);
      expect(q.specularFraction, closeTo(0.0, 1e-12));
    });
  });

  group('regions and reporting', () {
    test('measures only the requested window', () {
      final image = RgbImage.filled(20, 20, 128, 128, 128);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 20; x++) {
          image.setPixel(x, y, 255, 255, 255);
        }
      }
      final whole = measureImageQuality(image);
      final bottom = measureImageQuality(
        image,
        region: const PixelRect(0, 10, 20, 10),
      );
      expect(whole.highClipFraction, closeTo(0.5, 1e-12));
      expect(bottom.highClipFraction, closeTo(0.0, 1e-12));
      expect(bottom.pixelCount, 200);
    });

    test('rejects a region outside the image', () {
      expect(
        () => measureImageQuality(
          RgbImage.filled(10, 10, 0, 0, 0),
          region: const PixelRect(5, 5, 10, 10),
        ),
        throwsArgumentError,
      );
    });

    test('reports each axis separately and offers no combined score', () {
      // Directive s10: a single "image quality: 98%" would let a fatal
      // failure on one axis be averaged away by comfortable values on the
      // others. The type has no such field, and this test exists to keep it
      // that way.
      final json = measureImageQuality(RgbImage.filled(16, 16, 128, 128, 128))
          .toJson();
      expect(json.keys, contains('laplacian_variance'));
      expect(json.keys, contains('high_clip_fraction'));
      expect(json.keys, contains('low_clip_fraction'));
      expect(json.keys, contains('specular_fraction'));
      expect(json.keys, isNot(contains('score')));
      expect(json.keys, isNot(contains('overall')));
    });

    test('luma statistics describe the exposure', () {
      final image = RgbImage.filled(32, 32, 30, 30, 30);
      for (var y = 16; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          image.setPixel(x, y, 220, 220, 220);
        }
      }
      final q = measureImageQuality(image);
      expect(q.luma.mean, closeTo((30 + 220) / 2 / 255, 1e-6));
      expect(q.luma.minimum, closeTo(30 / 255, 1e-9));
      expect(q.luma.maximum, closeTo(220 / 255, 1e-9));
    });
  });

  group('sanity of the blur helper itself', () {
    test('a box blur of a flat field is still flat', () {
      final flat = RgbImage.filled(16, 16, 77, 77, 77);
      final blurred = _blur(flat, 2);
      expect(blurred.red(8, 8), 77);
      expect(math.max(0, 0), 0);
    });
  });
}
