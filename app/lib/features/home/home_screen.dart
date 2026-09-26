import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/corporate.dart';
import '../../core/design/corporate_colors.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/async_value_x.dart';
import '../history/application/history_controller.dart';
import '../history/domain/measurement_record.dart';
import '../../core/design/status_presentation.dart';
import '../workflow/application/work_context_controller.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/domain/workflow_state.dart';
import 'domain/home_presentation.dart';
import 'presentation/home_cards.dart';

/// Worker home.
///
/// ## One screen, nine states
///
/// The architecture never changes: hero, identity, today's shift, work
/// context, monitoring status, primary action, status strip, quick actions.
/// What changes is the *content* of those sections and which action is
/// offered.
///
/// This matters more than it sounds. A worker checks this screen in gloves,
/// in daylight, between tasks. If the layout reorganises itself between "no
/// shift" and "monitoring active", there is no stable place to look — and the
/// previous version did exactly that, collapsing to an empty state that told
/// them nothing about what a monitored period even requires.
///
/// Missing data now produces an empty **value**, never an empty screen. Seeing
/// "Work area — Not selected" inside a complete dashboard tells a worker what
/// is outstanding; seeing nothing tells them only that the app has nothing.
///
/// ## It is a projection, not a second workflow
///
/// Everything here is derived from `shiftSessionProvider` and
/// `workContextReadinessProvider`. Home holds no state of its own and invents
/// no values: [HomePresentation] does the mapping in one place so the card,
/// the button and the strip cannot contradict each other.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corporate = context.corporate;
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;
    final readiness = ref.watch(workContextReadinessProvider);
    final history = ref.watch(historyProvider);

    final now = ref.watch(clockProvider)();
    final presentation = HomePresentation.from(
      session: session,
      readiness: readiness,
      now: now,
    );
    final workContext = session.context;

    return Scaffold(
      backgroundColor: corporate.surfaceMuted,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const HomeHero(),

          // Everything below the hero lifts by the same 20 points, so the
          // identity card reads as a masthead overlapping the image rather
          // than a banner above a list — and the lift does not leave a dead
          // gap under the card, which it did when only the card moved.
          Transform.translate(
            offset: const Offset(0, -20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.base),
                  child: WorkerIdentityCard(
                    worker: workContext?.worker,
                    onOpenProfile: () => context.go('/profile'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.base,
                    Space.md,
                    Space.base,
                    Space.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TodaysShiftCard(
                        context_: workContext,
                        now: now,
                        onViewDetails: () => context.push('/work-context'),
                      ),
                      const SizedBox(height: Space.sm),

                      WorkContextCard(
                        context_: workContext,
                        onViewAll: () => context.push('/work-context'),
                      ),
                      const SizedBox(height: Space.sm),

                      MonitoringStatusCard(
                        presentation: presentation,
                        badgeId: session.assignedBadge?.badgeId,
                        startedAt: session.startedAt,
                        coverage: session.coverageAt(now),
                      ),
                      const SizedBox(height: Space.sm),

                      _PrimaryAction(
                        label: presentation.actionLabel,
                        onPressed: () => context.push(presentation.actionRoute),
                      ),
                      const SizedBox(height: Space.sm),

                      DosimetryStatusStrip(message: presentation.statusStrip),
                      const SizedBox(height: Space.lg),

                      Text(
                        'Quick actions'.toUpperCase(),
                        style: context.type.caption.copyWith(
                          color: corporate.textSecondary,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      QuickActions(onTap: context.push),

                      if (history.isNotEmpty) ...[
                        const SizedBox(height: Space.lg),
                        _RecentRecords(history: history),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The single large contextual action.
///
/// Orange, and the only orange control on the screen. The accent's job here is
/// to answer "what do I do next?" in under a second; a second orange button
/// would cost exactly that.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          // Brand green, not orange: white on the orange is 2.88:1, and this
          // is the one button a gloved worker must read in sunlight.
          backgroundColor: corporate.primary,
          foregroundColor: corporate.textOnPrimary,
          // The token, not a literal: 56 exists because this is the
          // button a gloved worker taps, and 54 quietly undercut it.
          minimumSize: const Size.fromHeight(kMinTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CorporateRadii.md),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: t.label.copyWith(
            color: corporate.textOnAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RecentRecords extends StatelessWidget {
  const _RecentRecords({required this.history});

  final List<MeasurementRecord> history;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent'.toUpperCase(),
                style: t.caption.copyWith(
                  color: corporate.textSecondary,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            InkWell(
              onTap: () => context.go('/history'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                child: Text(
                  'View all',
                  style: t.caption.copyWith(color: corporate.primary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < history.take(3).length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md),
                    child: Divider(height: 1, color: corporate.border),
                  ),
                _RecentRow(record: history[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.record});

  final MeasurementRecord record;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final status = StatusPresentation.of(record.result.status, context.colours);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/measurement', extra: record),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.badge.badgeId,
                      style: t.readoutSmall.copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.label,
                      style: t.caption.copyWith(color: corporate.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: corporate.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
