import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/operations/application/access.dart';
import '../design/responsive.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import 'identity.dart';
import 'product_states.dart';
import 'product_status.dart';

/// Renders an [AsyncValue] view of the operations store: loading, permission
/// denied, error, or the content. Denial is a state, never an empty list that
/// would read as "nothing here" (PRODUCT BUILD v1 §81).
class OpsView<T> extends StatelessWidget {
  const OpsView({required this.value, required this.builder, super.key});

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T view) builder;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnReload: true,
    loading: () => const Center(
      child: StateView(kind: StateKind.loading, message: 'Opening records…'),
    ),
    error: (e, _) => Center(
      child: e is AccessDenied
          ? StateView(kind: StateKind.permissionDenied, message: e.reason)
          : StateView(
              kind: StateKind.error,
              message: 'The records on this device could not be read. $e',
            ),
    ),
    data: (v) => builder(context, v),
  );
}

/// A white card with a subtle border — the product's one container shape.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.children,
    this.padding = const EdgeInsets.all(Gaps.cardPadding),
    super.key,
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceCard,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.borderSubtle),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// One count with its label. Tappable when it leads somewhere.
class CountTile extends StatelessWidget {
  const CountTile({
    required this.label,
    required this.value,
    this.icon,
    this.tone = StatusTone.neutral,
    this.onTap,
    super.key,
  });

  final String label;

  /// Already formatted: a number, or a suppressed cell such as "<3".
  final String value;
  final IconData? icon;
  final StatusTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final colours = tone.resolve(p);
    final body = Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: colours.fg),
                const SizedBox(width: Space.xs),
              ],
              Flexible(
                child: Text(
                  value,
                  style: t.readoutBody.copyWith(color: p.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(label, style: t.caption.copyWith(color: p.textSecondary)),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      excludeSemantics: true,
      child: Material(
        color: p.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: p.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: onTap == null ? body : InkWell(onTap: onTap, child: body),
        ),
      ),
    );
  }
}

/// Count tiles in as many columns as the width allows — two on a phone.
class CountGrid extends StatelessWidget {
  const CountGrid({required this.tiles, super.key});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (WindowClass.forWidth(constraints.maxWidth)) {
          WindowClass.compact => constraints.maxWidth < 340 ? 1 : 2,
          WindowClass.medium => 3,
          WindowClass.expanded => 4,
        };
        final width =
            (constraints.maxWidth - Space.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

/// A label and its value, stacked on narrow widths.
class FactRow extends StatelessWidget {
  const FactRow({
    required this.label,
    required this.value,
    this.mono = false,
    super.key,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final valueStyle = (mono ? t.readoutSmall : t.body).copyWith(
      color: p.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: LayoutBuilder(
        builder: (context, c) {
          final label0 = Text(
            label,
            style: t.caption.copyWith(color: p.textSecondary),
          );
          final value0 = Text(value, style: valueStyle);
          if (c.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label0, const SizedBox(height: 2), value0],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: c.maxWidth * 0.38, child: label0),
              const SizedBox(width: Space.sm),
              Expanded(child: value0),
            ],
          );
        },
      ),
    );
  }
}

/// One person in a list: initials (or approved photo), name, a detail line
/// and a status chip. Never used where a view is de-identified.
class PersonTile extends StatelessWidget {
  const PersonTile({
    required this.name,
    required this.detail,
    this.status,
    this.onTap,
    super.key,
  });

  final String name;
  final String detail;
  final Widget? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          child: Row(
            children: [
              IdentityAvatar(name: name, size: 40),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: t.bodyStrong.copyWith(color: p.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: Space.xs),
                      status!,
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rows separated by hairlines inside one card.
class RowList extends StatelessWidget {
  const RowList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    // A Material, not a decorated box: rows are ink-splashing tiles, and ink
    // painted under a decoration is invisible.
    return Material(
      color: p.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: p.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.borderSubtle),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Single-choice filter chips, scrolling sideways on a narrow screen.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    super.key,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in options) ...[
            ChoiceChip(
              label: Text(labelOf(o)),
              selected: o == selected,
              onSelected: (_) => onSelected(o),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
            const SizedBox(width: Space.sm),
          ],
        ],
      ),
    );
  }
}

/// A compact line stating where the data on a screen comes from.
class DataOriginNote extends StatelessWidget {
  const DataOriginNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.smartphone_outlined, size: 16, color: p.textSecondary),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Text(
            message,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
        ),
      ],
    );
  }
}
