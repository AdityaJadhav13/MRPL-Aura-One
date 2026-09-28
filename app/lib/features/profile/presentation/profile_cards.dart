import 'package:flutter/material.dart';

import '../../../core/components/corporate.dart';
import '../../../core/components/identity.dart';
import '../../../core/design/brand_assets.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';

/// Worker Profile building blocks (Worker directive §6–§9).
///
/// These are the rich Home's cards, moved here: the Profile is now the
/// authoritative place for who the worker is and what they are assigned to,
/// and Home is left to say only what state the DoseBand is in.

const String _notRecorded = 'Not recorded';

/// The refinery header of every profile screen: organisation, product and
/// the site's safety message over the photograph. Solid scrim, no gradient.
class ProfileHero extends StatelessWidget {
  const ProfileHero({super.key});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, c) => _build(context, c.maxWidth));

  Widget _build(BuildContext context, double width) {
    final corporate = context.corporate;
    final t = context.type;
    // Side by side while both lockups fit on a line each; above 130 % text
    // or on the narrowest phones, one under the other. Measured from the
    // layout, not MediaQuery: a nested MediaQuery can report no size.
    final stacked =
        width < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final organisation = Text(
      'Mangalore Refinery\nand Petrochemicals Limited',
      style: t.caption.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
    Widget product(CrossAxisAlignment align, TextAlign textAlign) => Column(
      crossAxisAlignment: align,
      children: [
        Semantics(
          header: true,
          child: Text(
            'DoseBand',
            style: t.heading.copyWith(color: Colors.white, height: 1.1),
          ),
        ),
        Text(
          'OCCUPATIONAL\nEXPOSURE MONITORING',
          textAlign: textAlign,
          style: t.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.86),
            fontSize: 9,
            letterSpacing: 0.8,
            height: 1.3,
          ),
        ),
      ],
    );

    // No fixed height: the status-bar inset, the text scale and the overlap
    // of the identity card all vary, and a constant tuned on one screen
    // overflows on the next.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 176),
        child: Stack(
          children: [
            // Dark ground under the photograph, so white type still lands on a
            // dark field if the asset is slow to decode.
            const Positioned.fill(child: ColoredBox(color: Neutral.l20)),
            Positioned.fill(
              child: ExcludeSemantics(
                child: Image.asset(
                  BrandAssets.refineryBackdrop,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.2),
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            Positioned.fill(child: ColoredBox(color: context.product.scrim)),
            SafeArea(
              bottom: false,
              child: Padding(
                // The bottom inset clears the identity card, which lifts into
                // the header.
                padding: const EdgeInsets.fromLTRB(
                  Space.base,
                  Space.sm,
                  Space.base,
                  Space.xl + Space.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (stacked) ...[
                      product(CrossAxisAlignment.start, TextAlign.left),
                      const SizedBox(height: Space.sm),
                      organisation,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: organisation),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            flex: 5,
                            child: product(
                              CrossAxisAlignment.end,
                              TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: Space.lg),
                    Container(
                      height: 4,
                      width: 44,
                      decoration: BoxDecoration(
                        color: corporate.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      'Safe People',
                      style: t.display.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      'Sustainable Operations',
                      style: t.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The approved profile layout: the refinery header, and the content lifted
/// into it so the identity card overlaps the photograph. Used by the
/// worker's Profile and by every workspace's More screen, so each person's
/// profile looks the same whatever their role.
class ProfileLayout extends StatelessWidget {
  const ProfileLayout({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.corporate.surfaceMuted,
    body: ListView(
      // No top padding: the header runs under the status bar. The bottom
      // inset is kept, so the last card clears a home indicator; inside a
      // workspace shell the navigation already occupies its own slot and
      // the inset reported here is zero.
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      children: [
        const ProfileHero(),
        // Lifted by the same amount the header leaves below its text, so
        // the identity card overlaps the photograph and no gap opens.
        Transform.translate(
          offset: const Offset(0, -24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.maxContentWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.screenGutter,
                  0,
                  Gaps.screenGutter,
                  Space.base,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Who is signed in: photograph (or initials until an approved one is
/// supplied), name, worker type and ID, company, and where the records are.
class WorkerIdentityCard extends StatelessWidget {
  const WorkerIdentityCard({
    required this.name,
    required this.typeAndId,
    required this.company,
    this.photo,
    super.key,
  });

  final String? name;
  final String? typeAndId;
  final String? company;

  /// An approved photograph of this person, once one is supplied. Until
  /// then the avatar shows initials — never a stock or generated face.
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return Semantics(
      // Everything the card shows, since its children are excluded.
      label: [
        name ?? 'No worker signed in',
        ?typeAndId,
        ?company,
        'Records stored on this phone, not synced',
      ].join('. '),
      excludeSemantics: true,
      child: InfoCard(
        child: LayoutBuilder(
          builder: (context, c) {
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? 'No worker signed in',
                  style: t.heading.copyWith(color: corporate.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (typeAndId != null)
                  Text(
                    typeAndId!,
                    style: t.caption.copyWith(color: corporate.textSecondary),
                  ),
                if (company != null)
                  Text(
                    company!,
                    style: t.caption.copyWith(color: corporate.textSecondary),
                  ),
              ],
            );
            const avatarSize = 48.0;
            final avatar = IdentityAvatar(
              name: name ?? '?',
              photo: photo,
              size: avatarSize,
            );
            // Avatar and badge on one line, the details under them, once a
            // row would squeeze the name to a few characters.
            if (c.maxWidth < 240 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [avatar, const Spacer(), const _StorageBadge()],
                  ),
                  const SizedBox(height: Space.sm),
                  details,
                ],
              );
            }
            // On a compact phone the badge goes under the details rather
            // than taking a column from them.
            final compact = c.maxWidth < 340;
            return Row(
              children: [
                avatar,
                const SizedBox(width: Space.md),
                Expanded(
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            details,
                            const SizedBox(height: Space.xs),
                            const _StorageBadge(inline: true),
                          ],
                        )
                      : details,
                ),
                if (!compact) ...[
                  const SizedBox(width: Space.sm),
                  const _StorageBadge(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Where the worker's records are: on this phone, not synced — the only
/// sync state this build can produce.
class _StorageBadge extends StatelessWidget {
  const _StorageBadge({this.inline = false});

  /// One line, "Local · Not synced", under the details.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    if (inline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smartphone_outlined,
            size: 14,
            color: corporate.textSecondary,
          ),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(
              'Local · Not synced',
              style: t.caption.copyWith(color: corporate.textSecondary),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smartphone_outlined,
              size: 14,
              color: corporate.textSecondary,
            ),
            const SizedBox(width: Space.xs),
            Text(
              'Local',
              style: t.caption.copyWith(
                color: corporate.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          'Not synced',
          style: t.caption.copyWith(color: corporate.textSecondary),
        ),
      ],
    );
  }
}

/// A titled white card with an optional action link — the approved Home's
/// card shape.
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    // Every header row is one touch target tall, action or not, so card
    // titles sit at the same height; the card's top padding gives back what
    // the row adds.
    return InfoCard(
      padding: const EdgeInsets.fromLTRB(
        Space.base,
        Space.xs,
        Space.sm,
        Space.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(height: kMinInteractive),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title.toUpperCase(),
                    semanticsLabel: title,
                    style: t.caption.copyWith(
                      color: corporate.textSecondary,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (actionLabel != null)
                InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(CorporateRadii.sm),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: kMinInteractive,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel!,
                            style: t.body.copyWith(
                              color: corporate.primaryDeep,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: corporate.primaryDeep,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Label/value pairs in two columns on a phone, one at large text.
class ProfileFieldGrid extends StatelessWidget {
  const ProfileFieldGrid({required this.fields, super.key});

  /// (label, value, monospace)
  final List<(String, String, bool)> fields;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return LayoutBuilder(
      builder: (context, c) {
        final columns =
            c.maxWidth < 260 || MediaQuery.textScalerOf(context).scale(1) > 1.5
            ? 1
            : 2;
        final width = (c.maxWidth - Space.base * (columns - 1)) / columns;
        return Wrap(
          spacing: Space.base,
          runSpacing: Space.md,
          children: [
            for (final (label, value, mono) in fields)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: t.caption.copyWith(color: corporate.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: (mono ? t.readoutSmall : t.body).copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Label/value rows for the work context card.
class ProfileContextRows extends StatelessWidget {
  const ProfileContextRows({required this.rows, this.footnote, super.key});

  /// (label, value, monospace)
  final List<(String, String, bool)> rows;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final narrow = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value, mono) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: t.caption.copyWith(
                          color: corporate.textSecondary,
                        ),
                      ),
                      Text(
                        value,
                        style: (mono ? t.readoutSmall : t.body).copyWith(
                          color: corporate.textPrimary,
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 104,
                        child: Text(
                          label,
                          style: t.body.copyWith(
                            color: corporate.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: (mono ? t.readoutSmall : t.body).copyWith(
                            color: corporate.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        if (footnote != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            footnote!,
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// "Not recorded", for fields with no value.
String orNotRecorded(String? v) =>
    (v == null || v.trim().isEmpty) ? _notRecorded : v;
