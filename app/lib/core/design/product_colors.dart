import 'package:flutter/material.dart';

import 'tokens.dart';

/// The product register's semantic colours (design system v2).
///
/// **New components read these and nothing else.** Reach them with
/// `context.product`. They are built from the primitives in `tokens.dart`, so a
/// hex value exists in exactly one place.
///
/// The measurement surfaces keep `DoseBandColors`, which is chromatically
/// neutral on purpose; the instrument accent is repeated here only so product
/// chrome can *refer* to the instrument (a "measured" chip, a link into a
/// reading) without reaching into the other register.
///
/// ## Brand is not status
///
/// There is no `success`, `safe` or `ok` token, and there must never be one.
/// The brand green marks *what you can do* — the primary action, the selected
/// destination — and says nothing about the atmosphere, the exposure or the
/// measurement. See docs/design/design-system-v2.md §"Green is not safe".
@immutable
final class ProductColors extends ThemeExtension<ProductColors> {
  const ProductColors({
    required this.brandPrimary,
    required this.brandPrimaryPressed,
    required this.brandPrimaryContainer,
    required this.brandSubtle,
    required this.onBrandPrimary,
    required this.onBrandContainer,
    required this.brandMark,
    required this.brandSecondary,
    required this.surfacePage,
    required this.surfaceCard,
    required this.surfaceSecondary,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderInput,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.focusRing,
    required this.instrumentAccent,
    required this.instrumentContainer,
    required this.simulationAccent,
    required this.simulationContainer,
    required this.warning,
    required this.warningContainer,
    required this.critical,
    required this.criticalContainer,
    required this.info,
    required this.infoContainer,
    required this.scrim,
  });

  /// Primary actions, selected navigation, focused inputs. Never status.
  final Color brandPrimary;
  final Color brandPrimaryPressed;

  /// The pale selected fill: navigation indicator, selected chip, selected
  /// card ground.
  final Color brandPrimaryContainer;

  /// An even paler tint for a whole selected row.
  final Color brandSubtle;

  final Color onBrandPrimary;

  /// Text and icons placed on [brandPrimaryContainer].
  final Color onBrandContainer;

  /// The exact logo green. Identity marks only; not text.
  final Color brandMark;

  /// The MRPL-inspired orange, at the step that holds 3:1 for a meaningful
  /// mark. Never text, never a filled control with a label on it.
  final Color brandSecondary;

  /// The screen ground. White: the product is white-first.
  final Color surfacePage;

  /// Cards. Also white; separated from the page by a hairline, not a shadow.
  final Color surfaceCard;

  /// Recessed areas: a search field's fill, a section of secondary detail.
  final Color surfaceSecondary;

  /// Card edges and dividers.
  final Color borderSubtle;

  /// Outlined buttons and chips.
  final Color borderDefault;

  /// Input outlines. ≥3:1 against the page, as a control boundary must be.
  final Color borderInput;

  final Color textPrimary;
  final Color textSecondary;

  /// Disabled labels. Readable (4.54:1), just quieter.
  final Color textDisabled;

  /// Keyboard focus outline.
  final Color focusRing;

  /// The measurement register's accent, for product chrome that points at a
  /// reading. Not a brand colour and not a success colour.
  final Color instrumentAccent;
  final Color instrumentContainer;

  /// SIMULATED, and nothing else. It is meant to look wrong.
  final Color simulationAccent;
  final Color simulationContainer;

  /// Needs attention: review required, retake, sync pending too long.
  final Color warning;
  final Color warningContainer;

  /// Genuine failure or destructive action. Not a refusal, not a high reading.
  final Color critical;
  final Color criticalContainer;

  /// Neutral information: offline, not connected, unavailable.
  final Color info;
  final Color infoContainer;

  /// A solid translucent scrim for text over a photograph. Solid, never a
  /// gradient (§8, §29).
  final Color scrim;

  static const ProductColors light = ProductColors(
    brandPrimary: Brand.green46,
    brandPrimaryPressed: Brand.green38,
    brandPrimaryContainer: Brand.green94,
    brandSubtle: Brand.green97,
    onBrandPrimary: Neutral.l100,
    onBrandContainer: Brand.green38,
    brandMark: Brand.green50,
    brandSecondary: Brand.orangeMark,
    surfacePage: Neutral.l100,
    surfaceCard: Neutral.l100,
    surfaceSecondary: Neutral.l96,
    borderSubtle: Neutral.l92,
    borderDefault: Neutral.l86,
    borderInput: Neutral.l58,
    textPrimary: Neutral.l14,
    textSecondary: Neutral.l42,
    textDisabled: ProductNeutral.disabledText,
    focusRing: Brand.green38,
    instrumentAccent: Accent.cyanLight,
    instrumentContainer: Accent.cyanContainer,
    simulationAccent: Accent.magentaLight,
    simulationContainer: Accent.magentaContainer,
    warning: Accent.amberLight,
    warningContainer: Accent.amberContainer,
    critical: Accent.redLight,
    criticalContainer: Accent.redContainer,
    info: Accent.slateLight,
    infoContainer: Accent.slateContainer,
    scrim: Color(0xB3000000),
  );

