import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/product_page.dart';
import '../../../core/components/product_status.dart';
import '../../../core/components/workspace_components.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../operations/data/presentation_dataset.dart';
import '../../workflow/application/workflow_controller.dart';
import '../../workflow/domain/workflow_state.dart';
import '../application/presentation_controller.dart';
import '../domain/presentation_mode.dart';

/// Presentation Controls (Settings → About; presentation builds only).
///
/// The fallback that keeps the SIH demonstration runnable if a device
/// integration fails on the day. It is reached only from here — never from
/// Home or a result — and applies only to the presentation DoseBand. Every
/// control is real: the switch and the level change what the app does, and
/// the two workflow actions perform real transitions or remove
/// presentation-origin data. None of them produces a measurement.
class PresentationControlsScreen extends ConsumerWidget {
  const PresentationControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(presentationModeProvider);
    final controller = ref.read(presentationModeProvider.notifier);
    final session = ref.watch(shiftSessionProvider).value;
    final monitoring = session?.stage == ShiftStage.monitoring;
    final t = context.type;
    final p = context.product;

    return ProductPage(
      title: 'Presentation controls',
      children: [
        const StatusBanner(
          tone: StatusTone.info,
          icon: Icons.co_present_outlined,
          title: 'For the demonstration only',
          message:
              'The real path is always tried first. These controls apply only '
              'to the presentation DoseBand '
              '${PresentationDataset.presentationBandId}, never to a real '
              'band. Anything they produce is marked Presentation and kept '
              'out of registers, statistics and reports. Presentation mode '
              'turns off when the app restarts.',
        ),
        const SizedBox(height: Space.base),
        SectionCard(
          children: [
            // Its own Material, so the tile's ink shows on the card.
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Presentation mode'),
                subtitle: Text(
                  mode.enabled
                      ? 'On — ${mode.level.label}'
                      : 'Off — the real path only',
                ),
                value: mode.enabled,
                onChanged: controller.setEnabled,
              ),
            ),
          ],
        ),
        PageSection(
          title: 'Fallback level',
          children: [
            Text(
              'Use the lowest level that lets the demonstration run.',
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: Space.sm),
            SectionCard(
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: RadioGroup<FallbackLevel>(
                    groupValue: mode.level,
                    onChanged: (l) {
                      if (mode.enabled && l != null) controller.setLevel(l);
                    },
                    child: Column(
                      children: [
                        for (final level in FallbackLevel.values)
                          RadioListTile<FallbackLevel>(
                            contentPadding: EdgeInsets.zero,
                            value: level,
                            enabled: mode.enabled,
                            title: Text(level.label),
                            subtitle: Text(level.description),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        PageSection(
          title: 'Workflow',
          children: [
            DoseBandButton.secondary(
              label: 'Advance to final read',
              icon: Icons.fast_forward_outlined,
              onPressed: mode.enabled && monitoring
                  ? () async {
                      final ok = await ref
                          .read(presentationWorkflowProvider)
                          .advanceToFinalRead();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Monitoring ended. Ready for the final read.'
                                : 'Nothing is being monitored.',
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Ends the monitoring period now, as “Complete monitoring” does. '
              'It creates no exposure and no measurement.',
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: Space.base),
            DoseBandButton.destructive(
              label: 'Reset presentation workflow',
              onPressed: mode.enabled ? () => _reset(context, ref) : null,
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Returns the presentation DoseBand to available and removes its '
              'assignment, monitoring period and presentation records. Real '
              'records and archived photographs are not touched.',
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset presentation workflow?'),
        content: const Text(
          'The presentation DoseBand, its monitoring period and every '
          'presentation record are reset. Real records and photographs stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final removed = await ref.read(presentationWorkflowProvider).reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Presentation workflow reset. $removed presentation '
          'record${removed == 1 ? '' : 's'} removed.',
        ),
      ),
    );
  }
}
