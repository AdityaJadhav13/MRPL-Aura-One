import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic colour tokens. **Widgets read these; they never read [Neutral] or
/// [Accent] directly, and they never write a literal colour.**
///
/// Reach them with `context.colours`.
@immutable
class DoseBandColors extends ThemeExtension<DoseBandColors> {
  const DoseBandColors({
    required this.surfacePrimary,
    required this.surfaceElevated,
    required this.surfaceSunken,
    required this.surfaceViewfinder,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textOnAccent,
    required this.measurementAccent,
    required this.measurementAccentMuted,
    required this.statusValid,
    required this.statusWarning,
    required this.statusCensored,
    required this.statusRefused,
    required this.statusSimulated,
    required this.statusDestructive,
  });

  final Color surfacePrimary;
  final Color surfaceElevated;
  final Color surfaceSunken;

  /// True black. The correct surround for judging a captured image.
  final Color surfaceViewfinder;

  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textOnAccent;

  /// The instrument's own voice: measured values, primary actions, and the
  /// valid status all speak in this colour.
  final Color measurementAccent;
  final Color measurementAccentMuted;

  /// The measurement can be trusted. Deliberately **not green** — green means
  /// "safe", and this badge cannot tell anyone they are safe.
  final Color statusValid;

  /// Usable, with a caveat.
  final Color statusWarning;

  /// Outside the quantifiable range. Neither a failure nor a value.
  final Color statusCensored;

  /// No number may be reported. Neutral ink: a refusal is the instrument
  /// working correctly, so it gets no alarm colouring.
  final Color statusRefused;

  /// Not a real measurement.
  final Color statusSimulated;

  /// Irreversible actions only.
  final Color statusDestructive;

  static const DoseBandColors light = DoseBandColors(
    surfacePrimary: Neutral.l100,
    surfaceElevated: Neutral.l98,
    surfaceSunken: Neutral.l96,
    surfaceViewfinder: Neutral.l0,
    border: Neutral.l86,
    borderStrong: Neutral.l58,
    textPrimary: Neutral.l20,
    textSecondary: Neutral.l42,
    textDisabled: Neutral.l58,
    textOnAccent: Neutral.l100,
    measurementAccent: Accent.cyanLight,
    measurementAccentMuted: Accent.cyanMutedLight,
    statusValid: Accent.cyanLight,
    statusWarning: Accent.amberLight,
    statusCensored: Accent.slateLight,
    statusRefused: Neutral.l30,
    statusSimulated: Accent.magentaLight,
    statusDestructive: Accent.redLight,
  );

  static const DoseBandColors dark = DoseBandColors(
    surfacePrimary: Neutral.l9,
    surfaceElevated: Neutral.l14,
    surfaceSunken: Neutral.l5,
    surfaceViewfinder: Neutral.l0,
    border: Neutral.l30,
    borderStrong: Neutral.l58,
    textPrimary: Neutral.l96,
    textSecondary: Neutral.l74,
    textDisabled: Neutral.l58,
    textOnAccent: Neutral.l9,
    measurementAccent: Accent.cyanDark,
    measurementAccentMuted: Accent.cyanMutedDark,
    statusValid: Accent.cyanDark,
    statusWarning: Accent.amberDark,
    statusCensored: Accent.slateDark,
    statusRefused: Neutral.l74,
    statusSimulated: Accent.magentaDark,
    statusDestructive: Accent.redDark,
  );

  @override
  DoseBandColors copyWith({
    Color? surfacePrimary,
    Color? surfaceElevated,
    Color? surfaceSunken,
    Color? surfaceViewfinder,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? textOnAccent,
    Color? measurementAccent,
    Color? measurementAccentMuted,
    Color? statusValid,
    Color? statusWarning,
    Color? statusCensored,
    Color? statusRefused,
    Color? statusSimulated,
    Color? statusDestructive,
  }) {
    return DoseBandColors(
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceViewfinder: surfaceViewfinder ?? this.surfaceViewfinder,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      measurementAccent: measurementAccent ?? this.measurementAccent,
      measurementAccentMuted:
          measurementAccentMuted ?? this.measurementAccentMuted,
      statusValid: statusValid ?? this.statusValid,
      statusWarning: statusWarning ?? this.statusWarning,
      statusCensored: statusCensored ?? this.statusCensored,
      statusRefused: statusRefused ?? this.statusRefused,
      statusSimulated: statusSimulated ?? this.statusSimulated,
      statusDestructive: statusDestructive ?? this.statusDestructive,
    );
  }

  @override
  DoseBandColors lerp(ThemeExtension<DoseBandColors>? other, double t) {
    if (other is! DoseBandColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return DoseBandColors(
      surfacePrimary: c(surfacePrimary, other.surfacePrimary),
      surfaceElevated: c(surfaceElevated, other.surfaceElevated),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      surfaceViewfinder: c(surfaceViewfinder, other.surfaceViewfinder),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textDisabled: c(textDisabled, other.textDisabled),
      textOnAccent: c(textOnAccent, other.textOnAccent),
      measurementAccent: c(measurementAccent, other.measurementAccent),
      measurementAccentMuted: c(
        measurementAccentMuted,
        other.measurementAccentMuted,
      ),
      statusValid: c(statusValid, other.statusValid),
      statusWarning: c(statusWarning, other.statusWarning),
      statusCensored: c(statusCensored, other.statusCensored),
      statusRefused: c(statusRefused, other.statusRefused),
      statusSimulated: c(statusSimulated, other.statusSimulated),
      statusDestructive: c(statusDestructive, other.statusDestructive),
    );
  }
}
