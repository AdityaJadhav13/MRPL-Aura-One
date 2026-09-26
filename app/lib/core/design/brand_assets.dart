/// Bundled corporate brand assets.
///
/// Supplied by the project owner and declared in `pubspec.yaml`. They are
/// **bundled, never fetched**: the authentication flow has to work in a plant
/// with no signal, so there is no network image anywhere in it.
///
/// Paths live here rather than inline so a renamed file is one edit, and so no
/// widget carries a string literal pointing at a binary.
abstract final class BrandAssets {
  /// The ONGC / MRPL corporate mark. Square, solid-green field.
  static const String mrplLogo = 'assets/images/MRPL Logo.png';

  /// Refinery at dusk, portrait. The splash backdrop.
  static const String refineryBackdrop = 'assets/images/MRPL Background.png';
}
