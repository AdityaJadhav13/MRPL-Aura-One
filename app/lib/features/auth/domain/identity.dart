import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'auth_models.dart';

/// A stored password verifier: salt and PBKDF2-HMAC-SHA256 derived key.
///
/// **Never the password.** The password is typed, derived, compared and
/// dropped; no code path writes it anywhere (§105).
@immutable
final class PasswordVerifier {
  const PasswordVerifier({
    required this.saltHex,
    required this.keyHex,
    this.iterations = defaultIterations,
  });

  /// Derives a verifier. For tests and for issuing new accounts; the shipped
  /// presentation directory holds precomputed verifiers only.
  factory PasswordVerifier.derive(
    String password,
    List<int> salt, {
    int iterations = defaultIterations,
  }) => PasswordVerifier(
    saltHex: _hex(salt),
    keyHex: _hex(pbkdf2(password, salt, iterations)),
    iterations: iterations,
  );

  /// A cost chosen for a phone: a fraction of a second per attempt, run off
  /// the UI thread. Below current server-side guidance for PBKDF2 (§105
  /// forbids plaintext; it does not make this a production credential store).
  static const int defaultIterations = 120000;

  final String saltHex;
  final String keyHex;
  final int iterations;

  /// Constant-time over the derived key, so the comparison leaks nothing
  /// about how much of it matched.
  bool matches(String password) {
    final derived = pbkdf2(password, _unhex(saltHex), iterations);
    final expected = _unhex(keyHex);
    if (derived.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < derived.length; i++) {
      diff |= derived[i] ^ expected[i];
    }
    return diff == 0;
  }

  /// PBKDF2 (RFC 8018) with HMAC-SHA256, 32-byte output.
  static List<int> pbkdf2(String password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, password.codeUnits);
    final block = ByteData(4)..setUint32(0, 1);
    var u = hmac.convert([...salt, ...block.buffer.asUint8List()]).bytes;
    final t = List<int>.of(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _unhex(String s) => [
    for (var i = 0; i < s.length; i += 2)
      int.parse(s.substring(i, i + 2), radix: 16),
  ];
}

/// Why a sign-in did not produce a session. Each is a different sentence to
/// the person at the screen (§56).
enum SignInFailure {
  /// The ID and password do not match an account.
  invalidCredentials,

  /// The account exists and has been suspended by an administrator.
  accountSuspended,

  /// The device has no network, and the identity provider needs one.
  offline,

  /// The identity provider is configured and did not answer.
  serverUnavailable,

  /// No identity provider is connected to this build.
  notConnected,
}

@immutable
sealed class SignInOutcome {
  const SignInOutcome();
}

final class SignInAccepted extends SignInOutcome {
  const SignInAccepted(this.personId);
  final String personId;
}

final class SignInRefused extends SignInOutcome {
  const SignInRefused(this.failure);
  final SignInFailure failure;
}

/// Where identities are checked.
abstract interface class IdentityProvider {
  /// What a person is signing in against, in words.
  String get description;

  AuthSource get source;

  Future<SignInOutcome> signIn({
    required String loginId,
    required String password,
    required bool Function(String personId) isActive,
  });
}

/// The organisation's identity provider. **NOT CONNECTED** — this is the one
/// a production build gets, and it says so rather than pretending to check
/// anything (§56: "do not fake MRPL authentication").
final class NotConnectedIdentityProvider implements IdentityProvider {
  const NotConnectedIdentityProvider();

  @override
  String get description => 'Organisation sign-in (not connected)';

  @override
  AuthSource get source => AuthSource.organizationIdentity;

  @override
  Future<SignInOutcome> signIn({
    required String loginId,
    required String password,
    required bool Function(String personId) isActive,
  }) async => const SignInRefused(SignInFailure.notConnected);
}

/// The presentation directory: the six presentation accounts, verified on
/// this device against salted PBKDF2 verifiers.
///
/// It is a real check — a wrong password is refused — against accounts that
/// exist only for presentation. It is not organisation identity, and every
/// session it produces is marked [AuthSource.demo].
final class PresentationIdentityProvider implements IdentityProvider {
  const PresentationIdentityProvider(
    this.verifiers, {
    this.verify = _offThread,
  });

  /// The shipped verifiers. Login identifier → verifier.
  factory PresentationIdentityProvider.shipped() =>
      const PresentationIdentityProvider(_shipped);

  final Map<String, PasswordVerifier> verifiers;

  /// Runs the derivation. Off the UI thread in the app; tests may run it
  /// inline, since widget tests cannot wait on a real isolate.
  final Future<bool> Function(PasswordVerifier verifier, String password)
  verify;

  static Future<bool> _offThread(PasswordVerifier v, String password) =>
      compute(_verify, (v, password));

  static Future<bool> inline(PasswordVerifier v, String password) async =>
      v.matches(password);

  static const Map<String, PasswordVerifier> _shipped = {
    'CT-45832': PasswordVerifier(
      saltHex: 'b7eef356cbb3845b9c894503f27e29a9',
      keyHex:
          'd9738960ebea6c880b17ae70ce7ae87bb9f4d2b02b86dfe96504406ad1336716',
    ),
    'E-10231': PasswordVerifier(
      saltHex: 'baf3aeb3fd5fa9af41b10ba204ebfb2d',
      keyHex:
          'cb396f8b978ba0b4ea16459ed7e94078c1a8940f5995969571704fa0f6e51ac9',
    ),
    'CT-45871': PasswordVerifier(
      saltHex: '65a9833bb8f40a6613beb24ce93f9612',
      keyHex:
          'cffdc354c91bed3499e980f8efbf65dc7b3d3e48eccdbc9c4e10a5c13a84fccf',
    ),
    'E-10088': PasswordVerifier(
      saltHex: 'c8e26c845ec565d0422fb6eda96edf78',
      keyHex:
          '643c4308b27c0cdba94c02b218b7000eed765bfd30197eaed9d1dae66f3e1868',
    ),
    'E-10152': PasswordVerifier(
      saltHex: 'f55c5dac30bc82ff628b161537a154cd',
      keyHex:
          '9130cf874415d8ce4e92ed20581b77378dfe2642b80c9d6c4068be6923778bdf',
    ),
    'E-10007': PasswordVerifier(
      saltHex: '102d8679a1552fa887f9acb5f3b68fc7',
      keyHex:
          '55e3bd6b321c9866edc6723c92d0440b33e9215f4c74ff9f3f78d31e91ed0b8e',
    ),
  };

  @override
  String get description => 'Presentation accounts on this device';

  @override
  AuthSource get source => AuthSource.demo;

  @override
  Future<SignInOutcome> signIn({
    required String loginId,
    required String password,
    required bool Function(String personId) isActive,
  }) async {
    final id = loginId.trim().toUpperCase();
    final verifier = verifiers[id];
    // An unknown ID still costs one derivation, so response time does not
    // reveal which IDs exist.
    final ok = await verify(verifier ?? _decoy, password);
    if (verifier == null || !ok) {
      return const SignInRefused(SignInFailure.invalidCredentials);
    }
    if (!isActive(id)) {
      return const SignInRefused(SignInFailure.accountSuspended);
    }
    return SignInAccepted(id);
  }

  static const PasswordVerifier _decoy = PasswordVerifier(
    saltHex: '00000000000000000000000000000000',
    keyHex: '0000000000000000000000000000000000000000000000000000000000000000',
  );

  static bool _verify((PasswordVerifier, String) args) =>
      args.$1.matches(args.$2);
}
