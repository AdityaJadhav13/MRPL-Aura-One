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

/// Radii are meaningful rather than uniform: the radius tells you whether a
/// thing is a reading or a control.
abstract final class Radii {
  /// Measurement surfaces and the scale. An instrument face has square corners.
  static const double measurement = 0;

  /// Controls.
  static const double control = 4;

  /// Sheets and dialogs that genuinely float.
  static const double floating = 12;
}

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
