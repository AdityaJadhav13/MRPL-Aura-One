import 'package:meta/meta.dart';

/// One row of a future calibration dataset. MEASUREMENT-INTEGRATION-02 §57.
///
/// ## A schema, with no rows
///
/// No row exists, because no badge has been exposed to a known H₂S condition.
/// The type fixes what a row must carry so the first exposure run collects it
/// all, rather than discovering afterwards what was not recorded.
///
/// ## Where the label comes from
///
/// [trueIntegratedDosePpmH] is `D_true = ∫ C_reference(t) dt`, integrated from
/// a qualified reference instrument at the badge plane — [doseInstrument]. It
/// is never derived from the badge's own colour: a dose computed from the
/// optical response and then used to calibrate that response is circular, and
/// would validate perfectly while measuring nothing. §56.
///
/// ## Exposure history, not just the total
///
/// [concentrationHistoryReference] points at the concentration–time trace,
/// not only its integral. The reciprocity experiment — equal `D_true` reached
/// by different `C × t` histories — can only be analysed if the history was
/// kept. If equal doses leave different optical states, one endpoint
/// photograph does not identify cumulative dose, and no model recovers
/// information the chemistry did not retain. §64.
///
/// Every field that was not measured is null. None is defaulted.
@immutable
final class CalibrationRow {
  const CalibrationRow({
    required this.sampleId,
    required this.specimenId,
    required this.captureId,
    this.badgeId,
    this.batchId,
    this.formulationId,
    this.substrate,
    this.diffusionConfiguration,
    this.geometryVersion,
    this.exposureRunId,
    this.concentrationHistoryReference,
    this.exposureDuration,
    this.trueIntegratedDosePpmH,
    this.doseInstrument,
    this.temperatureC,
    this.relativeHumidityPercent,
    this.airflowMetresPerSecond,
    this.interferents = const <String>[],
    this.deviceModel,
    this.rawImageFile,
    this.rectifiedImageFile,
    this.correctionMethod,
    this.featureDefinitionVersion,
    this.algorithmVersion,
    this.appVersion,
    this.features = const <String, double>{},
    this.acquisitionValid,
  });

  final String sampleId;
  final String specimenId;
  final String captureId;
  final String? badgeId;
  final String? batchId;
  final String? formulationId;
  final String? substrate;
  final String? diffusionConfiguration;
  final String? geometryVersion;

  final String? exposureRunId;
  final String? concentrationHistoryReference;
  final Duration? exposureDuration;

  /// From the reference instrument. Null until one has measured it.
  final double? trueIntegratedDosePpmH;
  final String? doseInstrument;

  /// At the badge, measured. Not phone weather and not internet weather —
  /// neither is the badge's microclimate. §71.
  final double? temperatureC;
  final double? relativeHumidityPercent;
  final double? airflowMetresPerSecond;
  final List<String> interferents;

  final String? deviceModel;
  final String? rawImageFile;
  final String? rectifiedImageFile;
  final String? correctionMethod;
  final String? featureDefinitionVersion;
  final String? algorithmVersion;
  final String? appVersion;

  /// The optical features, by name, exactly as the capture record holds them.
  final Map<String, double> features;

  /// A row whose acquisition failed its quality checks is kept for analysis
  /// and excluded from fitting.
  final bool? acquisitionValid;

  /// Whether this row may be used to fit a model at all.
  bool get hasReferenceLabel =>
      trueIntegratedDosePpmH != null && doseInstrument != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 'doseband-calibration-row/1',
    'sample_id': sampleId,
    'specimen_id': specimenId,
    'capture_id': captureId,
    'badge_id': badgeId,
    'batch_id': batchId,
    'formulation_id': formulationId,
    'substrate': substrate,
    'diffusion_configuration': diffusionConfiguration,
    'geometry_version': geometryVersion,
    'exposure_run_id': exposureRunId,
    'concentration_history_reference': concentrationHistoryReference,
    'exposure_duration_seconds': exposureDuration?.inSeconds,
    'true_integrated_dose_ppm_h': trueIntegratedDosePpmH,
    'dose_instrument': doseInstrument,
    'temperature_c': temperatureC,
    'relative_humidity_percent': relativeHumidityPercent,
    'airflow_m_per_s': airflowMetresPerSecond,
    'interferents': interferents,
    'device_model': deviceModel,
    'raw_image_file': rawImageFile,
    'rectified_image_file': rectifiedImageFile,
    'correction_method': correctionMethod,
    'feature_definition_version': featureDefinitionVersion,
    'algorithm_version': algorithmVersion,
    'app_version': appVersion,
    'acquisition_valid': acquisitionValid,
    'features': features,
  };
}
