import 'package:flutter/material.dart';

import '../design/corporate_colors.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// Shared chrome for the corporate application surfaces.
///
/// Worker, Safety, HSE, Reporting and Admin are **one product**. These are the
/// pieces that make them look like it: the same card shape, the same section
/// rhythm, the same way of admitting that something is demonstration data.
///
/// Deliberately *not* used by the measurement surfaces. The scanner, capture
/// review and result screens stay chromatically neutral, because DoseBand
/// measures colour and a saturated green frame around a colorimetric badge is
/// a simultaneous-contrast problem, not a branding opportunity.

/// How much a screen's data can be trusted.
///
/// Every list, card and metric in the corporate surfaces declares one of these.
/// A screen that cannot say where its numbers came from is a screen that will
/// eventually be read as authoritative.
enum DataOrigin {
  /// Real application state — the workflow, the session, the local store.
  real,

  /// Purpose-built demonstration records. Looks like the real thing, is not.
  uiDemo,

  /// A future enterprise integration. No data exists at all.
  notConnected,
}

extension DataOriginPresentation on DataOrigin {
  /// Whether this origin earns a chip on an individual row or card.
  ///
  /// ## Why demonstration data does not
  ///
  /// APP-INTEGRATION-01 §33 classified every DEMO label. Fictional
  /// *organisational* seed data — a sample worker, a sample site, a sample
  /// register row — is Category B: it must be identifiable, but stamping
  /// "Demo" on every row made the product read as a mockup while adding no
  /// provenance the screen had not already stated. Every screen that shows
  /// such data carries one `DemoDataBanner`, and the Profile screen carries
  /// the environment indicator; the row chips repeated both. 30 of them were
  /// removed by this one getter.
  ///
  /// What is **not** affected, because it is Category A and must stay local:
  /// `notConnected` chips (a fictional enterprise connection would otherwise
  /// look real), and every SIMULATED marker on a quantity, which is a
  /// different component entirely and is never governed by this.
  bool get showsRowChip => this != DataOrigin.uiDemo;

  String get label => switch (this) {
    DataOrigin.real => 'Live',
    DataOrigin.uiDemo => 'Demo',
    DataOrigin.notConnected => 'Not connected',
  };

  IconData get icon => switch (this) {
    DataOrigin.real => Icons.check_circle_outline,
    DataOrigin.uiDemo => Icons.science_outlined,
    DataOrigin.notConnected => Icons.link_off,
  };
}

/// A small origin marker.
///
/// Neutral in every state. There is deliberately no green "Live" chip: green
/// reads as *good* or *safe*, and where this product is concerned the origin of
/// a number says nothing about whether the number is reassuring.
class OriginChip extends StatelessWidget {
  const OriginChip(this.origin, {this.compact = false, super.key});

