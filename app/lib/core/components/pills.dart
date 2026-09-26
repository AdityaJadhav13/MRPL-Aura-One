import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// A small status token: icon + label + colour together, on a muted fill.
///
/// Never colour alone — the icon and label carry the meaning in greyscale and
/// for colour-vision deficiency. Sentence case, like every label in the app.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.icon,
    required this.colour,
    this.mono = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color colour;

  /// Use the measured/traceable face when the pill carries a machine value
  /// (a stage code, a version). Off for ordinary status words.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colour),
          const SizedBox(width: Space.xs),
          Text(
            label,
            style: (mono ? t.readoutSmall : t.label).copyWith(color: colour),
          ),
        ],
      ),
    );
  }
}

/// Marks a value that comes from a system DoseBand is not integrated with, so it
/// is demonstration data. Neutral, not magenta: magenta is reserved for
/// simulated *measurements*. This chip means "we don't have the real enterprise
/// value yet", which is a different claim.
class DemoReferenceChip extends StatelessWidget {
  const DemoReferenceChip({this.label = 'Demo reference', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off, size: 14, color: c.textSecondary),
          const SizedBox(width: Space.xs),
          Text(
            label,
            style: context.type.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
