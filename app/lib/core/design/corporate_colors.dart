import 'package:flutter/material.dart';

import 'tokens.dart';

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

  /// The pressed state of [primary]. Formerly also a gradient stop; the
  /// product has no gradients (APP-PRODUCT-01 §8).
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

  /// Light — the production theme (APP-PRODUCT-01 §50).
  ///
  /// Repointed in APP-PRODUCT-01 at the design-system-v2 primitives, so every
  /// legacy screen that reads this extension becomes white-first with the
  /// logo-derived green without being rewritten. The previous values (a
  /// `#0E4634` forest green and white-on-orange primary actions at 2.88:1)
  /// are recorded in docs/design/design-system-v2.md.
  static const MrplCorporateColors light = MrplCorporateColors(
    primary: Brand.green46,
    primaryDeep: Brand.green38,
    primaryMuted: Brand.green94,
    accent: Brand.orangeMark,
    accentMuted: Color(0xFFFDF1E4),
    surface: Neutral.l100,
    surfaceMuted: Neutral.l96,
    surfaceElevated: Neutral.l100,
    selectedFill: Brand.green94,
    selectedBorder: Brand.green46,
    emphasisBorder: Neutral.l30,
    border: Neutral.l92,
    textPrimary: Neutral.l14,
    textSecondary: Neutral.l42,
    textOnPrimary: Neutral.l100,
    textOnAccent: Neutral.l100,
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

/// Corner radii for the corporate shell — **legacy aliases**.
///
/// APP-PRODUCT-01 §14 put the whole product on one radius scale, [Radii].
/// These names are kept so existing call sites compile unchanged; new code
/// reads [Radii] directly. `xl` (22) was retired: nothing in the product is
/// rounder than a floating sheet.
abstract final class CorporateRadii {
  /// Chips, small badges, segment thumbs.
  static const double sm = Radii.sm;

  /// Buttons and fields.
  static const double md = Radii.md;

  /// Cards and the sign-in panel.
  static const double lg = Radii.lg;

  /// Formerly 22, the large brand plate. Now the floating radius.
  static const double xl = Radii.lg;
}
