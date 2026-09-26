import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/markers.dart';
import '../../../core/components/step_scaffold.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../data/simulation_catalog.dart';
import '../../auth/application/auth_controller.dart';
import '../application/workflow_controller.dart';
import '../domain/badge_specimen.dart';
import '../domain/physical_badge.dart';

/// Badge assignment.
///
/// ## Two kinds of badge, never mixed
///
/// A **physical badge** is identified by its printed id, typed by the worker.
/// QR recognition is not implemented, and nothing here pretends otherwise:
/// there is no viewfinder, and the identity is labelled *manual entry*
/// wherever it appears. A physical badge's final scan opens the real camera
/// and runs the real pipeline. MEASUREMENT-INTEGRATION-02 §8–§9.
///
/// A **presentation specimen** is simulated: it carries a declared outcome,
/// and its scan plays that outcome back. Specimens exist so the interface can
/// be demonstrated without a badge, appear only in builds that include
/// simulation, and carry the simulation marker.
///
/// The screen as a whole is not marked simulated, because its first section
/// is not.
class BadgeAssignmentScreen extends ConsumerStatefulWidget {
  const BadgeAssignmentScreen({super.key});

  @override
  ConsumerState<BadgeAssignmentScreen> createState() =>
      _BadgeAssignmentScreenState();
}

class _BadgeAssignmentScreenState extends ConsumerState<BadgeAssignmentScreen> {
  final _badgeId = TextEditingController();
  final _batch = TextEditingController();
  final _formulation = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _badgeId.dispose();
    _batch.dispose();
    _formulation.dispose();
    super.dispose();
  }

  String? _orNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _assignPhysical() async {
    final id = _badgeId.text.trim();
    if (id.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(shiftSessionProvider.notifier)
          .assignPhysicalBadge(
            PhysicalBadge(
              badgeId: id,
              batchId: _orNull(_batch),
              formulationId: _orNull(_formulation),
              identifiedAt: ref.read(clockProvider)(),
            ),
          );
      // No verification screen: there is nothing to verify a hand-typed id
      // against. The pre-work check shows it as not verified instead.
      if (mounted) context.go('/prework');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final showSpecimens = ref
        .watch(environmentConfigProvider)
        .simulationAvailable;

    return StepScaffold(
      title: 'Assign badge',
      simulated: false,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Physical badge',
            style: t.label.copyWith(color: c.textPrimary),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'Type the id printed on the badge. QR recognition is not '
          'implemented, so the id is recorded as manual entry and is not '
          'checked against any inventory.',
          style: t.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _badgeId,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Badge ID *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _batch,
                // Short label: "(optional)" truncated at phone width.
                decoration: const InputDecoration(
                  labelText: 'Batch',
                  hintText: 'Optional',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: TextField(
                controller: _formulation,
                // Short label: "(optional)" truncated at phone width.
                decoration: const InputDecoration(
                  labelText: 'Formulation',
                  hintText: 'Optional',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        DoseBandButton.primary(
          label: 'Assign physical badge',
          icon: Icons.badge_outlined,
          onPressed: _badgeId.text.trim().isEmpty || _saving
              ? null
              : _assignPhysical,
        ),
        if (showSpecimens) ...[
          const SizedBox(height: Space.xl),
          const SimulationMarker(),
          const SizedBox(height: Space.sm),
          Text(
            'Presentation specimens',
            style: t.label.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Simulated badges with a fixed outcome, for demonstrating the '
            'interface without a physical badge. Their scan uses no camera.',
            style: t.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.sm),
          for (final specimen in SimulationCatalog.specimens()) ...[
            _SpecimenTile(specimen: specimen),
            const SizedBox(height: Space.sm),
          ],
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
