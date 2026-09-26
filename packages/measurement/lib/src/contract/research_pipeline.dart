import 'package:meta/meta.dart';

import '../colour/colour_types.dart';
import '../colour/delta_e.dart';
import '../colour/lab.dart';
import '../colour/srgb.dart';
import '../colour/reference_correction.dart';
import '../features/roi_sample.dart';
import '../geometry/badge_geometry.dart';
import '../geometry/homography.dart';
import '../imaging/rgb_image.dart';
import '../quality/image_quality.dart';
import '../validity/measurement_result.dart';
import '../validity/result_status.dart';
import 'data_domain.dart';
import 'feature_vector.dart';

/// The algorithm version this milestone's arithmetic is identified by.
const String algorithmVersion = 'm0a';

/// Everything M0A can say about a photograph of a badge.
///
/// Note what is absent: there is no dose, and no field that could hold one.
/// M0A extracts optical features and validates the conditions under which they
/// were extracted. Turning a feature into an exposure requires a calibration
/// model, and none exists — see `research/gates/`.
@immutable
final class ResearchObservation {
  const ResearchObservation({
    required this.dataDomain,
    required this.featureVector,
    required this.quality,
    required this.samples,
    required this.referenceValidation,
    required this.reprojectionRmsPx,
    this.correctionFit,
  });

  final DataDomain dataDomain;
  final FeatureVector featureVector;
  final ImageQuality quality;
  final Map<String, RoiSample> samples;

  /// Null when no correction could be fitted at all.
  final ReferenceValidation? referenceValidation;

  final double reprojectionRmsPx;

  /// The fitted correction — form, matrix, conditioning — or why none fitted.
  ///
  /// Kept so a stored observation says *which* correction produced its
  /// corrected values. Without it, a record written today cannot be compared
  /// with one written after M0C chooses a different method.
  final CorrectionFit? correctionFit;

  Map<String, Object?> toJson() => <String, Object?>{
    'data_domain': dataDomain.name,
    'disclosure': dataDomain.disclosure,
    'algorithm_version': algorithmVersion,
    'reprojection_rms_px': reprojectionRmsPx,
    'quality': quality.toJson(),
    'reference_validation': referenceValidation?.toJson(),
    'correction_fit': correctionFit?.toJson(),
    'samples': <String, Object?>{
      for (final e in samples.entries) e.key: e.value.toJson(),
    },
    'feature_vector': featureVector.toJson(),
  };
}

/// Raised when an observation cannot be made at all.
final class ObservationFailure implements Exception {
  const ObservationFailure(this.reason);

  final ReasonCode reason;

  @override
  String toString() => 'ObservationFailure: $reason';
}

