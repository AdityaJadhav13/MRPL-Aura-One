import 'package:meta/meta.dart';

import 'colour_types.dart';

/// Which published black/white normalisation is being applied.
///
/// Both forms appear in Escobedo et al. 2023 (QRsens, doi:10.1016/j.snb.2022.133001).
/// They are not interchangeable and the paper applies them to different
/// sensors, so the choice is carried explicitly rather than assumed.
enum BlackWhiteForm {
  /// QRsens Eq. 1 — used there for every sensor except H2S.
  ///
  ///     corrected = K * (sensor - black) / white
  ///
  /// Note this does not map black to 0 and white to K: the denominator does
  /// not span the reference interval. Implemented because it is what the paper
  /// published, not because it is recommended.
  qrsensEquation1,

  /// QRsens Eq. 2 — used there for the H2S sensor specifically, where it
  /// "experimentally delivered better results".
  ///
  ///     corrected = K * (sensor - black) / (white - black)
  ///
  /// This is the normalised form, and the one to prefer if a two-point
  /// correction is used at all.
  qrsensEquation2,
}

/// Why a black/white normalisation could not be computed.
enum BlackWhiteRejection {
  /// The denominator was at or below [BlackWhiteNormaliser.minimumDenominator]
  /// on at least one channel. QRsens as published divides regardless; a
  /// damaged, shadowed or clipped reference then produces a very large
  /// finite number rather than an error, which is the failure mode this guard
  /// exists to prevent (directive s13).
  degenerateReference,
}

/// The outcome of a black/white normalisation.
@immutable
final class BlackWhiteResult {
  const BlackWhiteResult.ok(this.value)
    : rejection = null,
      degenerateChannels = const <String>[];

  const BlackWhiteResult.rejected(this.rejection, this.degenerateChannels)
    : value = null;

  /// Null whenever [rejection] is set. There is no field to put a fabricated
  /// value in, for the same reason [MeasurementResult] has none.
  final LinearRgb? value;
  final BlackWhiteRejection? rejection;
  final List<String> degenerateChannels;

  bool get isOk => rejection == null;
}

/// QRsens-style two-point normalisation against printed black and white
/// references. Directive s13.
///
/// This is an explicitly named **baseline**, implemented so that the stronger
/// multi-patch correction in `reference_correction.dart` has something to be
/// measured against. It cannot correct an illuminant's spectrum — it corrects
/// level and scale only — and it has no held-out patch that could tell you it
/// failed. See `research/references/qrsens-analysis.md`.
@immutable
final class BlackWhiteNormaliser {
  const BlackWhiteNormaliser({
    required this.form,
    required this.black,
    required this.white,
    this.scale = 1.0,
    this.minimumDenominator = 1e-4,
  });

  final BlackWhiteForm form;

  /// Measured reference values, in **linear** RGB.
  ///
  /// QRsens works on 8-bit gamma-encoded RGB with K = 256. We work in linear
  /// light with K = 1 by default, because a ratio of gamma-encoded values is
  /// not a reflectance ratio (directive s16). The published K = 256 scaling is
  /// available via [scale] for reproducing the paper.
  final LinearRgb black;
  final LinearRgb white;

  /// K in the published equations.
  final double scale;

  /// Channels whose denominator falls at or below this are refused rather
  /// than divided.
  final double minimumDenominator;

  BlackWhiteResult apply(LinearRgb sensor) {
    final denominators = switch (form) {
      BlackWhiteForm.qrsensEquation1 => (white.r, white.g, white.b),
      BlackWhiteForm.qrsensEquation2 => (
        white.r - black.r,
        white.g - black.g,
        white.b - black.b,
      ),
    };

    final degenerate = <String>[
      if (denominators.$1.abs() <= minimumDenominator) 'R',
      if (denominators.$2.abs() <= minimumDenominator) 'G',
      if (denominators.$3.abs() <= minimumDenominator) 'B',
    ];
    if (degenerate.isNotEmpty) {
      return BlackWhiteResult.rejected(
        BlackWhiteRejection.degenerateReference,
        degenerate,
      );
    }

    return BlackWhiteResult.ok(
      LinearRgb(
        scale * (sensor.r - black.r) / denominators.$1,
        scale * (sensor.g - black.g) / denominators.$2,
        scale * (sensor.b - black.b) / denominators.$3,
      ),
    );
  }
}