  final DataOrigin origin;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Semantics(
      label: switch (origin) {
        DataOrigin.real => 'Live application data',
        DataOrigin.uiDemo => 'Demonstration data. Not from any MRPL system.',
        DataOrigin.notConnected =>
          'Not connected. No integration exists for this.',
      },
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? Space.xs : Space.sm,
          vertical: Space.xs,
        ),
        decoration: BoxDecoration(
          color: corporate.surfaceMuted,
          borderRadius: BorderRadius.circular(CorporateRadii.sm),
          border: Border.all(color: corporate.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(origin.icon, size: 12, color: corporate.textSecondary),
            if (!compact) ...[
              const SizedBox(width: Space.xs),
              Text(
                origin.label,
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A banner stating that a whole screen is demonstration data.
///
/// Used once per screen, at the top, rather than putting a chip on every row.
/// A screen covered in badges stops being read; a screen with one clear
/// statement at the top is understood.
class DemoDataBanner extends StatelessWidget {
  const DemoDataBanner({
    this.message =
        'This screen shows demonstration records. They are not from any MRPL '
        'system and describe no real worker or measurement.',
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        border: Border.all(color: corporate.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.science_outlined,
            size: 17,
            color: corporate.textSecondary,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEMONSTRATION DATA',
                  style: t.caption.copyWith(
                    color: corporate.textSecondary,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled section with optional trailing control.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.origin,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final DataOrigin? origin;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final sub = subtitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm, top: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: t.caption.copyWith(
                    color: corporate.textSecondary,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: t.caption.copyWith(color: corporate.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (origin?.showsRowChip ?? false) OriginChip(origin!),
          if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
        ],
      ),
    );
  }
}

/// The standard corporate card.
class InfoCard extends StatelessWidget {
  const InfoCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.base),
    this.emphasis = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// Draws the emphasis edge used for the one card on a screen that matters
  /// most. Restraint is the point: if three cards are emphasised, none are.
  ///
  /// The edge is neutral ink at double width, never the corporate green. Most
  /// emphasised cards in this product state an absence — no calibration, no
  /// validated device, no reading — and a green edge reads as approval of the
  /// sentence it surrounds. See [MrplCorporateColors.emphasisBorder].
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;

    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: corporate.surfaceElevated,
        borderRadius: BorderRadius.circular(CorporateRadii.lg),
        border: Border.all(
          color: emphasis ? corporate.emphasisBorder : corporate.border,
          width: emphasis ? Borders.emphasis : Borders.hairline,
        ),
      ),
      // The Material sits INSIDE the decoration, not around it. That
      // ordering is the whole fix: ink is painted on the nearest Material
      // ancestor, so one outside the DecoratedBox draws the splash beneath
      // the card's own background and it never appears.
      child: Material(type: MaterialType.transparency, child: child),
    );

    // A transparent Material inside the decoration, always.
    //
    // InfoCard paints a background, and anything inside it that draws ink —
    // a ListTile, a CheckboxListTile, a RadioListTile — paints onto the
    // nearest Material ancestor. Without one here that ancestor is outside
    // the decoration, so the splash is drawn *under* the card and is
    // invisible. Flutter asserts on it, which is how this was caught twice:
    // once on the work-context toolbox checkbox and again on the report
    // builder's section list.
    //
    // Fixing it here rather than in each screen is the point. Every card in
    // the corporate surfaces is this widget, so every future ListTile placed
    // in one works without the author having to know about the interaction.
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CorporateRadii.lg),
        child: body,
      ),
    );
  }
}

