import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/product_page.dart';
import '../../core/components/product_status.dart';
import '../../core/design/tokens.dart';

/// The one entry point to developer and research tooling (APP-PRODUCT-01 §91).
///
/// Registered only where simulation is available, so it does not exist in a
/// production build. It is reached from a single row on Profile, never from
/// worker navigation, and nothing here produces a worker-facing record.
class DeveloperToolsScreen extends StatelessWidget {
  const DeveloperToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProductPage(
      title: 'Developer and research tools',
      children: [
        const StatusBanner(
          tone: StatusTone.info,
          icon: Icons.build_outlined,
          title: 'Development build only',
          message:
              'These tools are for building and validating DoseBand. They are '
              'not part of the worker product and are absent from production '
              'builds.',
        ),
        const SizedBox(height: Gaps.section),
        PageSection(
          title: 'Design system',
          children: [
            ActionCard(
              icon: Icons.widgets_outlined,
              title: 'Component catalog',
              message:
                  'Design system v2: tokens, controls, states, navigation.',
              onTap: () => context.push('/dev/components'),
            ),
            const SizedBox(height: Gaps.control),
            ActionCard(
              icon: Icons.straighten,
              title: 'Instrument components',
              message: 'Readouts, the measurement scale, result states.',
              onTap: () => context.push('/dev/gallery'),
            ),
            const SizedBox(height: Gaps.control),
            ActionCard(
              icon: Icons.preview_outlined,
              title: 'Worker screen previews',
              message: 'Seeds the workflow store to show each worker state.',
              onTap: () => context.push('/dev/worker-previews'),
            ),
          ],
        ),
        PageSection(
          title: 'Research',
          children: [
            ActionCard(
              icon: Icons.photo_camera_outlined,
              title: 'Physical capture test',
              message:
                  'Real camera, full optical pipeline, archived evidence. '
                  'Produces research records only.',
              onTap: () => context.push('/dev/physical-capture'),
            ),
            const SizedBox(height: Gaps.control),
            ActionCard(
              icon: Icons.folder_open_outlined,
              title: 'Research captures',
              message: 'Saved captures, export, X0–X3 comparison.',
              onTap: () => context.push('/dev/research-captures'),
            ),
            const SizedBox(height: Gaps.control),
            ActionCard(
              icon: Icons.camera_outlined,
              title: 'Dossier V0 capture',
              message: 'The original research capture host.',
              onTap: () => context.push('/dev/capture'),
            ),
          ],
        ),
      ],
    );
  }
}
