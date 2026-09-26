import 'package:flutter/material.dart';

import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../domain/enterprise_value.dart';

/// The one chip that says where a value came from.
///
/// Every enterprise-linked value on screen is rendered through this, so the
/// vocabulary cannot drift: one component, three states, and a worker who
/// learns what "Manual" means on the permit row knows what it means on the gate
/// pass row.
///
/// The colouring is deliberately restrained. This is the corporate register, so
/// it may use the corporate palette — but it must never use the measurement
/// status colours, because a provenance chip is a statement about paperwork,
/// not about a reading. Nothing here is green-for-good: a "Verified" permit is
/// still not permission to work.
class ProvenanceChip extends StatelessWidget {
  const ProvenanceChip(this.source, {super.key});

  /// Convenience for a value that carries its own provenance.
  ProvenanceChip.of(EnterpriseValue<Object> value, {super.key})
    : source = value.source;

  final EnterpriseDataSource source;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;

    final (icon, foreground) = switch (source) {
      EnterpriseDataSource.demo => (Icons.science_outlined, c.textSecondary),
      EnterpriseDataSource.manualEntry => (
        Icons.edit_outlined,
        c.textSecondary,
      ),
      EnterpriseDataSource.organizationIntegration => (
        Icons.verified_outlined,
        c.textPrimary,
      ),
    };

    return Semantics(
      // Read out in full: a screen reader user gets the meaning, not a word
      // whose significance depends on having seen the legend.
      label: '${source.label}. ${source.explanation}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.sm,
          vertical: Space.xs,
        ),
        decoration: BoxDecoration(
          color: c.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: Space.xs),
            Text(source.label, style: t.caption.copyWith(color: foreground)),
          ],
        ),
      ),
    );
  }
}

/// A label, a value and its provenance, on one line.
///
/// Used wherever a referenced value is displayed. Keeping the chip welded to
/// the value in a single widget is what stops a redesign from showing the
/// number somewhere the chip did not follow.
class ProvenanceRow extends StatelessWidget {
  const ProvenanceRow({
    required this.label,
    required this.value,
    required this.source,
    this.secondary,
    super.key,
  });

  ProvenanceRow.of({
    required this.label,
    required EnterpriseValue<String> value,
    this.secondary,
    super.key,
  }) : value = value.value,
       source = value.source;

  final String label;
  final String value;
  final EnterpriseDataSource source;

  /// An optional second line, e.g. the permit category.
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final detail = secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.caption.copyWith(color: c.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: t.readoutSmall.copyWith(color: c.textPrimary),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: t.caption.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: ProvenanceChip(source),
          ),
        ],
      ),
    );
  }
}
