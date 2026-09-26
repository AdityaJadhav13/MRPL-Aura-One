import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:measurement/measurement.dart';
import 'package:path_provider/path_provider.dart';

/// Writes dossier V0 captures to disk.
///
/// One directory per capture, holding the original bytes and a record that
/// describes them. The record is written **last**, so a directory without one
/// is a crash mid-capture and can be discarded without ambiguity.
///
/// Two rules the layout enforces:
///
/// - **The original is never re-encoded.** The bytes the camera produced are
///   written unchanged. Features can be recomputed from an original; an
///   original cannot be recovered from features.
/// - **No file is identified by its name.** Every capture carries its own
///   metadata, so renaming files by hand cannot silently change what the
///   dataset means.
final class CaptureArchive {
  CaptureArchive({Directory? root}) : _explicitRoot = root;

  final Directory? _explicitRoot;
  Directory? _resolved;

  /// `<app documents>/dossier-v0/`.
  Future<Directory> root() async {
    final existing = _resolved;
    if (existing != null) return existing;
    final base = _explicitRoot ?? await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/dossier-v0');
    if (!directory.existsSync()) directory.createSync(recursive: true);
    return _resolved = directory;
  }

  /// Writes one capture and returns its directory.
  Future<Directory> write({
    required CaptureRecord record,
    required Uint8List originalBytes,
    Map<String, Uint8List> derivedFiles = const <String, Uint8List>{},
  }) async {
    final base = await root();
    final directory = Directory('${base.path}/${record.captureId}');
    if (directory.existsSync()) {
      throw StateError('capture ${record.captureId} already archived');
    }
    directory.createSync(recursive: true);

    File('${directory.path}/${record.originalImageFile}')
        .writeAsBytesSync(originalBytes, flush: true);

    // Derived views — the rectified badge. Written before the record so that
    // a complete record always has everything it names.
    for (final entry in derivedFiles.entries) {
      File('${directory.path}/${entry.key}')
          .writeAsBytesSync(entry.value, flush: true);
    }

    // Record last: a directory without one is an interrupted capture.
    File('${directory.path}/record.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(record.toJson())}\n',
      flush: true,
    );
    return directory;
  }

  /// The directory a capture was archived to, for sharing it.
  Future<Directory> directoryFor(String captureId) async =>
      Directory('${(await root()).path}/$captureId');

  /// Every complete capture, oldest first.
  Future<List<Map<String, Object?>>> records() async {
    final base = await root();
    final out = <Map<String, Object?>>[];
    for (final entity
        in base.listSync()..sort((a, b) => a.path.compareTo(b.path))) {
      if (entity is! Directory) continue;
      final file = File('${entity.path}/record.json');
      if (!file.existsSync()) continue;
      out.add(jsonDecode(file.readAsStringSync()) as Map<String, Object?>);
    }
    return out;
  }

  /// Captures written but never completed.
  Future<List<String>> incompleteCaptures() async {
    final base = await root();
    return <String>[
      for (final entity in base.listSync())
        if (entity is Directory &&
            !File('${entity.path}/record.json').existsSync())
          entity.path.split(Platform.pathSeparator).last,
    ];
  }

  /// A one-file summary of the whole session, for taking away.
  Future<File> writeManifest() async {
    final base = await root();
    final all = await records();
    final valid = all.where((r) {
      final conditions = r['conditions']! as Map<String, Object?>;
      return conditions['is_deliberate_failure'] == false;
    }).length;

    final manifest = <String, Object?>{
      'schema': 'doseband-capture-manifest/1',
      'generated_at': DateTime.now().toIso8601String(),
      'capture_count': all.length,
      // Kept apart deliberately: deliberate failures exist to test refusal and
      // must never be pooled with valid acquisitions in a detection rate.
      'valid_acquisition_count': valid,
      'deliberate_failure_count': all.length - valid,
      'incomplete': await incompleteCaptures(),
      'captures': all,
    };
    final file = File('${base.path}/manifest.json');
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
      flush: true,
    );
    return file;
  }
}
