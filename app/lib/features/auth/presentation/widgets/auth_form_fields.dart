import 'package:flutter/material.dart';

import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';

/// A corporate text field: leading icon, filled surface, subtle border.
///
/// Errors render beneath rather than replacing the field's own chrome, so the
/// field does not change height between valid and invalid — a form that jumps
/// as you leave each field is unpleasant to complete one-handed.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.errorText,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.semanticLabel,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final String? errorText;

  final bool obscure;

  /// Supplied for password fields; null for everything else.
  final VoidCallback? onToggleObscure;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: semanticLabel ?? hintText,
          textField: true,
          obscured: obscure,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            onSubmitted: onSubmitted,
            style: t.body.copyWith(color: corporate.textPrimary),
            cursorColor: corporate.primary,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: t.body.copyWith(color: corporate.textSecondary),
              filled: true,
              fillColor: corporate.surfaceMuted,
              isDense: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Space.base,
                vertical: Space.base,
              ),
              prefixIcon: Icon(icon, size: 20, color: corporate.textSecondary),
              suffixIcon: onToggleObscure == null
                  ? null
                  : Semantics(
                      button: true,
                      label: obscure ? 'Show password' : 'Hide password',
                      child: IconButton(
                        onPressed: onToggleObscure,
                        iconSize: 20,
                        color: corporate.textSecondary,
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
              border: _border(corporate.border),
              enabledBorder: _border(
                hasError ? context.product.critical : corporate.border,
              ),
              focusedBorder: _border(
                hasError ? context.product.critical : corporate.primary,
                width: 1.6,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs, left: Space.xs),
            child: Text(
              errorText!,
              style: t.caption.copyWith(color: context.product.critical),
            ),
          ),
      ],
    );
  }

  OutlineInputBorder _border(Color colour, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        borderSide: BorderSide(color: colour, width: width),
      );
}

/// Employee / Contractor segmented control.
///
/// The active segment is orange: it is the only orange fill in the flow, which
/// is what makes "which mode am I in" answerable at a glance. Both segments
/// carry a label, so the state is never conveyed by colour alone.
class EmployeeContractorToggle extends StatelessWidget {
  const EmployeeContractorToggle({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        border: Border.all(color: corporate.border),
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                label: options[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    // 48, the interactive floor (§17). It was 44.
                    height: kMinInteractive,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // Green with white, not orange: white on the orange is
                      // 2.88:1 and this label must be read.
                      color: i == selectedIndex
                          ? corporate.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(CorporateRadii.sm),
                    ),
                    child: Text(
                      options[i],
                      style: t.bodyStrong.copyWith(
                        color: i == selectedIndex
                            ? corporate.textOnPrimary
                            : corporate.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
