import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/corporate.dart';
import 'package:h2s_doseband/core/domain/connectivity.dart';
import 'package:h2s_doseband/core/domain/doseband.dart';
import 'package:h2s_doseband/core/domain/doseband_registry.dart';
import 'package:h2s_doseband/core/domain/monitoring_session.dart';
import 'package:h2s_doseband/core/domain/provenance.dart';
import 'package:h2s_doseband/core/domain/provenance_mapping.dart';
import 'package:h2s_doseband/features/auth/domain/access_policy.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/workflow/domain/enterprise_value.dart';
import 'package:h2s_doseband/features/workflow/domain/physical_badge.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:measurement/measurement.dart';

void main() {
  group('DoseBand lifecycle (§36)', () {
    test('the ordinary path is legal end to end', () {
      const path = [
        DoseBandLifecycle.available,
        DoseBandLifecycle.assigned,
        DoseBandLifecycle.monitoring,
        DoseBandLifecycle.readyForFinalRead,
        DoseBandLifecycle.read,
        DoseBandLifecycle.reviewed,
        DoseBandLifecycle.disposed,
      ];
      for (var i = 1; i < path.length; i++) {
        expect(
          DoseBandLifecyclePolicy.allows(path[i - 1], path[i]),
          isTrue,
          reason: '${path[i - 1].name} → ${path[i].name}',
        );
      }
    });

    test('a band is never reused: nothing leads back to available', () {
      for (final from in DoseBandLifecycle.values) {
        expect(
          DoseBandLifecyclePolicy.allows(from, DoseBandLifecycle.available),
          isFalse,
          reason: from.name,
        );
      }
    });

    test('monitoring cannot skip the final read', () {
      expect(
        DoseBandLifecyclePolicy.allows(
          DoseBandLifecycle.monitoring,
          DoseBandLifecycle.read,
        ),
        isFalse,
      );
      expect(
        DoseBandLifecyclePolicy.allows(
          DoseBandLifecycle.available,
          DoseBandLifecycle.monitoring,
        ),
        isFalse,
      );
    });

    test('disposed is the only terminal state and every state reaches it', () {
      final terminal = DoseBandLifecycle.values.where((s) => s.isTerminal);
      expect(terminal, [DoseBandLifecycle.disposed]);

      for (final start in DoseBandLifecycle.values) {
        final seen = <DoseBandLifecycle>{start};
        final queue = [start];
        while (queue.isNotEmpty) {
          for (final n in DoseBandLifecyclePolicy.nextFrom(
            queue.removeLast(),
          )) {
            if (seen.add(n)) queue.add(n);
          }
        }
        expect(
          seen,
          contains(DoseBandLifecycle.disposed),
          reason: '${start.name} cannot reach disposal',
        );
      }
    });

    test('an illegal transition is a typed refusal, not a throw', () {
      final t = DoseBandLifecyclePolicy.transition(
        DoseBandLifecycle.disposed,
        DoseBandLifecycle.assigned,
      );
      expect(t, isA<TransitionRefused<DoseBandLifecycle>>());
    });

    test('a lost band is never returned to service', () {
      expect(DoseBandLifecyclePolicy.nextFrom(DoseBandLifecycle.lost), {
        DoseBandLifecycle.disposed,
      });
    });

    test('lifecycle labels are qualified, never a bare "Complete"', () {
      for (final s in DoseBandLifecycle.values) {
        expect(s.label.toLowerCase(), isNot('complete'));
      }
    });

    test('bridges the existing identity without inventing data', () {
      final band = DoseBand.fromIdentity(
        PhysicalBadge(badgeId: 'DB-1', identifiedAt: DateTime.utc(2026)),
        lifecycle: DoseBandLifecycle.assigned,
      );
      expect(band.dosebandId, 'DB-1');
      expect(band.provenance, RecordProvenance.manualEntry);
      expect(band.lotId, isNull);
      expect(band.expiry, isNull);
      expect(band.calibrationApplicabilityId, isNull);
      expect(band.isSimulated, isFalse);

      expect(
        band.advanceTo(DoseBandLifecycle.monitoring)?.lifecycle,
        DoseBandLifecycle.monitoring,
      );
      expect(band.advanceTo(DoseBandLifecycle.available), isNull);
    });
  });

  group('monitoring session (§37)', () {
    test('the ordinary path is legal', () {
      const path = [
        MonitoringSessionState.notStarted,
        MonitoringSessionState.active,
        MonitoringSessionState.readyForFinalRead,
        MonitoringSessionState.readComplete,
        MonitoringSessionState.reviewed,
        MonitoringSessionState.closed,
      ];
      for (var i = 1; i < path.length; i++) {
        expect(MonitoringSessionPolicy.allows(path[i - 1], path[i]), isTrue);
      }
    });

    test('a session cannot be read before monitoring ends', () {
      expect(
        MonitoringSessionPolicy.allows(
          MonitoringSessionState.active,
          MonitoringSessionState.readComplete,
        ),
        isFalse,
      );
    });

    test('closed is terminal', () {
      expect(
        MonitoringSessionPolicy.nextFrom(MonitoringSessionState.closed),
        isEmpty,
      );
    });

    test('an unknown or backwards window is null, never zero', () {
      final start = DateTime.utc(2026, 9, 27, 8);
      MonitoringSession s(DateTime? end) => MonitoringSession(
        sessionId: 's',
        workerId: 'w',
        state: MonitoringSessionState.readComplete,
        provenance: RecordProvenance.realLocal,
        startedAt: start,
        endedAt: end,
      );
      expect(s(null).window, isNull);
      expect(s(start.subtract(const Duration(hours: 1))).window, isNull);
      expect(
        s(start.add(const Duration(hours: 8))).window,
        const Duration(hours: 8),
      );
    });

    test('every persisted stage maps onto the canonical lifecycles', () {
      for (final stage in ShiftStage.values) {
        expect(stage.sessionState, isA<MonitoringSessionState>());
      }
      expect(ShiftStage.monitoring.sessionState, MonitoringSessionState.active);
      expect(
        ShiftStage.awaitingScan.dosebandLifecycle,
        DoseBandLifecycle.readyForFinalRead,
      );
      expect(ShiftStage.noShift.dosebandLifecycle, isNull);
    });

    test('session and DoseBand labels never collide', () {
      final session = MonitoringSessionState.values.map((s) => s.label).toSet();
      final band = DoseBandLifecycle.values.map((s) => s.label).toSet();
      // Two concepts may share a *fact* (both say the final scan is missing)
      // but "complete" is never ambiguous between them.
      for (final label in session.intersection(band)) {
        expect(label.toLowerCase(), isNot(contains('complete')));
      }
    });
  });

  group('provenance (§21, §43)', () {
    test('simulated measurements can only map to simulated', () {
      expect(DataDomain.simulated.provenance, RecordProvenance.simulated);
      expect(RecordProvenance.simulated.mayCarryRealMeasurement, isFalse);
      expect(
        RecordProvenance.presentationSeeded.mayCarryRealMeasurement,
        isFalse,
      );
    });

    test('presentation data is never a real record', () {
      expect(DataOrigin.uiDemo.provenance, RecordProvenance.presentationSeeded);
      expect(
        EnterpriseDataSource.demo.provenance,
        RecordProvenance.presentationSeeded,
      );
    });

    test('manual entry is never mistaken for verification', () {
      expect(
        EnterpriseDataSource.manualEntry.provenance,
        RecordProvenance.manualEntry,
      );
      expect(
        BadgeIdentitySource.manualEntry.provenance,
        RecordProvenance.manualEntry,
      );
    });

    test('only simulated must be marked on the value itself', () {
      expect(RecordProvenance.values.where((p) => p.mustBeMarkedLocally), [
        RecordProvenance.simulated,
      ]);
    });

    test('nothing can produce synced or organisation-verified today', () {
      expect(
        RecordProvenance.producibleToday,
        isNot(contains(RecordProvenance.serverSynced)),
      );
      expect(
        RecordProvenance.producibleToday,
        isNot(contains(RecordProvenance.organizationIntegration)),
      );
    });
  });

  group('sync (§42)', () {
    test('no sync state that needs a server is producible today', () {
      expect(SyncState.producibleToday, {
        SyncState.localOnly,
        SyncState.notConnected,
      });
    });

    test('a sync failure never reads as a bad measurement', () {
      expect(
        SyncState.syncFailed.explanation,
        contains('reading is unaffected'),
      );
    });
  });

  group('roles, scopes and privacy (§39, §40)', () {
    const policy = DesignContractAccessPolicy();

    test('System Admin has no identified occupational access', () {
      expect(
        policy.scopeFor(
          AppRole.administrator,
          DataClass.identifiedOccupational,
        ),
        isNull,
      );
      expect(
        policy.allows(
          AppRole.administrator,
          Permission.viewIdentifiedExposures,
        ),
        isFalse,
      );
    });

    test('Management sees de-identified data only', () {
      expect(
        policy.scopeFor(AppRole.management, DataClass.identifiedOccupational),
        isNull,
      );
      expect(
        policy.scopeFor(AppRole.management, DataClass.deidentifiedExposure),
        AccessScope.organization,
      );
      expect(
        policy.allows(AppRole.management, Permission.viewTeamIdentities),
        isFalse,
      );
    });

    test('a worker sees only their own identified data', () {
      expect(
        policy.scopeFor(AppRole.worker, DataClass.identifiedOccupational),
        AccessScope.self,
      );
      expect(
        policy.allows(AppRole.worker, Permission.viewTeamMonitoring),
        isFalse,
      );
    });

    test('a supervisor is scoped to the team, not the organisation', () {
      expect(
        policy.scopeFor(AppRole.supervisor, DataClass.identifiedOccupational),
        AccessScope.team,
      );
    });

    test('only HSE reviews measurements', () {
      for (final role in AppRole.values) {
        expect(
          policy.allows(role, Permission.reviewMeasurements),
          role == AppRole.hseOfficer,
          reason: role.name,
        );
      }
    });

    test('every role is covered by the matrix', () {
      for (final role in AppRole.values) {
        expect(policy.allows(role, Permission.viewOwnProfile), isTrue);
      }
    });
  });

  group('DoseBand registry (§127)', () {
    test('the only registry today says it is not connected', () async {
      const r = NotConnectedDoseBandRegistry();
      final claim = await r.claim(dosebandId: 'DB-1', workerId: 'w');
      expect(claim, isA<ClaimAuthorityUnavailable>());
      expect(
        (claim as ClaimAuthorityUnavailable).reason,
        RegistryUnavailableReason.notConnected,
      );
      expect(await r.lookup('DB-1'), isA<DoseBandAuthorityUnavailable>());
    });
  });
}
