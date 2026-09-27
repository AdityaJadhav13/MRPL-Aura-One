import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/domain/doseband.dart';
import 'package:h2s_doseband/core/domain/monitoring_session.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/application/worker_service.dart';
import 'package:h2s_doseband/features/operations/data/operations_codec.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/operations/domain/assignment.dart';
import 'package:h2s_doseband/features/operations/domain/review.dart';

import 'operations_fixtures.dart';

/// PRODUCT BUILD v1 §13, §14, §26, §93, §118.
void main() {
  const band = 'DB-2609-0010';

  Future<String> claim(ProviderContainer c) async {
    await registryOf(c).claim(dosebandId: band, workerId: aditya.personId);
    return (await snap(c)).activeAssignmentOf(aditya.personId)!.sessionId;
  }

  test('start → end → record walks every axis forward together', () async {
    final c = opsContainer();
    final id = await claim(c);
    final w = workerOf(c, aditya);

    await w.startMonitoring(sessionId: id);
    var s = await snap(c);
    expect(s.session(id)!.state, MonitoringSessionState.active);
    expect(s.session(id)!.startedAt, fixedNow);
    expect(s.bands[band]!.lifecycle, DoseBandLifecycle.monitoring);

    await w.endMonitoring(sessionId: id);
    s = await snap(c);
    expect(s.session(id)!.state, MonitoringSessionState.readyForFinalRead);
    expect(s.bands[band]!.lifecycle, DoseBandLifecycle.readyForFinalRead);

    await w.recordMeasurement(
      refusalRecord(
        id: 'M-1',
        workerId: aditya.personId,
        sessionId: id,
        dosebandId: band,
      ),
    );
    s = await snap(c);
    // Five separate axes (§48): read / read complete / refusal / pending /
    // local only — none collapsed into "complete".
    expect(s.bands[band]!.lifecycle, DoseBandLifecycle.read);
    expect(s.session(id)!.state, MonitoringSessionState.readComplete);
    expect(s.measurement('M-1')!.result.status.isRefusal, isTrue);
    expect(s.reviewFor('M-1')!.state, ReviewState.pending);
    expect(s.session(id)!.syncState.name, 'localOnly');
    expect(s.activeAssignmentOf(aditya.personId), isNull);
  });

  test('monitoring survives a cold restart from the file store', () async {
    final dir = await Directory.systemTemp.createTemp('ops');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/ops.json');

    final first = opsContainer(store: FileOperationsStore(file), seed: null);
    final id = await claim(first);
    await workerOf(first, aditya).startMonitoring(sessionId: id);
    first.dispose();

    // A new process: nothing in memory, only the file.
    final second = opsContainer(store: FileOperationsStore(file));
    final s = await snap(second);
    expect(s.session(id)!.state, MonitoringSessionState.active);
    expect(s.session(id)!.startedAt, fixedNow);
    expect(s.bands[band]!.lifecycle, DoseBandLifecycle.monitoring);
  });

  test('an unreadable store file is set aside, never overwritten', () async {
    final dir = await Directory.systemTemp.createTemp('ops');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/ops.json')..writeAsStringSync('{"schema":');
    final c = opsContainer(store: FileOperationsStore(file));
    await snap(c);
    final kept = dir.listSync().where((f) => f.path.contains('unreadable'));
    expect(kept, hasLength(1), reason: 'the damaged file is kept for recovery');
  });

  test('a second record for the same period is refused', () async {
    final c = opsContainer();
    final id = await claim(c);
    final w = workerOf(c, aditya);
    await w.startMonitoring(sessionId: id);
    await w.endMonitoring(sessionId: id);
    final r = refusalRecord(
      id: 'M-1',
      workerId: aditya.personId,
      sessionId: id,
      dosebandId: band,
    );
    await w.recordMeasurement(r);
    await expectLater(
      w.recordMeasurement(
        refusalRecord(
          id: 'M-2',
          workerId: aditya.personId,
          sessionId: id,
          dosebandId: band,
        ),
      ),
      throwsA(isA<OperationRefused>()),
    );
    // Retrying the same write is harmless.
    await w.recordMeasurement(r);
    expect((await snap(c)).measurements, hasLength(1));
  });

  test('a re-read supersedes explicitly and keeps the original', () async {
    final c = opsContainer();
    final id = await claim(c);
    final w = workerOf(c, aditya);
    await w.startMonitoring(sessionId: id);
    await w.endMonitoring(sessionId: id);
    await w.recordMeasurement(
      refusalRecord(
        id: 'M-1',
        workerId: aditya.personId,
        sessionId: id,
        dosebandId: band,
      ),
    );
    await w.recordMeasurement(
      refusalRecord(
        id: 'M-2',
        workerId: aditya.personId,
        sessionId: id,
        dosebandId: band,
        supersedesId: 'M-1',
        supersessionReason: 'Re-read after a reference-patch failure',
      ),
    );
    final s = await snap(c);
    expect(s.measurements.map((m) => m.id), ['M-1', 'M-2']);
    expect(s.supersededBy('M-1')!.id, 'M-2');
    expect(s.session(id)!.measurementId, 'M-2');
    expect(
      identical(s.measurement('M-1')!.result, s.measurements.first.result),
      isTrue,
      reason: 'the original evidence is untouched',
    );
  });

  test('double start and double end are harmless', () async {
    final c = opsContainer();
    final id = await claim(c);
    final w = workerOf(c, aditya);
    await w.startMonitoring(sessionId: id);
    await w.startMonitoring(sessionId: id);
    await w.endMonitoring(sessionId: id);
    await w.endMonitoring(sessionId: id);
    expect(
      (await snap(c)).session(id)!.state,
      MonitoringSessionState.readyForFinalRead,
    );
  });

  test('a record cannot be made before the period has ended', () async {
    final c = opsContainer();
    final id = await claim(c);
    final w = workerOf(c, aditya);
    await w.startMonitoring(sessionId: id);
    await expectLater(
      w.recordMeasurement(
        refusalRecord(
          id: 'M-1',
          workerId: aditya.personId,
          sessionId: id,
          dosebandId: band,
        ),
      ),
      throwsA(isA<OperationRefused>()),
    );
  });

  test(
    'cancelling before start retires the band and closes the session',
    () async {
      final c = opsContainer();
      final id = await claim(c);
      await workerOf(
        c,
        aditya,
      ).cancelAssignment(sessionId: id, reason: 'Wrong DoseBand picked up');
      final s = await snap(c);
      expect(s.session(id)!.state, MonitoringSessionState.closed);
      expect(s.bands[band]!.lifecycle, DoseBandLifecycle.assignmentCancelled);
      expect(s.activeAssignmentOf(aditya.personId), isNull);
    },
  );

  test('a lost band interrupts the period and frees the worker', () async {
    final c = opsContainer();
    final id = await claim(c);
    final w = workerOf(c, aditya);
    await w.startMonitoring(sessionId: id);
    await w.reportDoseBand(sessionId: id, condition: DoseBandLifecycle.lost);
    var s = await snap(c);
    expect(s.session(id)!.state, MonitoringSessionState.interrupted);
    expect(s.bands[band]!.lifecycle, DoseBandLifecycle.lost);
    expect(s.activeAssignmentOf(aditya.personId), isNull);

    // A replacement is a new claim and a new period; the old one stays.
    await registryOf(c)
        .claim(dosebandId: 'DB-2609-0011', workerId: aditya.personId);
    s = await snap(c);
    expect(s.sessionsOf(aditya.personId), hasLength(2));
  });

  test('an overdue final read is closed as missing, not as zero', () async {
    final c = opsContainer();
    await workerOf(c, nikhil).closeMissingFinalRead(sessionId: 'SES-SEED-02');
    final s = await snap(c);
    final x = s.session('SES-SEED-02')!;
    expect(x.state, MonitoringSessionState.finalReadMissing);
    expect(x.measurementId, isNull, reason: 'no record is invented');
    expect(
      s.bands['DB-2609-0002']!.lifecycle,
      DoseBandLifecycle.missingFinalRead,
    );
    expect(s.assignment('ASG-SEED-02')!.state, AssignmentState.completed);
  });

  test('a backwards clock gives no window, never a zero-length one', () {
    final x = MonitoringSession(
      sessionId: 's',
      workerId: 'w',
      state: MonitoringSessionState.readyForFinalRead,
      provenance: PresentationDataset.people.first.provenance,
      startedAt: fixedNow,
      endedAt: fixedNow.subtract(const Duration(minutes: 1)),
    );
    expect(x.window, isNull);
  });

  test('the full store round-trips through its codec', () async {
    final c = opsContainer();
    final id = await claim(c);
    final w = workerOf(c, aditya);
    await w.startMonitoring(sessionId: id);
    await w.endMonitoring(sessionId: id);
    await w.recordMeasurement(
      refusalRecord(
        id: 'M-1',
        workerId: aditya.personId,
        sessionId: id,
        dosebandId: band,
      ),
    );
    final s = await snap(c);
    final encoded = OperationsCodec.encode(s);
    final decoded = OperationsCodec.decode(encoded)!;
    expect(OperationsCodec.encode(decoded), encoded);
    expect(
      decoded.measurement('M-1')!.result.status,
      s.measurement('M-1')!.result.status,
    );
  });

  test('a store that cannot be decoded faithfully decodes to nothing', () {
    final encoded = OperationsCodec.encode(PresentationDataset.build(fixedNow));
    final broken = {
      ...encoded,
      'people': [
        {'id': 'x'},
      ],
    };
    expect(OperationsCodec.decode(broken), isNull);
    expect(OperationsCodec.decode({...encoded, 'schema': 99}), isNull);
  });

  test('ids from the generator are unique', () {
    final g = RandomIdGenerator(now: () => fixedNow);
    final ids = {for (var i = 0; i < 500; i++) g.next('X')};
    expect(ids, hasLength(500));
  });
}
