import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/workflow_state.dart';
import 'session_codec.dart';
import 'workflow_store.dart';

/// A [WorkflowStore] backed by one JSON file in the application support
/// directory.
///
/// This is what makes interruption recovery real rather than notional: a
/// worker who starts a monitored period at 06:10 and whose phone is killed,
/// updated or rebooted at 09:40 comes back to the same period, at the same
/// stage, with the same badge — not to an empty home screen that quietly
/// discards three and a half hours of exposure.
///
/// ## Why a file and not a database
///
/// A session is a single small record that is written on each transition and
/// read once at launch. SQLite arrives in Phase 6 for the *measurement
/// history*, which is a growing, queryable, syncable table — a different
/// problem. Putting one record behind the same seam does not need it, and
/// `path_provider` is already a dependency, so this adds none.
///
/// ## Writes are atomic
///
/// The write goes to a sibling temporary file and is then renamed over the
/// target. `rename` within a directory is atomic on both platforms' native
/// filesystems, so a process killed mid-save leaves either the previous
/// snapshot or the new one, never a half-written file. This matters more here
/// than it looks: the app is killed *exactly* in the situations this store
/// exists to survive.
final class FileWorkflowStore implements WorkflowStore {
  FileWorkflowStore(this.file);

  /// The snapshot's location. Injected so tests exercise real file IO in a
  /// temporary directory instead of mocking a plugin channel.
  final File file;

  static const String fileName = 'shift_session.json';

  /// Opens the store at the platform's application-support directory — not a
  /// cache directory, which the OS may reclaim, and not external storage,
  /// which other applications can read.
  static Future<FileWorkflowStore> open() async {
    final dir = await getApplicationSupportDirectory();
    return FileWorkflowStore(
      File('${dir.path}${Platform.pathSeparator}$fileName'),
    );
  }

  @override
  Future<ShiftSession> load() async {
    try {
      if (!file.existsSync()) return ShiftSession.none;
      final raw = jsonDecode(await file.readAsString());
      // A snapshot that cannot be decoded faithfully is dropped, not patched.
      // The worker is told the period was lost by the app showing no period,
      // which is true, rather than by a restored session with a guessed field.
      return SessionCodec.decode(raw) ?? ShiftSession.none;
    } on FileSystemException {
      return ShiftSession.none;
    } on FormatException {
      return ShiftSession.none;
    }
  }

  @override
  Future<void> save(ShiftSession session) async {
    final parent = file.parent;
    if (!parent.existsSync()) await parent.create(recursive: true);

    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(SessionCodec.encode(session)),
      flush: true,
    );
    await temp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    if (file.existsSync()) await file.delete();
  }
}
