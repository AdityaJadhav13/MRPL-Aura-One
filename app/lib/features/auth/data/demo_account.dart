import 'package:flutter/foundation.dart';

import '../domain/auth_models.dart';

/// The one demo account the prototype recognises.
///
/// ## This is not a credential
///
/// The string below is a **published demo password**. It is printed on the
/// sign-in screen, it is in this repository, and it is meant to be typed by
/// anyone evaluating the prototype. It guards nothing, because there is
/// nothing behind it: no directory, no account, no personal data, no network
/// call.
///
/// It is therefore handled as *demonstration content*, not as a secret:
///
/// * it lives here, in one place, rather than being scattered through widgets
///   and tests — so the day a real identity provider arrives, there is exactly
///   one thing to delete;
/// * it is never persisted, never logged, and never written to the session;
/// * nothing hashes or salts it, because pretending to protect a value that is
///   displayed on screen would be security theatre, and theatre in an
///   authentication path is how a reviewer comes to believe the path is real.
///
/// When organisation identity is connected, this class is deleted whole. It is
/// deliberately not an extension point.
@immutable
abstract final class DemoAccount {
  /// Shown on screen and typed by evaluators.
  static const String workerId = 'CT-45832';

  /// See the class documentation before treating this as a password.
  static const String password = 'DoseBand@2026';

  static const String displayName = 'Aditya Jadhav';
  static const AuthUserType userType = AuthUserType.contractor;
  static const String contractorCompany = 'XYZ Engineering';

  /// Whether the supplied pair matches the demo account.
  ///
  /// A plain comparison. There is no timing-attack surface because there is no
  /// secret and no account to compromise — and a constant-time comparison here
  /// would imply otherwise.
  static bool matches({required String userId, required String password}) =>
      userId.trim() == workerId && password == DemoAccount.password;

  /// The identity a successful demo sign-in produces.
  ///
  /// Marked [AuthSource.demo], so everything downstream — the work context,
  /// the exposure record, the provenance chips — reports it as demonstration
  /// data rather than as a verified worker.
  static DemoIdentity identity() => const DemoIdentity(
    userId: workerId,
    displayName: displayName,
    userType: userType,
    source: AuthSource.demo,
    contractorCompany: contractorCompany,
  );
}
