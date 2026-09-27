import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../domain/provenance.dart';
import '../util/format.dart';
import 'product_status.dart';

/// The canonical text field (APP-PRODUCT-01 §18).
///
/// Always labelled: a placeholder that disappears on the first keystroke is
/// not a label. Helper and error text wrap to three lines instead of being
/// cut off. Styling comes from the theme's `inputDecorationTheme`, so every
/// field in the product looks the same.
class ProductTextField extends StatelessWidget {
  const ProductTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.enabled = true,
    this.readOnly = false,
    this.loading = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffix,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;

  /// A trailing control inside the field — e.g. a password visibility
  /// toggle. Replaced by the progress indicator while [loading].
  final Widget? suffix;

  final Iterable<String>? autofillHints;

  /// Replaces [helper] while present. Says what is wrong and how to fix it.
  final String? error;

  final bool enabled;
  final bool readOnly;

  /// A lookup is running for this field. Shown in the suffix; the field stays
  /// editable.
  final bool loading;

  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;

    return TextField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      style: t.body.copyWith(color: enabled ? p.textPrimary : p.textDisabled),
      // Keeps the field above the keyboard with room for its helper line.
      scrollPadding: const EdgeInsets.all(Space.xxl),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: error == null ? helper : null,
        errorText: error,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        fillColor: readOnly ? p.surfaceSecondary : null,
        suffixIcon: loading
            ? Padding(
                padding: const EdgeInsets.all(Space.md),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.textSecondary,
                    semanticsLabel: 'Checking',
                  ),
                ),
              )
            : suffix,
      ),
    );
  }
}

/// A search field. Labelled for screen readers even though the magnifier and
/// hint carry it visually.
///
/// Use only where it queries real or local data (§55). A search box that
/// filters nothing is a fake control.
class ProductSearchField extends StatelessWidget {
  const ProductSearchField({
    required this.label,
    required this.onChanged,
    this.hint,
    this.controller,
    super.key,
  });

  final String label;
  final String? hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    return Semantics(
      textField: true,
      label: label,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.type.body.copyWith(color: p.textPrimary),
        decoration: InputDecoration(
          hintText: hint ?? label,
          prefixIcon: const Icon(Icons.search),
          fillColor: p.surfaceSecondary,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
            borderSide: BorderSide(color: p.borderDefault),
          ),
        ),
      ),
    );
  }
}

/// A labelled single-choice field.
class ProductDropdownField<T> extends StatelessWidget {
  const ProductDropdownField({
    required this.label,
    required this.options,
    required this.labelOf,
    required this.value,
    required this.onChanged,
    this.helper,
    this.error,
    super.key,
  });

  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  final T? value;

  /// Null disables the field.
  final ValueChanged<T?>? onChanged;
  final String? helper;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      onChanged: onChanged,
      items: [
        for (final o in options)
          DropdownMenuItem<T>(
            value: o,
            child: Text(labelOf(o), overflow: TextOverflow.ellipsis),
          ),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: error == null ? helper : null,
        errorText: error,
      ),
    );
  }
}

/// A value the worker can read but not change, with where it came from.
///
/// Company-authoritative profile fields — employee ID, department, contractor
/// organisation — use this rather than an editable field (§18). An editable
/// box for a value the worker cannot legitimately change is a fake form.
class ReadOnlyField extends StatelessWidget {
  const ReadOnlyField({
    required this.label,
    required this.value,
    this.provenance,
    this.mono = false,
    super.key,
  });

  final String label;

  /// Null prints the absent-value placeholder, never an empty string or `0`.
  final String? value;

  final RecordProvenance? provenance;

  /// Monospace means measured or traceable: an identifier, a timestamp.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final shown = value ?? Fmt.noValue;

    return Semantics(
      label: '$label: ${value ?? 'not provided'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.caption.copyWith(color: p.textSecondary)),
            const SizedBox(height: Gaps.labelToValue),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  shown,
                  style: (mono ? t.readoutBody : t.body).copyWith(
                    color: value == null ? p.textSecondary : p.textPrimary,
                  ),
                ),
                if (provenance != null) ProvenanceChip(provenance!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
