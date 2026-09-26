import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'product_status.dart';
import 'step_scaffold.dart';

/// The canonical product screen (APP-PRODUCT-01 §23, §24, §96, §99).
///
/// * A title that is announced as a heading.
/// * White ground, screen gutters from [Gaps], content capped at
///   [Breakpoints.maxContentWidth] and centred on a wide window.
/// * The body always scrolls. On a normal phone the primary action is visible
///   without scrolling where the content allows; at 200% text it scrolls
///   rather than clips.
/// * At most one [primaryAction], pinned above the system inset. A second
///   action goes in [secondaryAction] and is drawn subordinate — a worker
///   screen never has two equally loud buttons.
/// * Publishes the product register, so a `DoseBandButton` inside it takes
///   the brand colour without the call site asking.
class ProductPage extends StatelessWidget {
  const ProductPage({
    required this.title,
    required this.children,
    this.actions,
    this.primaryAction,
    this.secondaryAction,
    this.showBack,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  /// Null lets the app bar decide (a back arrow when there is a route to pop).
  final bool? showBack;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final hasActions = primaryAction != null || secondaryAction != null;

    return StepRegisterScope(
      register: StepRegister.corporate,
      child: Scaffold(
        backgroundColor: p.surfacePage,
        appBar: AppBar(
          automaticallyImplyLeading: showBack ?? true,
          title: Semantics(header: true, child: Text(title)),
          actions: actions,
        ),
        body: SafeArea(
          top: false,
          bottom: !hasActions,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: Gaps.screenGutter,
              vertical: Space.base,
            ),
            children: [
              for (final child in children)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Breakpoints.maxContentWidth,
                    ),
                    child: child,
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: hasActions
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surfacePage,
                  border: Border(top: BorderSide(color: p.borderSubtle)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gaps.screenGutter,
                      Space.md,
                      Gaps.screenGutter,
                      Space.md,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Breakpoints.maxContentWidth,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ?primaryAction,
                            if (primaryAction != null &&
                                secondaryAction != null)
                              const SizedBox(height: Space.sm),
                            ?secondaryAction,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// A section heading inside a page: sentence case, announced as a heading.
class PageSection extends StatelessWidget {
  const PageSection({
    required this.title,
    required this.children,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gaps.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: Space.sm),
          ...children,
        ],
      ),
    );
  }
}

/// A card offering one action: icon, title, one sentence, and the action.
class ActionCard extends StatelessWidget {
  const ActionCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  /// A button. Mutually exclusive with [onTap] in spirit: either the card is
  /// the control or it contains one.
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;

    final body = Padding(
      padding: const EdgeInsets.all(Gaps.cardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.surfaceSecondary,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, size: 22, color: p.textPrimary),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyStrong.copyWith(color: p.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
                if (action != null) ...[
                  const SizedBox(height: Space.md),
                  action!,
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: Space.sm),
            Icon(Icons.chevron_right, color: p.textSecondary),
          ],
        ],
      ),
    );

    return Material(
      color: p.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: p.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

/// A full-width statement of a state, inside the page: an exception, a
/// warning, a not-connected notice. Tone from the status vocabulary, so it
/// can never be green.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final StatusTone tone;
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final colours = tone.resolve(p);

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: colours.container,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: colours.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colours.fg),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(message, style: t.body.copyWith(color: p.textPrimary)),
                  if (action != null) ...[
                    const SizedBox(height: Space.sm),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
