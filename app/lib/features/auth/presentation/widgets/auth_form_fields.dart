import 'package:flutter/material.dart';

import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';

/// A filled sign-in field with a leading icon, recovered from the approved
/// Sign In screen. The password variant carries its own show / hide control.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;

  /// Doubles as the hint and the accessible name.
  final String label;
  final IconData icon;
  final bool enabled;
  final bool obscure;

  /// Supplied for a password field: shows the visibility control.
  final VoidCallback? onToggleObscure;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    OutlineInputBorder border(Color colour, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(CorporateRadii.md),
          borderSide: BorderSide(color: colour, width: width),
        );

    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: t.body.copyWith(color: corporate.textPrimary),
      cursorColor: corporate.primary,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: t.body.copyWith(color: corporate.textSecondary),
        filled: true,
        fillColor: corporate.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.base,
          vertical: Space.base,
        ),
        prefixIcon: Icon(icon, size: 20, color: corporate.textSecondary),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: onToggleObscure,
                iconSize: 22,
                color: corporate.textSecondary,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
        border: border(corporate.border),
        enabledBorder: border(corporate.border),
        disabledBorder: border(corporate.border),
        focusedBorder: border(corporate.primary, width: 1.6),
      ),
    );
  }
}

/// The Employee / Contractor selector. The selected side carries the orange
/// accent, as in the approved design.
class AccountTypeToggle extends StatelessWidget {
  const AccountTypeToggle({
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
      padding: const EdgeInsets.all(Space.xs),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        border: Border.all(color: corporate.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                inMutuallyExclusiveGroup: true,
                selected: i == selectedIndex,
                label: '${options[i]} account',
                excludeSemantics: true,
                onTap: () => onChanged(i),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    constraints: const BoxConstraints(
                      minHeight: kMinInteractive,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.xs,
                      vertical: Space.sm,
                    ),
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? corporate.accent
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(CorporateRadii.sm),
                    ),
                    child: Text(
                      options[i],
                      textAlign: TextAlign.center,
                      style: t.bodyStrong.copyWith(
                        color: i == selectedIndex
                            ? corporate.textOnAccent
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