/// A single figure with a label.
///
/// [value] is rendered in the monospace face, because on these screens a
/// figure is a counted, traceable quantity. `--` is a legitimate value and
/// means *not known*; it must never be replaced by `0`.
class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.onTap,
    this.emphasis = false,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final cap = caption;

    return InfoCard(
      onTap: onTap,
      emphasis: emphasis,
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: corporate.textSecondary),
                const SizedBox(width: Space.xs),
              ],
              Expanded(
                child: Text(
                  label,
                  style: t.caption.copyWith(color: corporate.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            value,
            style: t.readoutLarge.copyWith(color: corporate.textPrimary),
          ),
          if (cap != null) ...[
            const SizedBox(height: 2),
            Text(
              cap,
              style: t.caption.copyWith(color: corporate.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable row leading somewhere, with an optional origin marker.
class NavigationRow extends StatelessWidget {
  const NavigationRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.origin,
    this.trailingText,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final DataOrigin? origin;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final sub = subtitle;
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Space.md,
            horizontal: Space.sm,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: enabled ? corporate.primary : corporate.textSecondary,
              ),
              const SizedBox(width: Space.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.bodyStrong.copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: t.caption.copyWith(
                          color: corporate.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: Space.sm),
                Text(
                  trailingText!,
                  style: t.readoutSmall.copyWith(
                    color: corporate.textSecondary,
                  ),
                ),
              ],
              if (origin?.showsRowChip ?? false) ...[
                const SizedBox(width: Space.sm),
                OriginChip(origin!, compact: true),
              ],
              const SizedBox(width: Space.xs),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: corporate.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The screen shown where an integration would be.
///
/// A first-class designed state, not an apology. It names the integration,
/// says plainly that nothing is connected, and lists what *will* be available —
/// so a reviewer can see the intent without being shown a fabrication of it.
class NotConnectedState extends StatelessWidget {
  const NotConnectedState({
    required this.integration,
    required this.explanation,
    this.whenConnected = const <String>[],
    this.icon = Icons.link_off,
    super.key,
  });

  final String integration;
  final String explanation;

  /// What this screen will show once the integration exists. Described, never
  /// rendered as sample rows that could be mistaken for data.
  final List<String> whenConnected;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 38, color: corporate.textSecondary),
            const SizedBox(height: Space.base),
            Text(
              integration,
              style: t.heading.copyWith(color: corporate.textPrimary),
            ),
            const SizedBox(height: Space.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.sm,
                vertical: Space.xs,
              ),
              decoration: BoxDecoration(
                color: corporate.surfaceMuted,
                borderRadius: BorderRadius.circular(CorporateRadii.sm),
                border: Border.all(color: corporate.border),
              ),
              child: Text(
                'NOT CONNECTED',
                style: t.caption.copyWith(
                  color: corporate.textSecondary,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: Space.base),
            Text(
              explanation,
              style: t.body.copyWith(color: corporate.textSecondary),
            ),
            if (whenConnected.isNotEmpty) ...[
              const SizedBox(height: Space.lg),
              Text(
                'When connected, this will show',
                style: t.caption.copyWith(
                  color: corporate.textSecondary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Space.sm),
              for (final item in whenConnected)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.circle,
                          size: 5,
                          color: corporate.textSecondary,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          item,
                          style: t.body.copyWith(
                            color: corporate.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A recoverable failure with the next useful action.
class CorporateErrorState extends StatelessWidget {
  const CorporateErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: corporate.textSecondary),
            const SizedBox(height: Space.base),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.heading.copyWith(color: corporate.textPrimary),
            ),
            const SizedBox(height: Space.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: corporate.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Space.lg),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A row of filter chips that reports which is selected.
class FilterChipRow<T extends Object> extends StatelessWidget {
  const FilterChipRow({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.countOf,
    super.key,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final int? Function(T)? countOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Builder(
                builder: (context) {
                  final count = countOf?.call(option);
                  final label = count == null
                      ? labelOf(option)
                      : '${labelOf(option)} ($count)';
                  return ChoiceChip(
                    label: Text(label),
                    selected: option == selected,
                    onSelected: (_) => onSelected(option),
                    // Selection is not carried by colour alone: the chip also
                    // gains a check mark and announces its state.
                    showCheckmark: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A search field sized for gloved hands.
class CorporateSearchField extends StatelessWidget {
  const CorporateSearchField({
    required this.hint,
    required this.onChanged,
    this.controller,
    super.key,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: t.body.copyWith(color: corporate.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.md,
        ),
        hintText: hint,
        hintStyle: t.body.copyWith(color: corporate.textSecondary),
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: corporate.textSecondary,
        ),
        filled: true,
        fillColor: corporate.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CorporateRadii.md),
          borderSide: BorderSide(color: corporate.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CorporateRadii.md),
          borderSide: BorderSide(color: corporate.border),
        ),
      ),
    );
  }
}

/// A label/value pair for dense corporate records.
///
/// [mono] marks a measured or traceable value — an identifier, a dose, a
/// timestamp — following the design system's rule that monospace *means*
/// something rather than being a style choice.
class RecordRow extends StatelessWidget {
  const RecordRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.origin,
    super.key,
  });

  final String label;
  final String value;
  final bool mono;
  final DataOrigin? origin;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: t.caption.copyWith(color: corporate.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? t.readoutSmall.copyWith(color: corporate.textPrimary)
                  : t.body.copyWith(color: corporate.textPrimary),
            ),
          ),
          if (origin?.showsRowChip ?? false) ...[
            const SizedBox(width: Space.sm),
            OriginChip(origin!, compact: true),
          ],
        ],
      ),
    );
  }
}
