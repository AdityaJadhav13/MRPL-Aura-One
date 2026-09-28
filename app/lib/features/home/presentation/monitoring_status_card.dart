import 'package:flutter/material.dart';

import '../../../core/components/markers.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../domain/home_presentation.dart';

/// The monitoring card — Home's anchor. One solid brand fill; its content is
/// whatever the monitoring session says. "Monitoring active" is a workflow
/// state, never a statement about the air: the card shows no ppm, because a
/// passive DoseBand measures nothing until it is read.
class MonitoringStatusCard extends StatelessWidget {
  const MonitoringStatusCard({
    required this.presentation,
    required this.badgeId,
    required this.simulated,
    required this.startedAt,
    required this.endedAt,
    required this.elapsed,
    required this.work,
    super.key,
  });

  final HomePresentation presentation;
  final String? badgeId;
  final bool simulated;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Monitoring duration; null when it cannot be established.
  final Duration? elapsed;

  /// Work area · shift, when recorded.
  final String? work;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final stage = presentation.stage;
    // Solid brand fill once there is a period to show; before that, a white
    // card with brand accents, so Home does not open on two stacked green
    // blocks (card and action) with nothing being monitored.
    // A problem is not dressed as a running period: it gets a white card
    // with an orange edge, never the brand green.
    final attention = stage == HomeStage.requiresAttention;
    final strong = stage != HomeStage.noDoseBand && !attention;
    final fg = strong ? Colors.white : corporate.textPrimary;
    final dim = strong
        ? Colors.white.withValues(alpha: 0.82)
        : corporate.textSecondary;
    final icon = switch (stage) {
      HomeStage.noDoseBand => Icons.qr_code_2,
      HomeStage.doseBandAssigned => Icons.badge_outlined,
      HomeStage.monitoringActive => Icons.sensors,
      HomeStage.readyForFinalRead => Icons.document_scanner_outlined,
      HomeStage.completed => Icons.task_alt,
      HomeStage.requiresAttention => Icons.schedule,
    };
    // As in the approved design: the orange marker is for a period that is
    // running, and nothing else — on other states it only repeated the title.
    final pill = stage == HomeStage.monitoringActive ? 'ACTIVE' : null;

    final showsBand = badgeId != null && stage != HomeStage.noDoseBand;
    final timing = switch (stage) {
      HomeStage.monitoringActive || HomeStage.requiresAttention => (
        Fmt.duration(elapsed),
        startedAt == null ? 'Not started' : 'Started ${Fmt.clock(startedAt!)}',
      ),
      HomeStage.readyForFinalRead || HomeStage.completed => (
        Fmt.duration(elapsed),
        endedAt == null ? '' : 'Ended ${Fmt.clock(endedAt!)}',
      ),
      _ => (null, null),
    };

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.base),
        decoration: BoxDecoration(
          color: strong ? corporate.primaryDeep : corporate.surface,
          borderRadius: BorderRadius.circular(CorporateRadii.lg),
          border: strong
              ? null
              : Border.all(
                  color: attention ? corporate.accent : corporate.border,
                  width: attention ? 1.6 : 1,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: strong
                        ? Colors.white.withValues(alpha: 0.16)
                        : attention
                        ? corporate.accentMuted
                        : corporate.primaryMuted,
                    borderRadius: BorderRadius.circular(CorporateRadii.sm),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: strong
                        ? Colors.white
                        : attention
                        ? corporate.accent
                        : corporate.primary,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    presentation.title.toUpperCase(),
                    semanticsLabel: presentation.title,
                    style: t.label.copyWith(
                      color: fg,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (pill != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: corporate.accent,
                      borderRadius: BorderRadius.circular(CorporateRadii.sm),
                    ),
                    child: Text(
                      pill,
                      style: t.caption.copyWith(
                        color: Colors.white,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (simulated) ...[
              const SizedBox(height: Space.md),
              const SimulationMarker(),
            ],
            if (showsBand || timing.$1 != null) ...[
              const SizedBox(height: Space.base),
              LayoutBuilder(
                builder: (context, c) {
                  final left = timing.$1 == null
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                timing.$1!,
                                maxLines: 1,
                                style: t.readoutLarge.copyWith(color: fg),
                              ),
                            ),
                            if (timing.$2 != null && timing.$2!.isNotEmpty)
                              Text(
                                timing.$2!,
                                style: t.caption.copyWith(color: dim),
                              ),
                          ],
                        );
                  final right = !showsBand
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DoseBand',
                              style: t.caption.copyWith(color: dim),
                            ),
                            Text(
                              badgeId!,
                              style: t.readoutSmall.copyWith(color: fg),
                            ),
                            Text(
                              'Assigned to you',
                              style: t.caption.copyWith(color: dim),
                            ),
                          ],
                        );
                  final stacked =
                      c.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3;
                  if (left == null) return right!;
                  if (right == null) return left;
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        left,
                        const SizedBox(height: Space.md),
                        right,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      Container(
                        width: 1,
                        height: 48,
                        color: strong
                            ? Colors.white.withValues(alpha: 0.24)
                            : corporate.border,
                        margin: const EdgeInsets.symmetric(
                          horizontal: Space.base,
                        ),
                      ),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
            ],
            if (work != null && stage != HomeStage.noDoseBand) ...[
              const SizedBox(height: Space.md),
              Text(work!, style: t.caption.copyWith(color: dim)),
            ],
            const SizedBox(height: Space.md),
            Text(presentation.message, style: t.body.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
