import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Robust summary statistics for one channel over a region.
///
/// Directive s12: never reduce an ROI to a single centre pixel, and never
/// trust a plain mean. A plain mean is included because it is the comparator
/// the published two-patch methods use (SmART-Form averages every pixel), not
/// because it should be preferred.
@immutable
final class ChannelStatistics {
  const ChannelStatistics({
    required this.count,
    required this.mean,
    required this.median,
    required this.trimmedMean,
    required this.standardDeviation,
    required this.p05,
    required this.p25,
    required this.p75,
    required this.p95,
    required this.minimum,
    required this.maximum,
    required this.trimFraction,
  });

  final int count;
  final double mean;
  final double median;

  /// Symmetric trimmed mean, discarding [trimFraction] from each tail.
  ///
  /// This is the statistic the pipeline uses. A single specular pixel or a
  /// fibre lying across the sensing window enters a plain mean at full weight;
  /// it does not survive trimming.
  final double trimmedMean;

  final double standardDeviation;
  final double p05;
  final double p25;
  final double p75;
  final double p95;
  final double minimum;
  final double maximum;
  final double trimFraction;

  /// Interquartile range — the spread measure used for heterogeneity checks,
  /// because it does not move when a few pixels are contaminated.
  double get interquartileRange => p75 - p25;

  Map<String, Object?> toJson() => <String, Object?>{
    'count': count,
    'mean': mean,
    'median': median,
    'trimmed_mean': trimmedMean,
    'standard_deviation': standardDeviation,
    'p05': p05,
    'p25': p25,
    'p75': p75,
    'p95': p95,
    'minimum': minimum,
    'maximum': maximum,
    'trim_fraction': trimFraction,
  };
}

/// Linear interpolation between order statistics.
///
/// Matches numpy's default `linear` method so the Python research stack and
/// the Dart engine agree; see `golden/README.md`. A percentile convention is
/// exactly the kind of quiet difference that makes two implementations
/// disagree by a little, forever.
double percentile(List<double> sorted, double fraction) {
  if (sorted.isEmpty) throw ArgumentError('percentile of an empty sample');
  if (sorted.length == 1) return sorted.first;
  final position = fraction * (sorted.length - 1);
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sorted[lower];
  final weight = position - lower;
  return sorted[lower] * (1 - weight) + sorted[upper] * weight;
}

/// Summarises [values]. The input is not modified.
///
/// [trimFraction] is the proportion removed from *each* tail before the
/// trimmed mean, so 0.1 discards the lowest and highest 10%.
ChannelStatistics summarise(List<double> values, {double trimFraction = 0.1}) {
  if (values.isEmpty) {
    throw ArgumentError('cannot summarise an empty sample');
  }
  if (trimFraction < 0 || trimFraction >= 0.5) {
    throw ArgumentError('trimFraction must be in [0, 0.5), got $trimFraction');
  }

  final sorted = List<double>.of(values)..sort();
  final n = sorted.length;

  var sum = 0.0;
  for (final v in sorted) {
    sum += v;
  }
  final mean = sum / n;

  var varianceSum = 0.0;
  for (final v in sorted) {
    final d = v - mean;
    varianceSum += d * d;
  }
  // Sample standard deviation (n - 1). With n = 1 the spread is not estimable
  // and is reported as zero rather than NaN.
  final standardDeviation = n > 1 ? math.sqrt(varianceSum / (n - 1)) : 0.0;

  final cut = (n * trimFraction).floor();
  final trimmed = (n - 2 * cut) > 0 ? sorted.sublist(cut, n - cut) : sorted;
  var trimmedSum = 0.0;
  for (final v in trimmed) {
    trimmedSum += v;
  }

  return ChannelStatistics(
    count: n,
    mean: mean,
    median: percentile(sorted, 0.5),
    trimmedMean: trimmedSum / trimmed.length,
    standardDeviation: standardDeviation,
    p05: percentile(sorted, 0.05),
    p25: percentile(sorted, 0.25),
    p75: percentile(sorted, 0.75),
    p95: percentile(sorted, 0.95),
    minimum: sorted.first,
    maximum: sorted.last,
    trimFraction: trimFraction,
  );
}
