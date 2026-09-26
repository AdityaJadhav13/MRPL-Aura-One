import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/step_scaffold.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../data/simulation_catalog.dart';
import '../domain/badge_specimen.dart';

/// Badge assignment — the QR scan step.
///
/// A real camera QR scan is Phase 3. Here the scan is simulated and says so: you
/// choose a specimen, and it carries a fixed outcome through the real result
/// state machine. This is deliberately a picker, not a fake camera feed —
/// simulated input must never masquerade as a live capture.
class BadgeAssignmentScreen extends StatelessWidget {
  const BadgeAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final specimens = SimulationCatalog.specimens();

    return StepScaffold(
      title: 'Assign badge',
      children: [
        // A framed viewfinder placeholder — the shape the real scanner will
        // take, on a true-black surround, but with no camera behind it.
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: c.surfaceViewfinder,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_2, size: 64, color: c.textDisabled),
                  const SizedBox(height: Space.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                    child: Text(
                      'Camera QR scanning arrives in Phase 3. Choose a simulated '
                      'badge below to continue.',
                      textAlign: TextAlign.center,
                      style: t.caption.copyWith(color: Neutral.l74),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Text('Simulated badges', style: t.label.copyWith(color: c.textPrimary)),
        const SizedBox(height: Space.sm),
        for (final specimen in specimens) ...[
          _SpecimenTile(specimen: specimen),
          const SizedBox(height: Space.sm),
        ],
      ],
    );
  }
}

class _SpecimenTile extends StatelessWidget {
  const _SpecimenTile({required this.specimen});

  final BadgeSpecimen specimen;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    return Material(
      color: c.surfaceElevated,
      borderRadius: BorderRadius.circular(Radii.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.control),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/verify', extra: specimen);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          padding: const EdgeInsets.all(Space.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      specimen.label,
                      style: t.bodyStrong.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specimen.description,
                      style: t.caption.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      specimen.badgeId,
                      style: t.readoutSmall.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
