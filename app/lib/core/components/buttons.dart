import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/theme.dart';
import 'step_scaffold.dart';
import '../design/tokens.dart';

enum _Kind { primary, secondary, destructive }

/// The app's buttons.
///
/// All three variants share one implementation because they differ only in
/// colour and border — three separate widgets would be three places to drift.
/// Minimum height is [kMinTouchTarget], not Material's 48: the user may be
/// gloved, and a mis-tap during badge closure corrupts a coverage record.
class DoseBandButton extends StatelessWidget {
  const DoseBandButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    super.key,
  }) : _kind = _Kind.primary;

  const DoseBandButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    super.key,
  }) : _kind = _Kind.secondary;

  /// Irreversible actions only. This is the one place destructive red appears.
  const DoseBandButton.destructive({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    super.key,
  }) : _kind = _Kind.destructive;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final enabled = onPressed != null;

    // On a corporate workflow screen the primary action is MRPL orange, the
    // same control Home uses. On a measurement screen it stays the instrument
    // accent — the badge is on that screen, and a saturated orange field next
    // to a colour measurement is the mistake the register split exists to
    // prevent.
    final corporate = context.corporate;
    final onCorporate = StepRegisterScope.of(context) == StepRegister.corporate;

    final (Color bg, Color fg, Color? border) = switch (_kind) {
      _Kind.primary =>
        onCorporate
            ? (corporate.accent, corporate.textOnAccent, null)
            : (c.measurementAccent, c.textOnAccent, null),
      _Kind.secondary => (Colors.transparent, c.textPrimary, c.borderStrong),
      _Kind.destructive => (
        Colors.transparent,
        c.statusDestructive,
        c.statusDestructive,
      ),
    };

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: enabled ? fg : c.textDisabled),
          const SizedBox(width: Space.sm),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.type.label.copyWith(
              color: enabled ? fg : c.textDisabled,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: enabled ? bg : c.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: kMinTouchTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control),
              border: border != null
                  ? Border.all(
                      color: enabled ? border : c.border,
                      width: Borders.hairline,
                    )
                  : null,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
