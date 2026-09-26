import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../domain/auth_models.dart';

/// Shared chrome for a selectable card.
///
/// Site and role cards differ in content, not in behaviour, and giving them
/// one shell is what keeps radius, border weight, padding and selected state
/// identical between the two screens.
class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;

    void handleTap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      // The label already reads the name and description, so the card
      // announces once as a single control instead of spelling its own
      // contents out a second time. The tap action is declared here rather
      // than inherited, because excluding the children's semantics also
      // excludes the gesture detector's.
      excludeSemantics: true,
      onTap: handleTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? corporate.selectedFill : corporate.surface,
            borderRadius: BorderRadius.circular(CorporateRadii.lg),
            border: Border.all(
              color: selected ? corporate.selectedBorder : corporate.border,
              width: selected ? 1.8 : 1,
            ),
          ),
          padding: const EdgeInsets.all(Space.md),
          child: child,
        ),
      ),
    );
  }
}

/// The selection indicator: a filled check when chosen, an empty ring when not.
///
/// Shape changes as well as colour, so selection does not depend on hue.
class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? corporate.selectedBorder : Colors.transparent,
        border: Border.all(
          color: selected ? corporate.selectedBorder : corporate.border,
          width: 1.6,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 16, color: corporate.textOnPrimary)
          : null,
    );
  }
}

/// The site card's thumbnail.
///
/// Uses the site's photograph when one has been supplied. Where none has, it
/// draws an illustrated plate for the site kind — a refinery, a tower block, a
/// forecourt canopy, a structural frame — rather than a flat icon, so the row
/// of cards reads consistently while images are still missing.
class _SiteThumbnail extends StatelessWidget {
  const _SiteThumbnail({required this.site});

  final Site site;

  static const double _width = 74;
  static const double _height = 86;

  @override
  Widget build(BuildContext context) {
    final asset = site.imageAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(CorporateRadii.md),
      child: SizedBox(
        width: _width,
        height: _height,
        child: asset != null
            ? Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.45),
                filterQuality: FilterQuality.medium,
              )
            : CustomPaint(
                painter: _SiteIllustration(
                  kind: site.kind,
                  corporate: context.corporate,
                ),
              ),
      ),
    );
  }
}

/// A small painted scene per site kind.
class _SiteIllustration extends CustomPainter {
  _SiteIllustration({required this.kind, required this.corporate});

