import 'dart:convert';
import 'dart:io';

import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

/// The committed demo geometry, loaded from the repository rather than
/// restated here. Geometry is data; a test that hard-codes a copy of it is
/// testing a different badge.
File get _demoGeometryFile => File('geometry/demo-badge-v0.geometry.json');

void main() {
  group('the committed demo badge geometry', () {
    test('parses and validates', () {
      expect(
        _demoGeometryFile.existsSync(),
        isTrue,
        reason: 'demo geometry is missing from assets/badge-samples/',
      );
      final geometry = BadgeGeometry.parse(
        _demoGeometryFile.readAsStringSync(),
      );
      expect(geometry.version, 'demo-badge-v0');
      expect(geometry.validate(), isEmpty);
    });

    test('has exactly one orientation marker', () {
      final geometry = BadgeGeometry.parse(
        _demoGeometryFile.readAsStringSync(),
      );
      expect(
        geometry.fiducials.where((f) => f.orientationMarker).length,
        1,
        reason:
            'without exactly one, a square layout has a four-fold '
            'rotational ambiguity',
      );
    });

    test('carries enough reference patches to both fit and withhold', () {
      final geometry = BadgeGeometry.parse(
        _demoGeometryFile.readAsStringSync(),
      );
      final references = geometry.ofKind(RoiKind.reference).toList();
      expect(
        references.length,
        greaterThanOrEqualTo(5),
        reason:
            'an affine correction consumes 4; at least one must be left '
            'to validate it',
      );
    });

    test('every ROI survives its own erosion margin', () {
      final geometry = BadgeGeometry.parse(
        _demoGeometryFile.readAsStringSync(),
      );
      for (final roi in geometry.rois) {
        expect(roi.eroded, isNotNull, reason: '${roi.id} is over-eroded');
      }
    });

    test('round-trips through JSON', () {
      final original = BadgeGeometry.parse(
        _demoGeometryFile.readAsStringSync(),
      );
      final reparsed = BadgeGeometry.parse(jsonEncode(original.toJson()));
      expect(reparsed.version, original.version);
      expect(reparsed.rois.length, original.rois.length);
      expect(reparsed.roiById('A1')!.xMm, original.roiById('A1')!.xMm);
    });
  });

  group('geometry validation catches authoring errors', () {
    BadgeGeometry build({
      List<FiducialDefinition>? fiducials,
      List<RoiDefinition>? rois,
    }) => BadgeGeometry(
      version: 'test',
      widthMm: 40,
      heightMm: 25,
      fiducials:
          fiducials ??
          const <FiducialDefinition>[
            FiducialDefinition(
              id: 'A',
              centreMm: PointMm(3, 3),
              sizeMm: 3,
              orientationMarker: true,
            ),
            FiducialDefinition(id: 'B', centreMm: PointMm(37, 3), sizeMm: 3),
            FiducialDefinition(id: 'C', centreMm: PointMm(37, 22), sizeMm: 3),
            FiducialDefinition(id: 'D', centreMm: PointMm(3, 22), sizeMm: 3),
          ],
      rois:
          rois ??
          const <RoiDefinition>[
            RoiDefinition(
              id: 'A1',
              kind: RoiKind.sensor,
              xMm: 6,
              yMm: 6,
              widthMm: 6,
              heightMm: 6,
            ),
            RoiDefinition(
              id: 'R1',
              kind: RoiKind.reference,
              xMm: 14,
              yMm: 6,
              widthMm: 4,
              heightMm: 4,
            ),
            RoiDefinition(
              id: 'R2',
              kind: RoiKind.reference,
              xMm: 20,
              yMm: 6,
              widthMm: 4,
              heightMm: 4,
            ),
          ],
    );

    test('the baseline fixture is valid', () {
      expect(build().validate(), isEmpty);
    });

    test('rejects fewer than four fiducials', () {
      final problems = build(
        fiducials: const <FiducialDefinition>[
          FiducialDefinition(
            id: 'A',
            centreMm: PointMm(3, 3),
            sizeMm: 3,
            orientationMarker: true,
          ),
          FiducialDefinition(id: 'B', centreMm: PointMm(37, 3), sizeMm: 3),
        ],
      ).validate();
      expect(problems.join(' '), contains('at least 4 fiducials'));
    });

    test('rejects zero or multiple orientation markers', () {
      expect(
        build(
          fiducials: const <FiducialDefinition>[
            FiducialDefinition(id: 'A', centreMm: PointMm(3, 3), sizeMm: 3),
            FiducialDefinition(id: 'B', centreMm: PointMm(37, 3), sizeMm: 3),
            FiducialDefinition(id: 'C', centreMm: PointMm(37, 22), sizeMm: 3),
            FiducialDefinition(id: 'D', centreMm: PointMm(3, 22), sizeMm: 3),
          ],
        ).validate().join(' '),
        contains('exactly 1 primary orientation marker'),
      );
    });

    test('rejects an ROI that falls off the badge', () {
      final problems = build(
        rois: const <RoiDefinition>[
          RoiDefinition(
            id: 'A1',
            kind: RoiKind.sensor,
            xMm: 36,
            yMm: 6,
            widthMm: 8,
            heightMm: 6,
          ),
          RoiDefinition(
            id: 'R1',
            kind: RoiKind.reference,
            xMm: 14,
            yMm: 6,
            widthMm: 4,
            heightMm: 4,
          ),
          RoiDefinition(
            id: 'R2',
            kind: RoiKind.reference,
            xMm: 20,
            yMm: 6,
            widthMm: 4,
            heightMm: 4,
          ),
        ],
      ).validate();
      expect(problems.join(' '), contains('falls outside the badge'));
    });

    test('rejects duplicate region identifiers', () {
      final problems = build(
        rois: const <RoiDefinition>[
          RoiDefinition(
            id: 'X',
            kind: RoiKind.sensor,
            xMm: 6,
            yMm: 6,
            widthMm: 4,
            heightMm: 4,
          ),
          RoiDefinition(
            id: 'X',
            kind: RoiKind.reference,
            xMm: 14,
            yMm: 6,
            widthMm: 4,
            heightMm: 4,
          ),
          RoiDefinition(
            id: 'R2',
            kind: RoiKind.reference,
            xMm: 20,
            yMm: 6,
            widthMm: 4,
            heightMm: 4,
          ),
        ],
      ).validate();
      expect(problems.join(' '), contains('duplicate ROI id'));
    });

    test('rejects a geometry with fewer than two reference patches', () {
      final problems = build(
        rois: const <RoiDefinition>[
          RoiDefinition(
            id: 'A1',
            kind: RoiKind.sensor,
            xMm: 6,
            yMm: 6,
            widthMm: 6,
            heightMm: 6,
          ),
          RoiDefinition(
            id: 'R1',
            kind: RoiKind.reference,
            xMm: 14,
            yMm: 6,
            widthMm: 4,
            heightMm: 4,
          ),
        ],
      ).validate();
      expect(problems.join(' '), contains('withheld from its own fit'));
    });

    test('rejects an unknown ROI kind at parse time', () {
      expect(
        () => BadgeGeometry.parse(
          '{"version":"v","width_mm":10,"height_mm":10,"fiducials":[],'
          '"rois":[{"id":"X","kind":"nonsense","x_mm":1,"y_mm":1,'
          '"width_mm":2,"height_mm":2}]}',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ROI erosion', () {
    test('shrinks the region symmetrically', () {
      const roi = RoiDefinition(
        id: 'A1',
        kind: RoiKind.sensor,
        xMm: 6,
        yMm: 8,
        widthMm: 8,
        heightMm: 8,
        erosionMm: 1.0,
      );
      final eroded = roi.eroded!;
      expect(eroded.xMm, 7.0);
      expect(eroded.yMm, 9.0);
      expect(eroded.widthMm, 6.0);
      expect(eroded.heightMm, 6.0);
      expect(
        eroded.erosionMm,
        0.0,
        reason: 'erosion must not be applied twice',
      );
    });

    test('returns null when erosion would consume the region', () {
      const roi = RoiDefinition(
        id: 'tiny',
        kind: RoiKind.sensor,
        xMm: 0,
        yMm: 0,
        widthMm: 1,
        heightMm: 1,
        erosionMm: 0.6,
      );
      expect(roi.eroded, isNull);
    });
  });
}
