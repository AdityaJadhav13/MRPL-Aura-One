import 'package:flutter/material.dart';

import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import 'auth_background.dart';
import 'auth_brand_header.dart';
import 'auth_controls.dart';

/// The shell every corporate authentication screen sits in.
///
/// It owns the identity header, the footer sweep, the safe-area insets and the
/// skip control's position, so the four screens cannot drift apart on any of
/// them. Content scrolls, always: a fixed column that fits a 390-point phone
/// at default text size will overflow the same phone at 200%.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    this.title,
    this.subtitle,
    this.footerAction,
    this.onSkip,
    this.showHeader = true,
    this.scrollable = true,
    super.key,
  });

  final Widget child;

  /// Screen title, e.g. "Select Site". Rendered under the identity header.
  final String? title;
  final String? subtitle;

  /// A persistent bottom action that stays above the footer sweep.
  final Widget? footerAction;

  /// Supplied only when the build permits skipping; null hides the control.
  final VoidCallback? onSkip;

  final bool showHeader;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showHeader) ...<Widget>[
          const AuthBrandHeader(),
          const SizedBox(height: Space.lg),
        ],
        if (title != null) ...<Widget>[
          // Flagged as a heading, not merely styled as one. Auth is the
          // first screen a screen-reader user meets, and without this there
          // is nothing to navigate to.
          Semantics(
            header: true,
            child: Text(
              title!,
              textAlign: TextAlign.center,
              style: t.heading.copyWith(
                color: corporate.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: Space.xs),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: corporate.textSecondary),
            ),
          ],
          const SizedBox(height: Space.lg),
        ],
      ],
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[header, child],
    );

    return Scaffold(
      backgroundColor: corporate.surface,
      body: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const CorporateFooterWave(),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: scrollable
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            Space.lg,
                            Space.lg,
                            Space.lg,
                            Space.sm,
                          ),
                          child: body,
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Space.lg,
                            Space.lg,
                            Space.lg,
                            Space.sm,
                          ),
                          child: body,
                        ),
                ),
                if (footerAction != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      0,
                      Space.lg,
                      Space.sm,
                    ),
                    child: footerAction,
                  ),
                SizedBox(
                  height: 44,
                  child: onSkip == null
                      ? null
                      : Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: Space.sm),
                            child: AuthSkipButton(onPressed: onSkip!),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
