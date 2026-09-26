import 'package:flutter/material.dart';

import '../../../../core/design/brand_assets.dart';
import '../../../../core/design/theme.dart';

/// The corporate brandmark.
///
/// Renders the supplied ONGC / MRPL asset ([BrandAssets.mrplLogo]). The asset
/// is a square with its own solid-green field, so it is drawn edge to edge
/// with only a small corner radius rather than being inset on a plate.
///
/// [assetPath] can be overridden, and a null path falls back to a neutral
/// monogram — which is what shipped before the licensed asset existed, kept so
/// the widget still renders in a context where the asset is unavailable rather
/// than throwing.
class MrplBrandmark extends StatelessWidget {
  const MrplBrandmark({
    this.size = 56,
    this.assetPath = BrandAssets.mrplLogo,
    this.cornerRadius,
    super.key,
  });

  /// A monogram stand-in, for contexts without the licensed asset.
  const MrplBrandmark.placeholder({
    this.size = 56,
    this.cornerRadius,
    super.key,
  }) : assetPath = null;

  /// Edge length of the square plate.
  final double size;

  /// The bundled corporate mark. Null renders the monogram fallback.
  final String? assetPath;

  /// Defaults to a radius proportional to [size].
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final path = assetPath;

    return Semantics(
      label: 'Mangalore Refinery and Petrochemicals Limited',
      image: true,
      // A logo does not scale with the reader's text-size setting: the real
      // asset will be an image, and the placeholder must behave the same way.
      // Without this the monogram grows past its plate at large text scales.
      child: MediaQuery.withNoTextScaling(
        child: SizedBox(
          width: size,
          height: size,
          child: path == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: corporate.surface,
                    borderRadius: BorderRadius.circular(
                      cornerRadius ?? size * 0.10,
                    ),
                    border: Border.all(
                      color: corporate.primary,
                      width: size * 0.045,
                    ),
                  ),
                  child: _Monogram(size: size),
                )
              // The supplied asset carries its own solid green field edge to
              // edge, so it is clipped rather than inset on a plate. Padding
              // it onto a white card would print a keyline the mark does not
              // have.
              : ClipRRect(
                  borderRadius: BorderRadius.circular(
                    cornerRadius ?? size * 0.10,
                  ),
                  child: Image.asset(
                    path,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
        ),
      ),
    );
  }
}

/// A restrained monogram: the company initials over a horizon rule.
///
/// Deliberately generic. It is a stand-in that reads as a corporate plate
/// without imitating any real mark.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'MRPL',
            style: TextStyle(
              fontFamily: 'IBMPlexSans',
              fontSize: size * 0.225,
              height: 1.0,
              fontWeight: FontWeight.w700,
              letterSpacing: size * 0.008,
              color: corporate.primary,
            ),
          ),
          SizedBox(height: size * 0.06),
          Container(
            width: size * 0.42,
            height: size * 0.035,
            decoration: BoxDecoration(
              color: corporate.accent,
              borderRadius: BorderRadius.circular(size * 0.02),
            ),
          ),
        ],
      ),
    );
  }
}
