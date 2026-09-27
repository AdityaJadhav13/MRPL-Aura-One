import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import 'widgets/safety_components.dart';
import 'widgets/safety_scaffold.dart';

/// The worker's safety landing screen.
///
/// ## What this screen is for
///
/// Reference material and handoffs to the organisation's own safety
/// processes. It is not an alarm, not a permit system and not a medical
/// service — and because a worker may arrive here while deciding whether an
/// atmosphere is safe, the first thing on it says so.
///
/// ## Why Emergency and H₂S are emphasised without red
///
/// Those two are what someone reaches for under pressure, so they sit first
/// and carry the accent edge. The rest of the screen stays calm: a safety
/// section rendered in alarm colours becomes wallpaper within a week, and then
/// the one genuinely urgent thing on it has no way left to stand out.
class SafetyHubScreen extends StatelessWidget {
  const SafetyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Safety',
      subtitle: 'Reference material and organisation resources',
      showHero: false,
      children: [
        const NotAnAlarmNotice(),
        const SizedBox(height: Space.base),

        Text(
          'This area holds general information about exposure, statements '
          'about what DoseBand can and cannot do, and handoffs to your '
          'organisation’s safety processes. Each item says which of those it '
          'is.',
          style: t.body.copyWith(color: corporate.textSecondary),
        ),
        const SizedBox(height: Space.lg),

        // The two a worker reaches for first.
        _PriorityCard(
          icon: Icons.emergency_outlined,
          title: 'Emergency',
          subtitle: 'Site contacts and procedures',
          origin: DataOrigin.notConnected,
          onTap: () => context.push('/safety/emergency'),
        ),
        const SizedBox(height: Space.sm),
        _PriorityCard(
          icon: Icons.science_outlined,
          title: 'Hydrogen sulphide',
          subtitle: 'What it is, and what DoseBand measures',
          onTap: () => context.push('/safety/h2s'),
        ),

        const SectionHeader(title: 'Report'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              NavigationRow(
                icon: Icons.report_gmailerrorred_outlined,
                title: 'Near miss or hazard',
                subtitle: 'Hand off to the organisation process',
                origin: DataOrigin.notConnected,
                onTap: () => context.push('/safety/hazard'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.medical_information_outlined,
                title: 'Occupational health',
                subtitle: 'Exposure record handoff',
                origin: DataOrigin.notConnected,
                onTap: () => context.push('/safety/occupational-health'),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Work process guidance'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              NavigationRow(
                icon: Icons.assignment_outlined,
                title: 'Permit to Work',
                subtitle: 'How DoseBand relates to your permit',
                onTap: () => context.push('/safety/ptw'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.fact_check_outlined,
                title: 'Job Safety Analysis',
                subtitle: 'How DoseBand relates to your JSA',
                onTap: () => context.push('/safety/jsa'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.engineering_outlined,
                title: 'PPE',
                subtitle: 'Protective equipment reference',
                origin: DataOrigin.notConnected,
                onTap: () => context.push('/safety/ppe'),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Documents'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              NavigationRow(
                icon: Icons.groups_outlined,
                title: 'Toolbox resources',
                subtitle: 'Briefing material',
                origin: DataOrigin.notConnected,
                onTap: () => context.push('/safety/toolbox'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.description_outlined,
                title: 'Safety data sheets',
                subtitle: 'Substance documents',
                origin: DataOrigin.notConnected,
                onTap: () => context.push('/safety/sds'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.download_outlined,
                title: 'Offline documents',
                subtitle: 'Availability without a connection',
                origin: DataOrigin.notConnected,
                onTap: () => context.push('/safety/offline'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
      ],
    );
  }
}

/// A card for the two resources worth reaching first.
class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.origin,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final DataOrigin? origin;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      emphasis: true,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: corporate.accentMuted,
              borderRadius: BorderRadius.circular(CorporateRadii.md),
            ),
            child: Icon(icon, size: 23, color: corporate.accent),
          ),
          const SizedBox(width: Space.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ],
            ),
          ),
          if (origin?.showsRowChip ?? false) ...[
            OriginChip(origin!, compact: true),
            const SizedBox(width: Space.xs),
          ],
          Icon(Icons.chevron_right, color: corporate.textSecondary),
        ],
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.md),
    child: Divider(height: 1, color: context.corporate.border),
  );
}
