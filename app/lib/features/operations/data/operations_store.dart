import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/operations_snapshot.dart';
import 'operations_codec.dart';

/// Where the operations snapshot is kept.
abstract interface class OperationsStore {
  /// The stored snapshot, or null when there is none (first launch) or the
  /// stored one cannot be decoded faithfully.
  Future<OperationsSnapshot?> load();

  Future<void> save(OperationsSnapshot snapshot);

  Future<void> clear();
}

final class InMemoryOperationsStore implements OperationsStore {
  InMemoryOperationsStore([this._snapshot]);

  OperationsSnapshot? _snapshot;

  @override
  Future<OperationsSnapshot?> load() async => _snapshot;

  @override
  Future<void> save(OperationsSnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<void> clear() async => _snapshot = null;
}

/// One JSON file in the app-support directory, written atomically.
///
/// **Not encrypted.** It sits in the application's private storage, which the
/// operating system keeps from other apps; nothing more is claimed (§105). It
/// holds no credential.
///
/// A file that cannot be decoded is moved aside rather than overwritten, so
/// the records in it are not destroyed by the next save.
final class FileOperationsStore implements OperationsStore {
  FileOperationsStore(this.file);

  final File file;

  static const String fileName = 'operations_v1.json';

  static Future<FileOperationsStore> open() async {
    final dir = await getApplicationSupportDirectory();
    return FileOperationsStore(
      File('${dir.path}${Platform.pathSeparator}$fileName'),
    );
  }

  @override
  Future<OperationsSnapshot?> load() async {
    try {
      if (!file.existsSync()) return null;
      final decoded = OperationsCodec.decode(
        jsonDecode(await file.readAsString()),
      );
      if (decoded == null) await _quarantine();
      return decoded;
    } on FormatException {
      await _quarantine();
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _quarantine() async {
    final stamp = DateTime.fromMillisecondsSinceEpoch(
      file.statSync().modified.millisecondsSinceEpoch,
    ).toUtc().toIso8601String().replaceAll(':', '-');
    await file.rename('${file.path}.unreadable-$stamp');
  }

  @override
  Future<void> save(OperationsSnapshot snapshot) async {
    final parent = file.parent;
    if (!parent.existsSync()) await parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(OperationsCodec.encode(snapshot)),
      flush: true,
    );
    await temp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    if (file.existsSync()) await file.delete();
  }
}
