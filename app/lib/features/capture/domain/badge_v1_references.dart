import 'package:measurement/measurement.dart';

/// Badge V1's reference patches as the capture pipeline uses them.
///
/// ## Two copies, one truth
///
/// The canonical design values live in the measurement package, beside the
/// renderer and the print-sheet generator. They are repeated here because the
/// app must not import `package:measurement/testing.dart` into production
/// code. A repeated constant is a drift risk, so
/// `test/capture/badge_v1_references_test.dart` fails if the two copies ever
/// disagree by a single byte. G-10.

/// Patch ids used to fit the colour correction: the light neutral plus every
/// chromatic patch. Neutrals alone are collinear in RGB and cannot constrain a
/// correction (design rule R4).
const List<String> badgeV1FitPatchIds = <String>[
  'REF-LIGHT',
  'REF-RED',
  'REF-GREEN',
  'REF-BLUE',
  'REF-CYAN',
  'REF-YELLOW',
];

/// Withheld from every fit, so the correction can be scored on colours it has
/// not seen. §37: a correction that fits its own references proves nothing.
const List<String> badgeV1HoldoutPatchIds = <String>[
  'REF-BLACK',
  'REF-DARK',
  'REF-MID',
  'REF-MAGENTA',
];

/// **DESIGN-SPACE values, not measured printed colour.** Ink, substrate and
/// printer profile all intervene between the design file and the paper. Until
/// a print lot is measured with a spectrophotometer, results computed against
/// these support *relative* conclusions only — repeatability, cross-device and
/// cross-illuminant spread — and no claim of absolute colorimetric accuracy.
const Map<String, List<int>> badgeV1ReferenceDesignBytes = <String, List<int>>{
  'REF-BLACK': <int>[24, 24, 24],
  'REF-DARK': <int>[72, 72, 72],
  'REF-MID': <int>[128, 128, 128],
  'REF-LIGHT': <int>[205, 205, 205],
  'REF-RED': <int>[196, 62, 52],
  'REF-GREEN': <int>[62, 158, 82],
  'REF-BLUE': <int>[58, 78, 186],
  'REF-CYAN': <int>[60, 160, 170],
  'REF-MAGENTA': <int>[170, 66, 140],
  'REF-YELLOW': <int>[200, 180, 60],
};

/// The design values as linear-light targets, for patches the geometry has.
Map<String, LinearRgb> badgeV1ReferenceTargets(BadgeGeometry geometry) =>
    <String, LinearRgb>{
      for (final entry in badgeV1ReferenceDesignBytes.entries)
        if (geometry.roiById(entry.key) != null)
          entry.key: SrgbColor.fromBytes(
            entry.value[0],
            entry.value[1],
            entry.value[2],
          ).toLinear(),
    };
