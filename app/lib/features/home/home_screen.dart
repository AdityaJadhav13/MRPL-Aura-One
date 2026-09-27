import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/buttons.dart';
import '../../core/components/product_page.dart';
import '../../core/components/step_scaffold.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/domain/workflow_state.dart';
import 'domain/home_presentation.dart';
import 'presentation/monitoring_status_card.dart';

/// Worker Home (Worker directive §3–§5).
///
/// Deliberately simple. It answers two questions and nothing else: *do I
/// have a DoseBand?* and *what do I do next?* Who the worker is and what
/// they are assigned to live in Profile; how the app is built lives in
/// Settings.
///
/// One screen whose status and action follow the monitoring session:
/// no band → scan a new one; assigned → the pre-work step; monitoring →
/// complete and scan; ready for final read → scan the assigned band;
/// completed → the record; a problem (e.g. an untrusted clock) → what went
/// wrong and how to recover. It never shows ppm, and "monitoring" never
/// means "safe".
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The elapsed figure is monitoring duration, not exposure; a refresh
    // every half minute is all it needs.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(shiftSessionProvider).value ?? ShiftSession.none;
    final now = ref.watch(clockProvider)();
    final presentation = HomePresentation.from(session: session, now: now);
    final badge = session.assignedBadge;

    return StepRegisterScope(
      register: StepRegister.corporate,
      child: ProductPage(
        title: 'Home',
        showBack: false,
        children: [
          MonitoringStatusCard(
            presentation: presentation,
            badgeId: badge?.badgeId,
            simulated: badge?.isSimulated ?? false,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            elapsed: session.coverageAt(session.endedAt ?? now),
            work: null,
          ),
          const SizedBox(height: Space.base),
          DoseBandButton.primary(
            label: presentation.actionLabel,
            icon: switch (presentation.stage) {
              HomeStage.noDoseBand => Icons.qr_code_scanner,
              HomeStage.readyForFinalRead => Icons.document_scanner_outlined,
              HomeStage.completed => Icons.receipt_long_outlined,
              HomeStage.requiresAttention => Icons.flag_outlined,
              _ => Icons.arrow_forward,
            },
            onPressed: () => context.push(presentation.actionRoute),
          ),
          if (presentation.secondaryLabel != null) ...[
            const SizedBox(height: Space.sm),
            DoseBandButton.secondary(
              label: presentation.secondaryLabel!,
              onPressed: () => context.push(presentation.secondaryRoute!),
            ),
          ],
          if (presentation.stage == HomeStage.noDoseBand) ...[
            const SizedBox(height: Space.lg),
            const _HowItStarts(),
          ],
        ],
      ),
    );
  }
}

/// With no band, the three steps that begin monitoring — the only guidance
/// Home needs in that state.
class _HowItStarts extends StatelessWidget {
  const _HowItStarts();

  static const _steps = [
    (Icons.inventory_2_outlined, 'Take an unused DoseBand from the store.'),
    (Icons.qr_code_2, 'Scan the QR code printed on it.'),
    (
      Icons.fact_check_outlined,
      'Photograph it for the pre-use check, then wear it as your site '
          'instructs.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'HOW MONITORING STARTS',
              semanticsLabel: 'How monitoring starts',
              style: t.caption.copyWith(
                color: corporate.textSecondary,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          for (var i = 0; i < _steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: corporate.primaryMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _steps[i].$1,
                    size: 18,
                    color: corporate.primaryDeep,
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(
                      '${i + 1}. ${_steps[i].$2}',
                      style: t.body.copyWith(color: corporate.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
            if (i < _steps.length - 1) const SizedBox(height: Space.md),
          ],
        ],
      ),
    );
  }
}
