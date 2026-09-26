import 'package:flutter/material.dart';

import '../design/responsive.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// One column of an [AdaptiveRecordList].
@immutable
class RecordColumn<T> {
  const RecordColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.mono = false,
    this.primary = false,
  });

  final String label;

  /// The cell's text. Return `null` for an absent value; it is printed as the
  /// absent-value placeholder, never as an empty cell or `0`.
  final String? Function(T record) cell;

  final int flex;

  /// Measured or traceable value: an identifier, a timestamp.
  final bool mono;

  /// The record's title on a phone card. Exactly one column should be.
  final bool primary;
}

/// Dense operational data that is a card list on a phone and a table on a
/// wide window (APP-PRODUCT-01 §54).
///
/// The decision is made from the space this widget actually has, via
/// [WindowClass.forWidth], so a list inside a split pane on a tablet stays a
/// list. A 360-point phone never gets a squeezed desktop table, and phone
/// cards are compact rows, not billboards.
class AdaptiveRecordList<T> extends StatelessWidget {
  const AdaptiveRecordList({
    required this.records,
    required this.columns,
    this.onTap,
    this.trailing,
    super.key,
  });

  final List<T> records;
  final List<RecordColumn<T>> columns;
  final ValueChanged<T>? onTap;

  /// A status chip or similar, shown at the end of each row/card.
  final Widget Function(T record)? trailing;

  static const String _absent = '- - -';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = WindowClass.forWidth(constraints.maxWidth).prefersTable;
        return wide ? _table(context) : _cards(context);
      },
    );
  }

  Widget _cards(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final title = columns.firstWhere(
      (c) => c.primary,
      orElse: () => columns.first,
    );
    final rest = columns.where((c) => !identical(c, title));

    return Column(
      children: [
        for (final r in records)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Material(
              color: p.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                side: BorderSide(color: p.borderSubtle),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap == null ? null : () => onTap!(r),
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Flexible beside flexible: at 200% text the status
                          // wraps instead of pushing the title off-screen.
                          Expanded(
                            flex: 3,
                            child: Text(
                              title.cell(r) ?? _absent,
                              style: (title.mono ? t.readoutBody : t.bodyStrong)
                                  .copyWith(color: p.textPrimary),
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: Space.sm),
                            Flexible(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.topRight,
                                child: trailing!(r),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Wrap(
                        spacing: Space.base,
                        runSpacing: Space.xs,
                        children: [
                          for (final c in rest)
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${c.label}  ',
                                    style: t.caption.copyWith(
                                      color: p.textSecondary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: c.cell(r) ?? _absent,
                                    style: (c.mono ? t.readoutSmall : t.caption)
                                        .copyWith(color: p.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _table(BuildContext context) {
    final p = context.product;
    final t = context.type;

    Widget cell(String text, {bool mono = false, bool header = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.md,
          ),
          child: Text(
            text,
            style: header
                ? t.caption.copyWith(
                    color: p.textSecondary,
                    fontWeight: FontWeight.w600,
                  )
                : (mono ? t.readoutSmall : t.caption).copyWith(
                    color: p.textPrimary,
                  ),
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceCard,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: p.borderSubtle),
      ),
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                for (final c in columns)
                  Expanded(flex: c.flex, child: cell(c.label, header: true)),
                if (trailing != null)
                  const Expanded(flex: 2, child: SizedBox()),
              ],
            ),
          ),
          for (final r in records) ...[
            Divider(height: 1, color: p.borderSubtle),
            InkWell(
              onTap: onTap == null ? null : () => onTap!(r),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kMinInteractive),
                child: Row(
                  children: [
                    for (final c in columns)
                      Expanded(
                        flex: c.flex,
                        child: cell(c.cell(r) ?? _absent, mono: c.mono),
                      ),
                    if (trailing != null)
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(Space.sm),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: trailing!(r),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
