import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// Persistent, non-dismissible marker on anything in the simulated data domain.
///
/// Deliberately magenta and deliberately loud. Simulated data must never be
/// mistakable for a measurement, on screen or in a screenshot.
class SimulationMarker extends StatelessWidget {
  const SimulationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.base,
          vertical: Space.md,
        ),
        decoration: BoxDecoration(
          color: c.statusSimulated,
          border: Border(
            bottom: BorderSide(
              color: c.statusSimulated,
              width: Borders.emphasis,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.science_outlined, size: 18, color: c.surfacePrimary),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                'Simulated — not a real H₂S measurement',
                style: context.type.label.copyWith(color: c.surfacePrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offline state. Stated plainly, without alarm: working offline is normal in a
/// refinery and the workflow is designed for it.
class OfflineMarker extends StatelessWidget {
  const OfflineMarker({this.pendingCount = 0, super.key});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final detail = pendingCount > 0
        ? '$pendingCount record${pendingCount == 1 ? '' : 's'} waiting to sync'
        : 'Records are saved on this phone';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.base,
        vertical: Space.md,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: c.textSecondary),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              'Offline · $detail',
              style: context.type.caption.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A presentation-origin record (SIH demonstration build): a small neutral
/// tag beside the record's state, so the example is identifiable in a list
/// without dressing the whole screen as a simulation.
class PresentationTag extends StatelessWidget {
  const PresentationTag({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Semantics(
      label: 'Presentation record, not a validated measurement',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
        decoration: BoxDecoration(
          color: c.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.co_present_outlined, size: 14, color: c.textSecondary),
            const SizedBox(width: Space.xs),
            Text(
              'Presentation',
              style: context.type.caption.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
