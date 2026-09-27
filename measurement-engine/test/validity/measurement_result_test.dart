import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

const _provenanceWithModel = Provenance(
  algorithmVersion: 'cv-0.1.0',
  geometryVersion: 'geom-mock-1',
  calibrationModelId: 'cal-mock-1',
  referenceProfileId: 'ref-mock-1',
  appVersion: '0.1.0+1',
  deviceModel: 'test',
);

const _provenanceNoModel = Provenance(
  algorithmVersion: 'cv-0.1.0',
  geometryVersion: 'geom-mock-1',
  calibrationModelId: null,
  referenceProfileId: null,
  appVersion: '0.1.0+1',
  deviceModel: 'test',
);

void main() {
  group('a failure is never a number', () {
    // The whole architecture exists to hold this line. If these tests are ever
    // deleted or weakened, read docs/architecture/overview.md before agreeing.
    test('only two statuses may carry a dose', () {
      final carrying = ResultStatus.values.where((s) => s.carriesDose).toSet();
      expect(carrying, {ResultStatus.valid, ResultStatus.validWithWarning});
    });

    test('every status is exactly one of valued, censored or refused', () {
      for (final status in ResultStatus.values) {
        final kinds = [status.carriesDose, status.isCensored, status.isRefusal];
        expect(
          kinds.where((k) => k).length,
          1,
          reason: '$status must belong to exactly one kind',
        );
      }
    });

    test('Refused has no dose to report', () {
      final result = Refused(
        status: ResultStatus.poorImage,
        reasons: const [ReasonCode('image.blur')],
        provenance: _provenanceNoModel,
      );
      // There is no `.dose` on Refused. This is a compile-time property, so the
      // test asserts the shape that guarantees it.
      expect(result, isA<MeasurementResult>());
      expect(result, isNot(isA<Valid>()));
      expect(result.status.carriesDose, isFalse);
    });

    test('Censored reports a bound, not a value', () {
      final result = Censored(
        status: ResultStatus.aboveRange,
        direction: CensorDirection.above,
        bound: const Dose.ppmHours(40),
        reasons: const [ReasonCode('range.above')],
        provenance: _provenanceWithModel,
      );
      expect(result, isNot(isA<Valid>()));
      expect(result.bound?.value, 40);
    });

    test('below the quantification limit is not zero', () {
      final result = Censored(
        status: ResultStatus.belowQuantificationLimit,
        direction: CensorDirection.below,
        reasons: const [ReasonCode('range.below_loq')],
        provenance: _provenanceWithModel,
      );
      expect(result, isNot(isA<Valid>()));
      expect(result.status, isNot(ResultStatus.valid));
    });
  });

  group('a valid result must be defensible', () {
    test('requires the calibration model that produced it', () {
      expect(
        () => Valid(
          dose: const Dose.ppmHours(3.2),
          uncertainty: const Uncertainty(halfWidth: 0.8, basis: 'mock'),
          coverage: const Duration(hours: 8),
          provenance: _provenanceNoModel,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('warnings downgrade valid to valid_with_warning', () {
      final clean = Valid(
        dose: const Dose.ppmHours(3.2),
        uncertainty: const Uncertainty(halfWidth: 0.8, basis: 'mock'),
        coverage: const Duration(hours: 8),
        provenance: _provenanceWithModel,
      );
      final warned = Valid(
        dose: const Dose.ppmHours(3.2),
        uncertainty: const Uncertainty(halfWidth: 0.8, basis: 'mock'),
        coverage: const Duration(hours: 8),
        provenance: _provenanceWithModel,
        warnings: const [ReasonCode('coverage.sleeve_suspected')],
      );
      expect(clean.status, ResultStatus.valid);
      expect(warned.status, ResultStatus.validWithWarning);
    });

    test('a dose cannot be negative', () {
      expect(() => Dose.ppmHours(-1), throwsA(isA<AssertionError>()));
    });
  });

  group('a non-valid result must explain itself', () {
    test('a refusal cannot be silent', () {
      expect(
        () => Refused(
          status: ResultStatus.badgeExpired,
          reasons: const [],
          provenance: _provenanceNoModel,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a censored result cannot be silent', () {
      expect(
        () => Censored(
          status: ResultStatus.saturated,
          direction: CensorDirection.above,
          reasons: const [],
          provenance: _provenanceWithModel,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Refused rejects a status that is not a refusal', () {
      expect(
        () => Refused(
          status: ResultStatus.aboveRange,
          reasons: const [ReasonCode('x')],
          provenance: _provenanceNoModel,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Censored rejects a status that is not censored', () {
      expect(
        () => Censored(
          status: ResultStatus.poorImage,
          direction: CensorDirection.below,
          reasons: const [ReasonCode('x')],
          provenance: _provenanceWithModel,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
