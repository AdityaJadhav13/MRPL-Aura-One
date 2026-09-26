import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

void main() {
  group('QRsens black/white normalisation (directive s13)', () {
    const black = LinearRgb(0.02, 0.02, 0.02);
    const white = LinearRgb(0.82, 0.82, 0.82);

    test('equation 2 maps black to 0 and white to the scale', () {
      const n = BlackWhiteNormaliser(
        form: BlackWhiteForm.qrsensEquation2,
        black: black,
        white: white,
      );
      final atBlack = n.apply(black);
      final atWhite = n.apply(white);
      expect(atBlack.isOk, isTrue);
      expect(atBlack.value!.r, closeTo(0.0, 1e-12));
      expect(atWhite.value!.r, closeTo(1.0, 1e-12));
    });

    test('equation 1 does NOT map white to the scale', () {
      // Eq. 1 subtracts black from the numerator but not the denominator, so
      // it does not span the reference interval. This is what the paper
      // published, and it is why Eq. 2 was found to work better for H2S.
      const n = BlackWhiteNormaliser(
        form: BlackWhiteForm.qrsensEquation1,
        black: black,
        white: white,
      );
      final atWhite = n.apply(white);
      expect(atWhite.isOk, isTrue);
      expect(atWhite.value!.r, isNot(closeTo(1.0, 1e-6)));
      expect(atWhite.value!.r, closeTo((0.82 - 0.02) / 0.82, 1e-12));
    });

    test('the published K = 256 scaling is reproducible', () {
      const n = BlackWhiteNormaliser(
        form: BlackWhiteForm.qrsensEquation2,
        black: black,
        white: white,
        scale: 256.0,
      );
      expect(n.apply(white).value!.r, closeTo(256.0, 1e-9));
    });

    test('refuses rather than divides when the references collapse', () {
      // A damaged, shadowed or clipped reference drives the denominator
      // toward zero. QRsens as published divides anyway and returns a very
      // large finite number, which then looks like an enormous response.
      const n = BlackWhiteNormaliser(
        form: BlackWhiteForm.qrsensEquation2,
        black: LinearRgb(0.5, 0.02, 0.02),
        white: LinearRgb(0.5, 0.82, 0.82),
      );
      final result = n.apply(const LinearRgb(0.4, 0.4, 0.4));
      expect(result.isOk, isFalse);
      expect(result.value, isNull);
      expect(result.rejection, BlackWhiteRejection.degenerateReference);
      expect(result.degenerateChannels, <String>['R']);
    });

    test('a rejection has no value field to misread', () {
      const n = BlackWhiteNormaliser(
        form: BlackWhiteForm.qrsensEquation2,
        black: LinearRgb(0.5, 0.5, 0.5),
        white: LinearRgb(0.5, 0.5, 0.5),
      );
      final result = n.apply(const LinearRgb(0.4, 0.4, 0.4));
      expect(result.value, isNull);
      expect(result.degenerateChannels, <String>['R', 'G', 'B']);
    });

    test('is invariant to a pure gain on all three signals', () {
      // The one thing a two-point correction genuinely does: remove a
      // multiplicative exposure change. It cannot remove a spectral one,
      // which is the next test.
      const n1 = BlackWhiteNormaliser(
        form: BlackWhiteForm.qrsensEquation2,
        black: black,
        white: white,
      );
      const gain = 1.7;
      const n2 = BlackWhiteNormaliser(
        form: BlackWhiteForm.qrsensEquation2,
        black: LinearRgb(0.02 * gain, 0.02 * gain, 0.02 * gain),
        white: LinearRgb(0.82 * gain, 0.82 * gain, 0.82 * gain),
      );
      const sensor = LinearRgb(0.4, 0.35, 0.3);
      final a = n1.apply(sensor).value!;
      final b = n2
          .apply(const LinearRgb(0.4 * gain, 0.35 * gain, 0.3 * gain))
          .value!;
      expect(b.r, closeTo(a.r, 1e-12));
      expect(b.g, closeTo(a.g, 1e-12));
      expect(b.b, closeTo(a.b, 1e-12));
    });
  });
}
