import 'package:flutter/material.dart';

import '../../../core/components/corporate.dart';
import '../../../core/components/identity.dart';
import '../../../core/components/markers.dart';
import '../../../core/design/brand_assets.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../domain/home_presentation.dart';

/// Worker Home building blocks, recovered from the approved Home design and
/// rebound to the current state model (PRODUCT BUILD v1 corrective §3C).
///
/// The approved design supplied the hierarchy — refinery header, overlapping
/// identity card, Today's shift, Work context, a strong monitoring card, one
/// primary action. What it also had, and does not come back: a DEMO chip on
/// every row, a supervisor string invented by the demo data, a card whose
/// content ignored the workflow state.

const String _notRecorded = 'Not recorded';

/// The refinery header: organisation, product and the site's safety message
/// over the photograph. Solid scrim, no gradient.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

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

/// Who is signed in, on the card that overlaps the header. Tapping opens the
/// profile.
class WorkerIdentityCard extends StatelessWidget {
  const WorkerIdentityCard({
    required this.name,
    required this.typeAndId,
    required this.company,
    required this.onOpenProfile,
    super.key,
  });

  final String? name;
  final String? typeAndId;
  final String? company;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return Semantics(
      label: 'Account and profile: ${name ?? 'worker'}',
      button: true,
      excludeSemantics: true,
      child: InfoCard(
        onTap: onOpenProfile,
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
            final avatar = IdentityAvatar(name: name ?? '?', size: avatarSize);
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
class HomeSectionCard extends StatelessWidget {
  const HomeSectionCard({
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
class HomeFieldGrid extends StatelessWidget {
  const HomeFieldGrid({required this.fields, super.key});

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
class HomeContextRows extends StatelessWidget {
  const HomeContextRows({required this.rows, this.footnote, super.key});

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

/// The monitoring card — Home's anchor. One solid brand fill; its content is
/// whatever the monitoring session says. "Monitoring active" is a workflow
/// state, never a statement about the air: the card shows no ppm, because a
/// passive DoseBand measures nothing until it is read.
class MonitoringStatusCard extends StatelessWidget {
  const MonitoringStatusCard({
    required this.presentation,
    required this.badgeId,
    required this.simulated,
    required this.startedAt,
    required this.endedAt,
    required this.elapsed,
    required this.work,
    super.key,
  });

  final HomePresentation presentation;
  final String? badgeId;
  final bool simulated;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Monitoring duration; null when it cannot be established.
  final Duration? elapsed;

  /// Work area · shift, when recorded.
  final String? work;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final stage = presentation.stage;
    // Solid brand fill once there is a period to show; before that, a white
    // card with brand accents, so Home does not open on two stacked green
    // blocks (card and action) with nothing being monitored.
    final strong = stage != HomeStage.noDoseBand;
    final fg = strong ? Colors.white : corporate.textPrimary;
    final dim = strong
        ? Colors.white.withValues(alpha: 0.82)
        : corporate.textSecondary;
    final icon = switch (stage) {
      HomeStage.noDoseBand => Icons.qr_code_2,
      HomeStage.doseBandAssigned => Icons.badge_outlined,
      HomeStage.monitoringActive => Icons.sensors,
      HomeStage.readyForFinalRead => Icons.document_scanner_outlined,
      HomeStage.completed => Icons.task_alt,
      HomeStage.requiresAttention => Icons.schedule,
    };
    // As in the approved design: the orange marker is for a period that is
    // running, and nothing else — on other states it only repeated the title.
    final pill = stage == HomeStage.monitoringActive ? 'ACTIVE' : null;

    final showsBand = badgeId != null && stage != HomeStage.noDoseBand;
    final timing = switch (stage) {
      HomeStage.monitoringActive || HomeStage.requiresAttention => (
        Fmt.duration(elapsed),
        startedAt == null ? 'Not started' : 'Started ${Fmt.clock(startedAt!)}',
      ),
      HomeStage.readyForFinalRead || HomeStage.completed => (
        Fmt.duration(elapsed),
        endedAt == null ? '' : 'Ended ${Fmt.clock(endedAt!)}',
      ),
      _ => (null, null),
    };

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.base),
        decoration: BoxDecoration(
          color: strong ? corporate.primaryDeep : corporate.surface,
          borderRadius: BorderRadius.circular(CorporateRadii.lg),
          border: strong ? null : Border.all(color: corporate.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: strong
                        ? Colors.white.withValues(alpha: 0.16)
                        : corporate.primaryMuted,
                    borderRadius: BorderRadius.circular(CorporateRadii.sm),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: strong ? Colors.white : corporate.primary,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    presentation.title.toUpperCase(),
                    semanticsLabel: presentation.title,
                    style: t.label.copyWith(
                      color: fg,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (pill != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: corporate.accent,
                      borderRadius: BorderRadius.circular(CorporateRadii.sm),
                    ),
                    child: Text(
                      pill,
                      style: t.caption.copyWith(
                        color: Colors.white,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (simulated) ...[
              const SizedBox(height: Space.md),
              const SimulationMarker(),
            ],
            if (showsBand || timing.$1 != null) ...[
              const SizedBox(height: Space.base),
              LayoutBuilder(
                builder: (context, c) {
                  final left = timing.$1 == null
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                timing.$1!,
                                maxLines: 1,
                                style: t.readoutLarge.copyWith(color: fg),
                              ),
                            ),
                            if (timing.$2 != null && timing.$2!.isNotEmpty)
                              Text(
                                timing.$2!,
                                style: t.caption.copyWith(color: dim),
                              ),
                          ],
                        );
                  final right = !showsBand
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DoseBand',
                              style: t.caption.copyWith(color: dim),
                            ),
                            Text(
                              badgeId!,
                              style: t.readoutSmall.copyWith(color: fg),
                            ),
                          ],
                        );
                  final stacked =
                      c.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3;
                  if (left == null) return right!;
                  if (right == null) return left;
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        left,
                        const SizedBox(height: Space.md),
                        right,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      Container(
                        width: 1,
                        height: 48,
                        color: strong
                            ? Colors.white.withValues(alpha: 0.24)
                            : corporate.border,
                        margin: const EdgeInsets.symmetric(
                          horizontal: Space.base,
                        ),
                      ),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
            ],
            if (work != null && stage != HomeStage.noDoseBand) ...[
              const SizedBox(height: Space.md),
              Text(work!, style: t.caption.copyWith(color: dim)),
            ],
            const SizedBox(height: Space.md),
            Text(presentation.message, style: t.body.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

/// "Not recorded", for fields with no value.
String orNotRecorded(String? v) =>
    (v == null || v.trim().isEmpty) ? _notRecorded : v;
