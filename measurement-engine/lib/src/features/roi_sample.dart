import 'package:meta/meta.dart';

import '../colour/colour_types.dart';
import '../colour/lab.dart';
import '../colour/srgb.dart';
import '../geometry/badge_geometry.dart';
import '../geometry/homography.dart';
import '../imaging/rgb_image.dart';
import 'statistics.dart';

/// Why an individual sample point was excluded from an ROI statistic.
enum SampleExclusion {
  /// The point mapped outside the image.
  outOfFrame,

  /// At least one channel is at or beyond the sensor's rail. A clipped
  /// channel carries no recoverable information, so it is excluded rather
  /// than corrected — see `docs/computer-vision/pipeline.md` s3.
  clipped,

  /// Bright and near-neutral: a specular highlight reflecting the illuminant
  /// rather than the surface.
  specular,
}

/// Thresholds for excluding sample points.
///
/// **Provisional.** These are development values chosen to be obviously
/// defensible, not empirical ones. They have not been set from photographs of
/// a real badge on a real device matrix, and directive s9 requires that they
/// be labelled as provisional until they have been.
@immutable
final class SampleGuards {
  const SampleGuards({
    this.clipHigh = 0.99,
    this.clipLow = 0.01,
    this.specularLuma = 0.95,
    this.specularChroma = 0.06,
    this.provisional = true,
  });

  /// A channel at or above this (normalised, gamma-encoded) is treated as
  /// clipped high.
  final double clipHigh;

  /// A channel at or below this is treated as clipped low.
  final double clipLow;

  /// Luma above which a near-neutral pixel is considered specular.
  final double specularLuma;

  /// Chroma (max channel minus min channel) below which a bright pixel is
  /// considered neutral, and therefore a reflection of the source rather than
  /// of the surface.
  final double specularChroma;

  /// Whether these values are still development placeholders. Carried into the
  /// sample so a downstream consumer cannot mistake a provisional rejection
  /// for a validated one.
  final bool provisional;
}

/// The statistics of one region of the badge, with the evidence about how
/// much of it was actually usable.
@immutable
final class RoiSample {
  const RoiSample({
    required this.roiId,
    required this.kind,
    required this.requestedSamples,
    required this.usedSamples,
    required this.exclusions,
    required this.linearR,
    required this.linearG,
    required this.linearB,
    required this.trimmedMeanLinear,
    required this.medianLinear,
    required this.guardsWereProvisional,
  });

  final String roiId;
  final RoiKind kind;

  /// Points on the canonical sampling grid inside the eroded region.
  final int requestedSamples;

  /// Points that survived every guard and entered the statistics.
  final int usedSamples;

  final Map<SampleExclusion, int> exclusions;

  final ChannelStatistics linearR;
  final ChannelStatistics linearG;
  final ChannelStatistics linearB;

  /// The region's representative colour: the per-channel trimmed mean in
  /// linear light.
  final LinearRgb trimmedMeanLinear;

  final LinearRgb medianLinear;

  final bool guardsWereProvisional;

  /// Proportion of the region that survived the guards.
  ///
  /// A low value is not a reason to scale a result up; it is a reason to
  /// distrust the region.
  double get usableFraction =>
      requestedSamples == 0 ? 0.0 : usedSamples / requestedSamples;

  /// CIELAB of the representative colour.
  Lab get lab => trimmedMeanLinear.toXyz().toLab();

  /// A crude within-region heterogeneity measure: the largest per-channel
  /// interquartile range in linear light.
  ///
  /// A uniform chemical response is a property of a real one; a blotchy one
  /// is not to be averaged into confidence. This is the quantity a
  /// contamination check would eventually threshold — the threshold itself
  /// awaits real coupons.
  double get maximumChannelIqr => <double>[
    linearR.interquartileRange,
    linearG.interquartileRange,
    linearB.interquartileRange,
  ].reduce((a, b) => a > b ? a : b);

  Map<String, Object?> toJson() => <String, Object?>{
    'roi_id': roiId,
    'kind': kind.name,
    'requested_samples': requestedSamples,
    'used_samples': usedSamples,
    'usable_fraction': usableFraction,
    'exclusions': <String, int>{
      for (final e in exclusions.entries) e.key.name: e.value,
    },
    'linear_r': linearR.toJson(),
    'linear_g': linearG.toJson(),
    'linear_b': linearB.toJson(),
    'trimmed_mean_linear': <double>[
      trimmedMeanLinear.r,
      trimmedMeanLinear.g,
      trimmedMeanLinear.b,
    ],
    'median_linear': <double>[medianLinear.r, medianLinear.g, medianLinear.b],
    'lab': <double>[lab.lStar, lab.aStar, lab.bStar],
    'guards_were_provisional': guardsWereProvisional,
  };
}

