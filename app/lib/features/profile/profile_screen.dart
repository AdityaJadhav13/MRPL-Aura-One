import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/surfaces.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/env/environment.dart';

/// Profile, sync status and settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(Space.base),
        children: [
          DoseBandSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sync', style: t.heading.copyWith(color: c.textPrimary)),
                const SizedBox(height: Space.md),
                const TraceabilityRow(label: 'Last sync', value: '—'),
                const TraceabilityRow(label: 'Pending', value: '2'),
                const TraceabilityRow(label: 'Environment', value: 'dev'),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          DoseBandSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Build', style: t.heading.copyWith(color: c.textPrimary)),
                const SizedBox(height: Space.md),
                const TraceabilityRow(label: 'App', value: '0.1.0+1'),
                const TraceabilityRow(label: 'Algorithm', value: 'cv-0.1.0'),
                const TraceabilityRow(label: 'Calibration', value: 'none'),
              ],
            ),
          ),
          if (config.simulationAvailable) ...[
            const SizedBox(height: Space.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.palette_outlined, color: c.textSecondary),
              title: Text(
                'Design system gallery',
                style: t.body.copyWith(color: c.textPrimary),
              ),
              subtitle: Text(
                'Development builds only',
                style: t.caption.copyWith(color: c.textSecondary),
              ),
              trailing: Icon(Icons.chevron_right, color: c.textSecondary),
              onTap: () => context.go('/profile/gallery'),
            ),
          ],
        ],
      ),
    );
  }
}
