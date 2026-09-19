import 'package:flutter/material.dart';

import '../../core/components/buttons.dart';
import '../../core/components/markers.dart';
import '../../core/components/measurement_readout.dart';
import '../../core/components/surfaces.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import 'gallery_specimens.dart';

/// Development-only design system gallery.
///
/// Every component and every important state in one place, so they can be
/// inspected without walking the worker workflow and without seeding the
/// workflow with fake records. It is reachable only when
/// [EnvironmentConfig.simulationAvailable] is true, so it cannot appear in a
/// production build.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  // Local UI state only. No state-management dependency is warranted for a
  // single toggle on a development screen.
  double _textScale = 1;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design system'),
        actions: [
          PopupMenuButton<double>(
            tooltip: 'Text scale',
            initialValue: _textScale,
            onSelected: (v) => setState(() => _textScale = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1.0, child: Text('Text 100%')),
              PopupMenuItem(value: 1.5, child: Text('Text 150%')),
              PopupMenuItem(value: 2.0, child: Text('Text 200%')),
            ],
            icon: const Icon(Icons.format_size),
          ),
        ],
      ),
      body: MediaQuery.withClampedTextScaling(
        minScaleFactor: _textScale,
        maxScaleFactor: _textScale,
        child: ListView(
          padding: const EdgeInsets.all(Space.base),
          children: [
            _Section(
              'Markers',
              children: const [
                SimulationMarker(),
                SizedBox(height: Space.sm),
                OfflineMarker(pendingCount: 2),
              ],
            ),
            _Section(
              'Buttons',
              children: [
                DoseBandButton.primary(
                  label: 'End shift and read badge',
                  onPressed: () {},
                ),
                const SizedBox(height: Space.md),
                DoseBandButton.secondary(
                  label: 'Enter badge ID by hand',
                  onPressed: () {},
                ),
                const SizedBox(height: Space.md),
                DoseBandButton.destructive(
                  label: 'Void this badge',
                  onPressed: () {},
                ),
                const SizedBox(height: Space.md),
                const DoseBandButton.primary(
                  label: 'Disabled',
                  onPressed: null,
                ),
              ],
            ),
            _Section(
              'Readout',
              children: [
                DoseBandSurface(
                  measurement: true,
                  child: const MeasurementReadout(
                    value: '3.2',
                    uncertainty: '0.8',
                    unit: 'ppm·h',
                  ),
                ),
                const SizedBox(height: Space.md),
                DoseBandSurface(
                  measurement: true,
                  child: const MeasurementReadout(unit: 'ppm·h'),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'No reading holds the slot open. It never prints a zero.',
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            _Section(
              'Typography',
              children: [
                Text(
                  'Display 28',
                  style: t.display.copyWith(color: c.textPrimary),
                ),
                Text(
                  'Heading 20',
                  style: t.heading.copyWith(color: c.textPrimary),
                ),
                Text('Body 16', style: t.body.copyWith(color: c.textPrimary)),
                Text('Label 14', style: t.label.copyWith(color: c.textPrimary)),
                Text(
                  'Caption 13',
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  '0123456789 ppm·h',
                  style: t.readoutLarge.copyWith(color: c.textPrimary),
                ),
                Text(
                  'DB-4K7M2 · L26-0912-A',
                  style: t.readoutBody.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'Monospace means the value is measured or traceable.',
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            for (final s in resultSpecimens)
              _Section(s.name, children: [Builder(builder: s.build)]),
            const SizedBox(height: Space.xxl),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.type.heading.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: Space.md),
          ...children,
        ],
      ),
    );
  }
}
