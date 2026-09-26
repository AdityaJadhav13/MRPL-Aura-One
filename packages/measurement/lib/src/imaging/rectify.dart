import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../geometry/badge_geometry.dart';
import '../geometry/homography.dart';
import 'rgb_image.dart';

/// Resamples the badge into canonical, front-on coordinates.
///
/// ## What this is for, and what it is not
///
/// **Evidence and diagnostics only.** The measurement pipeline does not use
/// it: `observe()` samples each ROI by mapping badge millimetres straight into
/// the original image, which avoids resampling the whole badge and the
/// interpolation error that would add. This function exists so that a person
/// can *look* at what the homography did — whether the fiducials land where
/// the geometry says, whether the ROIs cover the patches they should — without
/// reconstructing the mapping by hand. APP-INTEGRATION-01 §10, §14.
///
/// Nearest-neighbour on purpose: an interpolating resampler would produce a
/// smoother, more convincing picture that is further from the pixels the
/// measurement actually read.
///
/// Returns null when the homography maps part of the badge to infinity, which
/// only happens under a degenerate pose that the pipeline would already have
/// refused.
RgbImage? rectifyBadge({
  required RgbImage image,
  required Homography badgeToImage,
  required BadgeGeometry geometry,
  double pixelsPerMm = 8.0,
}) {
  final width = (geometry.widthMm * pixelsPerMm).round();
  final height = (geometry.heightMm * pixelsPerMm).round();
  if (width < 1 || height < 1) return null;

  final out = RgbImage.filled(width, height, 0, 0, 0);
  for (var y = 0; y < height; y++) {
    final yMm = (y + 0.5) / pixelsPerMm;
    for (var x = 0; x < width; x++) {
      final xMm = (x + 0.5) / pixelsPerMm;
      final double px;
      final double py;
      try {
        (px, py) = badgeToImage.mapXy(xMm, yMm);
      } on Object {
        return null;
      }
      final sx = px.floor();
      final sy = py.floor();
      // Outside the photograph: left black, never extrapolated. A rectified
      // view that invented edge pixels would hide exactly the crop it should
      // make obvious.
      if (sx < 0 || sy < 0 || sx >= image.width || sy >= image.height) {
        continue;
      }
      out.setPixel(
        x,
        y,
        image.red(sx, sy),
        image.green(sx, sy),
        image.blue(sx, sy),
      );
    }
  }
  return out;
}

/// Lossless encoding of a derived image for the evidence archive.
///
/// Used for derived views only — the rectified badge. The ORIGINAL capture is
/// never passed through here: it is stored as the exact bytes the camera
/// produced.
Uint8List encodePng(RgbImage image) {
  final out = img.Image(width: image.width, height: image.height);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      out.setPixelRgb(
        x,
        y,
        image.red(x, y),
        image.green(x, y),
        image.blue(x, y),
      );
    }
  }
  return Uint8List.fromList(img.encodePng(out));
}
