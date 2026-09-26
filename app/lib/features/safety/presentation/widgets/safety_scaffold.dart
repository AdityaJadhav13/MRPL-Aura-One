import 'package:flutter/material.dart';

import '../../../../core/components/corporate_navigation.dart';
import '../../../../core/design/brand_assets.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';

/// The standard page for the corporate (non-measurement) surfaces.
///
/// One scaffold for Safety, HSE, Reporting and Admin, so the product reads as
/// one application rather than four that happen to be installed together.
///
/// [showHero] puts the refinery photograph behind the title. It is used
/// sparingly — landing screens only. Behind a dense table it would cost
/// legibility and buy nothing, and repeating it on every screen turns a strong
/// image into wallpaper.
class SafetyScaffold extends StatelessWidget {
  const SafetyScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.showHero = false,
    this.actions,
    this.floatingAction,
    this.bottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showHero;
  final List<Widget>? actions;
  final Widget? floatingAction;

  /// Pinned below the header — a search field or filter row that must stay
  /// reachable while the list scrolls.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;

    return CorporateNavigationTheme(
      child: Scaffold(
        backgroundColor: corporate.surfaceMuted,
        floatingActionButton: floatingAction,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                title: title,
                subtitle: subtitle,
                showHero: showHero,
                actions: actions,
              ),
              if (bottom != null)
                Container(
                  color: corporate.surface,
                  padding: const EdgeInsets.fromLTRB(
                    Space.base,
                    0,
                    Space.base,
                    Space.md,
                  ),
                  child: bottom,
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.base,
                    Space.base,
                    Space.base,
                    Space.xl,
                  ),
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.showHero,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final bool showHero;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final sub = subtitle;
    final canPop = Navigator.of(context).canPop();

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Marked as a heading, not merely styled like one. A sighted user
        // gets the hierarchy from the type scale; a screen-reader user gets
        // it only from this flag, and without it there is no way to jump to
        // the top of a screen or tell a title from body text.
        Semantics(
          header: true,
          child: Text(
            title,
            style: t.display.copyWith(
              color: showHero ? Colors.white : corporate.textPrimary,
              fontSize: 26,
            ),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            style: t.caption.copyWith(
              color: showHero
                  ? Colors.white.withValues(alpha: 0.85)
                  : corporate.textSecondary,
            ),
          ),
        ],
      ],
    );

    final bar = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canPop)
          Padding(
            padding: const EdgeInsets.only(right: Space.xs),
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
              icon: Icon(
                Icons.arrow_back,
                color: showHero ? Colors.white : corporate.textPrimary,
              ),
            ),
          ),
        Expanded(child: titleBlock),
        ...?actions,
      ],
    );

    if (!showHero) {
      return Container(
        color: corporate.surface,
        padding: const EdgeInsets.fromLTRB(
          Space.base,
          Space.md,
          Space.base,
          Space.md,
        ),
        child: bar,
      );
    }

    // The hero sizes to its content rather than to a fixed height. At 200%
    // text a 168-pixel band overflows by about 60 pixels, and a title clipped
    // by its own decoration is a worse outcome than a taller band.
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      decoration: BoxDecoration(
        // A solid corporate ground *under* the photograph. The title is white,
        // so if the asset is missing, slow or fails to decode, it must still
        // land on dark green rather than on whatever the surface happens to
        // be — white-on-grey is unreadable, and a header that disappears is
        // worse than one without a picture.
        color: corporate.primaryDeep,
        image: DecorationImage(
          image: const AssetImage(BrandAssets.refineryBackdrop),
          fit: BoxFit.cover,
          // A deep corporate scrim. Without it the photograph's highlights
          // sit under white type at around 2:1 contrast in places.
          colorFilter: ColorFilter.mode(
            corporate.primaryDeep.withValues(alpha: 0.82),
            BlendMode.srcOver,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.base,
          Space.lg,
          Space.base,
          Space.base,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [bar],
        ),
      ),
    );
  }
}