  /// The product is white-first and ships the light theme (§50). This exists
  /// only so a legacy dark-theme golden still resolves the extension; it is
  /// not a supported product mode.
  static const ProductColors dark = ProductColors(
    brandPrimary: Color(0xFF8DB35C),
    brandPrimaryPressed: Color(0xFFA6C77C),
    brandPrimaryContainer: Color(0xFF26331A),
    brandSubtle: Color(0xFF1C2416),
    onBrandPrimary: Neutral.l9,
    onBrandContainer: Color(0xFFC9DDB0),
    brandMark: Brand.green50,
    brandSecondary: Color(0xFFF0913D),
    surfacePage: Neutral.l9,
    surfaceCard: Neutral.l14,
    surfaceSecondary: Neutral.l5,
    borderSubtle: Neutral.l20,
    borderDefault: Neutral.l30,
    borderInput: Neutral.l58,
    textPrimary: Neutral.l96,
    textSecondary: Neutral.l74,
    textDisabled: Neutral.l58,
    focusRing: Color(0xFFA6C77C),
    instrumentAccent: Accent.cyanDark,
    instrumentContainer: Accent.cyanMutedDark,
    simulationAccent: Accent.magentaDark,
    simulationContainer: Color(0xFF3A1535),
    warning: Accent.amberDark,
    warningContainer: Color(0xFF33260D),
    critical: Accent.redDark,
    criticalContainer: Color(0xFF3A1714),
    info: Accent.slateDark,
    infoContainer: Color(0xFF1E262C),
    scrim: Color(0xB3000000),
  );

  @override
  ProductColors copyWith({
    Color? brandPrimary,
    Color? brandPrimaryPressed,
    Color? brandPrimaryContainer,
    Color? brandSubtle,
    Color? onBrandPrimary,
    Color? onBrandContainer,
    Color? brandMark,
    Color? brandSecondary,
    Color? surfacePage,
    Color? surfaceCard,
    Color? surfaceSecondary,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderInput,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? focusRing,
    Color? instrumentAccent,
    Color? instrumentContainer,
    Color? simulationAccent,
    Color? simulationContainer,
    Color? warning,
    Color? warningContainer,
    Color? critical,
    Color? criticalContainer,
    Color? info,
    Color? infoContainer,
    Color? scrim,
  }) {
    return ProductColors(
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandPrimaryPressed: brandPrimaryPressed ?? this.brandPrimaryPressed,
      brandPrimaryContainer:
          brandPrimaryContainer ?? this.brandPrimaryContainer,
      brandSubtle: brandSubtle ?? this.brandSubtle,
      onBrandPrimary: onBrandPrimary ?? this.onBrandPrimary,
      onBrandContainer: onBrandContainer ?? this.onBrandContainer,
      brandMark: brandMark ?? this.brandMark,
      brandSecondary: brandSecondary ?? this.brandSecondary,
      surfacePage: surfacePage ?? this.surfacePage,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderInput: borderInput ?? this.borderInput,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      focusRing: focusRing ?? this.focusRing,
      instrumentAccent: instrumentAccent ?? this.instrumentAccent,
      instrumentContainer: instrumentContainer ?? this.instrumentContainer,
      simulationAccent: simulationAccent ?? this.simulationAccent,
      simulationContainer: simulationContainer ?? this.simulationContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      critical: critical ?? this.critical,
      criticalContainer: criticalContainer ?? this.criticalContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  ProductColors lerp(ThemeExtension<ProductColors>? other, double t) {
    if (other is! ProductColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return ProductColors(
      brandPrimary: c(brandPrimary, other.brandPrimary),
      brandPrimaryPressed: c(brandPrimaryPressed, other.brandPrimaryPressed),
      brandPrimaryContainer: c(
        brandPrimaryContainer,
        other.brandPrimaryContainer,
      ),
      brandSubtle: c(brandSubtle, other.brandSubtle),
      onBrandPrimary: c(onBrandPrimary, other.onBrandPrimary),
      onBrandContainer: c(onBrandContainer, other.onBrandContainer),
      brandMark: c(brandMark, other.brandMark),
      brandSecondary: c(brandSecondary, other.brandSecondary),
      surfacePage: c(surfacePage, other.surfacePage),
      surfaceCard: c(surfaceCard, other.surfaceCard),
      surfaceSecondary: c(surfaceSecondary, other.surfaceSecondary),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      borderDefault: c(borderDefault, other.borderDefault),
      borderInput: c(borderInput, other.borderInput),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textDisabled: c(textDisabled, other.textDisabled),
      focusRing: c(focusRing, other.focusRing),
      instrumentAccent: c(instrumentAccent, other.instrumentAccent),
      instrumentContainer: c(instrumentContainer, other.instrumentContainer),
      simulationAccent: c(simulationAccent, other.simulationAccent),
      simulationContainer: c(simulationContainer, other.simulationContainer),
      warning: c(warning, other.warning),
      warningContainer: c(warningContainer, other.warningContainer),
      critical: c(critical, other.critical),
      criticalContainer: c(criticalContainer, other.criticalContainer),
      info: c(info, other.info),
      infoContainer: c(infoContainer, other.infoContainer),
      scrim: c(scrim, other.scrim),
    );
  }
}
