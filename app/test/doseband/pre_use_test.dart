import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/doseband/domain/pre_use.dart';
import 'package:h2s_doseband/features/operations/application/local_doseband_registry.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/operations/domain/assignment.dart';

import '../operations/operations_fixtures.dart';

/// PRODUCT BUILD v1 §10, §11, §117 — BAD PHOTO ≠ BAD DOSEBAND.
void main() {
  final s = PresentationDataset.build(fixedNow);
  Eligibility assess(String id, [String worker = PresentationDataset.aditya]) =>
      DoseBandEligibility.assess(
        s,
        dosebandId: id,
        workerId: worker,
        now: fixedNow,
      );

  const blurred = OpticalNotReadable(
    reason: 'The image is blurred.',
    action: 'Hold the phone steady.',
  );

  test('a good band and a readable photo: ready to use', () {
    final v = PreUseAssessment.verdict(
      assess('DB-2609-0010'),
      const OpticalReadable(),
    );
    expect(v.outcome, PreUseOutcome.readyToUse);
    expect(v.message, contains('not assessed'), reason: 'no chemistry claim');
  });

  test('a good band and a bad photo: cannot verify — never replace', () {
    final v = PreUseAssessment.verdict(assess('DB-2609-0010'), blurred);
    expect(v.outcome, PreUseOutcome.cannotVerify);
    expect(v.message, contains('may be fine'));
    expect(v.replaceReason, isNull);
  });

  test('camera unavailable: cannot verify, nothing assigned', () {
    final v = PreUseAssessment.verdict(
      assess('DB-2609-0010'),
      const OpticalCameraUnavailable('permission refused'),
    );
    expect(v.outcome, PreUseOutcome.cannotVerify);
  });

  test('a correction caveat does not stop a readable band', () {
    final v = PreUseAssessment.verdict(
      assess('DB-2609-0010'),
      const OpticalReadable(correctionCaveat: 'REF-BLACK residual'),
    );
    expect(v.outcome, PreUseOutcome.readyToUse);
  });

  for (final (id, reason) in [
    ('DB-2609-0001', ReplaceReason.alreadyAssigned),
    ('DB-2609-0003', ReplaceReason.recordedDamaged),
    ('DB-2608-0001', ReplaceReason.expired),
    ('DB-2607-0001', ReplaceReason.unsupportedLot),
    ('DB-9999-0001', ReplaceReason.unknownDoseBand),
  ]) {
    test('$id is replace (${reason.name}) whatever the photo shows', () {
      for (final optical in [null, const OpticalReadable(), blurred]) {
        final v = PreUseAssessment.verdict(assess(id), optical);
        expect(v.outcome, PreUseOutcome.replace);
        expect(v.replaceReason, reason);
      }
    });
  }

  test('a worker who already holds a band is told so, not told to replace', () {
    final v = PreUseAssessment.verdict(
      assess('DB-2609-0010', PresentationDataset.lavitra),
      const OpticalReadable(),
    );
    expect(v.outcome, PreUseOutcome.cannotVerify);
    expect(v.message, contains('DB-2609-0001'));
  });
}
