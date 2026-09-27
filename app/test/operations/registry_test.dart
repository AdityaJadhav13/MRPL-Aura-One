import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/domain/doseband.dart';
import 'package:h2s_doseband/core/domain/doseband_registry.dart';
import 'package:h2s_doseband/core/domain/monitoring_session.dart';
import 'package:h2s_doseband/features/operations/application/access.dart';
import 'package:h2s_doseband/features/operations/application/local_doseband_registry.dart';
import 'package:h2s_doseband/features/operations/domain/assignment.dart';
import 'package:h2s_doseband/features/operations/domain/audit.dart';

import 'operations_fixtures.dart';

/// PRODUCT BUILD v1 §9, §116 — the claim is decided by the store, not a
/// screen, and at most one claim of a band can win.
void main() {
  const fresh = 'DB-2609-0010';
  const heldByLavitra = 'DB-2609-0001';
  const damaged = 'DB-2609-0003';
  const expiredLot = 'DB-2608-0001';
  const unsupportedLot = 'DB-2607-0001';

  test(
    'a valid unused DoseBand is claimed: assignment, session, audit',
    () async {
      final c = opsContainer();
      final r = await registryOf(c).claimWith(
        dosebandId: fresh,
        workerId: aditya.personId,
        preUse: PreUseRecord(
          outcome: PreUseOutcome.readyToUse,
          checkedAt: fixedNow,
          opticalCheck: OpticalCheckStatus.readable,
        ),
      );
      expect(r, isA<ClaimAccepted>());
      final s = await snap(c);
      final band = s.bands[fresh]!;
      expect(band.lifecycle, DoseBandLifecycle.assigned);
      final a = s.activeAssignmentOf(aditya.personId)!;
      expect(a.dosebandId, fresh);
      expect(band.assignmentId, a.assignmentId);
      expect(a.preUse!.outcome, PreUseOutcome.readyToUse);
      final session = s.session(a.sessionId)!;
      expect(session.state, MonitoringSessionState.notStarted);
      expect(session.dosebandId, fresh);
      expect(
        s.audit.last.action,
        AuditAction.dosebandClaimed,
        reason: 'the claim and its audit event are one write',
      );
    },
  );

  test('an unknown QR identity is not found, and nothing changes', () async {
    final c = opsContainer();
    final before = await snap(c);
    final r = await registryOf(c)
        .claim(dosebandId: 'DB-9999-0001', workerId: aditya.personId);
    expect(r, isA<ClaimNotFound>());
    expect(identical(await snap(c), before), isTrue);
  });

  test('a band held by someone else is a conflict that names no one', () async {
    final c = opsContainer();
    final r = await registryOf(c)
        .claim(dosebandId: heldByLavitra, workerId: aditya.personId);
    expect(r, isA<ClaimConflict>());
    // ClaimConflict carries no fields at all: the losing worker learns
    // nothing about who holds the band.
    expect(const ClaimConflict().toString(), isNot(contains('Lavitra')));
  });

  test(
    'already used, damaged, expired and unsupported bands are ineligible',
    () async {
      final c = opsContainer();
      final reg = registryOf(c);
      expect(
        await reg.claim(dosebandId: damaged, workerId: aditya.personId),
        isA<ClaimIneligible>().having(
          (x) => x.lifecycle,
          'lifecycle',
          DoseBandLifecycle.damaged,
        ),
      );
      expect(
        await reg.claim(dosebandId: expiredLot, workerId: aditya.personId),
        isA<ClaimIneligible>(),
      );
      expect(
        await reg.claim(dosebandId: unsupportedLot, workerId: aditya.personId),
        isA<ClaimIneligible>(),
      );
      final s = await snap(c);
      expect(
        DoseBandEligibility.assess(
          s,
          dosebandId: expiredLot,
          workerId: aditya.personId,
          now: fixedNow,
        ),
        isA<NotEligible>().having(
          (x) => x.reason,
          'reason',
          ReplaceReason.expired,
        ),
      );
      expect(
        DoseBandEligibility.assess(
          s,
          dosebandId: unsupportedLot,
          workerId: aditya.personId,
          now: fixedNow,
        ),
        isA<NotEligible>().having(
          (x) => x.reason,
          'reason',
          ReplaceReason.unsupportedLot,
        ),
      );
    },
  );

  test('a band used once can never be claimed again', () async {
    final c = opsContainer();
    await registryOf(c).claim(dosebandId: fresh, workerId: aditya.personId);
    final s0 = await snap(c);
    final session = s0.activeAssignmentOf(aditya.personId)!.sessionId;
    final w = workerOf(c, aditya);
    await w.startMonitoring(sessionId: session);
    await w.endMonitoring(sessionId: session);
    await w.recordMeasurement(
      refusalRecord(
        id: 'M-1',
        workerId: aditya.personId,
        sessionId: session,
        dosebandId: fresh,
      ),
    );
    // Aditya is free again — the period completed — and the band is spent.
    final r = await registryOf(c)
        .claim(dosebandId: fresh, workerId: aditya.personId);
    expect(
      r,
      isA<ClaimIneligible>().having(
        (x) => x.lifecycle,
        'lifecycle',
        DoseBandLifecycle.read,
      ),
    );
  });

  test('two simultaneous claims of one band: exactly one wins', () async {
    // Both workers need to be free: Nikhil's overdue period is closed out
    // first, as his supervisor would.
    final c = opsContainer();
    await workerOf(c, nikhil).closeMissingFinalRead(sessionId: 'SES-SEED-02');
    final reg = registryOf(c);
    final results = await Future.wait([
      reg.claim(dosebandId: fresh, workerId: aditya.personId),
      reg.claim(dosebandId: fresh, workerId: nikhil.personId),
    ]);
    expect(results.whereType<ClaimAccepted>(), hasLength(1));
    final s = await snap(c);
    expect(
      s.assignments.where((a) => a.dosebandId == fresh && a.isActive),
      hasLength(1),
      reason: 'one physical band, one active assignment',
    );
  });

  test('a worker with an active band cannot claim a second one', () async {
    final c = opsContainer();
    final r = await registryOf(c)
        .claim(dosebandId: fresh, workerId: lavitra.personId);
    expect(r, isA<ClaimWorkerHasActiveBand>());
    expect(
      (await snap(c)).bands[fresh]!.lifecycle,
      DoseBandLifecycle.available,
    );
  });

  test('re-claiming the band you already hold is idempotent', () async {
    final c = opsContainer();
    final r = await registryOf(c)
        .claim(dosebandId: heldByLavitra, workerId: lavitra.personId);
    expect(
      r,
      isA<ClaimAccepted>().having(
        (x) => x.assignmentId,
        'assignment',
        'ASG-SEED-01',
      ),
    );
    final s = await snap(c);
    expect(
      s.assignments.where((a) => a.workerId == lavitra.personId),
      hasLength(1),
    );
  });

  test('only a real, active worker account can claim', () async {
    final c = opsContainer();
    await expectLater(
      registryOf(c).claim(dosebandId: fresh, workerId: 'NOT-A-PERSON'),
      throwsA(isA<AccessDenied>()),
    );
    await expectLater(
      registryOf(c).claim(dosebandId: fresh, workerId: samhita.personId),
      throwsA(isA<AccessDenied>()),
      reason: 'an HSE officer does not wear a DoseBand in this model',
    );
  });

  test('lookup distinguishes found from not found', () async {
    final c = opsContainer();
    expect(await registryOf(c).lookup(fresh), isA<DoseBandFound>());
    expect(await registryOf(c).lookup('nope'), isA<DoseBandNotFound>());
  });
}
