import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/auth_models.dart';

/// What is kept between launches: who, and in which workspace. Nothing that
/// could sign anyone in — no password, no token (§105).
///
/// Restoring re-checks the person against the directory, so a suspended
/// account or a withdrawn role does not come back through a stale file.
@immutable
final class StoredSession {
  const StoredSession({
    required this.personId,
    required this.activeRole,
    this.siteId,
  });

  final String personId;
  final AppRole activeRole;

  /// The site confirmed at sign-in, when one was selected during setup.
  final String? siteId;
}

abstract interface class AuthSessionStore {
  Future<StoredSession?> load();
  Future<void> save(StoredSession session);
  Future<void> clear();
}

final class InMemoryAuthSessionStore implements AuthSessionStore {
  InMemoryAuthSessionStore([this._session]);

  StoredSession? _session;

  @override
  Future<StoredSession?> load() async => _session;

  @override
  Future<void> save(StoredSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

final class FileAuthSessionStore implements AuthSessionStore {
  FileAuthSessionStore(this.file);

  final File file;

  static Future<FileAuthSessionStore> open() async {
    final dir = await getApplicationSupportDirectory();
    return FileAuthSessionStore(
      File('${dir.path}${Platform.pathSeparator}auth_session.json'),
    );
  }

  @override
  Future<StoredSession?> load() async {
    try {
      if (!file.existsSync()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      final id = raw['person_id'];
      final role = AppRole.values
          .where((r) => r.name == raw['active_role'])
          .firstOrNull;
      if (id is! String || id.isEmpty || role == null) return null;
      final site = raw['site_id'];
      return StoredSession(
        personId: id,
        activeRole: role,
        siteId: site is String && site.isNotEmpty ? site : null,
      );
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> save(StoredSession session) async {
    final parent = file.parent;
    if (!parent.existsSync()) await parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'person_id': session.personId,
        'active_role': session.activeRole.name,
        if (session.siteId != null) 'site_id': session.siteId,
      }),
      flush: true,
    );
    await temp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    if (file.existsSync()) await file.delete();
  }
}
