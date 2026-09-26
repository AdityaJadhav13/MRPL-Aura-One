import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/file_workflow_store.dart';
import 'package:h2s_doseband/features/workflow/data/session_codec.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/domain/badge_specimen.dart';
import 'package:h2s_doseband/features/workflow/domain/enterprise_value.dart';
import 'package:h2s_doseband/features/workflow/domain/permit_context.dart';
import 'package:h2s_doseband/features/workflow/domain/work_context.dart';
import 'package:h2s_doseband/features/workflow/domain/worker_identity.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';

BadgeSpecimen _badge() => SimulationCatalog.specimens().first;

/// The encoded form of a session that has reached [stage] with a full context.
Map<String, Object?> _snapshot(
  ShiftStage stage, {
  WorkerType workerType = WorkerType.employee,
  String siteId = 'mangalore-refinery',
}) {
  final now = DateTime(2026, 9, 25, 6, 10);
  return SessionCodec.encode(
    ShiftSession(
      stage: stage,
      context: SimulationCatalog.demoContext(
        workerType: workerType,
        siteId: siteId,
      ),
      badge: _badge(),
      startedAt: stage.index >= ShiftStage.monitoring.index ? now : null,
      endedAt: stage.index >= ShiftStage.awaitingScan.index
          ? now.add(const Duration(hours: 7))
          : null,
    ),
  );
}

/// Applies [mutate] to the encoded context and returns the whole snapshot.
Map<String, Object?> _mutatedContext(
  void Function(Map<String, Object?> context) mutate, {
  ShiftStage stage = ShiftStage.monitoring,
}) {
  final raw = _snapshot(stage);
  mutate(raw['context']! as Map<String, Object?>);
  return raw;
}

