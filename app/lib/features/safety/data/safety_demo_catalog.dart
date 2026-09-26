import '../domain/safety_content.dart';

/// Demonstration safety documents.
///
/// ## Rules these entries obey
///
/// * **No realistic MRPL document numbers.** Every identifier begins `DEMO-`.
///   A plausible-looking procedure number is what makes a fabricated document
///   credible, and a worker quoting one back to a supervisor is the failure.
/// * **No body text.** These are catalogue entries, not documents. DoseBand
///   does not hold the contents of a safety data sheet or a site procedure.
/// * **Nothing is marked [SafetyContentSource.organisation].** Nothing here
///   came from an organisation, so nothing here may carry that authority.
/// * **Nothing is downloaded.** No repository is connected, so no entry claims
///   to be available offline.
///
/// Kept in one file so "what safety content is fake?" has a one-word answer,
/// and so the day a document repository is connected there is exactly one
/// thing to delete.
abstract final class SafetyDemoCatalog {
  /// Toolbox and reference material.
  static List<SafetyDocument> toolboxResources() => const [
    SafetyDocument(
      id: 'DEMO-TBT-001',
      title: 'Recognising H₂S exposure risk on the unit',
      category: SafetyCategory.hydrogenSulphide,
      source: SafetyContentSource.demo,
    ),
    SafetyDocument(
      id: 'DEMO-TBT-002',
      title: 'Gas detector checks before entering a work area',
      category: SafetyCategory.gasSafety,
      source: SafetyContentSource.demo,
    ),
    SafetyDocument(
      id: 'DEMO-TBT-003',
      title: 'Wearing and returning a DoseBand badge',
      category: SafetyCategory.doseBand,
      source: SafetyContentSource.demo,
    ),
    SafetyDocument(
      id: 'DEMO-TBT-004',
      title: 'What a dosimeter reading does and does not tell you',
      category: SafetyCategory.doseBand,
      source: SafetyContentSource.demo,
    ),
    SafetyDocument(
      id: 'DEMO-TBT-005',
      title: 'Attaching exposure monitoring to a permit',
      category: SafetyCategory.permitAndJsa,
      source: SafetyContentSource.demo,
    ),
    SafetyDocument(
      id: 'DEMO-TBT-006',
      title: 'Reporting a near miss',
      category: SafetyCategory.generalSafety,
      source: SafetyContentSource.demo,
    ),
  ];

  /// Safety data sheets.
  ///
  /// Substances a refinery genuinely handles, with **demonstration** entries
  /// only. No revision numbers: a revision is exactly the detail that makes an
  /// invented sheet look authoritative, and getting it wrong on an SDS is a
  /// hazard.
  static List<SafetyDocument> safetyDataSheets() => const [
    SafetyDocument(
      id: 'DEMO-SDS-001',
      title: 'Hydrogen sulphide — safety data sheet',
      substance: 'Hydrogen sulphide (H₂S)',
      category: SafetyCategory.safetyDataSheet,
      source: SafetyContentSource.demo,
    ),
    SafetyDocument(
      id: 'DEMO-SDS-002',
      title: 'Sulphur dioxide — safety data sheet',
      substance: 'Sulphur dioxide (SO₂)',
      category: SafetyCategory.safetyDataSheet,
      source: SafetyContentSource.demo,
    ),
    SafetyDocument(
      id: 'DEMO-SDS-003',
      title: 'Crude oil — safety data sheet',
      substance: 'Crude oil',
      category: SafetyCategory.safetyDataSheet,
      source: SafetyContentSource.demo,
    ),
    SafetyDocument(
      id: 'DEMO-SDS-004',
      title: 'Liquefied petroleum gas — safety data sheet',
      substance: 'LPG',
      category: SafetyCategory.safetyDataSheet,
      source: SafetyContentSource.demo,
    ),
    SafetyDocument(
      id: 'DEMO-SDS-005',
      title: 'Amine solution — safety data sheet',
      substance: 'Amine solution',
      category: SafetyCategory.safetyDataSheet,
      source: SafetyContentSource.demo,
    ),
  ];

  /// Everything a document library could list.
  static List<SafetyDocument> allDocuments() => [
    ...toolboxResources(),
    ...safetyDataSheets(),
  ];

  /// PPE categories a site would configure.
  ///
  /// The categories are general; the **requirements** are deliberately absent.
  /// What PPE a job needs depends on the job, the area and the organisation's
  /// assessment of both, and a list invented by an app is exactly the kind of
  /// thing that gets trusted and should not be.
  static List<String> ppeCategories() => const [
    'Head',
    'Eye and face',
    'Respiratory',
    'Hearing',
    'Hands',
    'Body',
    'Feet',
  ];
}
