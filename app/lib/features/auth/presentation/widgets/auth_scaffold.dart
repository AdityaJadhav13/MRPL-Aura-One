import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import 'corporate_brand.dart';

/// The shell the setup screens (Select Site, Select Your Role) sit in,
/// recovered from the approved design.
///
/// It owns the identity header, the title, the pinned Continue action and
/// the footer wave, so the screens cannot drift apart. Content scrolls: a
/// fixed column that fits a 390-point phone at default text overflows the
/// same phone at 200 %. There is no Skip: setup cannot be bypassed.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    required this.title,
    required this.subtitle,
    this.footerAction,
    this.onBack,
    super.key,
  });

  final Widget child;
  final String title;
  final String subtitle;

  /// The pinned primary action (Continue), kept above the footer wave.
  final Widget? footerAction;

  /// Shown as a back control when the screen is not the first in its flow.
  final VoidCallback? onBack;

  static const double _waveHeight = 56;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: corporate.surface,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CorporateFooterWave(height: _waveHeight + bottomInset),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.base,
                      Space.lg,
                      Space.base,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (onBack != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  tooltip: 'Back',
                                  onPressed: onBack,
                                  icon: Icon(
                                    Icons.arrow_back,
                                    color: corporate.textPrimary,
                                  ),
                                ),
                              ),
                            const AuthBrandHeader(markSize: 48),
                            const SizedBox(height: Space.xl),
                            // A heading, not merely styled as one: this is
                            // the first thing a screen-reader user meets.
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: t.heading.copyWith(
                                  color: corporate.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: Space.xs),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: t.body.copyWith(
                                color: corporate.textSecondary,
                              ),
                            ),
                            const SizedBox(height: Space.lg),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (footerAction != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.sm,
                      Space.lg,
                      Space.sm,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: footerAction,
                      ),
                    ),
                  ),
                // Clears the wave, so the action never sits on it.
                SizedBox(height: _waveHeight * 0.75 + bottomInset),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "DoseBand / OCCUPATIONAL EXPOSURE MONITORING", as on the approved entry
/// screens.
class DoseBandLockup extends StatelessWidget {
  const DoseBandLockup({this.fontSize = 34, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            'DoseBand',
            textAlign: TextAlign.center,
            style: t.display.copyWith(
              fontSize: fontSize,
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: Brand.identityInk,
            ),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'OCCUPATIONAL EXPOSURE MONITORING',
          textAlign: TextAlign.center,
          style: t.caption.copyWith(
            color: corporate.textSecondary,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// The entry screens' primary action: full width, one touch target tall,
/// with the approved chevron. Disabled until the screen has what it needs.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final enabled = onPressed != null && !busy;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: double.infinity,
          minHeight: kMinTouchTarget,
        ),
        child: FilledButton(
          onPressed: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: corporate.primaryDeep,
            foregroundColor: corporate.textOnPrimary,
            disabledBackgroundColor: corporate.border,
            disabledForegroundColor: corporate.textSecondary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.base,
              vertical: Space.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CorporateRadii.md),
            ),
          ),
          child: busy
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: corporate.textOnPrimary,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: t.bodyStrong.copyWith(
                          color: enabled
                              ? corporate.textOnPrimary
                              : corporate.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

/// "Skip →", as on the approved entry screens: a small bordered control
/// bottom-right, on its own surface so it reads over the footer wave.
/// Offered only in presentation builds.
class AuthSkipButton extends StatelessWidget {
  const AuthSkipButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return Semantics(
      button: true,
      label:
          'Skip sign-in and choose a site and role. Presentation build only.',
      excludeSemantics: true,
      child: TextButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        style: TextButton.styleFrom(
          foregroundColor: corporate.textSecondary,
          backgroundColor: corporate.surface.withValues(alpha: 0.92),
          minimumSize: const Size(88, kMinInteractive),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CorporateRadii.sm),
            side: BorderSide(color: corporate.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Skip',
              style: t.body.copyWith(color: corporate.textSecondary),
            ),
            const SizedBox(width: Space.xs),
            Icon(Icons.arrow_forward, size: 16, color: corporate.textSecondary),
          ],
        ),
      ),
    );
  }
}
