import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../features/statistics.dart';

/// Which way a feature moves with increasing dose.
enum ResponseDirection {
  increasing,
  decreasing,

  /// The feature moves both ways over the range, or does not move at all.
  /// Not a direction — a finding.
  indeterminate,
}

/// One dose level and the feature values observed at it.
@immutable
final class DoseLevel {
  const DoseLevel({required this.dose, required this.responses});

  /// True cumulative dose, from the reference method. Never inferred from the
  /// badge itself — that would be circular calibration (directive §25).
  final double dose;

  /// Replicate feature values at this dose.
  final List<double> responses;

  double get mean => responses.reduce((a, b) => a + b) / responses.length;

  double get spread => responses.length > 1
      ? summarise(responses, trimFraction: 0).standardDeviation
      : 0.0;
}

/// A place where the response moved against the prevailing direction.
@immutable
final class Reversal {
  const Reversal({
    required this.fromIndex,
    required this.toIndex,
    required this.fromDose,
    required this.toDose,
    required this.magnitude,
    required this.significant,
  });

  final int fromIndex;
  final int toIndex;
  final double fromDose;
  final double toDose;

  /// How far the response moved the wrong way, in feature units.
  final double magnitude;

  /// Whether the reversal is larger than the replicate spread at the levels
  /// involved. An insignificant reversal is noise; a significant one is a
  /// property of the chemistry.
  final bool significant;

  Map<String, Object?> toJson() => <String, Object?>{
    'from_index': fromIndex,
    'to_index': toIndex,
    'from_dose': fromDose,
    'to_dose': toDose,
    'magnitude': magnitude,
    'significant': significant,
  };
}

/// What a dose-response series says about a candidate feature.
///
/// **This is a research utility, not a validity check.** It describes a
/// feature's behaviour across a set of reference exposures. It cannot be run
/// on a single photograph, and nothing in the image pipeline calls it: there
/// is no calibration, so there is no dose axis to be monotonic against.
///
/// Its job is to decide, once laboratory data exists, whether a feature may be
/// used at all and over what sub-domain — directive §28, and finding F-4,
/// which is not hypothetical. In Carpenter et al. 2017 the CIELAB b\* response
/// of a Cu-PAN H₂S probe rises, falls monotonically from 30 to 250 ppb, jumps
/// discontinuously at 400 ppb, then rises again. A monotonic interpolator
/// fitted through that returns a confident wrong answer in the ambiguous
/// region.
@immutable
final class MonotonicityReport {
  const MonotonicityReport({
    required this.direction,
    required this.spearmanRho,
    required this.reversals,
    required this.significantReversals,
    required this.largestReversal,
    required this.plateauLevels,
    required this.minimumSeparationRatio,
    required this.monotonicFromIndex,
    required this.monotonicToIndex,
    required this.levelCount,
    required this.doses,
  });

  final ResponseDirection direction;

  /// Spearman rank correlation between dose and mean response.
  ///
  /// Rank-based on purpose: it measures whether the response is *ordered* with
  /// dose, which is the question, rather than whether it is linear, which is
  /// not. R² is deliberately **not** reported — a high R² on a curve with a
  /// turning point is exactly the reassurance this report exists to deny.
  final double spearmanRho;

  final List<Reversal> reversals;
  final int significantReversals;

  /// Largest single backward move, in feature units.
  final double largestReversal;

  /// Indices of levels whose response is not separated from the previous
  /// level by more than the replicate spread — saturation, or a dead zone.
  final List<int> plateauLevels;

  /// The smallest ratio, over adjacent levels, of between-level response
  /// difference to pooled within-level spread.
  ///
  /// Below about 1 the levels are not distinguishable at all: the feature
  /// cannot resolve those doses no matter what model is fitted to it.
  final double minimumSeparationRatio;

  /// The longest run of levels over which the response is strictly monotonic.
  /// This is the sub-domain a feature could honestly be restricted to.
  final int monotonicFromIndex;
  final int monotonicToIndex;

  final int levelCount;
  final List<double> doses;

  bool get isMonotonicThroughout =>
      significantReversals == 0 && direction != ResponseDirection.indeterminate;

  /// The dose interval over which the feature is monotonic.
  (double, double) get monotonicDomain =>
      (doses[monotonicFromIndex], doses[monotonicToIndex]);

  bool get coversFullRange =>
      monotonicFromIndex == 0 && monotonicToIndex == levelCount - 1;

  Map<String, Object?> toJson() => <String, Object?>{
    'direction': direction.name,
    'spearman_rho': spearmanRho,
    'level_count': levelCount,
    'significant_reversals': significantReversals,
    'largest_reversal': largestReversal,
    'plateau_levels': plateauLevels,
    'minimum_separation_ratio': minimumSeparationRatio,
    'monotonic_domain': <double>[
      doses[monotonicFromIndex],
      doses[monotonicToIndex],
    ],
    'covers_full_range': coversFullRange,
    'is_monotonic_throughout': isMonotonicThroughout,
    'reversals': reversals.map((r) => r.toJson()).toList(),
  };
}

