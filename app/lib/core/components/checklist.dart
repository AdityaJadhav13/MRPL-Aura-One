import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// One line in a validation checklist.
@immutable
class ChecklistItem {
  const ChecklistItem({required this.label, required this.passed, this.detail});

  final String label;
  final bool passed;
  final String? detail;
}

/// An ordered set of checks with a pass/fail mark on each.
///
/// A passed check speaks in the instrument's own colour; a failed one is neutral
/// ink with a distinct icon, so the two are told apart in greyscale and never
/// rely on colour alone. A failed check is not alarmed in red — red is reserved
/// for destructive actions.
class ValidationChecklist extends StatelessWidget {
  const ValidationChecklist({required this.items, super.key});

  final List<ChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.passed
                      ? Icons.check_circle_outline
                      : Icons.highlight_off,
                  size: 20,
                  color: item.passed ? c.statusValid : c.statusRefused,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: t.body.copyWith(color: c.textPrimary),
                      ),
                      if (item.detail != null)
                        Text(
                          item.detail!,
                          style: t.caption.copyWith(color: c.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
