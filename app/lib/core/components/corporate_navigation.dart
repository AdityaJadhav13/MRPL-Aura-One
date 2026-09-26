import 'package:flutter/material.dart';

import '../design/theme.dart';

/// Recolours navigation chrome for the corporate surfaces.
///
/// The application theme paints navigation in the instrument accent, because
/// the theme was built when the only shell was the worker's and the accent was
/// the product's single highlight colour.
///
/// That accent belongs to the **measurement** register. Leaving it on the HSE,
/// Reporting and Admin shells puts a cyan indicator under an MRPL-green header
/// — two different products in one frame, and a reviewer notices the seam even
/// when they cannot name it.
///
/// This wrapper keeps the split honest in the other direction too: it only
/// touches navigation chrome. Nothing here recolours a measurement readout, a
/// status pill or a badge image, so the rule that instrument surfaces stay
/// chromatically neutral is untouched.
class CorporateNavigationTheme extends StatelessWidget {
  const CorporateNavigationTheme({
    required this.child,
    this.onDark = false,
    super.key,
  });

  final Widget child;

  /// Paints the bar on deep refinery green with an orange selection, as the
  /// worker shell does. The HSE, Reporting and Admin shells stay on a light
  /// surface: they are desk-and-plant tools used for longer stretches, and a
  /// dark bar under a long scrolling table reads as a floor rather than a
  /// control.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final base = Theme.of(context);

    return Theme(
      data: base.copyWith(
        navigationBarTheme: base.navigationBarTheme.copyWith(
          backgroundColor: onDark ? corporate.primaryDeep : corporate.surface,
          indicatorColor: onDark
              // Barely-there on dark: the orange icon and label already carry
              // the selection, and a solid pill behind them would fight the
              // one accent the screen is allowed.
              ? corporate.accent.withValues(alpha: 0.18)
              : corporate.selectedFill,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            final selectedColour = onDark
                ? corporate.accent
                : corporate.primary;
            final restColour = onDark
                ? Colors.white.withValues(alpha: 0.72)
                : corporate.textSecondary;
            return t.caption.copyWith(
              color: selected ? selectedColour : restColour,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            final selectedColour = onDark
                ? corporate.accent
                : corporate.primary;
            final restColour = onDark
                ? Colors.white.withValues(alpha: 0.78)
                : corporate.textSecondary;
            return IconThemeData(
              size: 24,
              color: selected ? selectedColour : restColour,
            );
          }),
        ),
        // Chips are selection controls on corporate surfaces — filters,
        // categories, pickers — so they follow the corporate palette for the
        // same reason navigation does. Left alone they render in the
        // measurement accent, which puts a cyan chip under an MRPL-green
        // header.
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: corporate.surface,
          selectedColor: corporate.selectedFill,
          checkmarkColor: corporate.selectedBorder,
          side: BorderSide(color: corporate.border),
          labelStyle: t.caption.copyWith(color: corporate.textPrimary),
          secondaryLabelStyle: t.caption.copyWith(color: corporate.textPrimary),
        ),
        navigationRailTheme: base.navigationRailTheme.copyWith(
          backgroundColor: corporate.surface,
          indicatorColor: corporate.selectedFill,
          selectedIconTheme: IconThemeData(color: corporate.primary),
          unselectedIconTheme: IconThemeData(color: corporate.textSecondary),
          selectedLabelTextStyle: t.caption.copyWith(
            color: corporate.primary,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: t.caption.copyWith(
            color: corporate.textSecondary,
          ),
        ),
      ),
      child: child,
    );
  }
}
