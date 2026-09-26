import 'package:flutter/material.dart';

import 'corporate_colors.dart';
import 'product_colors.dart';
import 'semantic_colors.dart';
import 'tokens.dart';
import 'typography.dart';

/// Reaching the semantic tokens. Widgets use `context.product` (design system
/// v2), `context.colours` (the measurement instrument) and `context.type`, and
/// nothing else.
extension DoseBandTheme on BuildContext {
  DoseBandColors get colours => Theme.of(this).extension<DoseBandColors>()!;
  DoseBandTypography get type =>
      Theme.of(this).extension<DoseBandTypography>()!;

  /// The product register — design system v2. New components read this.
  ProductColors get product => Theme.of(this).extension<ProductColors>()!;

  /// The MRPL-inspired corporate palette, as the legacy screens name it.
  ///
  /// Since APP-PRODUCT-01 its values are the same primitives [product] uses,
  /// so legacy and v2 screens agree. The instrument surfaces stay on
  /// [colours], which is neutral by design — see [MrplCorporateColors].
  MrplCorporateColors get corporate =>
      Theme.of(this).extension<MrplCorporateColors>()!;
}

/// The application theme.
///
/// **Light is the production theme** (APP-PRODUCT-01 §50: white-first). The
/// dark variant is still buildable because legacy goldens render it, but the
/// app does not offer it: `MaterialApp.themeMode` is fixed to light.
///
/// Material's own widgets — buttons, fields, chips, dialogs, sheets, snack
/// bars, navigation — are all themed here from semantic tokens, so no default
/// Material colour leaks into the product (§51). The default `primary` is the
/// brand green, because most of the product is product chrome; measurement
/// surfaces re-map it to the instrument accent with [InstrumentTheme].
ThemeData buildDoseBandTheme({required Brightness brightness}) {
  final isLight = brightness == Brightness.light;
  final c = isLight ? DoseBandColors.light : DoseBandColors.dark;
  final p = isLight ? ProductColors.light : ProductColors.dark;
  final t = DoseBandTypography.standard;
  final corporate = isLight
      ? MrplCorporateColors.light
      : MrplCorporateColors.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.brandPrimary,
    onPrimary: p.onBrandPrimary,
    primaryContainer: p.brandPrimaryContainer,
    onPrimaryContainer: p.onBrandContainer,
    secondary: p.brandPrimary,
    onSecondary: p.onBrandPrimary,
    secondaryContainer: p.brandPrimaryContainer,
    onSecondaryContainer: p.onBrandContainer,
    tertiary: p.instrumentAccent,
    onTertiary: p.onBrandPrimary,
    error: p.critical,
    onError: p.onBrandPrimary,
    errorContainer: p.criticalContainer,
    onErrorContainer: p.critical,
    surface: p.surfacePage,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerLowest: p.surfaceCard,
    surfaceContainerLow: p.surfaceCard,
    surfaceContainer: p.surfaceSecondary,
    surfaceContainerHigh: p.surfaceSecondary,
    surfaceContainerHighest: p.surfaceSecondary,
    outline: p.borderInput,
    outlineVariant: p.borderSubtle,
    scrim: p.scrim,
    shadow: Neutral.l0,
    // Material tints raised surfaces with primary by default. A green cast on
    // every sheet and menu is exactly the "green everywhere" look this theme
    // exists to avoid.
    surfaceTint: Colors.transparent,
  );

  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.sm),
  );
  const controlMinSize = Size(kMinInteractive, kMinInteractive);
  const controlPadding = EdgeInsets.symmetric(
    horizontal: Space.lg,
    vertical: Space.md,
  );

  OutlineInputBorder inputBorder(Color colour, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: colour, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.surfacePage,
    canvasColor: p.surfacePage,
    // Plain ink. The sparkle ripple is decoration that says nothing about
    // state, and on a mid-range phone it is the most expensive splash.
    splashFactory: InkRipple.splashFactory,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    extensions: [c, t, corporate, p],
    iconTheme: IconThemeData(color: p.textPrimary, size: 24),
    textTheme: TextTheme(
      displaySmall: t.display.copyWith(color: p.textPrimary),
      headlineSmall: t.heading.copyWith(color: p.textPrimary),
      titleLarge: t.heading.copyWith(color: p.textPrimary),
      titleMedium: t.bodyStrong.copyWith(color: p.textPrimary),
      titleSmall: t.label.copyWith(color: p.textPrimary),
      bodyLarge: t.body.copyWith(color: p.textPrimary),
      bodyMedium: t.body.copyWith(color: p.textPrimary),
      bodySmall: t.caption.copyWith(color: p.textSecondary),
      labelLarge: t.label.copyWith(color: p.textPrimary),
      labelMedium: t.label.copyWith(color: p.textSecondary),
      labelSmall: t.caption.copyWith(color: p.textSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.surfacePage,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: t.heading.copyWith(color: p.textPrimary),
      shape: Border(
        bottom: BorderSide(color: p.borderSubtle, width: Borders.hairline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: p.borderSubtle,
      thickness: Borders.hairline,
      space: Borders.hairline,
    ),
    // Elevation is carried by the page/card contrast plus a hairline, never
    // by a soft grey drop shadow.
    cardTheme: CardThemeData(
      color: p.surfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: p.borderSubtle, width: Borders.hairline),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.brandPrimary,
        foregroundColor: p.onBrandPrimary,
        disabledBackgroundColor: p.surfaceSecondary,
        disabledForegroundColor: p.textDisabled,
        minimumSize: controlMinSize,
        padding: controlPadding,
        shape: controlShape,
        textStyle: t.label,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      // An elevated button is a filled button in this product: no shadow.
      style: ElevatedButton.styleFrom(
        backgroundColor: p.brandPrimary,
        foregroundColor: p.onBrandPrimary,
        disabledBackgroundColor: p.surfaceSecondary,
        disabledForegroundColor: p.textDisabled,
        minimumSize: controlMinSize,
        padding: controlPadding,
        shape: controlShape,
        textStyle: t.label,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.textPrimary,
        disabledForegroundColor: p.textDisabled,
        side: BorderSide(color: p.borderDefault),
        minimumSize: controlMinSize,
        padding: controlPadding,
        shape: controlShape,
        textStyle: t.label,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.brandPrimaryPressed,
        disabledForegroundColor: p.textDisabled,
        minimumSize: controlMinSize,
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        shape: controlShape,
        textStyle: t.label,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.textPrimary,
        disabledForegroundColor: p.textDisabled,
        minimumSize: controlMinSize,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceCard,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.md,
      ),
      labelStyle: t.body.copyWith(color: p.textSecondary),
      floatingLabelStyle: t.label.copyWith(color: p.textPrimary),
      hintStyle: t.body.copyWith(color: p.textSecondary),
      helperStyle: t.caption.copyWith(color: p.textSecondary),
      helperMaxLines: 3,
      errorStyle: t.caption.copyWith(color: p.critical),
      errorMaxLines: 3,
      prefixIconColor: p.textSecondary,
      suffixIconColor: p.textSecondary,
      border: inputBorder(p.borderInput),
      enabledBorder: inputBorder(p.borderInput),
      focusedBorder: inputBorder(p.focusRing, 2),
      errorBorder: inputBorder(p.critical),
      focusedErrorBorder: inputBorder(p.critical, 2),
      disabledBorder: inputBorder(p.borderSubtle),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceCard,
      selectedColor: p.brandPrimaryContainer,
      disabledColor: p.surfaceSecondary,
      checkmarkColor: p.onBrandContainer,
      side: BorderSide(color: p.borderDefault),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      labelStyle: t.caption.copyWith(color: p.textPrimary),
      secondaryLabelStyle: t.caption.copyWith(color: p.onBrandContainer),
      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      titleTextStyle: t.heading.copyWith(color: p.textPrimary),
      contentTextStyle: t.body.copyWith(color: p.textSecondary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surfaceCard,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surfaceCard,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: p.borderDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      // Neutral ink. A transient confirmation must never be a green toast:
      // on a measurement surface green reads as "all clear" (§53).
      backgroundColor: p.textPrimary,
      contentTextStyle: t.body.copyWith(color: p.surfaceCard),
      actionTextColor: Brand.green94,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      textStyle: t.body.copyWith(color: p.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        side: BorderSide(color: p.borderSubtle),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textSecondary,
      textColor: p.textPrimary,
      titleTextStyle: t.bodyStrong.copyWith(color: p.textPrimary),
      subtitleTextStyle: t.caption.copyWith(color: p.textSecondary),
      minVerticalPadding: Space.sm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.brandPrimary : null,
      ),
      checkColor: WidgetStatePropertyAll(p.onBrandPrimary),
      side: BorderSide(color: p.borderInput, width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? p.brandPrimary : p.borderInput,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? p.onBrandPrimary : p.borderInput,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? p.brandPrimary
            : p.surfaceSecondary,
      ),
      trackOutlineColor: WidgetStatePropertyAll(p.borderInput),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.brandPrimary,
      linearTrackColor: p.surfaceSecondary,
      circularTrackColor: Colors.transparent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.textPrimary,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      textStyle: t.caption.copyWith(color: p.surfaceCard),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surfaceCard,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.brandPrimaryContainer,
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return t.caption.copyWith(
          color: selected ? p.onBrandContainer : p.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? p.onBrandContainer : p.textSecondary,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.surfaceCard,
      indicatorColor: p.brandPrimaryContainer,
      selectedIconTheme: IconThemeData(color: p.onBrandContainer),
      unselectedIconTheme: IconThemeData(color: p.textSecondary),
      selectedLabelTextStyle: t.caption.copyWith(
        color: p.onBrandContainer,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: t.caption.copyWith(color: p.textSecondary),
      labelType: NavigationRailLabelType.all,
    ),
  );
}

/// Re-maps Material's defaults to the measurement register for a subtree.
///
/// The product theme's `primary` is the brand green. A measurement surface —
/// capture, processing, result, anything rendering the badge — must not pick
/// that up by accident through a default-coloured button or progress
/// indicator: a saturated field beside a colorimetric reading biases the eye
/// judging it, and green beside a result reads as "safe" (§92).
///
/// Applied by `StepScaffold(register: StepRegister.instrument)` and around the
/// measurement routes, so a measurement screen is neutral without every call
/// site remembering to ask.
class InstrumentTheme extends StatelessWidget {
  const InstrumentTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final c = context.colours;
    final t = context.type;
    final accent = c.measurementAccent;
    final onAccent = c.textOnAccent;

    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: accent,
          onPrimary: onAccent,
          primaryContainer: c.measurementAccentMuted,
          onPrimaryContainer: c.textPrimary,
          secondary: accent,
          onSecondary: onAccent,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: base.filledButtonTheme.style?.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) =>
                  s.contains(WidgetState.disabled) ? c.surfaceSunken : accent,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) =>
                  s.contains(WidgetState.disabled) ? c.textDisabled : onAccent,
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.control),
              ),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: base.textButtonTheme.style?.copyWith(
            foregroundColor: WidgetStatePropertyAll(accent),
          ),
        ),
        progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
          color: accent,
        ),
        textSelectionTheme: TextSelectionThemeData(cursorColor: accent),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.control),
            borderSide: BorderSide(color: accent, width: 2),
          ),
          floatingLabelStyle: t.label.copyWith(color: c.textPrimary),
        ),
      ),
      child: child,
    );
  }
}
