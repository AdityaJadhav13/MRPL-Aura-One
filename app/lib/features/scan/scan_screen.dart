import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/buttons.dart';
import '../../core/components/product_page.dart';
import '../../core/components/workspace_components.dart';
import '../../core/domain/doseband.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/format.dart';
import '../home/domain/home_presentation.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/domain/workflow_state.dart';

/// The centre Scan destination — contextual (PRODUCT BUILD v1 §18).
///
/// * No DoseBand: scan a new one.
/// * Monitoring: show what is being worn, the way to finish, and the
///   controlled route for a damaged or lost band. There is deliberately no
///   "scan another DoseBand" here — one worker, one band at a time.
/// * Final read due: scan the assigned band.
class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(shiftSessionProvider).value ?? ShiftSession.none;
    final now = ref.watch(clockProvider)();
    final home = HomePresentation.from(session: session, now: now);
    final t = context.type;
    final p = context.product;
    final badge = session.assignedBadge;

    return ProductPage(
      title: 'Scan',
      showBack: false,
      children: [
        SectionCard(
          children: [
            Icon(
              switch (home.stage) {
                HomeStage.monitoringActive => Icons.sensors,
                HomeStage.readyForFinalRead => Icons.document_scanner_outlined,
                _ => Icons.qr_code_scanner,
              },
              size: 40,
              color: p.textPrimary,
            ),
            const SizedBox(height: Space.md),
            Semantics(
              header: true,
              child: Text(
                home.title,
                style: t.heading.copyWith(color: p.textPrimary),
              ),
            ),
            if (badge != null && home.stage != HomeStage.noDoseBand) ...[
              const SizedBox(height: Space.sm),
              FactRow(label: 'DoseBand', value: badge.badgeId, mono: true),
              if (session.startedAt != null)
                FactRow(label: 'Started', value: Fmt.stamp(session.startedAt!)),
              if (session.stage == ShiftStage.monitoring)
                FactRow(
                  label: 'Monitoring for',
                  value: Fmt.duration(session.coverageAt(now)),
                ),
            ],
            const SizedBox(height: Space.sm),
            Text(home.message, style: t.body.copyWith(color: p.textPrimary)),
            const SizedBox(height: Space.base),
            DoseBandButton.primary(
              label: home.actionLabel,
              icon: Icons.arrow_forward,
              onPressed: () => context.push(home.actionRoute),
            ),
            if (home.secondaryLabel != null) ...[
              const SizedBox(height: Space.sm),
              DoseBandButton.secondary(
                label: home.secondaryLabel!,
                onPressed: () => context.push(home.secondaryRoute!),
              ),
            ],
          ],
        ),
        if (session.stage == ShiftStage.monitoring &&
            session.sessionId != null) ...[
          const SizedBox(height: Gaps.section),
          PageSection(
            title: 'DoseBand damaged or lost?',
            children: [
              Text(
                'Report it here. This period is recorded as interrupted and you '
                'can then scan a replacement for a new period. You cannot claim '
                'a second DoseBand while this one is assigned.',
                style: t.body.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: Space.sm),
              DoseBandButton.destructive(
                label: 'Report DoseBand damaged or lost',
                onPressed: () => _report(context, ref),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final condition = await showDialog<DoseBandLifecycle>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('What happened to the DoseBand?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(c).pop(DoseBandLifecycle.damaged),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: Space.sm),
              child: Text('It is damaged'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(c).pop(DoseBandLifecycle.lost),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: Space.sm),
              child: Text('It is lost'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(c).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: Space.sm),
              child: Text('Cancel'),
            ),
          ),
        ],
      ),
    );
    if (condition == null) return;
    await ref.read(shiftSessionProvider.notifier).reportDoseBand(condition);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Recorded. Tell your supervisor, then scan a replacement DoseBand.',
          ),
        ),
      );
      context.go('/home');
    }
  }
}
