import 'package:flutter/foundation.dart';

import '../domain/auth_models.dart';
import 'demo_account.dart';

/// The outcome of a demo sign-in attempt.
///
/// Deliberately not called `AuthResult`. Nothing here authenticates: the type's
/// name is the first line of defence against a later reader assuming it does.
@immutable
sealed class DemoAuthResult {
  const DemoAuthResult();
}

/// Required fields were present, so the flow may continue.
///
/// **This is not proof of anything.** No credential was checked against any
/// directory, and the identity it carries is marked [AuthSource.demo].
final class DemoAuthAccepted extends DemoAuthResult {
  const DemoAuthAccepted(this.identity);

  final DemoIdentity identity;
}

/// The form was incomplete. Field key → message.
final class DemoAuthIncomplete extends DemoAuthResult {
  const DemoAuthIncomplete(this.fieldErrors);

  final Map<String, String> fieldErrors;
}

/// The form was complete, but the values are not the demo account.
///
/// Distinct from [DemoAuthIncomplete] because the two mean different things to
/// the person in front of the screen: one is "you missed a field", the other is
/// "those are not the demo credentials".
///
/// Neither means "MRPL rejected you". MRPL was never asked. The message this
/// carries says so, and a test asserts it names no organisation — telling a
/// user their *MRPL account* is invalid, when nothing queried MRPL, is a lie
/// that happens to be convenient.
final class DemoAuthRejected extends DemoAuthResult {
  const DemoAuthRejected(this.message);

  final String message;
}

/// Field keys, so screens and validation cannot drift apart over a string.
abstract final class AuthField {
  static const String userId = 'userId';
  static const String password = 'password';
  static const String contractorCompany = 'contractorCompany';
}

/// UI-only sign-in.
///
/// **No identity verification occurs.** This checks that required fields are
/// non-empty and returns an identity marked as demo. It performs no network
/// request, reaches no directory, and validates no credential.
///
/// The password is read, checked for emptiness, and dropped. It is never
/// stored on the result, never logged, never persisted and never returned.
final class DemoAuthRepository {
  const DemoAuthRepository();

  DemoAuthResult signIn({
    required AuthUserType userType,
    required String userId,
    required String password,
    String contractorCompany = '',
  }) {
    final errors = <String, String>{};

    final id = userId.trim();
    if (id.isEmpty) {
      errors[AuthField.userId] = userType == AuthUserType.employee
          ? 'Enter your User ID or Employee ID'
          : 'Enter your Worker or Contractor ID';
    }

    if (userType == AuthUserType.contractor &&
        contractorCompany.trim().isEmpty) {
      errors[AuthField.contractorCompany] = 'Enter your contractor company';
    }

    // Emptiness only. There is nothing to check it against.
    if (password.isEmpty) {
      errors[AuthField.password] = 'Enter your password';
    }

    if (errors.isNotEmpty) return DemoAuthIncomplete(errors);

    // One deterministic demo account. Anything else is refused rather than
    // waved through: a sign-in that accepts every input teaches an evaluator
    // that the screen is decorative, and the first thing they will then
    // discount is everything behind it.
    if (!DemoAccount.matches(userId: id, password: password)) {
      return const DemoAuthRejected(
        'Demo credentials do not match. Use the demo access details below.',
      );
    }

    return DemoAuthAccepted(DemoAccount.identity());
  }

  /// The identity created when a developer skips authentication.
  ///
  /// Obviously synthetic on sight. Skipping must not quietly produce something
  /// that reads like a real employee record.
  DemoIdentity skipIdentity() => const DemoIdentity(
    userId: 'DEMO-USER',
    displayName: 'Demo User',
    userType: AuthUserType.employee,
    source: AuthSource.demo,
  );
}
