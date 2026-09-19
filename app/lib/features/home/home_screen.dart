import 'package:flutter/material.dart';

import '../../core/components/buttons.dart';
import '../../core/components/markers.dart';
import '../../core/components/surfaces.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';

/// Worker home.
///
/// Answers, without scrolling and in this order: am I on a monitored shift,
/// which badge and is it valid, how long has it been active, what do I do next,
/// and is my data synced.
///
/// No charts, no dashboard tiles. A worker opens this perhaps three times a
/// shift and needs an answer each time, not an overview.
///
/// Phase 1: static placeholder content. State arrives in Phase 2.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;

    return Scaffold(
      appBar: AppBar(title: const Text('DoseBand')),
      body: ListView(
        padding: const EdgeInsets.all(Space.base),
        children: [
          const OfflineMarker(pendingCount: 2),
          const SizedBox(height: Space.base),
          DoseBandSurface(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shift in progress',
                  style: t.heading.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'Badge active since 06:12',
                  style: t.body.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.lg),
                const TraceabilityRow(label: 'Badge', value: 'DB-4K7M2'),
                const TraceabilityRow(label: 'Lot', value: 'L26-0912-A'),
                const TraceabilityRow(label: 'Elapsed', value: '05:48'),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          DoseBandButton.primary(
            label: 'End shift and read badge',
            icon: Icons.stop_circle_outlined,
            onPressed: () {},
          ),
          const SizedBox(height: Space.md),
          DoseBandButton.secondary(
            label: 'Report a problem with this badge',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
