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
    this.correctionMethod,
    this.substrate,
    this.diffusionArchitecture,
    this.referenceDesign,
    this.trainingDatasetReference,
    this.validationDatasetReference,
    this.validationStatus = CalibrationValidationStatus.none,
    this.modelData,
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

  /// The colour correction the training features were produced under, e.g.
  /// `affine3x4`. Features corrected one way are not comparable with features
  /// corrected another, so a mismatch refuses. MEASUREMENT-INTEGRATION-02 §54.
  final String? correctionMethod;

  final String? substrate;
  final String? diffusionArchitecture;

  /// The reference-patch design the training captures used.
  final String? referenceDesign;

  /// Pointers to the datasets the model was fitted and validated on. The two
  /// must be different sets, held out by physical badge, batch and exposure
  /// run — not by photograph — or validation measures leakage. §92.
  final String? trainingDatasetReference;
  final String? validationDatasetReference;

  final CalibrationValidationStatus validationStatus;

  /// The model's parameters or lookup table, opaque to the application. The
  /// app never reads this — §16 — only the implementing [Calibration] does.
  final Map<String, Object?>? modelData;

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
    'correction_method': correctionMethod,
    'substrate': substrate,
    'diffusion_architecture': diffusionArchitecture,
    'reference_design': referenceDesign,
    'training_dataset_reference': trainingDatasetReference,
    'validation_dataset_reference': validationDatasetReference,
    'validation_status': validationStatus.name,
    'model_data': modelData,
  };
}

/// How far a calibration package has been validated.
enum CalibrationValidationStatus {
  /// No validation has been performed.
  none,

  /// Fitted and internally checked, not yet validated on held-out badges.
  development,

  /// Validated on held-out physical badges across the declared domain.
  validated,
}

/// What is known about the capture being interpreted, beyond its pixels.
///
/// Only validated, relevant inputs belong here. A calibration never reads
/// application or UI state — §53 — and a field that is not established is
/// null, never defaulted.
@immutable
final class MeasurementContext {
  const MeasurementContext({
    this.batchId,
    this.formulationId,
    this.correctionMethod,
    this.monitoredDuration,
  });

  final String? batchId;
  final String? formulationId;

  /// The correction the observation was actually produced under.
  final String? correctionMethod;

  /// Null when the monitored window is unknown or untrusted — a clock anomaly
  /// never becomes a duration.
  final Duration? monitoredDuration;

  static const MeasurementContext none = MeasurementContext();
}

/// Why [package] may not be made ACTIVE, or an empty list if it may.
///
/// A package does not become active because a file exists. §95. These are the
/// requirements that can be checked before any chemistry is known; each one
/// absent is a reason, and all of them are reported rather than the first.
List<ReasonCode> calibrationActivationProblems(
  CalibrationPackage package,
) => <ReasonCode>[
  if (package.dataDomain == DataDomain.simulated)
    const ReasonCode(
      'CALIBRATION_FROM_SIMULATED_DATA',
      detail: 'a package fitted to simulated data is never production',
    ),
  if (package.validationStatus != CalibrationValidationStatus.validated)
    ReasonCode(
      'CALIBRATION_NOT_VALIDATED',
      detail: 'validation status is ${package.validationStatus.name}',
    ),
  if (package.evidenceReference == null)
    const ReasonCode('CALIBRATION_WITHOUT_EVIDENCE'),
  if (package.formulationId == null)
    const ReasonCode('CALIBRATION_FORMULATION_UNSPECIFIED'),
  if (package.correctionMethod == null)
    const ReasonCode('CALIBRATION_CORRECTION_METHOD_UNSPECIFIED'),
  if (package.lowerQuantificationBound == null ||
      package.upperQuantificationBound == null)
    const ReasonCode(
      'CALIBRATION_RANGE_UNDEFINED',
      detail:
          'without a quantification range, below-limit and '
          'above-range cannot be distinguished from a value',
    ),
  if (package.batchApplicability.isEmpty)
    const ReasonCode('CALIBRATION_BATCHES_UNSPECIFIED'),
  if (package.trainingDatasetReference == null ||
      package.validationDatasetReference == null)
    const ReasonCode('CALIBRATION_DATASETS_UNSPECIFIED'),
  if (package.trainingDatasetReference != null &&
      package.trainingDatasetReference == package.validationDatasetReference)
    const ReasonCode(
      'CALIBRATION_VALIDATED_ON_TRAINING_DATA',
      detail: 'training and validation datasets are the same',
    ),
];

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
    MeasurementContext context = MeasurementContext.none,
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
    MeasurementContext context = MeasurementContext.none,
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
  ResearchObservation observation, {
  MeasurementContext context = MeasurementContext.none,
}) {
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
  final pc = package.correctionMethod;
  final oc =
      context.correctionMethod ??
      observation.correctionFit?.correction?.form.name;
  if (pc != null && pc != oc) {
    return ReasonCode(
      'CALIBRATION_CORRECTION_METHOD_MISMATCH',
      detail: 'package expects $pc, observation was corrected with $oc',
    );
  }
  final pf = package.formulationId;
  if (pf != null &&
      context.formulationId != null &&
      pf != context.formulationId) {
    return ReasonCode(
      'CALIBRATION_FORMULATION_MISMATCH',
      detail: 'package is for $pf, badge is ${context.formulationId}',
    );
  }
  // An unknown batch is not assumed to be a supported one, and the nearest
  // batch is never substituted. §96.
  final batch = context.batchId;
  if (batch == null || !package.batchApplicability.contains(batch)) {
    return ReasonCode(
      'CALIBRATION_BATCH_UNSUPPORTED',
      detail: batch == null
          ? 'badge batch unknown'
          : 'batch $batch is not in the package applicability list',
    );
  }
  return null;
}

/// The equivalent time-average concentration, from a validated cumulative
/// exposure and a trusted monitored duration. §1, §65.
///
/// `C_avg = D / T`. It is **not** an instantaneous or current concentration,
/// and a single endpoint photograph cannot recover one: the concentration
/// history is integrated away. Null unless [result] is a `Valid` quantity and
/// [monitored] is a positive, trusted duration.
({double ppm, String label})? equivalentAverageConcentration(
  MeasurementResult result,
  Duration? monitored,
) {
  if (result is! Valid || monitored == null || monitored <= Duration.zero) {
    return null;
  }
  final hours = monitored.inMicroseconds / Duration.microsecondsPerHour;
  return (
    ppm: result.dose.value / hours,
    label: 'Equivalent time-average H₂S concentration',
  );
}
