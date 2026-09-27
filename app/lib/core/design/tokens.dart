/// Raw design primitives. Nothing in the app reads these directly — they are
/// referenced only by the semantic token layer in `semantic_colors.dart` and
/// `typography.dart`. See docs/design/design-system.md.
library;

import 'package:flutter/painting.dart';

/// Neutral surfaces, defined by equal steps of CIELAB L* converted to sRGB
/// with a*=b*=0.
///
/// Equal L* steps are equal *perceptual* steps, so the surface hierarchy reads
/// evenly in bright sun and in a dark tank area alike. Every value here is
/// exactly neutral (R=G=B): the user's task is judging a colour, and a tinted
/// "near-black" would shift the apparent hue of the badge beside it.
abstract final class Neutral {
  /// L*100
  static const Color l100 = Color(0xFFFFFFFF);

  /// L*98
  static const Color l98 = Color(0xFFF9F9F9);

  /// L*96
  static const Color l96 = Color(0xFFF3F3F3);

  /// L*92
  static const Color l92 = Color(0xFFE8E8E8);

  /// L*86
  static const Color l86 = Color(0xFFD7D7D7);

  /// L*74
  static const Color l74 = Color(0xFFB6B6B6);

  /// L*58
  static const Color l58 = Color(0xFF8B8B8B);

  /// L*42
  static const Color l42 = Color(0xFF636363);

  /// L*30
  static const Color l30 = Color(0xFF474747);

  /// L*20
  static const Color l20 = Color(0xFF303030);

  /// L*14
  static const Color l14 = Color(0xFF242424);

  /// L*9 — the darkest full-screen surface.
  static const Color l9 = Color(0xFF191919);

  /// L*5 — recessed panels in dark mode. Not the scaffold: pure black is
  /// reserved for the camera viewfinder, and a near-black scaffold smears on
  /// OLED during scroll.
  static const Color l5 = Color(0xFF111111);

  /// L*0 — viewfinder only.
  static const Color l0 = Color(0xFF000000);
}

/// Saturated primitives. Each is placed deliberately; see the design system
/// document for why each hue was chosen and what it may not be used for.
abstract final class Accent {
  /// Instrument cyan. Placed away from the chemistry's white -> yellow ->
  /// brown -> black trajectory so the interface can never be mistaken for, or
  /// bias, a reading.
  static const Color cyanLight = Color(0xFF0E6E7D);
  static const Color cyanDark = Color(0xFF4FC3D4);
  static const Color cyanMutedLight = Color(0xFFD6EEF1);
  static const Color cyanMutedDark = Color(0xFF123C44);

  /// Warning amber, dark enough to hold 4.5:1 on light surfaces.
  static const Color amberLight = Color(0xFF8A5A00);
  static const Color amberDark = Color(0xFFE0A73A);

  /// Cool slate for censored results — neither a failure nor a value.
  static const Color slateLight = Color(0xFF4A5C6A);
  static const Color slateDark = Color(0xFF9BB0C0);

  /// Simulation magenta, from the missing-texture convention in graphics.
  /// It should look wrong, because simulated data is not real data.
  static const Color magentaLight = Color(0xFFB5179E);
  static const Color magentaDark = Color(0xFFF06FDD);

  /// Destructive red. Used for irreversible actions and nothing else — not for
  /// refusals, not for high exposure readings. Reserving it keeps it meaningful.
  static const Color redLight = Color(0xFFA02114);
  static const Color redDark = Color(0xFFF0806F);

  /// Pale containers for the status hues above, each holding ≥5:1 against its
  /// own hue so a label on a tinted pill stays readable.
  static const Color amberContainer = Color(0xFFFDF3E1);
  static const Color magentaContainer = Color(0xFFFBEAF8);
  static const Color cyanContainer = Color(0xFFE3F2F4);
  static const Color redContainer = Color(0xFFFBEAE8);
  static const Color slateContainer = Color(0xFFEEF1F3);
}

/// Brand primitives (APP-PRODUCT-01 §9).
///
/// **Derived, not invented.** The anchor is the field green of the approved
/// logo asset `assets/images/MRPL Logo.png` — `#5C822D`, the most frequent
/// pixel value in that file, CIELAB L*50 a*−28 b*+41. The ramp holds that hue
/// and chroma direction and moves only in L*, so every step is recognisably the
/// same green.
///
/// These are MRPL-*inspired* values sampled from a supplied asset. No official
/// MRPL brand standard has been seen, and nothing here claims to be one.
///
/// The logo green itself is 4.48:1 on white — just under the 4.5:1 floor for
/// body text — so text and filled controls use the L*46 step, and the exact
/// logo value is kept for identity marks only.
abstract final class Brand {
  /// L*97. Barely-there tint for a selected row's ground.
  static const Color green97 = Color(0xFFF4F8EE);

