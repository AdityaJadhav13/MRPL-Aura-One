import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'buttons.dart';
import 'product_status.dart';
import 'step_scaffold.dart';

/// The distinct non-content states a screen or section can be in
/// (APP-PRODUCT-01 §22).
///
/// They are separate on purpose, because each tells the reader something
/// different and asks them to do something different:
///
/// * **offline** is the phone; **serverUnavailable** is the server. Different
///   fixes.
/// * **empty** (nothing exists yet) is not **noResults** (a filter hid
///   everything), and neither is `0`.
/// * **notConnected** (no integration exists) is not **unavailable** (this
///   cannot be provided right now) is not **notConfigured** (the organisation
///   has not supplied it). See design-system.md "three absence words".
///
/// There is no generic "Something went wrong".
enum StateKind {
  loading(Icons.hourglass_empty, 'Loading', StatusTone.neutral),
  empty(Icons.inbox_outlined, 'Nothing here yet', StatusTone.neutral),
  noResults(Icons.search_off, 'No matches', StatusTone.neutral),
  offline(Icons.cloud_off_outlined, "You're offline", StatusTone.info),
  serverUnavailable(
    Icons.dns_outlined,
    'Server not responding',
    StatusTone.info,
  ),
  permissionDenied(
    Icons.lock_outline,
    'Not available to your role',
    StatusTone.neutral,
  ),
  notConnected(Icons.link_off, 'Not connected', StatusTone.info),
  notConfigured(
    Icons.settings_suggest_outlined,
    'Not configured',
    StatusTone.neutral,
  ),
  unavailable(Icons.block, 'Unavailable', StatusTone.info),
  error(Icons.error_outline, "Couldn't complete that", StatusTone.critical);

  const StateKind(this.icon, this.defaultTitle, this.tone);

  final IconData icon;

  /// A generic title. Screens should normally pass their own, specific one.
  final String defaultTitle;
  final StatusTone tone;
}

/// Renders one [StateKind]: an icon, a plain statement, what to do next, and —
/// where there is one — the action that does it.
///
/// [compact] draws it inside a card, for a section of a screen; otherwise it
/// fills and centres in the available space, scrolling rather than clipping at
/// large text sizes.
class StateView extends StatelessWidget {
  const StateView({
    required this.kind,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final StateKind kind;
  final String? title;

  /// What happened and what the reader should do next (§94).
  final String message;

  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final colours = kind.tone.resolve(p);
    final heading = title ?? kind.defaultTitle;

    final Widget glyph = kind == StateKind.loading
        ? SizedBox.square(
            dimension: compact ? 24 : 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: p.textSecondary,
              semanticsLabel: heading,
            ),
          )
        : Container(
            width: compact ? 40 : 56,
            height: compact ? 40 : 56,
            decoration: BoxDecoration(
              color: colours.container,
              shape: BoxShape.circle,
            ),
            child: Icon(kind.icon, size: compact ? 20 : 28, color: colours.fg),
          );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        glyph,
        const SizedBox(height: Space.md),
        Semantics(
          header: !compact,
          child: Text(
            heading,
            textAlign: compact ? TextAlign.start : TextAlign.center,
            style: (compact ? t.bodyStrong : t.heading).copyWith(
              color: p.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          message,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: t.body.copyWith(color: p.textSecondary),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: Space.base),
          StepRegisterScope(
            register: StepRegister.corporate,
            child: DoseBandButton.secondary(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Gaps.cardPadding),
        decoration: BoxDecoration(
          color: p.surfaceCard,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: p.borderSubtle),
        ),
        child: content,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? (constraints.maxHeight - Space.lg * 2).clamp(0, 1e9)
                : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
