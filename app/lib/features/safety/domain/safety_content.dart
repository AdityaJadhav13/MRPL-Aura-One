import 'package:flutter/foundation.dart';

/// Where a piece of safety information came from.
///
/// ## Why safety copy needs its own provenance model
///
/// `DataOrigin` answers "is this row real?" for a record. This answers a
/// sharper question for text a worker may act on: **who is telling me this?**
///
/// A general fact about hydrogen sulphide, a DoseBand product limitation, and
/// an MRPL procedure carry completely different authority. Blended into one
/// block of prose they become indistinguishable, and generated placeholder
/// copy starts reading like a site instruction. That is the failure this
/// enum exists to prevent.
enum SafetyContentSource {
  /// Widely published, non-controversial description — what H₂S is, how a
  /// passive badge works in principle. Not specific to any site.
  general(
    'General information',
    'Widely published information. Not specific to your site.',
  ),

  /// A statement about this product: what DoseBand measures, what it refuses,
  /// what it cannot do. DoseBand is the authority on itself and on nothing
  /// else.
  product(
    'DoseBand',
    'A statement about this product and what it can and cannot do.',
  ),

  /// Content that must come from the organisation — procedures, limits, PPE
  /// requirements, emergency directories. **Never authored here.**
  organisation(
    'Organisation',
    'Issued by your organisation. DoseBand displays it and does not author '
        'it.',
  ),

  /// A published standard or regulation, cited rather than reproduced.
  publicStandard(
    'Public standard',
    'A published standard, cited rather than reproduced here.',
  ),

  /// Demonstration content, so a library screen has something in it during
  /// review. Describes no real document.
  demo('Demo', 'Demonstration content. Describes no real document.'),

  /// The organisation has not supplied this, and DoseBand will not invent it.
  notConfigured(
    'Not configured',
    'Your organisation has not supplied this. DoseBand does not invent it.',
  );

  const SafetyContentSource(this.label, this.explanation);

  final String label;
  final String explanation;

  /// Whether this content carries organisational authority.
  ///
  /// Only [organisation] does. A test asserts that nothing DoseBand authors is
  /// ever marked this way — the whole point is that a worker can tell a
  /// product statement from a site instruction.
  bool get isOrganisational => this == SafetyContentSource.organisation;
}

/// A safety document in a library screen.
///
/// Deliberately carries no body text. DoseBand does not hold the contents of a
/// safety data sheet or a procedure, and reproducing one from memory would be
/// a hazard in its own right: an out-of-date SDS read as current is worse than
/// no SDS at all.
@immutable
final class SafetyDocument {
  const SafetyDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.source,
    this.substance,
    this.revision,
    this.offline = OfflineState.notAvailable,
  });

  final String id;
  final String title;
  final SafetyCategory category;
  final SafetyContentSource source;

  /// For safety data sheets.
  final String? substance;

  /// The revision the organisation issued, where it is known. Null renders as
  /// unavailable — a made-up revision number is the kind of detail that makes
  /// a fabricated document credible.
  final String? revision;

  final OfflineState offline;
}

enum SafetyCategory {
  hydrogenSulphide('H₂S'),
  gasSafety('Gas safety'),
  doseBand('DoseBand'),
  permitAndJsa('PTW / JSA'),
  generalSafety('General safety'),
  safetyDataSheet('Safety data sheet');

  const SafetyCategory(this.label);

  final String label;
}

/// Whether a document is available without connectivity.
///
/// `downloaded` is never produced today: nothing downloads, because no
/// document repository is connected. The state exists so the screen is built
/// around the real vocabulary rather than retrofitted later.
enum OfflineState {
  downloaded('Downloaded'),
  available('Available to download'),
  updateAvailable('Update available'),
  failed('Download failed'),
  notAvailable('Not available offline');

  const OfflineState(this.label);

  final String label;
}
