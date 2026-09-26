import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Compares optical features across specimens in an intended order.
///
/// ## What this answers, and what it refuses to
///
/// Given captures of specimens labelled `X0` < `X1` < `X2` < `X3`, it answers
/// §43's questions per feature: *are the levels optically distinguishable, and
/// do they move in one direction?* It does that descriptively — group means,
/// spreads, the direction of each step, and a separation ratio — and it issues
/// no verdict. There is no threshold for "distinguishable" because none has
/// been established, and a threshold invented here would become the de facto
/// acceptance criterion for the chemistry.
///
/// It is **ordinal**. The levels carry no dose, because none is known until a
/// reference instrument measures one at the badge plane (§42, §47). The engine
/// has a dose-response tool (`monotonicity.dart`); feeding it these ranks as
/// if they were doses would be exactly the mislabelling §42 forbids. G-15.
///
/// Research only. Nothing in the measurement path calls this.
@immutable
final class OrdinalComparison {
  const OrdinalComparison({
    required this.levels,
    required this.features,
    required this.excludedCaptures,
  });

  /// Series levels found, in the order compared.
  final List<String> levels;

  final List<FeatureOrdering> features;

  /// Captures left out, and why — refused acquisitions and deliberate
  /// failures. Reported so the reader can see what the numbers are *not*
  /// drawn from.
  final Map<String, String> excludedCaptures;
}

/// One feature's behaviour across the levels.
@immutable
final class FeatureOrdering {
  const FeatureOrdering({
    required this.feature,
    required this.groups,
    required this.direction,
    required this.reversals,
  });

  final String feature;
  final List<LevelGroup> groups;
  final OrderingDirection direction;

  /// Step indices where the mean moved against the majority direction, e.g.
  /// `X1→X2`.
  final List<String> reversals;
}

@immutable
final class LevelGroup {
  const LevelGroup({required this.level, required this.values});

  final String level;
  final List<double> values;

  int get count => values.length;

  double get mean => values.reduce((a, b) => a + b) / values.length;

  /// Sample standard deviation. Null with fewer than two captures: one capture
  /// has no spread, and reporting zero would claim perfect repeatability.
  double? get standardDeviation {
    if (values.length < 2) return null;
    final m = mean;
    final ss = values.fold<double>(0, (s, v) => s + (v - m) * (v - m));
    return math.sqrt(ss / (values.length - 1));
  }
}

enum OrderingDirection {
  /// Every step between adjacent levels increased.
  increasing,

  /// Every step decreased.
  decreasing,

  /// At least one step went the other way, or did not move.
  nonMonotonic,

  /// Fewer than two levels had data.
  insufficient,
}

/// The separation between two adjacent levels, in units of their pooled
/// standard deviation.
///
/// Descriptive only. A value near zero says the step is lost in the
/// capture-to-capture spread; a large value says it is not. What counts as
/// large enough is a question for physical evidence, not for this function.
/// Null when either level has fewer than two captures.
double? separation(LevelGroup a, LevelGroup b) {
  final sa = a.standardDeviation;
  final sb = b.standardDeviation;
  if (sa == null || sb == null) return null;
  final pooled = math.sqrt(
    ((a.count - 1) * sa * sa + (b.count - 1) * sb * sb) /
        (a.count + b.count - 2),
  );
  if (pooled == 0) return null;
  return (b.mean - a.mean).abs() / pooled;
}

/// Compares every feature across the series levels in [records].
///
/// [records] are archived capture records (`record.json` contents). Only
/// observed, non-deliberate captures with a series level contribute.
/// [order] fixes the comparison order; levels not in it are ignored.
OrdinalComparison compareBySeriesLevel(
  List<Map<String, Object?>> records, {
  List<String> order = const <String>['X0', 'X1', 'X2', 'X3'],
}) {
  final excluded = <String, String>{};
  // feature -> level -> values
  final table = <String, Map<String, List<double>>>{};

  for (final r in records) {
    final id = r['capture_id'] as String? ?? '?';
    final conditions = r['conditions'] as Map<String, Object?>?;
    if (conditions?['is_deliberate_failure'] == true) {
      excluded[id] = 'deliberate failure';
      continue;
    }
    if (r['outcome'] != 'observed') {
      excluded[id] = 'acquisition refused';
      continue;
    }
    // Observed but failed a measurement-critical check — e.g. the withheld
    // references were not predicted. The features exist and are archived,
    // but they are not a basis for comparison.
    if (r['acquisition_valid'] == false) {
      excluded[id] = 'acquisition not valid';
      continue;
    }
    final specimen = r['specimen'] as Map<String, Object?>?;
    final level = specimen?['series_level'] as String?;
    if (level == null || !order.contains(level)) {
      excluded[id] = 'no series level';
      continue;
    }
    final vector = r['feature_vector'] as Map<String, Object?>?;
    final features = vector?['features'] as List<Object?>? ?? const [];
    for (final f in features) {
      final m = f! as Map<String, Object?>;
      final name = m['name']! as String;
      final value = (m['value'] as num?)?.toDouble();
      if (value == null || !value.isFinite) continue;
      table
          .putIfAbsent(name, () => <String, List<double>>{})
          .putIfAbsent(level, () => <double>[])
          .add(value);
    }
  }

  final present = <String>{for (final byLevel in table.values) ...byLevel.keys};
  final levels = [
    for (final l in order)
      if (present.contains(l)) l,
  ];

  final orderings = <FeatureOrdering>[];
  for (final entry in table.entries) {
    final groups = <LevelGroup>[
      for (final l in levels)
        if (entry.value[l] case final values?)
          LevelGroup(level: l, values: values),
    ];

    if (groups.length < 2) {
      orderings.add(
        FeatureOrdering(
          feature: entry.key,
          groups: groups,
          direction: OrderingDirection.insufficient,
          reversals: const <String>[],
        ),
      );
      continue;
    }

    final steps = <double>[
      for (var i = 1; i < groups.length; i++)
        groups[i].mean - groups[i - 1].mean,
    ];
    final ups = steps.where((d) => d > 0).length;
    final downs = steps.where((d) => d < 0).length;

    final OrderingDirection direction;
    if (ups == steps.length) {
      direction = OrderingDirection.increasing;
    } else if (downs == steps.length) {
      direction = OrderingDirection.decreasing;
    } else {
      direction = OrderingDirection.nonMonotonic;
    }

    final majorityUp = ups >= downs;
    final reversals = <String>[
      for (var i = 0; i < steps.length; i++)
        if (steps[i] == 0 || (steps[i] > 0) != majorityUp)
          '${groups[i].level}→${groups[i + 1].level}',
    ];

    orderings.add(
      FeatureOrdering(
        feature: entry.key,
        groups: groups,
        direction: direction,
        reversals: direction == OrderingDirection.nonMonotonic
            ? reversals
            : const <String>[],
      ),
    );
  }

  orderings.sort((a, b) => a.feature.compareTo(b.feature));
  return OrdinalComparison(
    levels: levels,
    features: orderings,
    excludedCaptures: excluded,
  );
}
