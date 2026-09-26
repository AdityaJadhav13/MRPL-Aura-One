import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/capture/data/capture_archive.dart';
import 'package:measurement/measurement.dart';

CaptureRecord _record(String id, {String? deliberateFailure}) => CaptureRecord(
  captureId: id,
  dataDomain: DataDomain.lab,
  geometryVersion: 'badge-v1-research',
  featureDefinitionVersion: featureDefinitionVersion,
  algorithmVersion: algorithmVersion,
  conditions: CaptureConditions(
    illuminationClass: 'warm-led',
    approximateDistanceMm: 180,
    approximateAngleDegrees: 5,
    targetId: 'print-001',
    operatorNote: 'bench, matte stock',
    deliberateFailure: deliberateFailure,
  ),
  metadata: CaptureMetadata(
    capturedAt: DateTime.utc(2026, 9, 24, 12),
    deviceManufacturer: 'test',
    deviceModel: 'TestPhone',
    operatingSystem: 'test',
    appVersion: '0.1.0',
    capabilities: const CameraCapabilities.unknown(),
    cameraId: const CaptureField<String>.known('0'),
    imageWidth: const CaptureField<int>.known(900),
    imageHeight: const CaptureField<int>.known(620),
    orientationDegrees: const CaptureField<int>.known(0),
    torchOn: const CaptureField<bool>.known(false),
    focusLocked: const CaptureField<bool>.known(true),
    exposureLocked: const CaptureField<bool>.known(true),
    whiteBalanceLocked: const CaptureField<bool>.unsupported(),
    exposureCompensation: const CaptureField<double>.unavailable(),
    isoSensitivity: const CaptureField<int>.unsupported(),
    exposureTimeSeconds: const CaptureField<double>.unsupported(),
    requestedSettings: const <String, String>{'focus_mode': 'locked'},
  ),
  previewAssessment: null,
  stillAssessment: null,
  outcome: deliberateFailure == null ? 'observed' : 'refused',
  originalImageFile: 'original.jpg',
);

void main() {
  late Directory temp;
  late CaptureArchive archive;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('doseband-archive-');
    archive = CaptureArchive(root: temp);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('writes the original bytes unchanged', () async {
    final bytes = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 1, 2, 3, 4, 5]);
    final directory = await archive.write(
      record: _record('cap-001'),
      originalBytes: bytes,
    );

    final written = File('${directory.path}/original.jpg').readAsBytesSync();
    expect(
      written,
      bytes,
      reason:
          'the original must never be re-encoded — features can be '
          'recomputed, an original cannot',
    );
  });

  test(
    'a record describes its own capture, so filenames carry no meaning',
    () async {
      await archive.write(
        record: _record('cap-001'),
        originalBytes: Uint8List(4),
      );
      final records = await archive.records();
      expect(records, hasLength(1));

      final record = records.single;
      expect(record['schema'], 'doseband-capture-record/2');
      expect(record['capture_id'], 'cap-001');
      expect(record['data_domain'], 'lab');
      expect(record['geometry_version'], 'badge-v1-research');
      expect(record['feature_definition_version'], featureDefinitionVersion);
      final conditions = record['conditions']! as Map<String, Object?>;
      expect(conditions['target_id'], 'print-001');
      expect(conditions['illumination_class'], 'warm-led');
    },
  );

  test('deliberate failures are separated from valid acquisitions', () async {
    // Pooling them would understate the detection rate while saying nothing
    // about refusal, which is what the failures are for.
    await archive.write(
      record: _record('cap-001'),
      originalBytes: Uint8List(4),
    );
    await archive.write(
      record: _record('cap-002', deliberateFailure: 'glare'),
      originalBytes: Uint8List(4),
    );
    await archive.write(
      record: _record('cap-003', deliberateFailure: 'occluded-marker'),
      originalBytes: Uint8List(4),
    );

    final manifest = jsonDecode(
      (await archive.writeManifest()).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(manifest['capture_count'], 3);
    expect(manifest['valid_acquisition_count'], 1);
    expect(manifest['deliberate_failure_count'], 2);
  });

  test(
    'an interrupted capture is identifiable, not silently counted',
    () async {
      // The record is written last, so a directory without one is a crash.
      Directory('${temp.path}/dossier-v0/cap-orphan')
          .createSync(recursive: true);
      File('${temp.path}/dossier-v0/cap-orphan/original.jpg')
          .writeAsBytesSync(<int>[1, 2, 3]);

      expect(await archive.incompleteCaptures(), <String>['cap-orphan']);
      expect(await archive.records(), isEmpty);
    },
  );

  test('refuses to overwrite an existing capture', () async {
    await archive.write(
      record: _record('cap-001'),
      originalBytes: Uint8List(4),
    );
    await expectLater(
      archive.write(record: _record('cap-001'), originalBytes: Uint8List(4)),
      throwsStateError,
    );
  });

  test('the disclosure travels with the record', () async {
    await archive.write(
      record: _record('cap-001'),
      originalBytes: Uint8List(4),
    );
    final record = (await archive.records()).single;
    expect(record['disclosure'], DataDomain.lab.disclosure);
  });
}
