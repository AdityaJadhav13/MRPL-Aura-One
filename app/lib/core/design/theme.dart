import 'package:flutter/material.dart';

import 'semantic_colors.dart';
import 'tokens.dart';
import 'typography.dart';

/// Reaching the semantic tokens. Widgets use `context.colours` and
/// `context.type` and nothing else.
extension DoseBandTheme on BuildContext {
  DoseBandColors get colours => Theme.of(this).extension<DoseBandColors>()!;
  DoseBandTypography get type =>
      Theme.of(this).extension<DoseBandTypography>()!;
}

ThemeData buildDoseBandTheme({required Brightness brightness}) {
  final isLight = brightness == Brightness.light;
  final c = isLight ? DoseBandColors.light : DoseBandColors.dark;
  final t = DoseBandTypography.standard;

  // Material's ColorScheme still drives built-in widgets, so it is mapped onto
  // the semantic tokens rather than left at its defaults.
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.measurementAccent,
    onPrimary: c.textOnAccent,
    secondary: c.measurementAccent,
    onSecondary: c.textOnAccent,
    error: c.statusDestructive,
    onError: c.textOnAccent,
    surface: c.surfacePrimary,
    onSurface: c.textPrimary,
    outline: c.border,
    outlineVariant: c.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.surfacePrimary,
    splashFactory: InkSparkle.splashFactory,
    extensions: [c, t],
    textTheme: TextTheme(
      displaySmall: t.display.copyWith(color: c.textPrimary),
      headlineSmall: t.heading.copyWith(color: c.textPrimary),
      bodyLarge: t.body.copyWith(color: c.textPrimary),
      bodyMedium: t.body.copyWith(color: c.textPrimary),
      labelLarge: t.label.copyWith(color: c.textPrimary),
      bodySmall: t.caption.copyWith(color: c.textSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surfacePrimary,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: t.display.copyWith(color: c.textPrimary),
      shape: Border(
        bottom: BorderSide(color: c.border, width: Borders.hairline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: c.border,
      thickness: Borders.hairline,
      space: Borders.hairline,
    ),
    // Elevation is carried by the neutral ramp plus a hairline, never by a
    // soft grey drop shadow.
    cardTheme: CardThemeData(
      color: c.surfaceElevated,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: c.border, width: Borders.hairline),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Radii.floating),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surfacePrimary,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.measurementAccentMuted,
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return t.caption.copyWith(
          color: selected ? c.measurementAccent : c.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? c.measurementAccent : c.textSecondary,
        );
      }),
    ),
  );
}
