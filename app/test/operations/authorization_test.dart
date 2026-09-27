import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/domain/doseband.dart';
import 'package:h2s_doseband/core/domain/monitoring_session.dart';
import 'package:h2s_doseband/features/auth/domain/access_policy.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/operations/application/access.dart';
import 'package:h2s_doseband/features/operations/application/admin_service.dart';
import 'package:h2s_doseband/features/operations/application/hse_service.dart';
import 'package:h2s_doseband/features/operations/application/management_service.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/application/supervisor_service.dart';
import 'package:h2s_doseband/features/operations/application/worker_service.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/operations/domain/operations_snapshot.dart';
import 'package:h2s_doseband/features/operations/domain/organisation.dart';
import 'package:h2s_doseband/features/operations/domain/review.dart';

import 'operations_fixtures.dart';

/// PRODUCT BUILD v1 §107 — the authorisation model, tested at the service
/// layer, which is as far down the stack as this build goes.
///
/// **SERVER ENFORCEMENT PENDING.** These prove the local policy that every
/// screen goes through. They do not, and cannot, prove a server would refuse
/// the same requests: there is no server.
void main() {
  /// Aditya and Nikhil each finish a period with a record.
  Future<OperationsSnapshot> withRecords() async {
    final c = opsContainer();
    Future<void> run(Actor who, String band, String id) async {
      await registryOf(c).claimWith(
        dosebandId: band,
        workerId: who.personId,
        work: const WorkSummary(
          siteId: PresentationDataset.siteId,
          siteName: PresentationDataset.siteName,
          departmentId: 'maintenance',
          departmentName: 'Maintenance',
          workAreaId: 'sru',
          workAreaName: 'Sulphur Recovery Unit — Demo area',
        ),
      );
      final s = (await snap(c)).activeAssignmentOf(who.personId)!.sessionId;
      final w = workerOf(c, who);
      await w.startMonitoring(sessionId: s);
      await w.endMonitoring(sessionId: s);
      await w.recordMeasurement(
        refusalRecord(
          id: id,
          workerId: who.personId,
          sessionId: s,
          dosebandId: band,
        ),
      );
    }

    await run(aditya, 'DB-2609-0010', 'M-ADITYA');
    await workerOf(c, nikhil).closeMissingFinalRead(sessionId: 'SES-SEED-02');
    await run(nikhil, 'DB-2609-0011', 'M-NIKHIL');
    return snap(c);
  }

  group('Worker', () {
    test('Worker A cannot read Worker B’s identified record', () async {
      final s = await withRecords();
      final me = WorkerView(s, aditya);
      expect(me.record('M-ADITYA').workerId, aditya.personId);
      expect(() => me.record('M-NIKHIL'), throwsA(isA<AccessDenied>()));
      expect(me.history().map((m) => m.workerId).toSet(), {
        aditya.personId,
      }, reason: 'history holds own records only');
    });

    test(
      'the refusal for someone else’s record and for a missing one match',
      () async {
        final s = await withRecords();
        final me = WorkerView(s, aditya);
        String message(String id) {
          try {
            me.record(id);
          } on AccessDenied catch (e) {
            return e.reason;
          }
          return '';
        }

        expect(message('M-NIKHIL'), message('DOES-NOT-EXIST'));
      },
    );

    test('a worker cannot act on another worker’s session', () async {
      final c = opsContainer();
      await expectLater(
        workerOf(c, aditya).endMonitoring(sessionId: 'SES-SEED-01'),
        throwsA(isA<AccessDenied>()),
      );
    });

    test('a forged role claim gets nothing', () async {
      final s = await withRecords();
      const forged = Actor(
        personId: PresentationDataset.aditya,
        role: AppRole.hseOfficer,
      );
      expect(() => HseView(s, forged), throwsA(isA<AccessDenied>()));
      expect(OperationsAccess(s, forged).identifiedWorkers(), isEmpty);
      const unknown = Actor(personId: 'X-1', role: AppRole.worker);
      expect(() => WorkerView(s, unknown), throwsA(isA<AccessDenied>()));
    });
  });

  group('Supervisor', () {
    test(
      'sees the explicit team, including a member from another department',
      () async {
        final s = await withRecords();
        final v = SupervisorView(s, aman);
        expect(v.teamIds, {
          PresentationDataset.aditya,
          PresentationDataset.lavitra,
          PresentationDataset.nikhil,
        });
        // Lavitra is in Operations; Aman in Maintenance. Team, not department.
        expect(
          v.worker(PresentationDataset.lavitra, fixedNow).person.departmentId,
          'operations',
        );
      },
    );

    test(
      'cannot reach a worker outside the team, even in the same department',
      () async {
        final base = await withRecords();
        // Nikhil moved to a team Aman does not supervise. Same department
        // (Maintenance) as Aman: that must not be enough.
        final s = base.copyWith(
          teams: [
            const Team(
              teamId: PresentationDataset.teamId,
              name: 'SRU maintenance crew A',
              siteId: PresentationDataset.siteId,
              departmentId: 'maintenance',
              supervisorId: PresentationDataset.aman,
              memberIds: [
                PresentationDataset.aditya,
                PresentationDataset.lavitra,
              ],
            ),
            const Team(
              teamId: 'team-other',
              name: 'Other crew',
              siteId: PresentationDataset.siteId,
              departmentId: 'maintenance',
              supervisorId: PresentationDataset.samhita,
              memberIds: [PresentationDataset.nikhil],
            ),
          ],
        );
        final v = SupervisorView(s, aman);
        expect(v.teamIds.contains(PresentationDataset.nikhil), isFalse);
        expect(
          () => v.worker(PresentationDataset.nikhil, fixedNow),
          throwsA(isA<AccessDenied>()),
        );
        expect(() => v.record('M-NIKHIL'), throwsA(isA<AccessDenied>()));
        expect(
          v.team(fixedNow, query: 'Nikhil'),
          isEmpty,
          reason: 'search cannot surface someone outside the team',
        );
      },
    );

    test('a team grant for someone else’s team gives nothing', () async {
      final base = await withRecords();
      final s = base.copyWith(
        teams: [
          for (final t in base.teams)
            Team(
              teamId: t.teamId,
              name: t.name,
              siteId: t.siteId,
              departmentId: t.departmentId,
              supervisorId: PresentationDataset.samhita,
              memberIds: t.memberIds,
            ),
        ],
      );
      expect(SupervisorView(s, aman).teamIds, isEmpty);
    });
  });

  group('HSE', () {
    test('reads identified records within the configured site scope', () async {
      final s = await withRecords();
      final v = HseView(s, samhita);
      expect(v.register().map((r) => r.record.id).toSet(), {
        'M-ADITYA',
        'M-NIKHIL',
      });
      expect(v.chain('M-ADITYA').person.personId, PresentationDataset.aditya);
    });

    test('a different site scope sees none of them', () async {
      final base = await withRecords();
      final s = base.copyWith(
        grants: [
          for (final g in base.grants)
            if (g.personId == PresentationDataset.samhita)
              ScopeGrant(
                personId: g.personId,
                role: g.role,
                scope: AccessScope.site,
                targetId: 'corporate-office',
              )
            else
              g,
        ],
      );
      final v = HseView(s, samhita);
      expect(v.register(), isEmpty);
      expect(() => v.chain('M-ADITYA'), throwsA(isA<AccessDenied>()));
    });

    test('review commands cannot edit the scientific result', () async {
      // HseCommands has no method taking a result; the record's result is
      // final. This asserts the invariant from the data side: after a review
      // round trip the record is the same object.
      final c = opsContainer();
      await registryOf(c)
          .claim(dosebandId: 'DB-2609-0010', workerId: aditya.personId);
      final sid = (await snap(c))
          .activeAssignmentOf(aditya.personId)!
          .sessionId;
      final w = workerOf(c, aditya);
      await w.startMonitoring(sessionId: sid);
      await w.endMonitoring(sessionId: sid);
      await w.recordMeasurement(
        refusalRecord(
          id: 'M-1',
          workerId: aditya.personId,
          sessionId: sid,
          dosebandId: 'DB-2609-0010',
        ),
      );
      final before = (await snap(c)).measurement('M-1');
      final hse = HseCommands(
        repository: c.read(operationsProvider.notifier),
        actor: samhita,
        ids: c.read(idGeneratorProvider),
        now: () => fixedNow,
      );
      await hse.moveReview(measurementId: 'M-1', to: ReviewState.inReview);
      expect(identical((await snap(c)).measurement('M-1'), before), isTrue);
    });
  });

  group('Management', () {
    test('cannot open any identified view', () async {
      final s = await withRecords();
      expect(
        () => WorkerView(s, yashviManagement),
        throwsA(isA<AccessDenied>()),
      );
      expect(
        () => SupervisorView(s, yashviManagement),
        throwsA(isA<AccessDenied>()),
      );
      expect(() => HseView(s, yashviManagement), throwsA(isA<AccessDenied>()));
      expect(
        OperationsAccess(s, yashviManagement).identifiedWorkers(),
        isEmpty,
      );
    });

    test('the overview is aggregate and suppresses small cells', () async {
      final s = await withRecords();
      final o = ManagementView(s, yashviManagement).overview(fixedNow);
      expect(o.expectedWorkers, 3);
      expect(
        o.byStatus.values.fold<int>(0, (a, b) => a + b),
        3,
        reason: 'each worker counted once',
      );
      // Two records in one area: below the small-cell threshold.
      final sru = o.workAreas.firstWhere((a) => a.workArea.contains('Sulphur'));
      expect(sru.completed.suppressed, isTrue);
      expect(sru.completed.display, '<3');
      expect(o.validatedExposureStatistics, isFalse);
    });
  });

  group('Administrator', () {
    test('does not receive occupational exposure access', () async {
      final s = await withRecords();
      expect(() => HseView(s, yashviAdmin), throwsA(isA<AccessDenied>()));
      expect(
        () => SupervisorView(s, yashviAdmin),
        throwsA(isA<AccessDenied>()),
      );
      expect(() => WorkerView(s, yashviAdmin), throwsA(isA<AccessDenied>()));
      expect(OperationsAccess(s, yashviAdmin).identifiedWorkers(), isEmpty);
      final policy = const DesignContractAccessPolicy();
      expect(
        policy.allows(
          AppRole.administrator,
          Permission.viewIdentifiedExposures,
        ),
        isFalse,
      );
    });

    test('sees inventory state but not who holds a band', () async {
      final s = await withRecords();
      final v = AdminView(s, yashviAdmin);
      final held = v
          .bands(fixedNow)
          .firstWhere((b) => b.band.dosebandId == 'DB-2609-0001');
      expect(held.band.lifecycle, DoseBandLifecycle.monitoring);
      // BandRow carries the band and its bucket only.
      expect(held.toString(), isNot(contains('Lavitra')));
    });

    test('lot counts are mutually exclusive and add up', () async {
      final s = await withRecords();
      for (final lot in AdminView(s, yashviAdmin).lots(fixedNow)) {
        expect(
          lot.total,
          s.bands.values.where((b) => b.lotId == lot.lot.lotId).length,
        );
      }
    });

    test('the audit view withholds who did occupational actions', () async {
      final s = await withRecords();
      final rows = AdminView(s, yashviAdmin).audit();
      final claims = rows.where((r) => r.action.name == 'dosebandClaimed');
      expect(claims, isNotEmpty);
      for (final r in claims) {
        expect(r.actor, contains('identity withheld'));
        for (final p in PresentationDataset.people) {
          expect(r.actor, isNot(contains(p.displayName)));
        }
      }
    });

    test('can suspend an account, which then gets nothing', () async {
      final c = opsContainer();
      await AdminCommands(
        repository: c.read(operationsProvider.notifier),
        actor: yashviAdmin,
        ids: c.read(idGeneratorProvider),
        now: () => fixedNow,
      ).setAccountActive(personId: PresentationDataset.aditya, active: false);
      final s = await snap(c);
      expect(() => WorkerView(s, aditya), throwsA(isA<AccessDenied>()));
    });
  });
}
