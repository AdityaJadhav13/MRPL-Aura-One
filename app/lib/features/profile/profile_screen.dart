import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart';

import '../../core/components/surfaces.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/env/app_version.dart';
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
          // The environment indicator. APP-INTEGRATION-01 §34.
          //
          // One place states what kind of build this is and where its data
          // comes from, so individual rows elsewhere need not repeat "Demo".
          //
          // This block replaced a "Sync" block that showed "Pending: 2" — a
          // hard-coded count implying records queued for a backend that does
          // not exist — and "Environment: dev" hard-coded regardless of build.
          DoseBandSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Environment',
                    style: t.heading.copyWith(color: c.textPrimary),
                  ),
                ),
                const SizedBox(height: Space.md),
                TraceabilityRow(label: 'Build', value: config.environment.name),
                TraceabilityRow(
                  label: 'Organisation data',
                  value: config.simulationAvailable
                      ? 'Sample data — not from any MRPL system'
                      : '—',
                ),
                const TraceabilityRow(
                  label: 'Backend',
                  value: 'Not connected — records stay on this device',
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          // Versions read from the code that actually runs. The previous
          // values were literals, and the algorithm one was wrong: it showed
          // "cv-0.1.0" while the engine identifies itself as "m0a".
          DoseBandSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Build',
                    style: t.heading.copyWith(color: c.textPrimary),
                  ),
                ),
                const SizedBox(height: Space.md),
                const TraceabilityRow(label: 'App', value: appVersion),
                const TraceabilityRow(
                  label: 'Algorithm',
                  value: algorithmVersion,
                ),
                const TraceabilityRow(
                  label: 'Features',
                  value: featureDefinitionVersion,
                ),
                const TraceabilityRow(
                  label: 'Geometry',
                  value: 'badge-v1-research',
                ),
                const TraceabilityRow(
                  label: 'Calibration',
                  value: 'None — no H₂S calibration exists',
                ),
              ],
            ),
          ),
          if (config.simulationAvailable) ...[
            const SizedBox(height: Space.lg),
            // First, because it is the reason this build exists: the bench
            // workflow for photographing physical specimens. §40.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.photo_camera_outlined,
                color: c.textSecondary,
              ),
              title: Text(
                'Physical capture test',
                style: t.body.copyWith(color: c.textPrimary),
              ),
              subtitle: Text(
                'Research · real camera, full pipeline, archived evidence',
                style: t.caption.copyWith(color: c.textSecondary),
              ),
              trailing: Icon(Icons.chevron_right, color: c.textSecondary),
              onTap: () => context.go('/profile/physical-capture'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.folder_open_outlined, color: c.textSecondary),
              title: Text(
                'Research captures',
                style: t.body.copyWith(color: c.textPrimary),
              ),
              subtitle: Text(
                'Saved captures, export, X0–X3 comparison',
                style: t.caption.copyWith(color: c.textSecondary),
              ),
              trailing: Icon(Icons.chevron_right, color: c.textSecondary),
              onTap: () => context.go('/profile/research-captures'),
            ),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.preview_outlined, color: c.textSecondary),
              title: Text(
                'Worker screen previews',
                style: t.body.copyWith(color: c.textPrimary),
              ),
              subtitle: Text(
                'Development builds only',
                style: t.caption.copyWith(color: c.textSecondary),
              ),
              trailing: Icon(Icons.chevron_right, color: c.textSecondary),
              onTap: () => context.go('/profile/worker-previews'),
            ),
          ],
        ],
      ),
    );
  }
}
