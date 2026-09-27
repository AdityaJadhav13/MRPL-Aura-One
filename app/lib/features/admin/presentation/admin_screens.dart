import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/env/environment.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';
import '../../workflow/data/work_context_repository.dart';
import '../data/admin_demo_catalog.dart';

/// Integration status.
///
/// ## The most important honesty screen in the product
///
/// Every integration is listed, and every one of them says NOT CONNECTED,
/// because every one of them is. A reviewer should be able to establish the
/// true extent of what is wired up from a single screen, without reading the
/// source and without having to trust a summary somebody wrote.
///
/// There is deliberately no green "Connected" state anywhere on it: no code
/// path can produce one, so rendering the style would only invite someone to
/// fake it.
class IntegrationStatusScreen extends StatelessWidget {
  const IntegrationStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final integrations = AdminDemoCatalog.integrations();

    return SafetyScaffold(
      title: 'Integration status',
      subtitle: '${integrations.length} integrations · none connected',
      children: [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.link_off,
                    size: 20,
                    color: corporate.textSecondary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'Nothing is connected',
                      style: t.bodyStrong.copyWith(
                        color: corporate.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                'DoseBand runs entirely on this device. It makes no network '
                'requests, holds no endpoints, and has never contacted any '
                'MRPL system. Every reference it stores was typed by hand or '
                'seeded as demonstration data.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        for (final integration in integrations)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: InfoCard(
              onTap: () =>
                  context.push('/admin/integrations/${integration.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          integration.name,
                          style: t.bodyStrong.copyWith(
                            color: corporate.textPrimary,
                          ),
                        ),
                      ),
                      // The only state this chip can take on this screen.
                      // There is no connected variant to render.
                      const OriginChip(DataOrigin.notConnected),
                      const SizedBox(width: Space.xs),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: corporate.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    integration.purpose,
                    style: t.caption.copyWith(color: corporate.textSecondary),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    integration.blockedBy,
                    style: t.caption.copyWith(color: corporate.textPrimary),
                  ),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      Text(
                        'Last attempt',
                        style: t.caption.copyWith(
                          color: corporate.textSecondary,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Text(
                        // Never attempted, because there is nothing to
                        // attempt. Not "pending", which would imply a queue.
                        'Never',
                        style: t.readoutSmall.copyWith(
                          color: corporate.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Configured sites — real configuration, not demo.
class AdminSitesScreen extends StatelessWidget {
  const AdminSitesScreen({required this.sites, super.key});

  /// Site id → display name, taken from the configured site repository.
  final List<({String id, String name, String locality})> sites;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Sites',
      subtitle: '${sites.length} configured',
      children: [
        InfoCard(
          child: Text(
            'These are the sites configured in the application. They are '
            'prototype configuration, not a directory retrieved from any MRPL '
            'system, and no claim is made that a worker may be assigned to '
            'any of them.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
        const SizedBox(height: Space.base),
        for (final site in sites)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.name,
                    style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    site.locality.replaceAll('\n', ', '),
                    style: t.caption.copyWith(color: corporate.textSecondary),
                  ),
                  const SizedBox(height: Space.sm),
                  RecordRow(label: 'Site ID', value: site.id, mono: true),
                  const RecordRow(label: 'Integration', value: 'Not connected'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Configured departments — real configuration.
class AdminDepartmentsScreen extends StatelessWidget {
  const AdminDepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const config = DemoWorkContextRepository();
    final departments = config.departments();
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Departments',
      subtitle: '${departments.length} configured',
      children: [
        InfoCard(
          child: Text(
            'A deliberately small operational subset. The organisation has '
            'more departments than these; the selector offers the ones whose '
            'workers wear a dosimeter badge.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Column(
            children: [
              for (final d in departments)
                RecordRow(label: d.name, value: d.id, mono: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// Configured work areas — real configuration.
class AdminWorkAreasScreen extends StatelessWidget {
  const AdminWorkAreasScreen({required this.siteIds, super.key});

  final List<String> siteIds;

  @override
  Widget build(BuildContext context) {
    const config = DemoWorkContextRepository();
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Work areas',
      subtitle: 'By site',
      children: [
        InfoCard(
          child: Text(
            'Demonstration areas, labelled as such. DoseBand stores no hazard '
            'classification for an area: where the work happens says nothing '
            'about what the atmosphere contains, and treating it as though it '
            'did would be an invented measurement.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
        for (final siteId in siteIds) ...[
          SectionHeader(title: siteId),
          InfoCard(
            child: Column(
              children: [
                for (final area in config.workAreas(siteId))
                  RecordRow(label: area.name, value: area.id, mono: true),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Retention profiles.
///
/// Every profile is unconfigured, and the screen says so per record type
/// rather than once at the top. Retention periods for occupational exposure
/// records come from regulation and organisation policy; shipping a default
/// would be a compliance claim in a field that looks like configuration.
class AdminRetentionScreen extends StatelessWidget {
  const AdminRetentionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final profiles = AdminDemoCatalog.retentionProfiles();

    return SafetyScaffold(
      title: 'Retention',
      subtitle: '${profiles.length} record types · none configured',
      children: [
        InfoCard(
          child: Text(
            'Retention periods for occupational exposure records are set by '
            'regulation and by organisation policy, and they differ by '
            'jurisdiction and record type. DoseBand does not ship a default: '
            'a hard-coded period would be a compliance claim this prototype '
            'is not entitled to make.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
        const SizedBox(height: Space.base),
        for (final profile in profiles)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.recordType,
                    style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    profile.note,
                    style: t.caption.copyWith(color: corporate.textSecondary),
                  ),
                  const SizedBox(height: Space.sm),
                  RecordRow(
                    label: 'Retention period',
                    value: profile.duration ?? 'Not configured',
                  ),
                  RecordRow(
                    label: 'Authority',
                    value: profile.authority ?? 'Not mapped',
                  ),
                  RecordRow(label: 'Status', value: profile.status),
                  const RecordRow(label: 'Legal hold', value: 'Not supported'),
                  const RecordRow(label: 'Archive', value: 'No archive exists'),
                ],
              ),
            ),
          ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Awaiting configuration',
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                'Each profile will carry the authority or policy it derives '
                'from, the retention period, whether a legal hold applies, '
                'and the archive state. Until an organisation supplies those, '
                'the fields stay empty rather than being filled with a '
                'plausible period.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sync health.
class AdminSyncScreen extends StatelessWidget {
  const AdminSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafetyScaffold(
      title: 'Sync health',
      subtitle: 'Backend synchronisation',
      children: [
        NotConnectedState(
          integration: 'Backend synchronisation',
          explanation:
              'DoseBand is local-only. Records live on this device and are '
              'not synchronised anywhere, so there is no pending queue, no '
              'last successful sync and no conflict to report. Showing a '
              'green "synced" state would be the most misleading thing this '
              'screen could do.',
          whenConnected: [
            'Records pending upload',
            'Last successful synchronisation',
            'Failed uploads and why',
            'Conflicts awaiting resolution',
          ],
          icon: Icons.sync_problem_outlined,
        ),
      ],
    );
  }
}

/// System information.
class SystemInformationScreen extends StatelessWidget {
  const SystemInformationScreen({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'System information',
      subtitle: 'Versions and limitations',
      children: [
        const SectionHeader(title: 'Build'),
        InfoCard(
          child: Column(
            children: [
              const RecordRow(
                label: 'App version',
                value: '0.1.0+1',
                mono: true,
              ),
              RecordRow(
                label: 'Environment',
                value: config.environment.name,
                mono: true,
              ),
              RecordRow(
                label: 'Simulation',
                value: config.simulationAvailable ? 'Available' : 'Disabled',
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Measurement'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(label: 'Algorithm version', value: 'sim-0', mono: true),
              RecordRow(
                label: 'Geometry version',
                value: 'badge-v1-research',
                mono: true,
              ),
              RecordRow(
                label: 'Feature definition',
                value: 'fdv-0.2.0-m0b',
                mono: true,
              ),
              RecordRow(label: 'Calibration model', value: 'None'),
              RecordRow(label: 'Workflow schema', value: '2', mono: true),
            ],
          ),
        ),

        const SectionHeader(title: 'Product limitations'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final limitation in const <String>[
                'No quantitative H₂S calibration exists. No ppm·h figure is '
                    'produced anywhere in this application.',
                'Scientific gates S1 (passive uptake), S2 (chemical '
                    'integration) and S3 (selectivity) are open.',
                'No badge has been manufactured. Batch and expiry data are '
                    'unavailable rather than estimated.',
                'No optical validation has been performed on a physical '
                    'smartphone photographing a printed target.',
                'Forward device-clock jumps cannot be detected. Backward '
                    'jumps are detected and cause a refusal.',
                'No enterprise integration is connected. Every reference is '
                    'manual or demonstration data.',
                'Records are stored on this device only and are not '
                    'synchronised or backed up.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.circle,
                          size: 5,
                          color: corporate.textSecondary,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          limitation,
                          style: t.caption.copyWith(
                            color: corporate.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
