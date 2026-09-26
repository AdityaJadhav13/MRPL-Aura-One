import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/theme.dart';
import 'step_scaffold.dart';
import '../design/tokens.dart';

enum _Kind { primary, secondary, tertiary, destructive }

/// The app's buttons — the canonical button for both registers (design
/// system v2, APP-PRODUCT-01 §17).
///
/// All four variants share one implementation because they differ only in
/// colour and border — four separate widgets would be four places to drift.
///
/// * **primary** — the one dominant action on a screen (§96). Brand green on a
///   product screen, the instrument accent on a measurement screen.
/// * **secondary** — outlined, neutral. Visibly subordinate to primary.
/// * **tertiary** — text only. Low-emphasis navigation ("View details").
/// * **destructive** — irreversible actions only; the one place red appears.
///
/// Every variant has default, pressed, focused, disabled and loading states.
/// Disabled is a quieter grey that stays readable (4.54:1), not a ghost.
/// Minimum height is [kMinTouchTarget], not Material's 48: the user may be
/// gloved, and a mis-tap during badge closure corrupts a coverage record.
class DoseBandButton extends StatelessWidget {
  const DoseBandButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
    super.key,
  }) : _kind = _Kind.primary;

  const DoseBandButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
    super.key,
  }) : _kind = _Kind.secondary;

  /// Text-only, for low-emphasis actions beside a primary one.
  const DoseBandButton.tertiary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
    super.key,
  }) : _kind = _Kind.tertiary;

  /// Irreversible actions only. This is the one place destructive red appears.
  const DoseBandButton.destructive({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
    super.key,
  }) : _kind = _Kind.destructive;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  /// Work is in progress. The button stays its full size, shows a progress
  /// indicator in place of its icon, ignores taps and says so to a screen
  /// reader — the label does not change, so the layout does not jump.
  final bool loading;

  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final enabled = onPressed != null && !loading;

    // On a corporate workflow screen the primary action is the brand green,
    // the same control Home uses. On a measurement screen it stays the
    // instrument accent — the badge is on that screen, and a saturated field
    // next to a colour measurement is the mistake the register split exists
    // to prevent.
    //
    // It was MRPL orange until APP-PRODUCT-01: white on that orange is 2.88:1,
    // below the 4.5:1 a label needs, on the button a gloved worker reads in
    // sunlight.
    final corporate = context.corporate;
    final onCorporate = StepRegisterScope.of(context) == StepRegister.corporate;

    final (Color bg, Color fg, Color? border) = switch (_kind) {
      _Kind.primary =>
        onCorporate
            ? (corporate.primary, corporate.textOnPrimary, null)
            : (c.measurementAccent, c.textOnAccent, null),
      _Kind.secondary => (Colors.transparent, c.textPrimary, c.borderStrong),
      _Kind.tertiary => (
        Colors.transparent,
        onCorporate ? corporate.primaryDeep : c.measurementAccent,
        null,
      ),
      _Kind.destructive => (
        Colors.transparent,
        c.statusDestructive,
        c.statusDestructive,
      ),
    };

    // Readable when disabled: a quieter grey, not a ghost (§17).
    final disabledFg = onCorporate
        ? context.product.textDisabled
        : c.textDisabled;
    // A loading primary keeps its fill, so the control does not appear to
    // have been refused while it is working.
    final Color fill = enabled || (loading && _kind == _Kind.primary)
        ? bg
        : (_kind == _Kind.primary ? c.surfaceSunken : Colors.transparent);

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _kind == _Kind.primary ? fg : c.textSecondary,
            ),
          ),
          const SizedBox(width: Space.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: enabled ? fg : disabledFg),
          const SizedBox(width: Space.sm),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.type.label.copyWith(
              color: enabled || loading ? fg : disabledFg,
            ),
          ),
        ),
      ],
    );

    final radius = onCorporate ? Radii.sm : Radii.control;

    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? '$label, in progress' : label,
      excludeSemantics: true,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kMinTouchTarget,
              minWidth: kMinTouchTarget,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: _kind == _Kind.tertiary ? Space.md : Space.lg,
              vertical: Space.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
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
