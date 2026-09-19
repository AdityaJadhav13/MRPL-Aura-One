/// Build-time environment configuration.
///
/// Three environments, three Supabase projects, three application IDs. The
/// separation is not a convenience: it is what makes simulated data
/// structurally incapable of reaching a production dataset, because a
/// development build physically points at a different database whose
/// `data_domain` CHECK does not admit `'simulated'`.
///
/// See docs/decisions/0005-supabase-backend.md and
/// docs/decisions/0006-data-domain-separation.md.
library;

enum AppEnvironment { dev, staging, prod }

/// Resolved once at startup and passed down. Nothing reads these values from a
/// global; the configuration is an argument, so tests can supply their own.
final class EnvironmentConfig {
  const EnvironmentConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Whether simulation mode may be offered at all.
  ///
  /// Never true in production. A simulated measurement is not a real H2S
  /// measurement, and there is no legitimate reason for a worker's production
  /// build to be able to produce one.
  bool get simulationAvailable => environment != AppEnvironment.prod;

  /// Whether experimental CV and calibration paths may be enabled.
  /// Experimental code must not silently enter production (directive 35).
  bool get experimentalFeaturesAvailable => environment == AppEnvironment.dev;

  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Credentials arrive via --dart-define at build time. They are never
  /// committed, and the anon key is the only key that ships. Service-role keys
  /// exist only in edge functions.
  static EnvironmentConfig fromDartDefines(AppEnvironment environment) {
    return EnvironmentConfig(
      environment: environment,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }
}
