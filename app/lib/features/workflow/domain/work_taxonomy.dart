import 'package:flutter/foundation.dart';

/// The site a monitored period took place at, as it was named at the time.
///
/// A light copy rather than a reference to the authentication feature's `Site`:
/// this is provenance, so the name is frozen into the record. If a site is
/// renamed next year, an exposure record from today must still say what it said
/// today.
@immutable
final class SiteRef {
  const SiteRef({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is SiteRef && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// An organisational department.
///
/// **Prototype configuration.** The names below are departments MRPL is
/// publicly associated with; this is not a directory pulled from any MRPL
/// system, it is not authoritative, and nothing here asserts that a given
/// worker belongs to any of them.
@immutable
final class Department {
  const Department({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) => other is Department && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A work area within a site.
///
/// **Demonstration configuration.** Labels are suffixed "— Demo area" so a
/// screenshot cannot be mistaken for real MRPL area configuration.
///
/// Deliberately absent: internal MRPL area codes, restricted-zone
/// classifications, and any H₂S risk or concentration banding. Selecting
/// "Sulphur Recovery Unit" says where the work is. It says **nothing** about
/// what the atmosphere contains — inferring one from the other is exactly the
/// kind of fabricated measurement this project exists to avoid.
@immutable
final class WorkArea {
  const WorkArea({
    required this.id,
    required this.name,
    required this.siteId,
    this.active = true,
  });

  final String id;
  final String name;

  /// The site this area belongs to. Areas are filtered by the selected site,
  /// so a worker cannot attach a refinery unit to the corporate office.
  final String siteId;

  /// Retired areas stay in configuration so that historical records still
  /// resolve, but are not offered for new selections.
  final bool active;

  @override
  bool operator ==(Object other) => other is WorkArea && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A work shift.
///
/// **Prototype configuration.** MRPL's actual shift scheduling system is not
/// known to this project and is not modelled here.
///
/// A shift is context — it says which work period the monitoring belongs to. It
/// is **not** used to compute exposure duration. The monitoring timestamps are
/// the only authority on the exposure window; a badge worn for three hours of
/// an eight-hour shift covers three hours, and no shift definition may be used
/// to extrapolate that to eight.
@immutable
final class WorkShift {
  const WorkShift({required this.id, required this.name, this.window});

  final String id;
  final String name;

  /// A human-readable window such as "06:00–14:00", for display only. Null
  /// where the configuration does not state one. Never parsed, never used in
  /// any calculation.
  final String? window;

  @override
  bool operator ==(Object other) => other is WorkShift && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A category of Permit to Work.
///
/// **Prototype configuration, not claimed to be exhaustive or current.** The
/// permit system belongs to MRPL; DoseBand records which category a worker says
/// their permit falls under, and does not validate it.
@immutable
final class PtwType {
  const PtwType({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) => other is PtwType && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
