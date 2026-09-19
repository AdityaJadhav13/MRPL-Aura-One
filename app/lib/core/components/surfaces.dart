import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// A container.
///
/// Elevation is carried by the neutral ramp plus a hairline — a surface one
/// step lighter than its parent — never by a soft grey drop shadow.
///
/// [measurement] squares the corners. An instrument face has square corners,
/// and the radius is how a reader tells a reading from a control.
class DoseBandSurface extends StatelessWidget {
  const DoseBandSurface({
    required this.child,
    this.measurement = false,
    this.padding = const EdgeInsets.all(Space.base),
    super.key,
  });

  final Widget child;
  final bool measurement;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(
          measurement ? Radii.measurement : Radii.control,
        ),
        border: Border.all(color: c.border, width: Borders.hairline),
      ),
      child: child,
    );
  }
}

/// A traceability row: sans label on the left, **mono** value on the right.
///
/// The monospace face is the signal that this value would appear in an audit
/// record. Values align to a common right edge so they read as a column.
class TraceabilityRow extends StatelessWidget {
  const TraceabilityRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Proportional rather than a fixed width: a fixed label column is too
          // narrow at large text scales and breaks words mid-syllable. Values
          // still right-align to the container edge, so they read as a column.
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: context.type.caption.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.type.readoutSmall.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// What happened, why it matters, what to do next (directive section 30).
///
/// The three parts are separate fields rather than one blob so a screen cannot
/// accidentally ship a reason without an action.
class ReasonPanel extends StatelessWidget {
  const ReasonPanel({
    required this.whatHappened,
    required this.whyItMatters,
    required this.whatToDo,
    required this.colour,
    super.key,
  });

  final String whatHappened;
  final String whyItMatters;
  final String whatToDo;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.base),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        border: Border(
          left: BorderSide(color: colour, width: Borders.statusRule),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            whatHappened,
            style: t.bodyStrong.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: Space.sm),
          Text(whyItMatters, style: t.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.md),
          Text(whatToDo, style: t.body.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}
