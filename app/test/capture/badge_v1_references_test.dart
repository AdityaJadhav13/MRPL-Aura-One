import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/capture/domain/badge_v1_references.dart';
import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

/// The app's copy of Badge V1's reference colours must equal the canonical
/// one, byte for byte. G-10.
///
/// The app cannot import `package:measurement/testing.dart` into production
/// code, so the values are repeated. A repeated constant drifts — and if these
/// drifted, the colour correction would aim at colours that were never
/// printed, and every corrected value would be wrong by an amount no single
/// capture could reveal.
void main() {
  test('every reference patch matches the canonical design value', () {
    final canonical = <String, List<int>>{
      for (final e in badgeV1Colours.entries)
        if (e.key.startsWith('REF-')) e.key: e.value,
    };
    expect(
      badgeV1ReferenceDesignBytes.keys.toSet(),
      canonical.keys.toSet(),
      reason: 'the two copies name different patches',
    );
    for (final id in canonical.keys) {
      expect(badgeV1ReferenceDesignBytes[id], canonical[id], reason: id);
    }
  });

  test('fit and holdout sets are disjoint and cover every patch', () {
    // §37: a withheld patch that leaks into the fit validates nothing.
    expect(
      badgeV1FitPatchIds.toSet().intersection(badgeV1HoldoutPatchIds.toSet()),
      isEmpty,
    );
    expect({
      ...badgeV1FitPatchIds,
      ...badgeV1HoldoutPatchIds,
    }, badgeV1ReferenceDesignBytes.keys.toSet());
  });

  test('every patch exists in the canonical geometry', () {
    final geometry = BadgeGeometry.parse(
      File('../packages/measurement/geometry/badge-v1.geometry.json')
          .readAsStringSync(),
    );
    for (final id in badgeV1ReferenceDesignBytes.keys) {
      expect(geometry.roiById(id), isNotNull, reason: id);
    }
  });
}
