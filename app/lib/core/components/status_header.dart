import 'package:flutter/material.dart';

import '../design/status_presentation.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// Status shown as icon + label + colour together, behind a left rule.
///
/// Never colour alone: the treatment has to survive colour-vision deficiency,
/// a sunlit screen, and a greyscale screenshot in an incident report.
class StatusHeader extends StatelessWidget {
  const StatusHeader({required this.presentation, super.key});

  final StatusPresentation presentation;

  @override
  Widget build(BuildContext context) {
    // The rule is sized against the text it sits beside, so it does not shrink
    // into a speck at large text scales.
    final ruleHeight = MediaQuery.textScalerOf(context).scale(24);
    return Semantics(
      label: 'Status: ${presentation.label}',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: Borders.statusRule,
            height: ruleHeight,
            color: presentation.colour,
          ),
          const SizedBox(width: Space.md),
          Icon(presentation.icon, size: 20, color: presentation.colour),
          const SizedBox(width: Space.sm),
          Flexible(
            child: Text(
              presentation.label,
              style: context.type.bodyStrong.copyWith(
                color: presentation.colour,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
