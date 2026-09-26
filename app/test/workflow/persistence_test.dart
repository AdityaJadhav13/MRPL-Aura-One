import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/util/async_value_x.dart';
import 'package:h2s_doseband/core/util/format.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/file_workflow_store.dart';
import 'package:h2s_doseband/features/workflow/data/session_codec.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/badge_specimen.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';
import 'package:measurement/measurement.dart';

BadgeSpecimen _byLabel(String label) =>
    SimulationCatalog.specimens().firstWhere((s) => s.label == label);

/// Runs the workflow forward to [stage] against [store], returning the session.
Future<ShiftSession> _runTo(
  ShiftStage stage,
  WorkflowStore store, {
  String specimen = 'Valid — mid response',
}) async {
  final container = ProviderContainer(
    overrides: [workflowStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);

  final n = container.read(shiftSessionProvider.notifier);
  await container.read(shiftSessionProvider.future);

  if (stage.index >= ShiftStage.contextSet.index) {
    await n.setContext(SimulationCatalog.demoContext());
  }
  if (stage.index >= ShiftStage.badgeAssigned.index) {
    await n.assignBadge(_byLabel(specimen));
  }
  if (stage.index >= ShiftStage.readyForDosimetry.index) {
    await n.confirmPreWork();
  }
  if (stage.index >= ShiftStage.monitoring.index) {
    await n.startMonitoring();
  }
  if (stage.index >= ShiftStage.awaitingScan.index) {
    await n.endMonitoring();
  }
  if (stage == ShiftStage.complete) {
    await n.completeScan();
  }

  await container.read(shiftSessionProvider.future);
  return container.read(shiftSessionProvider).dataOrNull ?? ShiftSession.none;
}

void main() {
  group('the session survives a cold start', () {
    late Directory dir;
    late FileWorkflowStore store;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('doseband_session_test');
      store = FileWorkflowStore(
        File('${dir.path}/${FileWorkflowStore.fileName}'),
      );
    });

    tearDown(() => dir.deleteSync(recursive: true));

    for (final stage in ShiftStage.values) {
      test('a session at ${stage.name} is restored exactly', () async {
        final saved = await _runTo(stage, store);
        expect(saved.stage, stage);

        // A second store over the same file is what the next launch sees.
        final reopened = await FileWorkflowStore(store.file).load();

        expect(reopened.stage, saved.stage);
        expect(reopened.badge?.badgeId, saved.badge?.badgeId);
        expect(
          reopened.context?.permit.reference,
          saved.context?.permit.reference,
        );
        expect(reopened.context?.worker, saved.context?.worker);
        expect(reopened.context?.workArea, saved.context?.workArea);
        expect(reopened.context?.toolboxTalk, saved.context?.toolboxTalk);
        expect(reopened.startedAt, saved.startedAt);
        expect(reopened.endedAt, saved.endedAt);
        expect(reopened.result?.status, saved.result?.status);
      });
    }

    test('every declared outcome round-trips through storage', () async {
      for (final specimen in SimulationCatalog.specimens()) {
        final fresh = FileWorkflowStore(
          File('${dir.path}/${specimen.badgeId}.json'),
        );
        final saved = await _runTo(
          ShiftStage.complete,
          fresh,
          specimen: specimen.label,
        );
        final result = saved.result;
        expect(result, isNotNull, reason: specimen.label);

        final reopened = await FileWorkflowStore(fresh.file).load();
        final restored = reopened.result;

        expect(restored, isNotNull, reason: specimen.label);
        expect(restored!.status, result!.status, reason: specimen.label);
        expect(
          restored.reasons.map((r) => r.code),
          result.reasons.map((r) => r.code),
          reason: specimen.label,
        );
        expect(
          restored.provenance.calibrationModelId,
          result.provenance.calibrationModelId,
          reason: specimen.label,
        );
        if (result is Valid) {
          restored as Valid;
          expect(restored.dose.value, result.dose.value);
          expect(restored.coverage, result.coverage);
          expect(restored.uncertainty.basis, result.uncertainty.basis);
        }
        if (result is Censored) {
          restored as Censored;
          expect(restored.direction, result.direction);
          expect(restored.bound?.value, result.bound?.value);
        }
      }
    });

    test('no snapshot yet is not an error', () async {
      expect(store.file.existsSync(), isFalse);
      expect((await store.load()).stage, ShiftStage.noShift);
    });

    test('clearing removes the snapshot from disk', () async {
      await _runTo(ShiftStage.monitoring, store);
      expect(store.file.existsSync(), isTrue);

      await store.clear();

      expect(store.file.existsSync(), isFalse);
      expect((await store.load()).stage, ShiftStage.noShift);
    });

    test('a save leaves no temporary file behind', () async {
      await _runTo(ShiftStage.monitoring, store);
      final leftovers = dir
          .listSync()
          .where((e) => e.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });

    test('a half-written snapshot is discarded, not repaired', () async {
      await _runTo(ShiftStage.monitoring, store);
      final whole = store.file.readAsStringSync();
      store.file.writeAsStringSync(whole.substring(0, whole.length ~/ 2));

      expect((await store.load()).stage, ShiftStage.noShift);
    });

    test('a snapshot from another schema is discarded', () async {
      await _runTo(ShiftStage.monitoring, store);
      final raw =
          jsonDecode(store.file.readAsStringSync()) as Map<String, Object?>;
      raw['schema'] = SessionCodec.schema + 1;
      store.file.writeAsStringSync(jsonEncode(raw));

      expect((await store.load()).stage, ShiftStage.noShift);
    });

    test('a snapshot naming a badge the catalogue no longer offers is '
        'discarded rather than restored without one', () async {
      await _runTo(ShiftStage.monitoring, store);
      final raw =
          jsonDecode(store.file.readAsStringSync()) as Map<String, Object?>;
      raw['badge_id'] = 'DB-NOT-A-BADGE';
      store.file.writeAsStringSync(jsonEncode(raw));

      final restored = await store.load();
      expect(restored.stage, ShiftStage.noShift);
      expect(restored.badge, isNull);
    });
  });

  group('a snapshot the workflow could not have written is refused', () {
    Map<String, Object?> encodedAt(ShiftStage stage) {
      final now = DateTime(2026, 9, 24, 6, 10);
      return SessionCodec.encode(
        ShiftSession(
          stage: stage,
          context: SimulationCatalog.demoContext(),
          badge: _byLabel('Valid — mid response'),
          startedAt: stage.index >= ShiftStage.monitoring.index ? now : null,
          endedAt: stage.index >= ShiftStage.awaitingScan.index
              ? now.add(const Duration(hours: 7))
              : null,
        ),
      );
    }

    test('monitoring without a start time', () {
      final raw = encodedAt(ShiftStage.monitoring)..['started_at'] = null;
      expect(SessionCodec.decode(raw), isNull);
    });

    test('a badge assigned without a work context', () {
      final raw = encodedAt(ShiftStage.badgeAssigned)..['context'] = null;
      expect(SessionCodec.decode(raw), isNull);
    });

    test('monitoring without a badge', () {
      final raw = encodedAt(ShiftStage.monitoring)..['badge_id'] = null;
      expect(SessionCodec.decode(raw), isNull);
    });

    test('complete without a result', () {
      final raw = encodedAt(ShiftStage.awaitingScan)
        ..['stage'] = ShiftStage.complete.name;
      expect(SessionCodec.decode(raw), isNull);
    });

    test('a stage carrying evidence of a later one', () {
      // contextSet cannot have a start time; that belongs to monitoring.
      final raw = encodedAt(ShiftStage.contextSet)
        ..['started_at'] = DateTime(2026, 9, 24).toIso8601String();
      expect(SessionCodec.decode(raw), isNull);
    });

    test('an unparseable timestamp', () {
      final raw = encodedAt(ShiftStage.monitoring)
        ..['started_at'] = 'yesterday';
      expect(SessionCodec.decode(raw), isNull);
    });

    test('an unknown stage', () {
      final raw = encodedAt(ShiftStage.monitoring)..['stage'] = 'loitering';
      expect(SessionCodec.decode(raw), isNull);
    });

    test('anything that is not a map', () {
      expect(SessionCodec.decode('a string'), isNull);
      expect(SessionCodec.decode(null), isNull);
      expect(SessionCodec.decode(<Object?>[]), isNull);
    });
  });

  group('a stored dose must still prove it came from a calibration', () {
    Future<Map<String, Object?>> completedSnapshot() async {
      final store = InMemoryWorkflowStore();
      final session = await _runTo(ShiftStage.complete, store);
      return SessionCodec.encode(session);
    }

    test('a stored Valid without a calibration model is refused', () async {
      final raw = await completedSnapshot();
      final result = raw['result']! as Map<String, Object?>;
      (result['provenance']! as Map<String, Object?>)['calibration_model_id'] =
          null;

      expect(SessionCodec.decode(raw), isNull);
    });

    test('a stored dose under a refusal status is refused', () async {
      final raw = await completedSnapshot();
      final result = raw['result']! as Map<String, Object?>;
      result['status'] = ResultStatus.poorImage.name;

      expect(SessionCodec.decode(raw), isNull);
    });

    test('a negative stored coverage is refused', () async {
      final raw = await completedSnapshot();
      final result = raw['result']! as Map<String, Object?>;
      result['coverage_microseconds'] = -60;

      expect(SessionCodec.decode(raw), isNull);
    });
  });

  group('an exposure window that cannot be established is refused, not zeroed', () {
    final start = DateTime(2026, 9, 24, 6, 10);

    test('coverage is null when the window runs backwards', () {
      final session = ShiftSession(
        stage: ShiftStage.monitoring,
        startedAt: start,
      );
      // The device clock has been moved back an hour since monitoring began.
      expect(
        session.coverageAt(start.subtract(const Duration(hours: 1))),
        isNull,
      );
    });

    test('coverage is null before monitoring has started', () {
      expect(const ShiftSession().coverageAt(start), isNull);
    });

    test('a window that has only just opened is zero, not unknown', () {
      final session = ShiftSession(
        stage: ShiftStage.monitoring,
        startedAt: start,
      );
      expect(session.coverageAt(start), Duration.zero);
    });

    test('an unknown window prints as a refusal, not as 0 min', () {
      expect(Fmt.duration(null), Fmt.noValue);
      expect(Fmt.duration(Duration.zero), '0 min');
      expect(Fmt.duration(const Duration(hours: 7, minutes: 52)), '7 h 52 min');
    });

    test('a scan over an untrustworthy window refuses instead of reporting '
        'the specimen dose', () async {
      // A session restored after the clock moved backwards: the period ended,
      // by the wall clock, before it began.
      final store = InMemoryWorkflowStore();
      await store.save(
        ShiftSession(
          stage: ShiftStage.awaitingScan,
          context: SimulationCatalog.demoContext(),
          badge: _byLabel('Valid — mid response'),
          startedAt: start,
          endedAt: start.subtract(const Duration(hours: 1)),
        ),
      );

      final container = ProviderContainer(
        overrides: [workflowStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      await container.read(shiftSessionProvider.future);

      final result = await container
          .read(shiftSessionProvider.notifier)
          .completeScan();

      expect(result, isA<Refused>());
      expect(result.status, ResultStatus.resultUnreliable);
      expect(result.status.carriesDose, isFalse);
      expect(
        result.reasons.map((r) => r.code),
        contains('EXPOSURE_WINDOW_UNTRUSTED'),
      );
      // The refusal must not smuggle a calibration model in, which would imply
      // a dose had been computed.
      expect(result.provenance.calibrationModelId, isNull);
    });

    test('the same specimen over a trustworthy window still reports its '
        'dose', () async {
      final session = await _runTo(
        ShiftStage.complete,
        InMemoryWorkflowStore(),
      );
      expect(session.result, isA<Valid>());
    });
  });
}
