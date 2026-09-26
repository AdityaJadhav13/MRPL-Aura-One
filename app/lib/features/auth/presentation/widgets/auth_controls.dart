import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/theme.dart';
import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/tokens.dart';

/// The one primary action on a corporate screen.
///
/// Deep green, full width, with a trailing chevron. Disabled state is a real
/// state, not reduced opacity on a live button: [onPressed] being null is what
/// makes it unreachable to a screen reader too.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.showChevron = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: double.infinity,
        // The gloved-hand minimum, not a literal near it. This is the
        // one primary action on every corporate screen, so 54 undercut the
        // project's own target everywhere at once.
        height: kMinTouchTarget,
        child: FilledButton(
          onPressed: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: corporate.primary,
            foregroundColor: corporate.textOnPrimary,
            disabledBackgroundColor: corporate.border,
            disabledForegroundColor: corporate.textSecondary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CorporateRadii.md),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: t.bodyStrong.copyWith(
                  color: enabled
                      ? corporate.textOnPrimary
                      : corporate.textSecondary,
                ),
              ),
              if (showChevron) ...<Widget>[
                const SizedBox(width: Space.sm),
                Icon(Icons.chevron_right, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A bordered secondary action, e.g. the gate-pass entry point.
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: corporate.textPrimary,
          side: BorderSide(color: corporate.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CorporateRadii.md),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 20, color: corporate.primary),
              const SizedBox(width: Space.sm),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(color: corporate.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The development-only bypass.
///
/// Visually tertiary and physically small, but with a full-size tap target:
/// developers need to hit it repeatedly, and shrinking the touch area to match
/// the ink would fail the accessibility floor for no benefit.
///
/// **Callers must not render this unless `AuthDemoConfig.allowSkip` is true.**
/// The widget does not check the flag itself — a control that decides its own
/// visibility is one refactor away from deciding wrongly.
class AuthSkipButton extends StatelessWidget {
  const AuthSkipButton({
    required this.onPressed,
    this.onDark = false,
    super.key,
  });

  final VoidCallback onPressed;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final colour = onDark
        ? corporate.textOnPrimary.withValues(alpha: 0.82)
        : corporate.textSecondary;

    return Semantics(
      button: true,
      label: 'Skip sign-in. Development build only.',
      child: TextButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        style: TextButton.styleFrom(
          foregroundColor: colour,
          // A surface behind it, because it sits over the corporate footer
          // sweep where plain text would land on green, orange and white in
          // the space of one control.
          backgroundColor: onDark
              ? corporate.textOnPrimary.withValues(alpha: 0.14)
              : corporate.surface.withValues(alpha: 0.92),
          minimumSize: const Size(84, 40),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.xs,
          ),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CorporateRadii.sm),
            side: BorderSide(
              color: onDark
                  ? corporate.textOnPrimary.withValues(alpha: 0.22)
                  : corporate.border,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Skip', style: t.caption.copyWith(color: colour)),
            const SizedBox(width: 3),
            Icon(Icons.arrow_forward, size: 13, color: colour),
          ],
        ),
      ),
    );
  }
}

/// Marks the prototype as unverified wherever an identity is shown.
class DemoModeBadge extends StatelessWidget {
  const DemoModeBadge({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: corporate.accentMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.sm),
        border: Border.all(color: corporate.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        compact ? 'DEMO' : 'DEMO — NO IDENTITY VERIFICATION',
        style: t.caption.copyWith(
          color: corporate.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
