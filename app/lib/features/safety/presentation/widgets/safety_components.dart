import 'package:flutter/material.dart';

import '../../../../core/components/corporate.dart';
import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../domain/safety_content.dart';

/// Marks who is speaking.
///
/// Neutral in every state, including [SafetyContentSource.organisation].
/// A green "Organisation" badge would read as endorsement, and a worker
/// deciding whether to act on a sentence needs to know its *author*, not how
/// reassuring it looks.
class ContentSourceChip extends StatelessWidget {
  const ContentSourceChip(this.source, {super.key});

  final SafetyContentSource source;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    final icon = switch (source) {
      SafetyContentSource.general => Icons.public,
      SafetyContentSource.product => Icons.badge_outlined,
      SafetyContentSource.organisation => Icons.apartment_outlined,
      SafetyContentSource.publicStandard => Icons.gavel_outlined,
      SafetyContentSource.demo => Icons.science_outlined,
      SafetyContentSource.notConfigured => Icons.link_off,
    };

    return Semantics(
      label: '${source.label}. ${source.explanation}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: corporate.surfaceMuted,
          borderRadius: BorderRadius.circular(CorporateRadii.sm),
          border: Border.all(color: corporate.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: corporate.textSecondary),
            const SizedBox(width: 4),
            Text(
              source.label,
              style: t.caption.copyWith(
                color: corporate.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A block of safety prose that states who wrote it.
///
/// The source chip sits in the heading rather than at the end, so a worker
/// reads "who is telling me this" before the content rather than after.
class SafetySection extends StatelessWidget {
  const SafetySection({
    required this.heading,
    required this.source,
    this.paragraphs = const <String>[],
    this.bullets = const <String>[],
    super.key,
  });

  final String heading;
  final SafetyContentSource source;
  final List<String> paragraphs;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      heading,
                      style: t.bodyStrong.copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                ContentSourceChip(source),
              ],
            ),
            const SizedBox(height: Space.sm),
            for (final paragraph in paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text(
                  paragraph,
                  style: t.body.copyWith(color: corporate.textSecondary),
                ),
              ),
            for (final bullet in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: corporate.textSecondary,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        bullet,
                        style: t.body.copyWith(color: corporate.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A slot the organisation has not filled.
///
/// Rendered as a deliberate, finished state rather than blankness. It names
/// what is missing, says DoseBand will not substitute for it, and where
/// useful says what the worker should do instead.
class NotConfiguredCard extends StatelessWidget {
  const NotConfiguredCard({
    required this.what,
    required this.explanation,
    this.instead,
    this.icon = Icons.inventory_2_outlined,
    super.key,
  });

  final String what;
  final String explanation;

  /// What to do in the meantime. Only stated where DoseBand can say something
  /// true — "follow your site's procedure" is true; inventing the procedure is
  /// not.
  final String? instead;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 19, color: corporate.textSecondary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    what,
                    style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                  ),
                ),
              ),
              const ContentSourceChip(SafetyContentSource.notConfigured),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            explanation,
            style: t.body.copyWith(color: corporate.textSecondary),
          ),
          if (instead != null) ...[
            const SizedBox(height: Space.sm),
            Container(
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: corporate.surfaceMuted,
                borderRadius: BorderRadius.circular(CorporateRadii.sm),
              ),
              child: Text(
                instead!,
                style: t.caption.copyWith(color: corporate.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A row in a document library.
class SafetyDocumentCard extends StatelessWidget {
  const SafetyDocumentCard({required this.document, this.onTap, super.key});

  final SafetyDocument document;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: InfoCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    document.title,
                    style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                  ),
                ),
                const SizedBox(width: Space.sm),
                ContentSourceChip(document.source),
              ],
            ),
            const SizedBox(height: Space.xs),
            if (document.substance case final substance?)
              Text(
                substance,
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            const SizedBox(height: Space.sm),
            // Wrap, not Row: at 200% text these two metadata blocks cannot
            // share a line on a phone, and reflowing is better than clipping
            // a revision number.
            Wrap(
              spacing: Space.base,
              runSpacing: Space.xs,
              children: [
                _Meta(label: 'Category', value: document.category.label),
                _Meta(
                  label: 'Revision',
                  // Never invented. An SDS revision is precisely the detail
                  // that makes a fabricated sheet credible.
                  value: document.revision ?? 'Unavailable',
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                Icon(
                  document.offline == OfflineState.downloaded
                      ? Icons.offline_pin_outlined
                      : Icons.cloud_off_outlined,
                  size: 14,
                  color: corporate.textSecondary,
                ),
                const SizedBox(width: Space.xs),
                Text(
                  document.offline.label,
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.caption.copyWith(
            color: corporate.textSecondary,
            fontSize: 10,
          ),
        ),
        Text(value, style: t.caption.copyWith(color: corporate.textPrimary)),
      ],
    );
  }
}

/// The persistent statement that DoseBand is not a gas alarm.
///
/// Appears on the hub and on every screen a worker might reach while deciding
/// whether an atmosphere is safe. Uses the accent rather than red: red is
/// destructive in this system, and dressing this as an alarm would be its own
/// kind of dishonesty — it is a statement about what the product *is not*.
class NotAnAlarmNotice extends StatelessWidget {
  const NotAnAlarmNotice({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Semantics(
      liveRegion: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.base),
        decoration: BoxDecoration(
          color: corporate.accentMuted,
          borderRadius: BorderRadius.circular(CorporateRadii.md),
          border: Border.all(color: corporate.accent.withValues(alpha: 0.42)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 19, color: corporate.accent),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'DoseBand is not a real-time gas alarm',
                      style: t.bodyStrong.copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    Text(
                      'DoseBand is a passive, cumulative occupational-exposure '
                      'monitor, read after the period. It cannot detect gas '
                      'now and will not warn you. It does not replace '
                      'certified portable H₂S detectors, fixed gas detection, '
                      'site alarms, approved PPE, Permit-to-Work controls or '
                      'site emergency procedures.',
                      style: t.caption.copyWith(color: corporate.textPrimary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
