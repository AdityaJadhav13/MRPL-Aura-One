/// The H2S DoseBand scientific core.
///
/// Pure Dart. This library must never depend on Flutter — see
/// docs/decisions/0004-repository-layout.md.
///
/// Milestone M0A implements the deterministic primitives only: geometry,
/// colour science, robust statistics, image quality and reference validation.
/// **There is no calibration model and no dose inference.** Nothing in this
/// library converts an optical feature into ppm-h, because nothing yet may.
library;

export 'src/calibration/calibration.dart';
export 'src/calibration/calibration_row.dart';
export 'src/capture/capture_metadata.dart';
export 'src/capture/guidance.dart';
export 'src/capture/stability.dart';
export 'src/colour/colour_types.dart';
export 'src/colour/delta_e.dart';
export 'src/colour/lab.dart';
export 'src/colour/normalisation.dart';
export 'src/colour/reference_correction.dart';
export 'src/colour/srgb.dart';
export 'src/contract/capture_record.dart';
export 'src/contract/data_domain.dart';
export 'src/contract/feature_vector.dart';
export 'src/contract/research_pipeline.dart';
export 'src/features/roi_sample.dart';
export 'src/features/statistics.dart';
export 'src/geometry/badge_geometry.dart';
export 'src/geometry/homography.dart';
export 'src/imaging/decode.dart';
export 'src/imaging/ppm.dart';
export 'src/imaging/rectify.dart';
export 'src/imaging/rgb_image.dart';
export 'src/linalg/matrix.dart';
export 'src/geometry/fiducial_detector.dart';
export 'src/geometry/geometry_validation.dart';
export 'src/quality/acquisition_quality.dart';
export 'src/quality/image_quality.dart';
export 'src/research/monotonicity.dart';
export 'src/validity/measurement_result.dart';
export 'src/validity/result_status.dart';