  final SiteKind kind;
  final MrplCorporateColors corporate;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[const Color(0xFFBFD4E3), const Color(0xFFE8EFF3)],
        ).createShader(rect),
    );

    final ground = Paint()..color = const Color(0xFFD8DEDB);
    final solid = Paint()..color = const Color(0xFF6E7B75);
    final light = Paint()..color = const Color(0xFF98A5A0);

    switch (kind) {
      case SiteKind.office:
        // A glazed tower. Horizontal bands ALONE read as ruled paper, so the
        // glazing is a grid: mullions both ways, with the upper panes lighter
        // to suggest sky reflected off the top of the facade.
        canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14), ground);
        final body = Rect.fromLTWH(w * 0.14, h * 0.18, w * 0.60, h * 0.68);
        canvas.drawRect(body, Paint()..color = const Color(0xFF7E93A2));

        const columns = 4;
        const floors = 7;
        for (var c = 0; c < columns; c++) {
          for (var f = 0; f < floors; f++) {
            canvas.drawRect(
              Rect.fromLTWH(
                body.left + body.width * (c + 0.18) / columns,
                body.top + body.height * (f + 0.20) / floors,
                body.width * 0.64 / columns,
                body.height * 0.58 / floors,
              ),
              Paint()
                ..color = f < 2
                    ? const Color(0xFFD3E2EC)
                    : const Color(0xFFB2C6D4),
            );
          }
        }

        // Parapet, and a slimmer service core alongside so the silhouette is
        // stepped rather than a single rectangle.
        canvas.drawRect(
          Rect.fromLTWH(
            body.left - w * 0.02,
            body.top - h * 0.03,
            body.width + w * 0.04,
            h * 0.03,
          ),
          solid,
        );
        canvas.drawRect(
          Rect.fromLTWH(body.right, h * 0.36, w * 0.12, h * 0.50),
          light,
        );
      case SiteKind.retail:
        // A forecourt canopy on columns, with a pump beneath.
        canvas.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), ground);
        canvas.drawRect(
          Rect.fromLTWH(w * 0.06, h * 0.30, w * 0.88, h * 0.10),
          Paint()..color = corporate.primary,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.06, h * 0.40, w * 0.88, h * 0.03),
          Paint()..color = corporate.accent,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.16, h * 0.43, w * 0.06, h * 0.32),
          light,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.78, h * 0.43, w * 0.06, h * 0.32),
          light,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.42, h * 0.52, w * 0.16, h * 0.23),
          solid,
        );
      case SiteKind.project:
        // Structural steel under construction.
        canvas.drawRect(Rect.fromLTWH(0, h * 0.76, w, h * 0.24), ground);
        final frame = Paint()
          ..color = const Color(0xFFA9763F)
          ..strokeWidth = h * 0.030
          ..style = PaintingStyle.stroke;
        for (var i = 0; i < 4; i++) {
          final x = w * (0.16 + i * 0.22);
          canvas.drawLine(Offset(x, h * 0.24), Offset(x, h * 0.78), frame);
        }
        for (var i = 0; i < 4; i++) {
          final y = h * (0.28 + i * 0.16);
          canvas.drawLine(Offset(w * 0.12, y), Offset(w * 0.90, y), frame);
        }
      case SiteKind.refinery:
      case SiteKind.terminal:
        // Columns and tanks, matching the plant vocabulary used elsewhere.
        canvas.drawRect(Rect.fromLTWH(0, h * 0.74, w, h * 0.26), ground);
        for (final spec in <List<double>>[
          <double>[0.14, 0.08, 0.40],
          <double>[0.30, 0.06, 0.56],
          <double>[0.46, 0.10, 0.34],
          <double>[0.64, 0.07, 0.50],
          <double>[0.80, 0.09, 0.42],
        ]) {
          canvas.drawRect(
            Rect.fromLTWH(
              w * spec[0],
              h * (0.74 - spec[2]),
              w * spec[1],
              h * spec[2],
            ),
            solid,
          );
        }
        canvas.drawRect(Rect.fromLTWH(0, h * 0.60, w, h * 0.014), light);
    }
  }

  @override
  bool shouldRepaint(_SiteIllustration oldDelegate) => oldDelegate.kind != kind;
}

/// A selectable work location.
class SelectableSiteCard extends StatelessWidget {
  const SelectableSiteCard({
    required this.site,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Site site;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return _SelectableCard(
      selected: selected,
      onTap: onTap,
      semanticLabel: '${site.name}. ${site.locality.replaceAll('\n', ', ')}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _SiteThumbnail(site: site),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  site.name,
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  site.locality,
                  style: t.caption.copyWith(
                    color: corporate.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          _SelectionIndicator(selected: selected),
        ],
      ),
    );
  }
}

/// A selectable application role.
class SelectableRoleCard extends StatelessWidget {
  const SelectableRoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppRole role;
  final bool selected;
  final VoidCallback onTap;

  /// Filled glyphs rather than outlines: at 34 points an outline icon reads as
  /// a thin smudge, and these sit directly on the card with no plate behind
  /// them, so weight is all they have.
  static IconData iconFor(AppRole role) => switch (role) {
    AppRole.worker => Icons.engineering,
    AppRole.hseOfficer => Icons.verified_user,
    AppRole.supervisor => Icons.groups,
    AppRole.management => Icons.bar_chart,
    AppRole.administrator => Icons.settings,
  };

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return _SelectableCard(
      selected: selected,
      onTap: onTap,
      semanticLabel: '${role.label}. ${role.description}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 52,
            child: Icon(
              iconFor(role),
              size: 34,
              // The worker is the role most people opening this app will be,
              // so it carries the accent; the rest are corporate green.
              color: role == AppRole.worker
                  ? corporate.accent
                  : corporate.primary,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  role.label,
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  role.description,
                  style: t.caption.copyWith(
                    color: corporate.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          // The chevron stays on the selected card, as in the approved design.
          // Selection is carried by the fill and the heavier border — both
          // non-colour cues — and announced through semantics.
          Icon(
            Icons.chevron_right,
            size: 22,
            color: selected
                ? corporate.selectedBorder
                : corporate.textSecondary,
          ),
        ],
      ),
    );
  }
}
