import 'package:meta/meta.dart';

import '../colour/colour_types.dart';
import 'data_domain.dart';

/// The identity of a feature definition.
///
/// A calibration model is fitted against *specific* feature arithmetic. If the
/// arithmetic changes — a different trim fraction, a different sampling
/// density, a different reference white — the old model's coefficients no
/// longer refer to the same quantity. Bumping this version is how that becomes
/// a refusal (`UNSUPPORTED_CALIBRATION`) instead of a wrong number.
///
/// Bump it for **any** change that alters a computed value, however small.
///
/// M0B bumped the minor version: the definition gained geometry-residual,
/// conditioning and monotonicity families. Every value that existed at
/// `fdv-0.1.0-m0a` is **unchanged** — this is an additive change — but the
/// version still moves, because "the definition is the same except for the
/// parts that are different" is not a property anything can check.
const String featureDefinitionVersion = 'fdv-0.2.0-m0b';

/// A named optical feature and its value.
@immutable
final class Feature {
  const Feature(this.name, this.value, {this.unit});

  final String name;
  final double value;
  final String? unit;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'value': value,
    if (unit != null) 'unit': unit,
  };
}

/// The optical description of one badge in one photograph.
///
/// Deliberately **not** a [MeasurementResult]. A feature vector is an
/// observation; a measurement result is a claim about exposure. Keeping them
/// as different types is what makes it impossible for M0A to accidentally
/// report a dose: there is no calibration model in this milestone, and this
/// type has nowhere to put one.
@immutable
final class FeatureVector {
  FeatureVector({
    required this.definitionVersion,
    required this.dataDomain,
    required this.geometryVersion,
    required List<Feature> features,
    required this.rawSensorLinear,
    this.correctedSensorLinear,
  }) : features = List<Feature>.unmodifiable(features) {
    final names = <String>{};
    for (final f in features) {
      if (!names.add(f.name)) {
        throw ArgumentError('duplicate feature name: ${f.name}');
      }
    }
  }

  final String definitionVersion;
  final DataDomain dataDomain;
  final String geometryVersion;
  final List<Feature> features;

  /// Kept separately and always, per directive s13: the uncorrected values
  /// must survive so that a future correction can be re-derived from the same
  /// observation without re-photographing the badge.
  final LinearRgb rawSensorLinear;

  /// Null when no correction could be fitted or validated.
  final LinearRgb? correctedSensorLinear;

  double? operator [](String name) {
    for (final f in features) {
      if (f.name == name) return f.value;
    }
    return null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'definition_version': definitionVersion,
    'data_domain': dataDomain.name,
    'geometry_version': geometryVersion,
    'raw_sensor_linear': <double>[
      rawSensorLinear.r,
      rawSensorLinear.g,
      rawSensorLinear.b,
    ],
    'corrected_sensor_linear': correctedSensorLinear == null
        ? null
        : <double>[
            correctedSensorLinear!.r,
            correctedSensorLinear!.g,
            correctedSensorLinear!.b,
          ],
    'features': features.map((f) => f.toJson()).toList(),
  };
}