void main() {
  group('a full work context survives storage', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('doseband_ctx_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<ShiftSession> roundTrip(ShiftSession session, String name) async {
      final store = FileWorkflowStore(File('${dir.path}/$name.json'));
      await store.save(session);
      return FileWorkflowStore(store.file).load();
    }

    for (final stage in ShiftStage.values.where(
      (s) => s.index >= ShiftStage.contextSet.index,
    )) {
      test('every field is restored at ${stage.name}', () async {
        final now = DateTime(2026, 9, 25, 6, 10);
        final original = ShiftSession(
          stage: stage,
          context: SimulationCatalog.demoContext(),
          badge: _badge(),
          startedAt: stage.index >= ShiftStage.monitoring.index ? now : null,
          endedAt: stage.index >= ShiftStage.awaitingScan.index
              ? now.add(const Duration(hours: 7))
              : null,
          result: stage == ShiftStage.complete
              ? null // completeScan writes this; not needed for context checks
              : null,
        );
        // `complete` requires a result, which this fixture does not build.
        if (stage == ShiftStage.complete) return;

        final restored = await roundTrip(original, stage.name);
        final a = original.context!;
        final b = restored.context;

        expect(b, isNotNull, reason: stage.name);
        expect(b!.worker, a.worker);
        expect(b.site, a.site);
        expect(b.department, a.department);
        expect(b.workArea, a.workArea);
        expect(b.shift, a.shift);
        expect(b.job, a.job);
        expect(b.permit, a.permit);
        expect(b.jsa, a.jsa);
        expect(b.toolboxTalk, a.toolboxTalk);
        // Equality across the whole object, so a field added later that nobody
        // remembers to encode fails here.
        expect(b, a);
      });
    }

    test('a contractor identity and company survive', () async {
      final session = ShiftSession(
        stage: ShiftStage.badgeAssigned,
        context: SimulationCatalog.demoContext(
          workerType: WorkerType.contractor,
        ),
        badge: _badge(),
      );
      final restored = await roundTrip(session, 'contractor');
      final worker = restored.context!.worker;

      expect(worker.workerType, WorkerType.contractor);
      expect(worker.contractorCompany, isNotNull);
      expect(worker, session.context!.worker);
    });

    test('every configured site survives', () async {
      for (final siteId in [
        'mangalore-refinery',
        'corporate-office',
        'retail-hiq',
        'projects-site',
      ]) {
        final session = ShiftSession(
          stage: ShiftStage.badgeAssigned,
          context: SimulationCatalog.demoContext(siteId: siteId),
          badge: _badge(),
        );
        final restored = await roundTrip(session, siteId);
        expect(restored.context?.site.id, siteId, reason: siteId);
        expect(restored.context?.workArea.siteId, siteId, reason: siteId);
      }
    });

    test('the toolbox acknowledgement keeps its exact timestamp', () async {
      final at = DateTime(2026, 9, 25, 5, 47, 13, 256, 991);
      final demo = SimulationCatalog.demoContext();
      final session = ShiftSession(
        stage: ShiftStage.badgeAssigned,
        context: WorkContext(
          worker: demo.worker,
          site: demo.site,
          department: demo.department,
          workArea: demo.workArea,
          shift: demo.shift,
          job: demo.job,
          permit: demo.permit,
          jsa: demo.jsa,
          toolboxTalk: ToolboxTalkAcknowledgement(
            acknowledgedAt: at,
            source: EnterpriseDataSource.manualEntry,
            reference: 'TBT-77',
          ),
        ),
        badge: _badge(),
      );
      final restored = await roundTrip(session, 'toolbox');

      expect(restored.context!.toolboxTalk.acknowledgedAt, at);
      expect(restored.context!.toolboxTalk.reference, 'TBT-77');
      expect(
        restored.context!.toolboxTalk.source,
        EnterpriseDataSource.manualEntry,
      );
    });

    test('a manual reference does not come back verified', () async {
      final demo = SimulationCatalog.demoContext();
      final session = ShiftSession(
        stage: ShiftStage.badgeAssigned,
        context: WorkContext(
          worker: demo.worker,
          site: demo.site,
          department: demo.department,
          workArea: demo.workArea,
          shift: demo.shift,
          job: demo.job,
          permit: const PtwReference(
            reference: EnterpriseValue<String>.manual('PTW-24-11873'),
          ),
          jsa: const JsaReference(
            reference: EnterpriseValue<String>.manual('JSA-2048'),
          ),
          toolboxTalk: demo.toolboxTalk,
        ),
        badge: _badge(),
      );
      final restored = await roundTrip(session, 'manual');

      expect(
        restored.context!.permit.reference.source,
        EnterpriseDataSource.manualEntry,
      );
      expect(restored.context!.permit.isVerified, isFalse);
      expect(restored.context!.jsa.isVerified, isFalse);
    });

    test('a session saved under schema 1 is discarded, not migrated', () async {
      final store = FileWorkflowStore(File('${dir.path}/old.json'));
      await store.save(
        ShiftSession(
          stage: ShiftStage.monitoring,
          context: SimulationCatalog.demoContext(),
          badge: _badge(),
          startedAt: DateTime(2026, 9, 25, 6),
        ),
      );
      final raw =
          jsonDecode(store.file.readAsStringSync()) as Map<String, Object?>;
      raw['schema'] = 1;
      store.file.writeAsStringSync(jsonEncode(raw));

      expect((await store.load()).stage, ShiftStage.noShift);
    });
  });

  group('a context that cannot be rebuilt faithfully is refused', () {
    test('the fixture itself decodes, so the negatives mean something', () {
      expect(SessionCodec.decode(_snapshot(ShiftStage.monitoring)), isNotNull);
    });

    test('monitoring with no worker', () {
      expect(
        SessionCodec.decode(_mutatedContext((c) => c['worker'] = null)),
        isNull,
      );
    });

    test('monitoring with no site', () {
      expect(
        SessionCodec.decode(_mutatedContext((c) => c['site'] = null)),
        isNull,
      );
    });

    test('a site missing its name', () {
      expect(
        SessionCodec.decode(
          _mutatedContext(
            (c) => c['site'] = <String, Object?>{'id': 'mangalore-refinery'},
          ),
        ),
        isNull,
      );
    });

    test('monitoring with no badge', () {
      final raw = _snapshot(ShiftStage.monitoring)..['badge_id'] = null;
      expect(SessionCodec.decode(raw), isNull);
    });

    test('an unknown work area', () {
      expect(
        SessionCodec.decode(
          _mutatedContext((c) => c['work_area_id'] = 'not-an-area'),
        ),
        isNull,
      );
    });

    test('a work area belonging to a different site', () {
      // Well-formed, resolvable, and wrong: restoring it would move the record.
      expect(
        SessionCodec.decode(
          _mutatedContext((c) => c['work_area_id'] = 'office-block'),
        ),
        isNull,
      );
    });

    test('an unknown department', () {
      expect(
        SessionCodec.decode(
          _mutatedContext((c) => c['department_id'] = 'not-a-department'),
        ),
        isNull,
      );
    });

    test('an unknown shift', () {
      expect(
        SessionCodec.decode(
          _mutatedContext((c) => c['shift_id'] = 'not-a-shift'),
        ),
        isNull,
      );
    });

    test('an unknown permit type', () {
      expect(
        SessionCodec.decode(
          _mutatedContext(
            (c) => (c['permit']! as Map<String, Object?>)['type_id'] =
                'not-a-type',
          ),
        ),
        isNull,
      );
    });

    test('an unknown worker type', () {
      expect(
        SessionCodec.decode(
          _mutatedContext(
            (c) =>
                (c['worker']! as Map<String, Object?>)['worker_type'] = 'ghost',
          ),
        ),
        isNull,
      );
    });

    test('a contractor with no company', () {
      expect(
        SessionCodec.decode(
          _mutatedContext((c) {
            final w = c['worker']! as Map<String, Object?>;
            w['worker_type'] = WorkerType.contractor.name;
            w['contractor_company'] = null;
          }),
        ),
        isNull,
      );
    });

    test('an employee carrying a contractor company', () {
      expect(
        SessionCodec.decode(
          _mutatedContext(
            (c) =>
                (c['worker']! as Map<String, Object?>)['contractor_company'] =
                    'Someone Ltd',
          ),
        ),
        isNull,
      );
    });

    test('a job with no title', () {
      expect(
        SessionCodec.decode(
          _mutatedContext(
            (c) => (c['job']! as Map<String, Object?>)['title'] = null,
          ),
        ),
        isNull,
      );
    });

    test('a toolbox acknowledgement with an invalid timestamp', () {
      expect(
        SessionCodec.decode(
          _mutatedContext(
            (c) =>
                (c['toolbox_talk']!
                        as Map<String, Object?>)['acknowledged_at'] =
                    'this morning',
          ),
        ),
        isNull,
      );
    });

    test('a missing toolbox acknowledgement', () {
      expect(
        SessionCodec.decode(_mutatedContext((c) => c['toolbox_talk'] = null)),
        isNull,
      );
    });
  });

  group('provenance cannot be laundered through storage', () {
    Map<String, Object?> permitProvenance(
      void Function(Map<String, Object?>) mutate,
    ) => _mutatedContext((c) {
      final permit = c['permit']! as Map<String, Object?>;
      mutate(permit['reference']! as Map<String, Object?>);
    });

    test('"verified" without the system that verified it is refused', () {
      // The attack this blocks: edit one word in the file and a typed-in
      // permit number comes back looking like MRPL confirmed it.
      expect(
        SessionCodec.decode(
          permitProvenance(
            (r) =>
                r['source'] = EnterpriseDataSource.organizationIntegration.name,
          ),
        ),
        isNull,
      );
    });

    test('"verified" with a system but no timestamp is refused', () {
      expect(
        SessionCodec.decode(
          permitProvenance((r) {
            r['source'] = EnterpriseDataSource.organizationIntegration.name;
            r['external_system'] = 'ptw-system';
            r['external_reference'] = 'ext-1';
          }),
        ),
        isNull,
      );
    });

    test('a manual value carrying verification fields is refused', () {
      // The domain cannot construct this, so its presence means the record was
      // edited or corrupted. Accepting it would silently discard the fields.
      expect(
        SessionCodec.decode(
          permitProvenance((r) {
            r['external_system'] = 'ptw-system';
            r['external_reference'] = 'ext-1';
            r['verified_at'] = DateTime(2026, 9, 25).toIso8601String();
          }),
        ),
        isNull,
      );
    });

    test('an unknown provenance source is refused', () {
      expect(
        SessionCodec.decode(permitProvenance((r) => r['source'] = 'trustMe')),
        isNull,
      );
    });

    test('a reference with no value is refused', () {
      expect(
        SessionCodec.decode(permitProvenance((r) => r['value'] = null)),
        isNull,
      );
    });

    test('a fully formed verified value does round-trip', () {
      // The positive case, so the refusals above are known to be about
      // *malformed* provenance rather than the codec rejecting verification
      // outright. Nothing in the app can produce this today.
      final decoded = SessionCodec.decode(
        permitProvenance((r) {
          r['source'] = EnterpriseDataSource.organizationIntegration.name;
          r['external_system'] = 'ptw-system';
          r['external_reference'] = 'ext-1';
          r['verified_at'] = DateTime(2026, 9, 25, 6).toIso8601String();
        }),
      );
      expect(decoded, isNotNull);
      expect(decoded!.context!.permit.isVerified, isTrue);
      expect(decoded.context!.permit.reference.externalSystem, 'ptw-system');
    });

    test('a gate pass keeps its provenance', () async {
      final dir = Directory.systemTemp.createTempSync('doseband_gp');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = FileWorkflowStore(File('${dir.path}/s.json'));
      await store.save(
        ShiftSession(
          stage: ShiftStage.badgeAssigned,
          context: SimulationCatalog.demoContext(),
          badge: _badge(),
        ),
      );
      final restored = await store.load();
      final gatePass = restored.context!.worker.gatePass;

      expect(gatePass, isNotNull);
      expect(gatePass!.source, EnterpriseDataSource.demo);
      expect(gatePass.isVerified, isFalse);
    });
  });

  group('a restored context still drives the workflow', () {
    test('a restored monitoring session is locked', () async {
      final dir = Directory.systemTemp.createTempSync('doseband_lock');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = FileWorkflowStore(File('${dir.path}/s.json'));
      await store.save(
        ShiftSession(
          stage: ShiftStage.monitoring,
          context: SimulationCatalog.demoContext(),
          badge: _badge(),
          startedAt: DateTime(2026, 9, 25, 6),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          workflowStoreProvider.overrideWithValue(
            FileWorkflowStore(store.file),
          ),
        ],
      );
      addTearDown(container.dispose);

      final session = await container.read(shiftSessionProvider.future);
      expect(session.contextIsLocked, isTrue);
      expect(
        () => container
            .read(shiftSessionProvider.notifier)
            .setContext(
              SimulationCatalog.demoContext(siteId: 'corporate-office'),
            ),
        throwsA(isA<WorkflowLockedError>()),
      );
    });
  });
}
