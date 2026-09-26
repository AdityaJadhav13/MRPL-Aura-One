import 'package:meta/meta.dart';

import '../features/statistics.dart';
import '../imaging/rgb_image.dart';

/// A rectangular window of the image, in pixels.
@immutable
final class PixelRect {
  const PixelRect(this.left, this.top, this.width, this.height)
    : assert(width > 0 && height > 0, 'rect must have positive extent');

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width;
  int get bottom => top + height;
}

/// Individually meaningful image-quality measurements. Directive s10.
///
/// There is deliberately **no overall score**. Combining these into one
/// number would invent a quantity nobody has calibrated, and would let a
/// severe failure on one axis be averaged away by comfortable values on the
/// others. Each metric is reported, and each gate is applied separately.
@immutable
final class ImageQuality {
  const ImageQuality({
    required this.region,
    required this.pixelCount,
    required this.laplacianVariance,
    required this.highClipFraction,
    required this.lowClipFraction,
    required this.specularFraction,
    required this.luma,
  });

  final PixelRect region;
  final int pixelCount;

  /// Variance of the Laplacian of the luma plane — the standard sharpness
  /// proxy. Higher is sharper.
  ///
  /// It is **scale-dependent**: the same badge photographed larger in frame
  /// scores higher. It is therefore only comparable between images at a
  /// similar pixels-per-millimetre, which is why the geometry stage records
  /// scale and why any threshold on this must be expressed against it.
  final double laplacianVariance;

  /// Fraction of pixels with at least one channel at or above the high rail.
  final double highClipFraction;

  /// Fraction with at least one channel at or below the low rail.
  final double lowClipFraction;

  /// Fraction that are bright and near-neutral — specular highlights.
  final double specularFraction;

  /// Distribution of luma over the region.
  final ChannelStatistics luma;

  Map<String, Object?> toJson() => <String, Object?>{
    'pixel_count': pixelCount,
    'laplacian_variance': laplacianVariance,
    'high_clip_fraction': highClipFraction,
    'low_clip_fraction': lowClipFraction,
    'specular_fraction': specularFraction,
    'luma': luma.toJson(),
  };
}

/// Measures [image] over [region], or over the whole frame when omitted.
///
/// The Laplacian is the 4-neighbour discrete form, evaluated only where all
/// four neighbours lie inside the region, so the measurement never depends on
/// an edge-padding convention. That matters for the cross-language golden
/// vectors: padding is exactly the sort of unstated choice on which two
/// implementations silently differ.
ImageQuality measureImageQuality(
  RgbImage image, {
  PixelRect? region,
  double clipHigh = 0.99,
  double clipLow = 0.01,
  double specularLuma = 0.95,
  double specularChroma = 0.06,
}) {
  final r = region ?? PixelRect(0, 0, image.width, image.height);
  if (r.left < 0 ||
      r.top < 0 ||
      r.right > image.width ||
      r.bottom > image.height) {
    throw ArgumentError('quality region falls outside the image');
  }

  var highClipped = 0;
  var lowClipped = 0;
  var specular = 0;
  final lumaValues = <double>[];
  final laplacianValues = <double>[];

  for (var y = r.top; y < r.bottom; y++) {
    for (var x = r.left; x < r.right; x++) {
      final rr = image.red(x, y) / 255.0;
      final gg = image.green(x, y) / 255.0;
      final bb = image.blue(x, y) / 255.0;

      final maxChannel = <double>[rr, gg, bb].reduce((a, b) => a > b ? a : b);
      final minChannel = <double>[rr, gg, bb].reduce((a, b) => a < b ? a : b);
      if (maxChannel >= clipHigh) highClipped++;
      if (minChannel <= clipLow) lowClipped++;

      final l = image.luma(x, y);
      lumaValues.add(l);
      if (l >= specularLuma && (maxChannel - minChannel) <= specularChroma) {
        specular++;
      }

      final hasNeighbours =
          x > r.left && y > r.top && x < r.right - 1 && y < r.bottom - 1;
      if (hasNeighbours) {
        laplacianValues.add(
          image.luma(x - 1, y) +
              image.luma(x + 1, y) +
              image.luma(x, y - 1) +
              image.luma(x, y + 1) -
              4.0 * l,
        );
      }
    }
  }

  final count = lumaValues.length;

  // A region too small to have any interior pixel has no measurable
  // sharpness. Reporting zero would be indistinguishable from a completely
  // flat image, so it is reported as not-a-number and must be handled by the
  // caller.
  //
  // Population variance (divide by n), not the sample estimate: this
  // describes the set of Laplacian responses actually present, it does not
  // estimate a parameter of some larger population. The choice is stated here
  // because it is exactly the kind of convention on which the Dart engine and
  // the Python research stack would otherwise disagree by a factor of
  // n/(n-1) forever.
  var laplacianVariance = double.nan;
  if (laplacianValues.length > 1) {
    var sum = 0.0;
    for (final v in laplacianValues) {
      sum += v;
    }
    final mean = sum / laplacianValues.length;
    var squares = 0.0;
    for (final v in laplacianValues) {
      final d = v - mean;
      squares += d * d;
    }
    laplacianVariance = squares / laplacianValues.length;
  }

  return ImageQuality(
    region: r,
    pixelCount: count,
    laplacianVariance: laplacianVariance,
    highClipFraction: highClipped / count,
    lowClipFraction: lowClipped / count,
    specularFraction: specular / count,
    luma: summarise(lumaValues, trimFraction: 0),
  );
}
