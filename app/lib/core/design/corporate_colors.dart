import 'package:flutter/material.dart';

/// MRPL-inspired corporate palette for the authentication and identity shell.
///
/// **This is a second, deliberately separate theme extension.** The measurement
/// surfaces keep [DoseBandColors], which is chromatically neutral by design: a
/// colorimetric reading must not sit next to saturated brand colour, because
/// the eye judges colour relative to its surroundings and a green frame around
/// a green-shifting badge is an invitation to misread it.
///
/// So the application has two visual registers, and the boundary is a rule:
///
/// | Register | Where | Colour |
/// |---|---|---|
/// | Corporate shell | splash, sign-in, site/role selection, identity | this |
/// | Instrument | capture, result, measurement readouts | `DoseBandColors` |
///
/// Widgets under `features/auth/` read this. Nothing under `features/capture/`
/// or `features/result/` may.
///
/// **Provenance: these are MRPL-*inspired* prototype tokens.** They were
/// sampled from the approved design mockup, not from a published MRPL brand
/// standard, and no official brand guide has been verified. They must be
/// replaced if and when real brand values are supplied. See
/// `docs/design/auth-flow.md`.
@immutable
final class MrplCorporateColors extends ThemeExtension<MrplCorporateColors> {
  const MrplCorporateColors({
    required this.primary,
    required this.primaryDeep,
    required this.primaryMuted,
    required this.accent,
    required this.accentMuted,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.selectedFill,
    required this.selectedBorder,
    required this.emphasisBorder,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
    required this.textOnAccent,
  });

  /// Deep refinery green. Primary actions, headers, the corporate footer.
  final Color primary;

  /// A darker green for gradients and pressed states.
  final Color primaryDeep;

  /// Very pale green, for tinted backgrounds that must not compete.
  final Color primaryMuted;

  /// Warm industrial orange. Used sparingly: the active segment, a rule under
  /// the safety message, the footer flash. Never for a whole surface.
  final Color accent;
  final Color accentMuted;

  final Color surface;
  final Color surfaceMuted;
  final Color surfaceElevated;

  /// Selection states on site and role cards.
  final Color selectedFill;
  final Color selectedBorder;

  /// The edge on the one card per screen that matters most.
  ///
  /// Deliberately neutral ink rather than the corporate green, and a separate
  /// token from [selectedBorder] even though both draw an edge. "Selected" is
  /// a state the user put a card into; "emphasised" is the author saying read
  /// this first — and in this product the card that matters most is usually
  /// stating an *absence*: no calibration, no validated device, no reading.
  /// A green edge on "No production H₂S calibration available" reads as
  /// approval of the sentence it surrounds. Emphasis is carried by weight and
  /// contrast instead, which says nothing about whether the news is good.
  final Color emphasisBorder;

  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;
  final Color textOnAccent;

  static const MrplCorporateColors light = MrplCorporateColors(
    primary: Color(0xFF0E4634),
    primaryDeep: Color(0xFF082B20),
    primaryMuted: Color(0xFFEAF3EE),
    accent: Color(0xFFE87B1E),
    accentMuted: Color(0xFFFDF1E4),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F6F5),
    surfaceElevated: Color(0xFFFFFFFF),
    selectedFill: Color(0xFFE3F4EA),
    selectedBorder: Color(0xFF177A4F),
    emphasisBorder: Color(0xFF3E4A45),
    border: Color(0xFFE3E7E5),
    textPrimary: Color(0xFF16201C),
    textSecondary: Color(0xFF63706B),
    textOnPrimary: Color(0xFFFFFFFF),
    textOnAccent: Color(0xFFFFFFFF),
  );

  /// Dark mode keeps the same identity but lowers surface luminance, so the
  /// corporate shell does not flash white at a worker in a dim plant at the
  /// end of a night shift.
  static const MrplCorporateColors dark = MrplCorporateColors(
    primary: Color(0xFF1E7A57),
    primaryDeep: Color(0xFF0B2C21),
    primaryMuted: Color(0xFF13241D),
    accent: Color(0xFFF0913D),
    accentMuted: Color(0xFF2E2013),
    surface: Color(0xFF141917),
    surfaceMuted: Color(0xFF1B211E),
    surfaceElevated: Color(0xFF1F2623),
    selectedFill: Color(0xFF14342A),
    selectedBorder: Color(0xFF2E9C6D),
    emphasisBorder: Color(0xFFA3AFAA),
    border: Color(0xFF2B332F),
    textPrimary: Color(0xFFF2F5F3),
    textSecondary: Color(0xFFA3AFAA),
    textOnPrimary: Color(0xFFFFFFFF),
    textOnAccent: Color(0xFF1A1206),
  );

  @override
  MrplCorporateColors copyWith({
    Color? primary,
    Color? primaryDeep,
    Color? primaryMuted,
    Color? accent,
    Color? accentMuted,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? selectedFill,
    Color? selectedBorder,
    Color? emphasisBorder,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnPrimary,
    Color? textOnAccent,
  }) {
    return MrplCorporateColors(
      primary: primary ?? this.primary,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      selectedFill: selectedFill ?? this.selectedFill,
      selectedBorder: selectedBorder ?? this.selectedBorder,
      emphasisBorder: emphasisBorder ?? this.emphasisBorder,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      textOnAccent: textOnAccent ?? this.textOnAccent,
    );
  }

  @override
  MrplCorporateColors lerp(
    ThemeExtension<MrplCorporateColors>? other,
    double t,
  ) {
    if (other is! MrplCorporateColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return MrplCorporateColors(
      primary: mix(primary, other.primary),
      primaryDeep: mix(primaryDeep, other.primaryDeep),
      primaryMuted: mix(primaryMuted, other.primaryMuted),
      accent: mix(accent, other.accent),
      accentMuted: mix(accentMuted, other.accentMuted),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      selectedFill: mix(selectedFill, other.selectedFill),
      selectedBorder: mix(selectedBorder, other.selectedBorder),
      emphasisBorder: mix(emphasisBorder, other.emphasisBorder),
      border: mix(border, other.border),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textOnPrimary: mix(textOnPrimary, other.textOnPrimary),
      textOnAccent: mix(textOnAccent, other.textOnAccent),
    );
  }
}

/// Corner radii for the corporate shell.
///
/// Separate from [Radii] on purpose. The instrument uses square corners
/// because an instrument face has square corners; the corporate shell is
/// ordinary application chrome and reads as stiff and dated without a moderate
/// radius. Two registers, two scales.
abstract final class CorporateRadii {
  /// Chips, small badges, segment thumbs.
  static const double sm = 8;

  /// Buttons and fields.
  static const double md = 12;

  /// Cards and the sign-in panel.
  static const double lg = 16;

  /// The large brand plate.
  static const double xl = 22;
}
