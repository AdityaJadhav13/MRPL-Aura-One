import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/buttons.dart';
import '../../core/components/info_note.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/async_value_x.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/domain/workflow_state.dart';

/// Scan hub.
///
/// The Scan tab is a launchpad, not a camera: it routes to the right action for
/// the worker's current state — assign a badge, or read the one they are wearing
/// — so the prominent SCAN destination always does the sensible thing.
class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colours;
    final t = context.type;
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;

    final (
      String title,
      String body,
      String action,
      String route,
      IconData icon,
    ) = switch (session.stage) {
      ShiftStage.monitoring => (
        'Read the badge you are wearing',
        'End the monitored period and read the badge to record a measurement.',
        'End and read badge',
        '/end',
        Icons.stop_circle_outlined,
      ),
      ShiftStage.awaitingScan => (
        'Final scan required',
        'Monitoring has ended. Read the badge now to record the measurement.',
        'Read badge now',
        '/read',
        Icons.qr_code_scanner,
      ),
      _ => (
        'Assign a badge to begin',
        'Set the work context and scan a badge to start a monitored period.',
        'Assign / receive badge',
        '/work-context',
        Icons.qr_code_scanner,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: ListView(
        padding: const EdgeInsets.all(Space.base),
        children: [
          Text(title, style: t.heading.copyWith(color: c.textPrimary)),
          const SizedBox(height: Space.sm),
          Text(body, style: t.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.lg),
          DoseBandButton.primary(
            label: action,
            icon: icon,
            onPressed: () => context.push(route),
          ),
          const SizedBox(height: Space.lg),
          const InfoNote(
            text:
                'The camera badge scanner is added in Phase 3. For now the scan '
                'is simulated and clearly marked.',
          ),
        ],
      ),
    );
  }
}