/// Extracts optical features from a badge photograph.
///
/// [correspondences] come from outside: M0A has no fiducial detector, and
/// supplying exact correspondences keeps the geometry maths testable
/// independently of blob detection. The detector is M0B.
///
/// [dataDomain] must be stated by the caller. There is no default, because a
/// default is how a simulated observation eventually gets treated as a real
/// one.
ResearchObservation observe({
  required RgbImage image,
  required BadgeGeometry geometry,
  required List<Correspondence> correspondences,
  required DataDomain dataDomain,
  required Map<String, LinearRgb> referenceTargets,
  required List<String> fitPatchIds,
  required List<String> holdoutPatchIds,
  double samplesPerMm = 20.0,
  double trimFraction = 0.1,
}) {
  final geometryProblems = geometry.validate();
  if (geometryProblems.isNotEmpty) {
    throw ObservationFailure(
      ReasonCode('GEOMETRY_INVALID', detail: geometryProblems.join('; ')),
    );
  }

  final estimate = estimateHomography(correspondences);
  if (!estimate.isOk) {
    throw ObservationFailure(
      ReasonCode(
        'GEOMETRY_NOT_RECOVERED',
        detail: '${estimate.rejection!.name}: ${estimate.detail}',
      ),
    );
  }
  final homography = estimate.homography!;

  final sensorRois = geometry.ofKind(RoiKind.sensor).toList();
  if (sensorRois.isEmpty) {
    throw const ObservationFailure(ReasonCode('NO_SENSOR_REGION'));
  }

  final wanted = <String>{
    for (final roi in sensorRois) roi.id,
    for (final roi in geometry.ofKind(RoiKind.blank)) roi.id,
    // Sampled and stored, never interpreted. Its optical state is recorded
    // so ageing chemistry can be studied once it exists; nothing here turns
    // it into a claim that a badge has expired, because no ageing chemistry
    // has been validated. Date expiry and chemical age are different facts.
    for (final roi in geometry.ofKind(RoiKind.expiry)) roi.id,
    ...fitPatchIds,
    ...holdoutPatchIds,
  };

  final samples = <String, RoiSample>{};
  for (final id in wanted) {
    final roi = geometry.roiById(id);
    if (roi == null) {
      throw ObservationFailure(ReasonCode('UNKNOWN_REGION', detail: id));
    }
    try {
      samples[id] = sampleRoi(
        image: image,
        badgeToImage: homography,
        roi: roi,
        samplesPerMm: samplesPerMm,
        trimFraction: trimFraction,
      );
    } on EmptyRoiException catch (e) {
      throw ObservationFailure(
        ReasonCode('REGION_UNREADABLE', detail: e.toString()),
      );
    }
  }

  ReferencePatch patchOf(String id) {
    final target = referenceTargets[id];
    if (target == null) {
      throw ObservationFailure(
        ReasonCode('REFERENCE_TARGET_MISSING', detail: id),
      );
    }
    return ReferencePatch(
      id: id,
      measured: samples[id]!.trimmedMeanLinear,
      target: target,
    );
  }

  final fit = fitCorrection(<ReferencePatch>[
    for (final id in fitPatchIds) patchOf(id),
  ]);
  final validation = fit.isOk
      ? validateCorrection(
          correction: fit.correction!,
          holdoutPatches: <ReferencePatch>[
            for (final id in holdoutPatchIds) patchOf(id),
          ],
        )
      : null;

  final sensor = samples[sensorRois.first.id]!;
  final corrected = fit.isOk
      ? fit.correction!.apply(sensor.trimmedMeanLinear)
      : null;

  final blankRois = geometry.ofKind(RoiKind.blank).toList();
  final blank = blankRois.isEmpty ? null : samples[blankRois.first.id];

  final sensorLab = sensor.lab;
  final features = <Feature>[
    Feature('sensor_linear_r', sensor.trimmedMeanLinear.r),
    Feature('sensor_linear_g', sensor.trimmedMeanLinear.g),
    Feature('sensor_linear_b', sensor.trimmedMeanLinear.b),
    Feature('sensor_lab_l', sensorLab.lStar),
    Feature('sensor_lab_a', sensorLab.aStar),
    Feature('sensor_lab_b', sensorLab.bStar),
    Feature('sensor_chroma', sensorLab.chroma),
    Feature('sensor_usable_fraction', sensor.usableFraction),
    Feature('sensor_max_channel_iqr', sensor.maximumChannelIqr),
    if (corrected != null) ...<Feature>[
      Feature('corrected_linear_r', corrected.r),
      Feature('corrected_linear_g', corrected.g),
      Feature('corrected_linear_b', corrected.b),
      Feature('corrected_lab_l', corrected.toXyz().toLab().lStar),
      Feature('corrected_lab_a', corrected.toXyz().toLab().aStar),
      Feature('corrected_lab_b', corrected.toXyz().toLab().bStar),
    ],
    if (blank != null) ...<Feature>[
      Feature('blank_lab_l', blank.lab.lStar),
      Feature('sensor_blank_delta_e00', deltaE2000(sensorLab, blank.lab)),
      Feature('sensor_blank_delta_e76', deltaE76(sensorLab, blank.lab)),
      Feature('sensor_minus_blank_lab_l', sensorLab.lStar - blank.lab.lStar),
    ],
    if (validation != null) ...<Feature>[
      Feature('reference_max_delta_e00', validation.maximumDeltaE00),
      Feature('reference_mean_delta_e00', validation.meanDeltaE00),
    ],
  ];

  return ResearchObservation(
    dataDomain: dataDomain,
    featureVector: FeatureVector(
      definitionVersion: featureDefinitionVersion,
      dataDomain: dataDomain,
      geometryVersion: geometry.version,
      features: features,
      rawSensorLinear: sensor.trimmedMeanLinear,
      correctedSensorLinear: corrected,
    ),
    quality: measureImageQuality(image),
    samples: samples,
    referenceValidation: validation,
    reprojectionRmsPx: homography.reprojectionRmsPx(correspondences),
    correctionFit: fit,
  );
}

/// Converts an observation into a [MeasurementResult].
///
/// **In M0A this always refuses, and that is not a placeholder.**
///
/// A dose requires a calibration model, and no calibration model exists for
/// any DoseBand chemistry. More than that: two scientific gates are open that
/// can invalidate the ppm-h quantity itself —
/// `research/gates/s1-passive-uptake.md` (whether the badge integrates
/// concentration or deposition flux) and
/// `research/gates/s2-chemical-integration.md` (whether the chemistry retains
/// a response at all). Until those close, a number here would not merely be
/// uncalibrated; it might be a number for the wrong quantity.
///
/// The signature takes no model parameter on purpose. When a validated model
/// exists this function gains one, and that change is a visible, reviewable
/// diff rather than a config value someone sets.
MeasurementResult refuseForLackOfCalibration(
  ResearchObservation observation, {
  required String appVersion,
  required String deviceModel,
}) => Refused(
  status: ResultStatus.unsupportedCalibration,
  reasons: <ReasonCode>[
    const ReasonCode(
      'NO_CALIBRATION_MODEL',
      detail:
          'no validated calibration model exists for any DoseBand '
          'formulation; optical features were extracted but cannot be '
          'converted to an exposure',
    ),
    ReasonCode('DATA_DOMAIN', detail: observation.dataDomain.disclosure),
  ],
  provenance: Provenance(
    algorithmVersion: algorithmVersion,
    geometryVersion: observation.featureVector.geometryVersion,
    // Null, and the type permits null here precisely because this is the
    // normal state of the system today.
    calibrationModelId: null,
    referenceProfileId: null,
    appVersion: appVersion,
    deviceModel: deviceModel,
  ),
);
