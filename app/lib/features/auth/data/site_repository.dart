import '../../../core/design/brand_assets.dart';
import '../domain/auth_models.dart';

/// Where the selectable sites come from.
///
/// An interface, and a seeded implementation behind it, so that presentation
/// never holds the list. When site configuration arrives from a real source,
/// the screen does not change.
abstract interface class SiteRepository {
  List<Site> sites();
}

/// Prototype site configuration.
///
/// **NOT FETCHED FROM ANY MRPL SYSTEM.** These are seed values for the
/// prototype, describing locations MRPL is publicly associated with. They are
/// not a directory, they are not authoritative, and no claim is made that a
/// given worker may be assigned to any of them. Replace wholesale when real
/// site configuration exists.
final class SeededSiteRepository implements SiteRepository {
  const SeededSiteRepository();

  @override
  List<Site> sites() => const <Site>[
    Site(
      id: 'mangalore-refinery',
      name: 'Mangalore Refinery',
      locality: 'Katipalla, Mangalore\nKarnataka, India',
      kind: SiteKind.refinery,
      // The one site with a supplied photograph. The rest fall back to an
      // illustrated plate until images are provided.
      imageAsset: BrandAssets.refineryBackdrop,
    ),
    Site(
      id: 'corporate-office',
      name: 'Corporate Office',
      locality: 'Mangalore, Karnataka',
      kind: SiteKind.office,
    ),
    Site(
      id: 'retail-hiq',
      name: 'MRPL Retail (HiQ)',
      locality: 'Various Locations',
      kind: SiteKind.retail,
    ),
    Site(
      id: 'projects-site',
      name: 'Projects Site',
      locality: 'Mangalore, Karnataka',
      kind: SiteKind.project,
    ),
  ];
}
