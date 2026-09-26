import 'package:meta/meta.dart';

import '../contract/data_domain.dart';
import '../contract/research_pipeline.dart';
import '../validity/measurement_result.dart';

/// What a calibration package declares about itself. APP-INTEGRATION-01 §18.
///
/// ## This is a schema, not a calibration
///
/// No instance of this class exists anywhere in DoseBand with production
/// values, because no H₂S calibration exists. The fields describe what a
/// package *will* have to state once laboratory data supports one, so that the
/// shape is settled before the first real package is built rather than
/// improvised around it.
///
/// Every field that a real package must establish from evidence is nullable,
/// and null means **not established** — never a default, never zero.
@immutable
final class CalibrationPackage {
  const CalibrationPackage({
    required this.calibrationId,
    required this.version,
    required this.dataDomain,
    required this.geometryVersion,
    required this.featureDefinitionVersion,
    required this.modelType,
    required this.createdAt,
    this.formulationId,
    this.batchApplicability = const <String>[],
    this.validatedDomain,
    this.deviceConstraints,
    this.environmentConstraints,
    this.lowerQuantificationBound,
    this.upperQuantificationBound,
    this.saturationBehaviour,
    this.evidenceReference,
    this.supersedes,
  });

  final String calibrationId;
  final String version;

  /// Where the calibration's training data came from.
  ///
  /// A package fitted to simulated data is marked `simulated`, and
  /// [calibrationMismatch] refuses to let it interpret anything that is not.
  /// That rule is what keeps a development calibration from ever producing a
  /// number for a real photograph. §19.
  final DataDomain dataDomain;

  /// The badge geometry the features were extracted under. A package is not
  /// transferable across geometries: every ROI coordinate is part of it.
  final String geometryVersion;

  /// The feature definition the model consumes. A model trained on one set of
  /// features applied to another is not a calibration, it is a coincidence.
  final String featureDefinitionVersion;

  /// e.g. `monotonic-lookup`, `piecewise-linear`, `regression`. The
  /// application does not branch on this — §16 — it is recorded so a result
  /// can say what produced it.
  final String modelType;

  final DateTime createdAt;

  final String? formulationId;

  /// Batch ids this package may interpret. Empty means none have been
  /// established, not that all are permitted.
  final List<String> batchApplicability;

  /// Free-form until the validated domain has a settled structure: the range
  /// of conditions over which the model was actually tested.
  final Map<String, Object?>? validatedDomain;
  final Map<String, Object?>? deviceConstraints;
  final Map<String, Object?>? environmentConstraints;

  /// In ppm·h. Null until established experimentally.
  final double? lowerQuantificationBound;
  final double? upperQuantificationBound;

  final String? saturationBehaviour;

  /// A pointer to the evidence the package was built from — a dataset id, a
  /// report. A calibration with no evidence reference is a claim, not a model.
  final String? evidenceReference;

  /// The package id this one replaces. A superseding calibration never
  /// rewrites results produced under the one it replaces. §51.
  final String? supersedes;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 'doseband-calibration-package/1',
    'calibration_id': calibrationId,
    'version': version,
    'data_domain': dataDomain.name,
    'geometry_version': geometryVersion,
    'feature_definition_version': featureDefinitionVersion,
    'model_type': modelType,
    'created_at': createdAt.toUtc().toIso8601String(),
    'formulation_id': formulationId,
    'batch_applicability': batchApplicability,
    'validated_domain': validatedDomain,
    'device_constraints': deviceConstraints,
    'environment_constraints': environmentConstraints,
    'lower_quantification_bound_ppm_h': lowerQuantificationBound,
    'upper_quantification_bound_ppm_h': upperQuantificationBound,
    'saturation_behaviour': saturationBehaviour,
    'evidence_reference': evidenceReference,
    'supersedes': supersedes,
  };
}

/// Turns an optical observation into a measurement result. §16.
///
/// ## The boundary this exists to hold
///
/// Camera, geometry, colour correction, the worker screens, HSE and reporting
/// all sit on one side of this interface. The chemistry-specific mapping from
/// optical features to cumulative exposure sits on the other. When a real
/// calibration exists, it arrives as a new implementation of this interface —
/// and nothing on the near side is rewritten. §20.
///
/// The application never asks what kind of model it holds. It asks for an
/// interpretation and gets back the same `MeasurementResult` types every
/// screen already renders.
///
/// ## Why adding one is still a reviewable change
///
/// The engine deliberately gave `refuseForLackOfCalibration` no model
/// parameter, so that switching on quantitative output could never be a
/// config value someone sets. This interface keeps that property: the only
/// implementation is [NoCalibration], and a real one is a new class in a
/// reviewable diff, carrying a [CalibrationPackage] whose evidence reference
/// someone has to supply.
abstract interface class Calibration {
  /// The package this calibration was built from. Null when none applies.
  CalibrationPackage? get package;

  MeasurementResult interpret(
    ResearchObservation observation, {
    required String appVersion,
    required String deviceModel,
  });
}

/// The only calibration that exists in DoseBand today.
///
/// Refuses every observation with `unsupportedCalibration`, by construction.
/// The optical acquisition may have been perfectly valid — the refusal says
/// only that there is no evidence-backed way to turn it into an exposure. §17.
final class NoCalibration implements Calibration {
  const NoCalibration();

  @override
  CalibrationPackage? get package => null;

  @override
  MeasurementResult interpret(
    ResearchObservation observation, {
    required String appVersion,
    required String deviceModel,
  }) => refuseForLackOfCalibration(
    observation,
    appVersion: appVersion,
    deviceModel: deviceModel,
  );
}

/// Why [package] may not interpret [observation], or null if it may.
///
/// Every real [Calibration] must call this before predicting. The checks are
/// the ones that do not depend on the chemistry and therefore can be written
/// before any chemistry is known:
///
/// * a calibration fitted to **simulated** data never interprets a real
///   capture — the rule that keeps development calibration out of physical
///   research (§19);
/// * a calibration is bound to the geometry its features were extracted under;
/// * a calibration is bound to the feature definition it was trained on.
ReasonCode? calibrationMismatch(
  CalibrationPackage package,
  ResearchObservation observation,
) {
  if (package.dataDomain == DataDomain.simulated &&
      observation.dataDomain != DataDomain.simulated) {
    return ReasonCode(
      'SIMULATED_CALIBRATION_ON_REAL_CAPTURE',
      detail:
          '${package.calibrationId} was fitted to simulated data and may not '
          'interpret a ${observation.dataDomain.name} observation',
    );
  }
  if (package.geometryVersion != observation.featureVector.geometryVersion) {
    return ReasonCode(
      'CALIBRATION_GEOMETRY_MISMATCH',
      detail:
          'package expects ${package.geometryVersion}, observation used '
          '${observation.featureVector.geometryVersion}',
    );
  }
  if (package.featureDefinitionVersion !=
      observation.featureVector.definitionVersion) {
    return ReasonCode(
      'CALIBRATION_FEATURE_DEFINITION_MISMATCH',
      detail:
          'package expects ${package.featureDefinitionVersion}, observation '
          'used ${observation.featureVector.definitionVersion}',
    );
  }
  return null;
}
