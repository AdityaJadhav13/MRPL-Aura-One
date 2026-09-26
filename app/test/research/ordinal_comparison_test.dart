import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/research/domain/ordinal_comparison.dart';

Map<String, Object?> _record(
  String id,
  String? level,
  Map<String, double> features, {
  String outcome = 'observed',
  bool deliberate = false,
}) => <String, Object?>{
  'capture_id': id,
  'outcome': outcome,
  'conditions': <String, Object?>{'is_deliberate_failure': deliberate},
  'specimen': <String, Object?>{'specimen_id': id, 'series_level': level},
  'feature_vector': <String, Object?>{
    'features': <Object?>[
      for (final e in features.entries)
        <String, Object?>{'name': e.key, 'value': e.value},
    ],
  },
};

void main() {
  test('reports a feature rising across X0–X3 as increasing', () {
    final result = compareBySeriesLevel(<Map<String, Object?>>[
      _record('a', 'X0', {'f': 1.0}),
      _record('b', 'X1', {'f': 2.0}),
      _record('c', 'X2', {'f': 3.0}),
      _record('d', 'X3', {'f': 4.0}),
    ]);
    final f = result.features.single;
    expect(f.direction, OrderingDirection.increasing);
    expect(f.reversals, isEmpty);
    expect(result.levels, <String>['X0', 'X1', 'X2', 'X3']);
  });

  test('names the step that goes the wrong way', () {
    // The Carpenter et al. failure mode: a response that turns back on
    // itself. A monotonic fit through this would be confidently wrong.
    final result = compareBySeriesLevel(<Map<String, Object?>>[
      _record('a', 'X0', {'b_star': 10}),
      _record('b', 'X1', {'b_star': 6}),
      _record('c', 'X2', {'b_star': 8}),
      _record('d', 'X3', {'b_star': 2}),
    ]);
    final f = result.features.single;
    expect(f.direction, OrderingDirection.nonMonotonic);
    expect(f.reversals, <String>['X1→X2']);
  });

  test('never pools refusals or staged failures with valid captures', () {
    final result = compareBySeriesLevel(<Map<String, Object?>>[
      _record('good0', 'X0', {'f': 1}),
      _record('good1', 'X1', {'f': 2}),
      // Would reverse the ordering if it were counted.
      _record('refused', 'X1', {'f': -100}, outcome: 'refused'),
      _record('staged', 'X1', {'f': -100}, deliberate: true),
    ]);
    expect(result.features.single.direction, OrderingDirection.increasing);
    expect(result.excludedCaptures.keys, containsAll(['refused', 'staged']));
  });

  test('a single capture per level has no spread, not zero spread', () {
    // Reporting zero would claim perfect repeatability from one photograph.
    final result = compareBySeriesLevel(<Map<String, Object?>>[
      _record('a', 'X0', {'f': 1}),
      _record('b', 'X1', {'f': 2}),
    ]);
    final groups = result.features.single.groups;
    expect(groups.first.standardDeviation, isNull);
    expect(separation(groups[0], groups[1]), isNull);
  });

  test('separation is reported with enough captures', () {
    final result = compareBySeriesLevel(<Map<String, Object?>>[
      _record('a1', 'X0', {'f': 1.0}),
      _record('a2', 'X0', {'f': 1.2}),
      _record('b1', 'X1', {'f': 3.0}),
      _record('b2', 'X1', {'f': 3.2}),
    ]);
    final g = result.features.single.groups;
    final s = separation(g[0], g[1])!;
    // Step of 2.0 against a pooled sd of ~0.1414.
    expect(s, closeTo(2.0 / 0.14142, 0.01));
  });

  test('carries no dose axis anywhere', () {
    // §42: an intended order is not an exposure.
    final result = compareBySeriesLevel(<Map<String, Object?>>[
      _record('a', 'X0', {'f': 1}),
      _record('b', 'X1', {'f': 2}),
    ]);
    for (final g in result.features.single.groups) {
      expect(g.level, isNot(contains('ppm')));
    }
  });

  test('one level of data is insufficient, not monotonic', () {
    final result = compareBySeriesLevel(<Map<String, Object?>>[
      _record('a', 'X2', {'f': 1}),
      _record('b', 'X2', {'f': 2}),
    ]);
    expect(result.features.single.direction, OrderingDirection.insufficient);
  });
}
