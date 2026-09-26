import 'package:flutter/foundation.dart';

import '../../../core/env/environment.dart';

/// What the authentication flow is allowed to do in this build.
///
/// The skip control is the reason this exists. It bypasses sign-in entirely,
/// which is indispensable while the rest of the application is being built and
/// indefensible in a shipped build — so its availability is derived from the
/// build environment rather than from a variable someone can flip.
@immutable
final class AuthDemoConfig {
  const AuthDemoConfig({required this.allowSkip, required this.isDemo});

  /// Derived from the environment, not chosen.
  ///
  /// `simulationAvailable` is already false in production by construction
  /// (see [EnvironmentConfig]), and reusing it means the skip control and
  /// simulated measurements are switched off by the same single fact about the
  /// build. Two independent flags could disagree; one cannot.
  factory AuthDemoConfig.fromEnvironment(EnvironmentConfig config) =>
      AuthDemoConfig(
        allowSkip: config.simulationAvailable,
        // Nothing authenticates anything yet, in any environment.
        isDemo: true,
      );

  /// Whether the development skip control may be rendered at all.
  final bool allowSkip;

  /// Whether sign-in is UI-only. True until a real identity provider is wired.
  final bool isDemo;
}
