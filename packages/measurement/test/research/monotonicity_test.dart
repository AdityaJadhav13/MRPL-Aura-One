import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

List<DoseLevel> _series(
  List<double> doses,
  List<double> means, {
  double spread = 0.05,
}) => <DoseLevel>[
  for (var i = 0; i < doses.length; i++)
    DoseLevel(
      dose: doses[i],
      // Three replicates straddling the mean, so the spread is well
      // defined without any randomness in the test.
      responses: <double>[means[i] - spread, means[i], means[i] + spread],
    ),
];

void main() {
  group('a clean monotonic response', () {
    test('increasing is recognised and certified over the full range', () {
      final report = analyseMonotonicity(
        _series(<double>[0, 1, 2, 4, 8, 16], <double>[10, 14, 18, 25, 33, 40]),
      );
      expect(report.direction, ResponseDirection.increasing);
      expect(report.spearmanRho, closeTo(1.0, 1e-9));
      expect(report.significantReversals, 0);
      expect(report.isMonotonicThroughout, isTrue);
      expect(report.coversFullRange, isTrue);
      expect(report.monotonicDomain, (0.0, 16.0));
    });

    test('decreasing is equally valid, not a failure', () {
      // Several published H2S features fall with dose. An implementation that
      // assumed "up" would report every one of them as broken.
      final report = analyseMonotonicity(
        _series(<double>[0, 1, 2, 4, 8, 16], <double>[40, 33, 25, 18, 14, 10]),
      );
      expect(report.direction, ResponseDirection.decreasing);
      expect(report.spearmanRho, closeTo(-1.0, 1e-9));
      expect(report.significantReversals, 0);
      expect(report.isMonotonicThroughout, isTrue);
    });
  });

  group('the Carpenter b* case (finding F-4)', () {
    // CIELAB b* of a Cu-PAN H2S probe, Carpenter et al. 2017 Table 1. The
    // response rises, falls monotonically from 30 to 250 ppb, jumps
    // discontinuously at 400, then rises. This is the shape a monotonic
    // interpolator must never be fitted through blind.
    final carpenter = _series(
      <double>[0, 30, 60, 100, 150, 250, 400, 600, 1000, 1750, 2500],
      <double>[
        -15.72,
        -10.92,
        -11.44,
        -12.03,
        -12.49,
        -13.48,
        -1.63,
        -1.19,
        -0.46,
        0.81,
        1.78,
      ],
      spread: 0.15,
    );

    test('is not certified as monotonic', () {
      final report = analyseMonotonicity(carpenter);
      expect(report.isMonotonicThroughout, isFalse);
      expect(report.significantReversals, greaterThan(0));
      expect(report.coversFullRange, isFalse);
    });

    test('a high rank correlation does not rescue it', () {
      // The overall trend is strongly upward, and a naive goodness-of-fit
      // number would look reassuring. The reversals are what matter, which is
      // why this report has no R-squared field at all.
      final report = analyseMonotonicity(carpenter);
      expect(report.spearmanRho, greaterThan(0.5));
      expect(report.isMonotonicThroughout, isFalse);
      expect(report.toJson().keys, isNot(contains('r_squared')));
    });

    test('identifies a usable monotonic sub-domain', () {
      final report = analyseMonotonicity(carpenter);
      final (from, to) = report.monotonicDomain;
      expect(to, greaterThan(from));
      // The longest strictly increasing run is the upper branch.
      expect(from, greaterThanOrEqualTo(250.0));
      expect(to, 2500.0);
    });

    test('locates the reversals at the right doses', () {
      final report = analyseMonotonicity(carpenter);
      final reversalDoses = report.reversals
          .where((r) => r.significant)
          .map((r) => r.toDose);
      expect(reversalDoses, contains(60.0));
    });
  });

  group('noise versus a real turning point', () {
    test('a reversal smaller than the replicate spread is not significant', () {
      final report = analyseMonotonicity(
        _series(
          <double>[0, 1, 2, 3, 4],
          // A 0.01 dip against a 0.2 spread: that is replicate noise.
          <double>[10, 12, 11.99, 14, 16],
          spread: 0.2,
        ),
      );
      expect(report.reversals, isNotEmpty);
      expect(report.significantReversals, 0);
      expect(report.isMonotonicThroughout, isTrue);
    });

    test('a reversal larger than the spread is significant', () {
      final report = analyseMonotonicity(
        _series(
          <double>[0, 1, 2, 3, 4],
          <double>[10, 12, 9.0, 14, 16],
          spread: 0.2,
        ),
      );
      expect(report.significantReversals, greaterThan(0));
      expect(report.isMonotonicThroughout, isFalse);
      expect(report.largestReversal, closeTo(3.0, 1e-9));
    });
  });

  group('saturation and resolution', () {
    test('a plateau is reported', () {
      final report = analyseMonotonicity(
        _series(
          <double>[0, 1, 2, 4, 8, 16],
          // Saturates after 4.
          <double>[10, 14, 18, 22, 22.05, 22.08],
          spread: 0.3,
        ),
      );
      expect(report.plateauLevels, isNotEmpty);
      expect(report.minimumSeparationRatio, lessThan(1.0));
    });

    test('levels indistinguishable from their neighbours are flagged', () {
      // If the between-level difference is smaller than the within-level
      // spread, the feature cannot resolve those doses no matter what model
      // is fitted to it.
      final report = analyseMonotonicity(
        _series(<double>[0, 1, 2], <double>[10, 10.1, 10.2], spread: 0.5),
      );
      expect(report.minimumSeparationRatio, lessThan(1.0));
    });

    test('a flat response has no direction', () {
      final report = analyseMonotonicity(
        _series(<double>[0, 1, 2, 3], <double>[10, 10, 10, 10]),
      );
      expect(report.direction, ResponseDirection.indeterminate);
      expect(report.isMonotonicThroughout, isFalse);
    });
  });

  group('input discipline', () {
    test('needs at least three levels', () {
      expect(
        () => analyseMonotonicity(_series(<double>[0, 1], <double>[10, 12])),
        throwsArgumentError,
      );
    });

    test('rejects unordered or duplicated doses', () {
      expect(
        () => analyseMonotonicity(
          _series(<double>[0, 2, 1], <double>[10, 12, 14]),
        ),
        throwsArgumentError,
      );
      expect(
        () => analyseMonotonicity(
          _series(<double>[0, 1, 1], <double>[10, 12, 14]),
        ),
        throwsArgumentError,
      );
    });
  });
}
