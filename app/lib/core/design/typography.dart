import 'package:flutter/material.dart';

/// Typographic tokens.
///
/// One superfamily, two roles. IBM Plex Sans carries the interface; IBM Plex
/// Mono carries measurement.
///
/// **Monospace is semantic: it means "this value is measured or traceable".**
/// Doses, uncertainties, badge IDs, lot codes, model versions, timestamps. It
/// is never used for labels, headings or chrome, so a reader can tell from the
/// letterforms alone which values would appear in an audit record.
@immutable
class DoseBandTypography extends ThemeExtension<DoseBandTypography> {
  const DoseBandTypography({
    required this.readoutHero,
    required this.readoutLarge,
    required this.readoutBody,
    required this.readoutSmall,
    required this.display,
    required this.heading,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
  });

  /// The dose. One per screen.
  final TextStyle readoutHero;
  final TextStyle readoutLarge;

  /// IDs, versions, timestamps.
  final TextStyle readoutBody;
  final TextStyle readoutSmall;

  final TextStyle display;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle label;
  final TextStyle caption;

  static const String sansFamily = 'IBMPlexSans';
  static const String monoFamily = 'IBMPlexMono';

  /// IBM Plex Sans ships here as a variable font, so weight is set through the
  /// `wght` axis. `fontWeight` is set alongside it to stop the engine
  /// synthesising a fake bold when the axis already provides a real one.
  static List<FontVariation> _wght(double w) => [FontVariation('wght', w)];

  static TextStyle _sans(double size, double height, double weight) {
    return TextStyle(
      fontFamily: sansFamily,
      fontSize: size,
      height: height / size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: _wght(weight),
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  static TextStyle _mono(double size, double height, FontWeight weight) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      leadingDistribution: TextLeadingDistribution.even,
      // Measured values line up in a column; figures must not shuffle.
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static final DoseBandTypography standard = DoseBandTypography(
    readoutHero: _mono(60, 60, FontWeight.w500),
    readoutLarge: _mono(32, 36, FontWeight.w500),
    readoutBody: _mono(16, 24, FontWeight.w400),
    readoutSmall: _mono(13, 18, FontWeight.w400),
    display: _sans(28, 34, 600),
    heading: _sans(20, 28, 600),
    body: _sans(16, 24, 400),
    bodyStrong: _sans(16, 24, 500),
    label: _sans(14, 20, 500),
    caption: _sans(13, 18, 400),
  );

  @override
  DoseBandTypography copyWith({
    TextStyle? readoutHero,
    TextStyle? readoutLarge,
    TextStyle? readoutBody,
    TextStyle? readoutSmall,
    TextStyle? display,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? label,
    TextStyle? caption,
  }) {
    return DoseBandTypography(
      readoutHero: readoutHero ?? this.readoutHero,
      readoutLarge: readoutLarge ?? this.readoutLarge,
      readoutBody: readoutBody ?? this.readoutBody,
      readoutSmall: readoutSmall ?? this.readoutSmall,
      display: display ?? this.display,
      heading: heading ?? this.heading,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      label: label ?? this.label,
      caption: caption ?? this.caption,
    );
  }

  @override
  DoseBandTypography lerp(ThemeExtension<DoseBandTypography>? other, double t) {
    if (other is! DoseBandTypography) return this;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return DoseBandTypography(
      readoutHero: s(readoutHero, other.readoutHero),
      readoutLarge: s(readoutLarge, other.readoutLarge),
      readoutBody: s(readoutBody, other.readoutBody),
      readoutSmall: s(readoutSmall, other.readoutSmall),
      display: s(display, other.display),
      heading: s(heading, other.heading),
      body: s(body, other.body),
      bodyStrong: s(bodyStrong, other.bodyStrong),
      label: s(label, other.label),
      caption: s(caption, other.caption),
    );
  }
}
