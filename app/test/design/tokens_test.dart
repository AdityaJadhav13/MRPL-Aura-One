import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/design/semantic_colors.dart';
import 'package:h2s_doseband/core/design/status_presentation.dart';
import 'package:h2s_doseband/core/design/tokens.dart';
import 'package:measurement/measurement.dart';

void main() {
  group('the neutral ramp is actually neutral', () {
    // The user's task is judging a colour. A tinted surface shifts the apparent
    // hue of the badge beside it, so every neutral must have R == G == B.
    const ramp = <Color>[
      Neutral.l100,
      Neutral.l98,
      Neutral.l96,
      Neutral.l92,
      Neutral.l86,
      Neutral.l74,
      Neutral.l58,
      Neutral.l42,
      Neutral.l30,
      Neutral.l20,
      Neutral.l14,
      Neutral.l9,
      Neutral.l0,
    ];

    test('every step has equal channels', () {
      for (final c in ramp) {
        expect(
          c.r == c.g && c.g == c.b,
          isTrue,
          reason: '$c is tinted; neutrals must be exactly neutral',
        );
      }
    });

    test('the ramp is monotonic', () {
      for (var i = 1; i < ramp.length; i++) {
        expect(ramp[i].r, lessThan(ramp[i - 1].r));
      }
    });
  });

  group('colour carries meaning that must not drift', () {
    test('valid is not green', () {
      // Green means "safe". This badge cannot tell anyone they are safe, and
      // saying so would be the false-reassurance failure the product exists to
      // avoid. Valid speaks in the instrument's own colour instead.
      for (final c in [DoseBandColors.light, DoseBandColors.dark]) {
        final v = c.statusValid;
        final isGreenish = v.g > v.r && v.g > v.b;
        expect(isGreenish, isFalse, reason: 'statusValid $v reads as green');
      }
    });

    test('valid speaks in the instrument accent', () {
      for (final c in [DoseBandColors.light, DoseBandColors.dark]) {
        expect(c.statusValid, c.measurementAccent);
      }
    });

    test('destructive red is distinct from every other status', () {
      for (final c in [DoseBandColors.light, DoseBandColors.dark]) {
        final others = [
          c.statusValid,
          c.statusWarning,
          c.statusCensored,
          c.statusRefused,
          c.statusSimulated,
        ];
        expect(others, isNot(contains(c.statusDestructive)));
      }
    });

    test('simulated is distinct from every other status', () {
      for (final c in [DoseBandColors.light, DoseBandColors.dark]) {
        final others = [
          c.statusValid,
          c.statusWarning,
          c.statusCensored,
          c.statusRefused,
          c.statusDestructive,
        ];
        expect(others, isNot(contains(c.statusSimulated)));
      }
    });
  });

  group('status presentation', () {
    test('every status has an icon and a label, not colour alone', () {
      for (final s in ResultStatus.values) {
        final p = StatusPresentation.of(s, DoseBandColors.light);
        expect(p.label, isNotEmpty, reason: '$s has no label');
        expect(p.icon, isNotNull);
      }
    });

    test('labels are sentence case, never shouted', () {
      for (final s in ResultStatus.values) {
        final p = StatusPresentation.of(s, DoseBandColors.light);
        expect(
          p.label,
          isNot(equals(p.label.toUpperCase())),
          reason: '${p.label} is all caps',
        );
      }
    });

    test('refusals never borrow the valid colour', () {
      const c = DoseBandColors.light;
      for (final s in ResultStatus.values.where((s) => s.isRefusal)) {
        expect(StatusPresentation.of(s, c).colour, isNot(c.statusValid));
      }
    });
  });

  test('true black is reserved for the viewfinder', () {
    // The correct surround for judging a captured image, and nothing else. A
    // pure-black panel elsewhere is both off-spec and harsh on OLED.
    for (final c in [DoseBandColors.light, DoseBandColors.dark]) {
      expect(c.surfaceViewfinder, Neutral.l0);
      expect(c.surfacePrimary, isNot(Neutral.l0));
      expect(c.surfaceElevated, isNot(Neutral.l0));
      expect(c.surfaceSunken, isNot(Neutral.l0));
    }
  });

  test('worker touch targets exceed the Material minimum', () {
    // The user may be gloved, and a mis-tap during badge closure corrupts a
    // coverage record.
    expect(kMinTouchTarget, greaterThan(48));
  });
}
