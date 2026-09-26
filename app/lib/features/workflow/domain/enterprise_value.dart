import 'package:flutter/foundation.dart';

/// Where a piece of enterprise-linked information actually came from.
///
/// DoseBand references MRPL's safety processes; it does not run them. A permit
/// number typed in by a worker and a permit number retrieved and confirmed from
/// an MRPL system are worth entirely different amounts, and the difference must
/// survive being written to storage, restored, and rendered months later next
/// to a measurement.
///
/// So provenance is carried in the type, not in a comment and not in a screen.
enum EnterpriseDataSource {
  /// Seeded demonstration data. Nobody entered it and no system supplied it.
  demo('Demo', 'Demonstration data. Not from any MRPL system.'),

  /// Typed in by the worker on this device. It is what someone said, which is
  /// not the same as what is true: nothing checked it against anything.
  manualEntry(
    'Manual',
    'Entered on this device. Not checked against any system.',
  ),

  /// Retrieved from an organisation system that confirmed it.
  ///
  /// **No such integration exists.** This value is declared so the model can
  /// express a verified fact when one becomes available, and so that the
  /// difference between verified and typed-in is representable *before* the
  /// integration lands rather than being retrofitted over stored data that
  /// never recorded it.
  organizationIntegration('Verified', 'Confirmed by an organisation system.');

  const EnterpriseDataSource(this.label, this.explanation);

  /// The short chip text: "Demo", "Manual", "Verified".
  final String label;

  /// One sentence a worker can read, stating what the label does and does not
  /// mean.
  final String explanation;

  bool get isVerified => this == EnterpriseDataSource.organizationIntegration;

  /// The sources this build can actually produce.
  ///
  /// Asserted by a test, so that connecting an integration is a deliberate
  /// change to this list and not something that happens by accident.
  static const List<EnterpriseDataSource> availableToday = [demo, manualEntry];
}

/// A value together with where it came from.
///
/// The invariant this type exists to enforce:
///
/// > A manually entered PTW number must never later be indistinguishable from
/// > a PTW fetched and verified through an MRPL integration.
///
/// That is enforced structurally. [EnterpriseValue.verified] is the only way to
/// obtain [EnterpriseDataSource.organizationIntegration], and it *requires* the
/// system that confirmed the value, the reference it was confirmed under, and
/// when. There is no way to mark something verified without saying what did the
/// verifying — which means there is no way for a typed-in value to drift into
/// looking authoritative.
@immutable
final class EnterpriseValue<T extends Object> {
  const EnterpriseValue._({
    required this.value,
    required this.source,
    this.verifiedAt,
    this.externalSystem,
    this.externalReference,
  });

  /// Seeded demonstration data.
  const EnterpriseValue.demo(T value)
    : this._(value: value, source: EnterpriseDataSource.demo);

  /// Typed in on this device, unchecked.
  const EnterpriseValue.manual(T value)
    : this._(value: value, source: EnterpriseDataSource.manualEntry);

  /// Confirmed by an external system.
  ///
  /// Nothing constructs this today — there is no integration — and a test
  /// asserts as much. It exists so the shape is right when one arrives.
  const EnterpriseValue.verified({
    required T value,
    required DateTime verifiedAt,
    required String externalSystem,
    required String externalReference,
  }) : this._(
         value: value,
         source: EnterpriseDataSource.organizationIntegration,
         verifiedAt: verifiedAt,
         externalSystem: externalSystem,
         externalReference: externalReference,
       );

  final T value;
  final EnterpriseDataSource source;

  /// When an external system confirmed this. Non-null only when [isVerified].
  final DateTime? verifiedAt;

  /// Which system confirmed it, e.g. a PTW system's name. Non-null only when
  /// [isVerified].
  final String? externalSystem;

  /// The identifier the external system confirmed it under — its own key, not
  /// the displayed [value]. Non-null only when [isVerified].
  final String? externalReference;

  bool get isVerified => source.isVerified;

  /// True when this value carries no more authority than "somebody said so".
  bool get isUnverified => !isVerified;

  EnterpriseValue<T> withValue(T next) => EnterpriseValue._(
    value: next,
    source: source,
    verifiedAt: verifiedAt,
    externalSystem: externalSystem,
    externalReference: externalReference,
  );

  @override
  bool operator ==(Object other) =>
      other is EnterpriseValue<T> &&
      other.value == value &&
      other.source == source &&
      other.verifiedAt == verifiedAt &&
      other.externalSystem == externalSystem &&
      other.externalReference == externalReference;

  @override
  int get hashCode =>
      Object.hash(value, source, verifiedAt, externalSystem, externalReference);

  @override
  String toString() => '$value [${source.label}]';
}