/// Raised when a region yielded nothing to measure.
final class EmptyRoiException implements Exception {
  const EmptyRoiException(this.roiId, this.exclusions);

  final String roiId;
  final Map<SampleExclusion, int> exclusions;

  @override
  String toString() =>
      'EmptyRoiException: no usable samples in ROI "$roiId" ($exclusions)';
}

/// Samples one region of the badge through [badgeToImage]. Directive s12.
///
/// The region is walked on a regular grid in **canonical millimetre space**,
/// and each grid point is mapped forward into the image and sampled
/// bilinearly. Working in canonical space rather than warping the whole image
/// first means the ROI statistics are independent of image resolution and
/// there is no intermediate resampling pass to blur them.
///
/// [samplesPerMm] fixes the sampling density. It is part of the feature
/// definition: changing it changes the statistics, so it is recorded rather
/// than assumed.
RoiSample sampleRoi({
  required RgbImage image,
  required Homography badgeToImage,
  required RoiDefinition roi,
  double samplesPerMm = 20.0,
  SampleGuards guards = const SampleGuards(),
  double trimFraction = 0.1,
}) {
  final region = roi.eroded;
  if (region == null) {
    throw ArgumentError('ROI ${roi.id} is consumed by its erosion margin');
  }

  final columns = (region.widthMm * samplesPerMm).floor();
  final rows = (region.heightMm * samplesPerMm).floor();
  if (columns < 1 || rows < 1) {
    throw ArgumentError(
      'ROI ${roi.id} yields no sample grid at $samplesPerMm samples/mm',
    );
  }

  final rValues = <double>[];
  final gValues = <double>[];
  final bValues = <double>[];
  final exclusions = <SampleExclusion, int>{
    SampleExclusion.outOfFrame: 0,
    SampleExclusion.clipped: 0,
    SampleExclusion.specular: 0,
  };

  for (var row = 0; row < rows; row++) {
    // Sample at cell centres, so the grid is symmetric within the region and
    // does not favour one edge.
    final y = region.yMm + (row + 0.5) / samplesPerMm;
    for (var col = 0; col < columns; col++) {
      final x = region.xMm + (col + 0.5) / samplesPerMm;

      final PointPx pixel;
      try {
        pixel = badgeToImage.mapMm(PointMm(x, y));
      } on Object {
        exclusions[SampleExclusion.outOfFrame] =
            exclusions[SampleExclusion.outOfFrame]! + 1;
        continue;
      }

      final srgb = image.sampleBilinear(pixel.x, pixel.y);
      if (srgb == null) {
        exclusions[SampleExclusion.outOfFrame] =
            exclusions[SampleExclusion.outOfFrame]! + 1;
        continue;
      }

      final maxChannel = <double>[
        srgb.r,
        srgb.g,
        srgb.b,
      ].reduce((a, b) => a > b ? a : b);
      final minChannel = <double>[
        srgb.r,
        srgb.g,
        srgb.b,
      ].reduce((a, b) => a < b ? a : b);

      if (maxChannel >= guards.clipHigh || minChannel <= guards.clipLow) {
        exclusions[SampleExclusion.clipped] =
            exclusions[SampleExclusion.clipped]! + 1;
        continue;
      }

      final luma = 0.2126 * srgb.r + 0.7152 * srgb.g + 0.0722 * srgb.b;
      if (luma >= guards.specularLuma &&
          (maxChannel - minChannel) <= guards.specularChroma) {
        exclusions[SampleExclusion.specular] =
            exclusions[SampleExclusion.specular]! + 1;
        continue;
      }

      final linear = srgb.toLinear();
      rValues.add(linear.r);
      gValues.add(linear.g);
      bValues.add(linear.b);
    }
  }

  if (rValues.isEmpty) {
    throw EmptyRoiException(roi.id, exclusions);
  }

  final rStats = summarise(rValues, trimFraction: trimFraction);
  final gStats = summarise(gValues, trimFraction: trimFraction);
  final bStats = summarise(bValues, trimFraction: trimFraction);

  return RoiSample(
    roiId: roi.id,
    kind: roi.kind,
    requestedSamples: rows * columns,
    usedSamples: rValues.length,
    exclusions: exclusions,
    linearR: rStats,
    linearG: gStats,
    linearB: bStats,
    trimmedMeanLinear: LinearRgb(
      rStats.trimmedMean,
      gStats.trimmedMean,
      bStats.trimmedMean,
    ),
    medianLinear: LinearRgb(rStats.median, gStats.median, bStats.median),
    guardsWereProvisional: guards.provisional,
  );
}
