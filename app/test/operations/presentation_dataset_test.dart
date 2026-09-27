import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/domain/doseband.dart';
import 'package:h2s_doseband/core/domain/provenance.dart';
import 'package:h2s_doseband/features/operations/data/operations_codec.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';

import 'operations_fixtures.dart';

/// PRODUCT BUILD v1 §31, §84, §85 — one controlled dataset, six approved
/// people, no invented measurements.
void main() {
  final s = PresentationDataset.build(fixedNow);

  test('only the six approved people exist', () {
    expect(s.people.map((p) => p.displayName).toSet(), {
      'Aditya Jadhav',
      'Lavitra Satam',
      'Nikhil Sharma',
      'Aman Singh',
      'Samhita Hejmadi',
      'Yashvi Chotalia',
    });
  });

  test('no measurement record, review or photograph is seeded', () {
    expect(s.measurements, isEmpty);
    expect(s.reviews, isEmpty);
    expect(s.people.where((p) => p.photoAsset != null), isEmpty);
  });

  test('every person has a role and a matching scope grant', () {
    for (final p in s.people) {
      expect(p.roles, isNotEmpty, reason: p.displayName);
      for (final r in p.roles) {
        expect(
          s.grants.where((g) => g.personId == p.personId && g.role == r),
          isNotEmpty,
          reason: '${p.displayName} as ${r.name}',
        );
      }
    }
  });

  test('everything is marked as presentation data', () {
    expect(
      s.people.every(
        (p) => p.provenance == RecordProvenance.presentationSeeded,
      ),
      isTrue,
    );
    expect(
      s.bands.values.every(
        (b) => b.provenance == RecordProvenance.presentationSeeded,
      ),
      isTrue,
    );
  });

  test('band lifecycles agree with the seeded sessions', () {
    for (final x in s.sessions) {
      final band = s.bands[x.dosebandId]!;
      final a = s.assignment(x.assignmentId!)!;
      expect(band.assignmentId, a.assignmentId);
      expect(a.workerId, x.workerId);
      expect(
        band.lifecycle,
        anyOf(
          DoseBandLifecycle.monitoring,
          DoseBandLifecycle.readyForFinalRead,
        ),
      );
    }
    for (final b in s.bands.values) {
      expect(s.lot(b.lotId), isNotNull);
    }
  });

  test('no lot has a calibration: none exists', () {
    expect(s.lots.every((l) => l.calibrationPackageId == null), isTrue);
    expect(s.formulations.every((f) => !f.validated), isTrue);
  });

  test('the seed round-trips through the codec', () {
    final e = OperationsCodec.encode(s);
    expect(OperationsCodec.encode(OperationsCodec.decode(e)!), e);
  });
}
