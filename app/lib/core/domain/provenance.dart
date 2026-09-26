import 'package:flutter/foundation.dart';

/// Where a record came from — the one product-wide provenance vocabulary
/// (APP-PRODUCT-01 §21, §43).
///
/// ## Why one more enum is not one more incompatible enum
///
/// The codebase already carries several provenance types, each answering a
/// narrower question and each load-bearing where it lives:
///
/// | Existing type | Question it answers |
/// |---|---|
/// | `DataDomain` (measurement) | simulated / lab / field — may a dose exist? |
/// | `DataOrigin` (corporate UI) | real / demo / not connected, per screen |
/// | `EnterpriseDataSource` | demo / typed / verified, per enterprise value |
/// | `BadgeIdentitySource` | how a DoseBand identity reached the app |
/// | `SafetyContentSource` | who authored a piece of safety text |
///
/// They are **not** replaced — several are persisted, and one is frozen in the
/// measurement package. Instead each maps *into* [RecordProvenance] (see
/// `provenance_mapping.dart`), so a shared component can render any record's
/// origin in one vocabulary without knowing which type it started as. The
/// mapping is total and tested, which is what stops the vocabularies
/// drifting.
///
/// `SafetyContentSource` is deliberately left out: authorship of text is a
/// different axis from where a record came from.
///
/// Named `RecordProvenance` rather than `Provenance` because the measurement
/// package already has a `Provenance` — the algorithm, geometry and
/// calibration versions behind one result — and the two must not be confused.
enum RecordProvenance {
  /// Produced on this device from real inputs: a real camera capture, a real
  /// workflow transition. Not yet confirmed by any server.
  realLocal,

  /// Confirmed by the central server. **Nothing can produce this yet** — no
  /// server exists (P10). Declared so the difference between "on my phone"
  /// and "on the record" is representable before sync lands.
  serverSynced,

  /// Organisational presentation data: a sample worker, a sample site. It
  /// is identifiable as such internally; it is not stamped "DEMO" on every
  /// row (§21).
  presentationSeeded,

  /// A simulated scientific quantity. Always marked locally, on the value.
  simulated,

  /// Typed on this device by a person. Nothing checked it.
  manualEntry,

  /// Confirmed by an organisation system. No such integration exists.
  organizationIntegration,

  /// An integration or service that exists conceptually and is not connected.
  notConnected,

  /// Cannot currently be provided.
  unavailable;

  /// The sources this build can actually produce. Asserted by a test, so
  /// adding a server or an integration is a deliberate edit here.
  static const Set<RecordProvenance> producibleToday = {
    realLocal,
    presentationSeeded,
    simulated,
    manualEntry,
    notConnected,
    unavailable,
  };

  String get label => switch (this) {
    RecordProvenance.realLocal => 'On this device',
    RecordProvenance.serverSynced => 'Synced',
    RecordProvenance.presentationSeeded => 'Presentation data',
    RecordProvenance.simulated => 'Simulated',
    RecordProvenance.manualEntry => 'Manual entry',
    RecordProvenance.organizationIntegration => 'Organisation system',
    RecordProvenance.notConnected => 'Not connected',
    RecordProvenance.unavailable => 'Unavailable',
  };

  /// One sentence stating what the label does and does not mean.
  String get explanation => switch (this) {
    RecordProvenance.realLocal =>
      'Recorded on this device. Not yet confirmed by a server.',
    RecordProvenance.serverSynced =>
      'Confirmed by the central DoseBand server.',
    RecordProvenance.presentationSeeded =>
      'Sample organisational data for presentation. Not from any MRPL system.',
    RecordProvenance.simulated => 'Simulated. Not a real H₂S measurement.',
    RecordProvenance.manualEntry =>
      'Entered on this device. Not checked against any system.',
    RecordProvenance.organizationIntegration =>
      'Confirmed by an organisation system.',
    RecordProvenance.notConnected => 'No connection to this system exists.',
    RecordProvenance.unavailable => 'This information cannot be provided now.',
  };

  /// Whether a scientific quantity with this provenance may be shown as a
  /// real measurement. Only a real capture, locally or once synced.
  bool get mayCarryRealMeasurement =>
      this == RecordProvenance.realLocal ||
      this == RecordProvenance.serverSynced;

  /// Whether a component must mark this on the value itself, rather than
  /// once per screen. Simulated quantities are always marked locally (§21).
  bool get mustBeMarkedLocally => this == RecordProvenance.simulated;
}

/// A value together with where it came from.
@immutable
final class Sourced<T> {
  const Sourced(this.value, this.provenance);

  final T value;
  final RecordProvenance provenance;

  @override
  bool operator ==(Object other) =>
      other is Sourced<T> &&
      other.value == value &&
      other.provenance == provenance;

  @override
  int get hashCode => Object.hash(value, provenance);
}
