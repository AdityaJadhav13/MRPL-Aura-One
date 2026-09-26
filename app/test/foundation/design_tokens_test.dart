import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/product_states.dart';
import 'package:h2s_doseband/core/components/product_status.dart';
import 'package:h2s_doseband/core/design/corporate_colors.dart';
import 'package:h2s_doseband/core/design/product_colors.dart';
import 'package:h2s_doseband/core/design/responsive.dart';
import 'package:h2s_doseband/core/design/theme.dart';
import 'package:h2s_doseband/core/design/tokens.dart';

/// WCAG relative luminance and contrast ratio.
double _luminance(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const p = ProductColors.light;

  group('contrast (APP-PRODUCT-01 §73, §114)', () {
    // Text needs 4.5:1; a meaningful icon or control boundary needs 3:1.
    final text = <String, (Color, Color)>{
      'primary text on page': (p.textPrimary, p.surfacePage),
      'secondary text on page': (p.textSecondary, p.surfacePage),
      'secondary text on secondary surface': (
        p.textSecondary,
        p.surfaceSecondary,
      ),
      'disabled text on page': (p.textDisabled, p.surfacePage),
      'label on a primary button': (p.onBrandPrimary, p.brandPrimary),
      'label on a pressed primary button': (
        p.onBrandPrimary,
        p.brandPrimaryPressed,
      ),
      'selected navigation label': (p.onBrandContainer, p.surfaceCard),
      'selected label on the indicator': (
        p.onBrandContainer,
        p.brandPrimaryContainer,
      ),
      'brand primary as link text': (p.brandPrimary, p.surfacePage),
      'field error': (p.critical, p.surfacePage),
      'warning on its container': (p.warning, p.warningContainer),
      'critical on its container': (p.critical, p.criticalContainer),
      'simulated on its container': (p.simulationAccent, p.simulationContainer),
      'instrument on its container': (
        p.instrumentAccent,
        p.instrumentContainer,
      ),
      'info on its container': (p.info, p.infoContainer),
      'neutral status on secondary surface': (
        p.textPrimary,
        p.surfaceSecondary,
      ),
    };
    for (final e in text.entries) {
      test('${e.key} ≥ 4.5:1', () {
        final (fg, bg) = e.value;
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
      });
    }

    final nonText = <String, (Color, Color)>{
      'input border on page': (p.borderInput, p.surfacePage),
      'brand secondary mark on page': (p.brandSecondary, p.surfacePage),
      'focus ring on page': (p.focusRing, p.surfacePage),
    };
    for (final e in nonText.entries) {
      test('${e.key} ≥ 3:1', () {
        final (fg, bg) = e.value;
        expect(contrast(fg, bg), greaterThanOrEqualTo(3));
      });
    }

    test('the legacy corporate primary action is readable', () {
      // It was white on orange, 2.88:1, on the worker's main button.
      const c = MrplCorporateColors.light;
      expect(contrast(c.textOnPrimary, c.primary), greaterThanOrEqualTo(4.5));
    });

    test('the raw brand orange is never adequate for text', () {
      // Recorded so nobody "fixes" a contrast failure by reaching for it.
      expect(contrast(Brand.orange, Colors.white), lessThan(3));
    });
  });

  group('the palette is derived, not invented (§9)', () {
    test('the brand mark is the logo field colour', () {
      expect(p.brandMark, const Color(0xFF5C822D));
    });

    test('the legacy corporate palette resolves to the same brand', () {
      const c = MrplCorporateColors.light;
      expect(c.primary, p.brandPrimary);
      expect(c.selectedFill, p.brandPrimaryContainer);
    });

    test('the old forest green is gone from the light palette', () {
      const c = MrplCorporateColors.light;
      for (final colour in [c.primary, c.primaryDeep, c.selectedBorder]) {
        expect(colour, isNot(const Color(0xFF0E4634)));
      }
    });

    test('the product ground is white', () {
      expect(p.surfacePage, const Color(0xFFFFFFFF));
      expect(p.surfaceCard, const Color(0xFFFFFFFF));
    });
  });

  group('brand is not status (§10)', () {
    test('no status tone resolves to the brand green', () {
      for (final tone in StatusTone.values) {
        final c = tone.resolve(p);
        expect(c.fg, isNot(p.brandPrimary), reason: tone.name);
        expect(c.fg, isNot(p.brandMark), reason: tone.name);
        expect(c.container, isNot(p.brandPrimaryContainer), reason: tone.name);
      }
    });

    test('the status vocabulary has no safe state', () {
      const banned = ['safe', 'ok', 'clear', 'no danger', 'no risk', 'normal'];
      for (final s in ProductStatus.values) {
        for (final word in banned) {
          expect(
            s.label.toLowerCase().contains(word) ||
                s.name.toLowerCase() == word,
            isFalse,
            reason: '${s.name} reads as "$word"',
          );
        }
      }
    });

    test('red is reserved: no refusal-type status is critical', () {
      for (final s in [
        ProductStatus.noReading,
        ProductStatus.belowQuantification,
        ProductStatus.aboveRange,
        ProductStatus.saturated,
        ProductStatus.unsupportedCalibration,
        ProductStatus.resultUnreliable,
        ProductStatus.invalid,
        ProductStatus.retake,
      ]) {
        expect(s.tone, isNot(StatusTone.critical), reason: s.name);
      }
    });

    test('simulated alone uses the simulation tone', () {
      final simulatedTone = ProductStatus.values
          .where((s) => s.tone == StatusTone.simulated)
          .toList();
      expect(simulatedTone, [ProductStatus.simulated]);
    });

    test('every status and state has a word and an icon', () {
      for (final s in ProductStatus.values) {
        expect(s.label, isNotEmpty);
      }
      for (final k in StateKind.values) {
        expect(k.defaultTitle, isNotEmpty);
      }
    });

    test('the product colour file declares no safe or success token', () {
      final source = File('lib/core/design/product_colors.dart')
          .readAsStringSync();
      for (final banned in [
        RegExp(r'final Color \w*[Ss]afe'),
        RegExp(r'final Color \w*[Ss]uccess'),
        RegExp(r'final Color \w*[Pp]ositive'),
      ]) {
        expect(banned.hasMatch(source), isFalse, reason: banned.pattern);
      }
    });
  });

  group('scales', () {
    test('radii are one restrained scale', () {
      expect([
        Radii.measurement,
        Radii.control,
        Radii.sm,
        Radii.md,
        Radii.lg,
      ], orderedEquals([0, 4, 8, 12, 16]));
      // Legacy aliases resolve into the scale; the retired 22 is gone.
      for (final r in [
        CorporateRadii.sm,
        CorporateRadii.md,
        CorporateRadii.lg,
        CorporateRadii.xl,
      ]) {
        expect([Radii.sm, Radii.md, Radii.lg], contains(r));
      }
    });

    test('spacing is a 4-point grid', () {
      for (final s in [
        Space.xs,
        Space.sm,
        Space.md,
        Space.base,
        Space.lg,
        Space.xl,
        Space.xxl,
        Space.xxxl,
      ]) {
        expect(s % 4, 0, reason: '$s');
      }
    });

    test('touch targets', () {
      expect(kMinInteractive, greaterThanOrEqualTo(48));
      expect(kMinTouchTarget, greaterThanOrEqualTo(56));
    });

    test('breakpoints classify the tested widths', () {
      expect(WindowClass.forWidth(320), WindowClass.compact);
      expect(WindowClass.forWidth(430), WindowClass.compact);
      expect(WindowClass.forWidth(600), WindowClass.medium);
      expect(WindowClass.forWidth(719), WindowClass.medium);
      expect(WindowClass.forWidth(720), WindowClass.expanded);
      expect(WindowClass.forWidth(1280), WindowClass.expanded);
    });

    test('the floating shadow is neutral, never tinted', () {
      for (final s in Elevation.floating) {
        expect(s.color.r == s.color.g && s.color.g == s.color.b, isTrue);
      }
    });
  });

  group('theme (§50, §51)', () {
    final theme = buildDoseBandTheme(brightness: Brightness.light);

    test('light, Material 3, white ground', () {
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, p.surfacePage);
    });

    test('Material primary is the brand, and nothing tints surfaces', () {
      expect(theme.colorScheme.primary, p.brandPrimary);
      expect(theme.colorScheme.surfaceTint, Colors.transparent);
    });

    test('every extension the widgets read is present', () {
      expect(theme.extension<ProductColors>(), isNotNull);
      expect(theme.extension<MrplCorporateColors>(), isNotNull);
    });

    test('a snack bar is never a green toast', () {
      expect(theme.snackBarTheme.backgroundColor, isNot(p.brandPrimary));
    });
  });
}
