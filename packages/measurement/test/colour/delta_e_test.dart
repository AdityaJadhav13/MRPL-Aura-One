import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

/// The 34-pair CIEDE2000 verification set from Sharma, Wu and Dalal (2005),
/// "The CIEDE2000 Color-Difference Formula: Implementation Notes,
/// Supplementary Test Data, and Mathematical Observations",
/// Color Research and Application 30(1), 21-30.
///
/// This set exists precisely because CIEDE2000 is easy to implement almost
/// correctly. The pairs are chosen to exercise the hue-arithmetic edge cases —
/// the 360-degree wrap in the mean hue, the discontinuity either side of the
/// a* axis, and the neutral case where hue is undefined — which is where a
/// plausible-looking implementation silently diverges.
///
/// Each entry is (L1, a1, b1, L2, a2, b2, expected dE00).
const List<List<double>> sharmaTestData = <List<double>>[
  <double>[50.0000, 2.6772, -79.7751, 50.0000, 0.0000, -82.7485, 2.0425],
  <double>[50.0000, 3.1571, -77.2803, 50.0000, 0.0000, -82.7485, 2.8615],
  <double>[50.0000, 2.8361, -74.0200, 50.0000, 0.0000, -82.7485, 3.4412],
  <double>[50.0000, -1.3802, -84.2814, 50.0000, 0.0000, -82.7485, 1.0000],
  <double>[50.0000, -1.1848, -84.8006, 50.0000, 0.0000, -82.7485, 1.0000],
  <double>[50.0000, -0.9009, -85.5211, 50.0000, 0.0000, -82.7485, 1.0000],
  <double>[50.0000, 0.0000, 0.0000, 50.0000, -1.0000, 2.0000, 2.3669],
  <double>[50.0000, -1.0000, 2.0000, 50.0000, 0.0000, 0.0000, 2.3669],
  <double>[50.0000, 2.4900, -0.0010, 50.0000, -2.4900, 0.0009, 7.1792],
  <double>[50.0000, 2.4900, -0.0010, 50.0000, -2.4900, 0.0010, 7.1792],
  <double>[50.0000, 2.4900, -0.0010, 50.0000, -2.4900, 0.0011, 7.2195],
  <double>[50.0000, 2.4900, -0.0010, 50.0000, -2.4900, 0.0012, 7.2195],
  <double>[50.0000, -0.0010, 2.4900, 50.0000, 0.0009, -2.4900, 4.8045],
  <double>[50.0000, -0.0010, 2.4900, 50.0000, 0.0010, -2.4900, 4.8045],
  <double>[50.0000, -0.0010, 2.4900, 50.0000, 0.0011, -2.4900, 4.7461],
  <double>[50.0000, 2.5000, 0.0000, 50.0000, 0.0000, -2.5000, 4.3065],
  <double>[50.0000, 2.5000, 0.0000, 73.0000, 25.0000, -18.0000, 27.1492],
  <double>[50.0000, 2.5000, 0.0000, 61.0000, -5.0000, 29.0000, 22.8977],
  <double>[50.0000, 2.5000, 0.0000, 56.0000, -27.0000, -3.0000, 31.9030],
  <double>[50.0000, 2.5000, 0.0000, 58.0000, 24.0000, 15.0000, 19.4535],
  <double>[50.0000, 2.5000, 0.0000, 50.0000, 3.1736, 0.5854, 1.0000],
  <double>[50.0000, 2.5000, 0.0000, 50.0000, 3.2972, 0.0000, 1.0000],
  <double>[50.0000, 2.5000, 0.0000, 50.0000, 1.8634, 0.5757, 1.0000],
  <double>[50.0000, 2.5000, 0.0000, 50.0000, 3.2592, 0.3350, 1.0000],
  <double>[60.2574, -34.0099, 36.2677, 60.4626, -34.1751, 39.4387, 1.2644],
  <double>[63.0109, -31.0961, -5.8663, 62.8187, -29.7946, -4.0864, 1.2630],
  <double>[61.2901, 3.7196, -5.3901, 61.4292, 2.2480, -4.9620, 1.8731],
  <double>[35.0831, -44.1164, 3.7933, 35.0232, -40.0716, 1.5901, 1.8645],
  <double>[22.7233, 20.0904, -46.6940, 23.0331, 14.9730, -42.5619, 2.0373],
  <double>[36.4612, 47.8580, 18.3852, 36.2715, 50.5065, 21.2231, 1.4146],
  <double>[90.8027, -2.0831, 1.4410, 91.1528, -1.6435, 0.0447, 1.4441],
  <double>[90.9257, -0.5406, -0.9208, 88.6381, -0.8985, -0.7239, 1.5381],
  <double>[6.7747, -0.2908, -2.4247, 5.8714, -0.0985, -2.2286, 0.6377],
  <double>[2.0776, 0.0795, -1.1350, 0.9033, -0.0636, -0.5514, 0.9082],
];

void main() {
  group('CIEDE2000 against the Sharma et al. published test set', () {
    for (var i = 0; i < sharmaTestData.length; i++) {
      final row = sharmaTestData[i];
      test('pair ${i + 1}', () {
        final a = Lab(row[0], row[1], row[2]);
        final b = Lab(row[3], row[4], row[5]);
        // The published values are quoted to 4 decimal places, so agreement
        // to within 1e-4 is agreement to the full stated precision.
        expect(deltaE2000(a, b), closeTo(row[6], 1e-4));
      });
    }

    test('is symmetric', () {
      for (final row in sharmaTestData) {
        final a = Lab(row[0], row[1], row[2]);
        final b = Lab(row[3], row[4], row[5]);
        expect(deltaE2000(a, b), closeTo(deltaE2000(b, a), 1e-12));
      }
    });

    test('a colour has zero difference from itself', () {
      for (final row in sharmaTestData) {
        final a = Lab(row[0], row[1], row[2]);
        expect(deltaE2000(a, a), closeTo(0.0, 1e-12));
      }
    });
  });

  group('CIE76', () {
    test('is the Euclidean distance in Lab', () {
      expect(
        deltaE76(const Lab(50, 0, 0), const Lab(50, 3, 4)),
        closeTo(5.0, 1e-12),
      );
    });

    test('differs from dE00 on the pairs the 2000 formula was built to fix', () {
      // Pairs 9-12 are near-neutral opposites across the a* axis: CIE76 sees a
      // small distance, CIEDE2000 sees a large one. If these two agreed, the
      // dE00 implementation would not be doing its job.
      final a = const Lab(50.0, 2.49, -0.001);
      final b = const Lab(50.0, -2.49, 0.0009);
      expect(deltaE76(a, b), closeTo(4.98, 0.01));
      expect(deltaE2000(a, b), closeTo(7.1792, 1e-4));
    });
  });
}