/// Average ranks, with ties sharing the mean of the ranks they span.
List<double> _ranks(List<double> values) {
  final indexed = <({double value, int index})>[
    for (var i = 0; i < values.length; i++) (value: values[i], index: i),
  ]..sort((a, b) => a.value.compareTo(b.value));

  final ranks = List<double>.filled(values.length, 0);
  var i = 0;
  while (i < indexed.length) {
    var j = i;
    while (j + 1 < indexed.length && indexed[j + 1].value == indexed[i].value) {
      j++;
    }
    final averageRank = (i + j) / 2.0 + 1.0;
    for (var k = i; k <= j; k++) {
      ranks[indexed[k].index] = averageRank;
    }
    i = j + 1;
  }
  return ranks;
}

/// Pearson correlation of two equal-length series.
double _pearson(List<double> a, List<double> b) {
  final n = a.length;
  if (n < 2) return double.nan;
  final meanA = a.reduce((x, y) => x + y) / n;
  final meanB = b.reduce((x, y) => x + y) / n;
  var num = 0.0, denA = 0.0, denB = 0.0;
  for (var i = 0; i < n; i++) {
    final da = a[i] - meanA;
    final db = b[i] - meanB;
    num += da * db;
    denA += da * da;
    denB += db * db;
  }
  if (denA == 0 || denB == 0) return 0.0;
  return num / math.sqrt(denA * denB);
}

/// Analyses how a candidate feature behaves across reference dose levels.
///
/// [levels] must be ordered by ascending dose. Both increasing and decreasing
/// responses are supported: the direction is inferred, not assumed, because
/// several published H₂S features decrease with dose and an implementation
/// that assumes "up" would report every one of them as broken.
MonotonicityReport analyseMonotonicity(List<DoseLevel> levels) {
  if (levels.length < 3) {
    throw ArgumentError(
      'need at least 3 dose levels to say anything about monotonicity, '
      'got ${levels.length}',
    );
  }
  for (var i = 1; i < levels.length; i++) {
    if (levels[i].dose <= levels[i - 1].dose) {
      throw ArgumentError('dose levels must be strictly ascending');
    }
  }

  final doses = <double>[for (final l in levels) l.dose];
  final means = <double>[for (final l in levels) l.mean];
  final spreads = <double>[for (final l in levels) l.spread];

  final rho = _pearson(_ranks(doses), _ranks(means));

  // Direction from the overall trend, not from the first step, which may be
  // noise or an initial transient.
  final ResponseDirection direction;
  if (rho.isNaN || rho.abs() < 0.3) {
    direction = ResponseDirection.indeterminate;
  } else {
    direction = rho > 0
        ? ResponseDirection.increasing
        : ResponseDirection.decreasing;
  }

  final sign = direction == ResponseDirection.decreasing ? -1.0 : 1.0;

  final reversals = <Reversal>[];
  final plateaus = <int>[];
  var largestReversal = 0.0;
  var minimumSeparation = double.infinity;

  for (var i = 1; i < levels.length; i++) {
    final step = sign * (means[i] - means[i - 1]);
    // Pooled spread of the two levels involved.
    final pooled = math.sqrt(
      (spreads[i] * spreads[i] + spreads[i - 1] * spreads[i - 1]) / 2,
    );

    final separation = pooled > 0 ? step.abs() / pooled : double.infinity;
    if (separation < minimumSeparation) minimumSeparation = separation;

    if (step < 0) {
      final magnitude = -step;
      if (magnitude > largestReversal) largestReversal = magnitude;
      reversals.add(
        Reversal(
          fromIndex: i - 1,
          toIndex: i,
          fromDose: doses[i - 1],
          toDose: doses[i],
          magnitude: magnitude,
          // A backward move smaller than the replicate noise is not evidence
          // of a turning point; it is evidence of replicate noise.
          significant: pooled <= 0 || magnitude > pooled,
        ),
      );
    } else if (separation <= 1.0) {
      plateaus.add(i);
    }
  }

  // Longest strictly monotonic run, by the prevailing direction.
  var bestStart = 0, bestEnd = 0, runStart = 0;
  for (var i = 1; i < levels.length; i++) {
    final step = sign * (means[i] - means[i - 1]);
    if (step <= 0) {
      runStart = i;
    }
    if (i - runStart > bestEnd - bestStart) {
      bestStart = runStart;
      bestEnd = i;
    }
  }

  return MonotonicityReport(
    direction: direction,
    spearmanRho: rho,
    reversals: reversals,
    significantReversals: reversals.where((r) => r.significant).length,
    largestReversal: largestReversal,
    plateauLevels: plateaus,
    minimumSeparationRatio: minimumSeparation.isFinite
        ? minimumSeparation
        : double.infinity,
    monotonicFromIndex: bestStart,
    monotonicToIndex: bestEnd,
    levelCount: levels.length,
    doses: doses,
  );
}
