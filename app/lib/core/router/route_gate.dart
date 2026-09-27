import 'package:flutter/foundation.dart';

import '../../features/auth/domain/auth_models.dart';

/// Which workspace every route belongs to, and who may be sent there
/// (PRODUCT BUILD v1 §54, §57, §145).
///
/// ## What this is — and is not
///
/// A navigation rule: a signed-out person reaches sign-in, and a signed-in
/// person reaches only their active workspace. A worker who types `/hse` into
/// a deep link lands on their own Home.
///
/// It is **not** the security boundary. Data access is decided by the
/// operations services, below the UI, whatever route is showing; this gate
/// only keeps people out of screens that would refuse them anyway.
abstract final class RouteGate {
  static const Map<AppRole, List<String>> _prefixes = {
    AppRole.worker: [
      '/home',
      '/history',
      '/scan',
      '/safety',
      '/profile',
      '/doseband',
      '/work-context',
      '/assign',
      '/verify',
      '/prework',
      '/active',
      '/end',
      '/read',
      '/processing',
      '/result',
      '/measurement',
      '/shift',
      '/worker-identity',
      '/work-area',
      '/ptw',
      '/jsa',
      '/toolbox',
      '/scan-badge',
      '/traceability',
    ],
    AppRole.supervisor: ['/supervisor'],
    AppRole.hseOfficer: ['/hse', '/reporting'],
    AppRole.management: ['/management'],
    AppRole.administrator: ['/admin'],
  };

  /// Routes reachable without signing in.
  static const List<String> _public = ['/splash', '/sign-in'];

  static bool _under(String path, String prefix) =>
      path == prefix || path.startsWith('$prefix/');

  static String _path(String location) =>
      Uri.tryParse(location)?.path ?? location;

  /// The workspace [location] belongs to, or null for shared routes.
  @visibleForTesting
  static AppRole? workspaceOf(String location) {
    final path = _path(location);
    for (final e in _prefixes.entries) {
      if (e.value.any((p) => _under(path, p))) return e.key;
    }
    return null;
  }

  /// Whether a signed-in [session] may be shown [location].
  static bool allows({required AppSession session, required String location}) {
    final path = _path(location);
    if (_public.any((p) => _under(path, p))) return false;
    final owner = workspaceOf(path);
    return owner == null || owner == session.activeRole;
  }

  /// Where to send someone instead of [location], or null to let them in.
  static String? redirect({
    required AuthState auth,
    required String location,
    required bool devToolsAvailable,
  }) {
    final path = _path(location);
    final isDev = _under(path, '/dev');
    if (isDev) return devToolsAvailable ? null : '/sign-in';
    if (_under(path, '/splash')) return null;

    if (auth.status == AuthStatus.unknown) {
      return Uri(
        path: '/splash',
        queryParameters: {'from': location},
      ).toString();
    }

    final session = auth.session;
    if (session == null || !auth.isSignedIn) {
      return _under(path, '/sign-in') ? null : '/sign-in';
    }
    if (path == '/' || _under(path, '/sign-in')) {
      return session.activeRole.landingRoute;
    }
    return allows(session: session, location: location)
        ? null
        : session.activeRole.landingRoute;
  }
}
