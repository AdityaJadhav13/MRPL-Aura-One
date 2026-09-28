import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

/// How much of the real pipeline the presentation fallback replaces (SIH
/// demonstration build, Presentation Controls).
///
/// The real path is always primary: with presentation mode off — the
/// default, and the state after every restart — nothing here applies. With
/// it on, the fallback applies **only to the presentation DoseBand**; a real
/// band scanned from its QR code always takes the real path. Use the lowest
/// level that lets the demonstration run.
enum FallbackLevel {
  /// Real QR, real camera, real engine. Presentation mode changes nothing
  /// except making the time-compression and reset controls available.
  real(
    'Level 0 — Full real path',
    'Real QR, real camera and the real measurement engine.',
  ),

  /// The presentation DoseBand stands in for a QR the scanner cannot read;
  /// the camera and the engine stay real.
  qr(
    'Level 1 — QR fallback',
    'Presentation DoseBand identity; real camera and real engine.',
  ),

  /// As level 1, and the photographs are still taken and archived, but the
  /// pre-use check and the result come from the presentation fixture.
  optical(
    'Level 2 — Optical fallback',
    'Presentation identity and interpretation; the real photograph is still '
        'taken and archived with the engine’s actual outcome.',
  ),

  /// No camera at all: the whole reading comes from the fixture. Only if the
  /// device pipeline cannot run.
  fixture(
    'Level 3 — Complete presentation fixture',
    'No camera. Use only if the device pipeline cannot run at all.',
  );

  const FallbackLevel(this.label, this.description);

  final String label;
  final String description;

  bool get usesPresentationIdentity => index >= FallbackLevel.qr.index;
  bool get usesPresentationInterpretation =>
      index >= FallbackLevel.optical.index;
  bool get skipsCamera => this == FallbackLevel.fixture;
}

/// Presentation mode as the operator set it. Never persisted: a restart
/// always returns to the real path, so it cannot stay on by accident.
@immutable
final class PresentationMode {
  const PresentationMode({
    this.enabled = false,
    this.level = FallbackLevel.real,
  });

  static const PresentationMode off = PresentationMode();

  final bool enabled;
  final FallbackLevel level;

  PresentationMode copyWith({bool? enabled, FallbackLevel? level}) =>
      PresentationMode(
        enabled: enabled ?? this.enabled,
        level: level ?? this.level,
      );
}

/// The one example result the presentation fallback shows, so the product's
/// result screen can be demonstrated before a calibration exists.
///
/// **Not a measurement.** It is a fixed, deterministic example — the same
/// value on every take — carried in the real result type so the same result
/// component renders it, under a calibration-model identifier that says
/// what it is. Records carrying it are [RecordOrigin.presentation] and
/// [DataDomain.simulated], so neither the domain nor the origin lets them
/// pass as field data. The measurement engine is never involved.
abstract final class PresentationResultFixture {
  static const double dosePpmHours = 4.2;
  static const double halfWidthPpmHours = 0.9;
  static const String modelId = 'PRESENTATION-EXAMPLE';

  static Valid result({
    required Duration coverage,
    required String geometryVersion,
    required String appVersion,
    required String deviceModel,
  }) => Valid(
    dose: Dose.ppmHours(dosePpmHours),
    uncertainty: const Uncertainty(
      halfWidth: halfWidthPpmHours,
      basis:
          'Presentation example — no validated calibration exists; this is '
          'not a measured interval.',
    ),
    coverage: coverage,
    provenance: Provenance(
      algorithmVersion: 'presentation-fixture-1',
      geometryVersion: geometryVersion,
      calibrationModelId: modelId,
      referenceProfileId: null,
      appVersion: appVersion,
      deviceModel: deviceModel,
    ),
  );
}