  /// L*94. Selected fills, the navigation indicator.
  static const Color green94 = Color(0xFFEAF0E0);

  /// L*50. The logo's own field colour. Identity marks only.
  static const Color green50 = Color(0xFF5C822D);

  /// L*46. Primary actions and selected navigation. 5.16:1 against white.
  static const Color green46 = Color(0xFF527823);

  /// L*38. Pressed primary, and text on a green94 container (5.97:1).
  static const Color green38 = Color(0xFF416318);

  /// The approved MRPL-inspired orange. **2.88:1 on white — never text, never a
  /// filled control with a label on it.** Thin rules and small marks only.
  static const Color orange = Color(0xFFE87B1E);

  /// The same orange at L*58: 3.39:1 on white, which clears the 3:1 floor for
  /// a meaningful icon or rule. Still never text on its own.
  static const Color orangeMark = Color(0xFFD96E0C);

  /// The deep refinery green under the splash photograph's dark foreground,
  /// used as a solid scrim there. Never a large card or page colour.
  static const Color refineryNight = Color(0xFF082B20);

  /// Organisation-name ink on light photography (splash identity block).
  static const Color identityInk = Color(0xFF14532D);
}

/// Neutral values used only by the product (corporate) register. Taken from
/// the [Neutral] step wedge where one fits, so the two registers share greys.
abstract final class ProductNeutral {
  /// Disabled text. 4.54:1 on white: visibly quieter, still readable.
  static const Color disabledText = Color(0xFF767676);
}

/// 4pt base grid.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

/// Semantic spacing. Built from [Space] so the grid stays one grid; these name
/// the *role* a gap plays, so a screen does not choose its own gutter.
abstract final class Gaps {
  /// Left and right padding of a phone screen.
  static const double screenGutter = Space.base;

  /// Between two sections of a screen.
  static const double section = Space.lg;

  /// Inside a card.
  static const double cardPadding = Space.base;

  /// Between two controls, or two cards in a list.
  static const double control = Space.md;

  /// Between a label and the value or control it names.
  static const double labelToValue = Space.xs;
}

/// Radii are meaningful rather than uniform: the radius tells you whether a
/// thing is a reading, a control, a card or something that floats.
///
/// One scale for the whole product (APP-PRODUCT-01 §14). `CorporateRadii` is
/// kept as a set of aliases into it so legacy call sites migrate without a
/// visual jump; new code reads this class.
abstract final class Radii {
  /// Measurement surfaces and the scale. An instrument face has square corners.
  static const double measurement = 0;

  /// Instrument-register controls (the measurement surfaces' buttons). Kept
  /// tighter than product controls on purpose: the instrument reads squarer.
  static const double control = 4;

  /// Product controls: buttons, fields, chips, small tiles.
  static const double sm = 8;

  /// Standard cards.
  static const double md = 12;

  /// Things that genuinely float: sheets, dialogs, the worker navigation bar,
  /// and the occasional large feature card.
  static const double lg = 16;

  /// Status pills only. A card is never a pill.
  static const double pill = 999;

  /// Sheets and dialogs that genuinely float.
  static const double floating = md;
}

/// Elevation is carried by surface contrast and a hairline first. A shadow is
/// reserved for the few things that float over content, and it is neutral —
/// never tinted with the brand colour, never a glow.
abstract final class Elevation {
  /// Cards, lists, sections: no shadow at all.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// The floating worker navigation bar.
  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
  ];

  /// Sheets and dialogs.
  static const List<BoxShadow> overlay = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

/// Layout breakpoints, in logical pixels of available width.
///
/// Defined once. A screen asks [WindowClass.of] which class it is in; it never
/// compares against its own number.
abstract final class Breakpoints {
  /// Below this: a phone in portrait. Single column, bottom navigation.
  static const double medium = 600;

  /// At or above this: navigation becomes a rail and dense data may become a
  /// table. Matches the HSE shell's rail, which predates this class.
  static const double expanded = 720;

  /// The widest a column of reading text or a phone-first form grows to on a
  /// tablet. Wider than this, lines get too long to scan.
  static const double maxContentWidth = 720;
}

/// Minimum interactive size for ordinary controls (Material's floor).
const double kMinInteractive = 48;

abstract final class Borders {
  static const double hairline = 1;
  static const double emphasis = 2;

  /// The status rule down the left edge of a result.
  static const double statusRule = 4;
}

/// Minimum touch target in the worker flow. Larger than Material's 48 because
/// the user may be gloved, and a mis-tap during badge closure corrupts a
/// coverage record.
const double kMinTouchTarget = 56;

abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration control = Duration(milliseconds: 160);
  static const Duration surface = Duration(milliseconds: 240);

  /// The one orchestrated moment: the measurement scale drawing in.
  static const Duration reveal = Duration(milliseconds: 420);
}
