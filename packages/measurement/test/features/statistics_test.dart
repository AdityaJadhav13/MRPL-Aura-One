import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

void main() {
  group('percentile', () {
    test('uses linear interpolation between order statistics', () {
      // Pinned to numpy's default "linear" method so the Python research
      // stack and this engine cannot disagree about what a quartile is.
      final s = <double>[1, 2, 3, 4];
      expect(percentile(s, 0.0), 1.0);
      expect(percentile(s, 0.25), closeTo(1.75, 1e-12));
      expect(percentile(s, 0.5), closeTo(2.5, 1e-12));
      expect(percentile(s, 0.75), closeTo(3.25, 1e-12));
      expect(percentile(s, 1.0), 4.0);
    });

    test('handles a single value', () {
      expect(percentile(<double>[7], 0.5), 7.0);
      expect(percentile(<double>[7], 0.0), 7.0);
    });

    test('rejects an empty sample rather than returning zero', () {
      expect(() => percentile(<double>[], 0.5), throwsArgumentError);
    });
  });

  group('summarise', () {
    test('computes the expected statistics on a known sample', () {
      final stats = summarise(<double>[1, 2, 3, 4, 5], trimFraction: 0);
      expect(stats.count, 5);
      expect(stats.mean, closeTo(3.0, 1e-12));
      expect(stats.median, closeTo(3.0, 1e-12));
      // Sample standard deviation, n - 1.
      expect(stats.standardDeviation, closeTo(1.5811388300841898, 1e-12));
      expect(stats.minimum, 1.0);
      expect(stats.maximum, 5.0);
      expect(stats.interquartileRange, closeTo(2.0, 1e-12));
    });

    test('does not modify the input', () {
      final input = <double>[5, 1, 3];
      summarise(input);
      expect(input, <double>[5, 1, 3]);
    });

    test('the trimmed mean resists a contaminated sample and the plain mean '
        'does not', () {
      // Nineteen good readings and one specular pixel. This is the whole
      // argument for directive s12: SmART-Form averages every pixel, so a
      // single highlight enters its result at full weight.
      final values = <double>[for (var i = 0; i < 19; i++) 0.40, 100.0];
      final stats = summarise(values, trimFraction: 0.1);
      expect(stats.mean, greaterThan(5.0));
      expect(stats.trimmedMean, closeTo(0.40, 1e-12));
      expect(stats.median, closeTo(0.40, 1e-12));
    });

    test('trimFraction zero leaves the trimmed mean equal to the mean', () {
      final stats = summarise(<double>[1, 2, 10], trimFraction: 0);
      expect(stats.trimmedMean, closeTo(stats.mean, 1e-12));
    });

    test('rejects a trim fraction that would remove everything', () {
      expect(
        () => summarise(<double>[1, 2, 3], trimFraction: 0.5),
        throwsArgumentError,
      );
      expect(
        () => summarise(<double>[1, 2, 3], trimFraction: -0.1),
        throwsArgumentError,
      );
    });

    test('a single value has zero spread rather than NaN', () {
      final stats = summarise(<double>[3.0]);
      expect(stats.standardDeviation, 0.0);
      expect(stats.mean, 3.0);
    });

    test('rejects an empty sample', () {
      expect(() => summarise(<double>[]), throwsArgumentError);
    });
  });
}
