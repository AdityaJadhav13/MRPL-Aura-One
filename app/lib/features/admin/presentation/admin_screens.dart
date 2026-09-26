import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/env/environment.dart';
import '../../../core/util/format.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';
import '../../workflow/data/work_context_repository.dart';
import '../data/admin_demo_catalog.dart';

/// Administration home.
///
/// ## What this screen is for
///
/// A reviewer opening Administration is asking one question: *how much of
/// this actually exists?* So the first thing on the screen is a count of the
/// system's real state — integrations connected, devices validated, retention
/// policies configured, calibrations installed — and every one of those counts
/// is currently zero.
///
/// Those zeros are rendered in the ordinary text colour, not in red and
/// certainly not in green. They are not failures; they are the accurate
/// position of a prototype. Colouring them as alarms would be as misleading
/// as colouring them as successes.
///
/// A sectioned index rather than a bottom bar: there are seventeen modules
/// here and squeezing them into five tabs would hide most of them behind a
/// "More" destination that nobody opens.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({required this.config, super.key});

  /// Needed for one decision only: whether the demo-data controls exist. They
  /// are compiled out of production the same way the gallery is.
  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final integrations = AdminDemoCatalog.integrations();
    final devices = AdminDemoCatalog.devices();
    final retention = AdminDemoCatalog.retentionProfiles();

    final validated = devices
        .where((d) => d.validation == DeviceValidationState.validated)
        .length;
    final configuredRetention = retention
        .where((r) => r.duration != null)
        .length;

    return SafetyScaffold(
      title: 'Administration',
      subtitle: 'Configuration and system state',
      showHero: true,
      children: [
        const DemoDataBanner(
          message:
              'Administration is read-only in this prototype. Nothing on '
              'these screens writes configuration, and no identity or access '
              'management system is connected.',
        ),
        const SizedBox(height: Space.base),

        const SectionHeader(
          title: 'System state',
          subtitle: 'What exists today, counted',
        ),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StateCount(
                label: 'Integrations connected',
                value: '0 of ${integrations.length}',
              ),
              _StateCount(
                label: 'Devices validated for measurement',
                value: '$validated of ${devices.length}',
              ),
              _StateCount(
                label: 'Retention policies configured',
                value: '$configuredRetention of ${retention.length}',
              ),
              const _StateCount(
                label: 'Calibration packages installed',
                value: 'None',
              ),
              const _StateCount(
                label: 'Records synchronised',
                value: 'None — local to each device',
              ),
              const SizedBox(height: Space.sm),
              Text(
                'These are counts, not warnings. A prototype with no backend '
                'legitimately has nothing connected; the point of showing the '
                'numbers is that nobody has to take that on trust.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Integrations'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              NavigationRow(
                icon: Icons.hub_outlined,
                title: 'Integration status',
                subtitle: 'What is and is not connected',
                onTap: () => context.push('/admin/integrations'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.sync_outlined,
                title: 'Sync health',
                origin: DataOrigin.notConnected,
                onTap: () => context.push('/admin/sync'),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Organisation'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              NavigationRow(
                icon: Icons.manage_accounts_outlined,
                title: 'Users and roles',
                origin: DataOrigin.uiDemo,
                onTap: () => context.push('/admin/users'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.factory_outlined,
                title: 'Sites',
                onTap: () => context.push('/admin/sites'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.account_tree_outlined,
                title: 'Departments',
                onTap: () => context.push('/admin/departments'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.map_outlined,
                title: 'Work areas',
                onTap: () => context.push('/admin/work-areas'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.tune_outlined,
                title: 'Organisation configuration',
                subtitle: 'Terminology and workflow',
                onTap: () => context.push('/admin/organisation'),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Measurement'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              NavigationRow(
                icon: Icons.science_outlined,
                title: 'Calibration',
                subtitle: 'No production calibration exists',
                onTap: () => context.push('/admin/calibration'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.badge_outlined,
                title: 'Badge configuration',
                subtitle: 'Geometry, formulation and batches',
                onTap: () => context.push('/admin/badges'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.numbers_outlined,
                title: 'Versions',
                subtitle: 'App, algorithm and data',
                onTap: () => context.push('/admin/versions'),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'System'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              NavigationRow(
                icon: Icons.phone_android_outlined,
                title: 'Devices',
                origin: DataOrigin.uiDemo,
                onTap: () => context.push('/admin/devices'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.inventory_outlined,
                title: 'Retention profiles',
                onTap: () => context.push('/admin/retention'),
              ),
              _Sep(),
              NavigationRow(
                icon: Icons.info_outline,
                title: 'System information',
                onTap: () => context.push('/admin/system'),
              ),
              if (config.simulationAvailable) ...[
                _Sep(),
                NavigationRow(
                  icon: Icons.dataset_outlined,
                  title: 'Demo data',
                  subtitle: 'Development build only',
                  origin: DataOrigin.uiDemo,
                  onTap: () => context.push('/admin/demo-data'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One line of the system-state count.
///
/// Deliberately unstyled by state: no green, no red. See [AdminHomeScreen].
class _StateCount extends StatelessWidget {
  const _StateCount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: t.body.copyWith(color: corporate.textSecondary),
            ),
          ),
          const SizedBox(width: Space.sm),
          // Flexible, not a bare Text: "None — local to each device" is
          // longer than the row at large text scales, and an unconstrained
          // child there overflows rather than wrapping.
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: t.bodyStrong.copyWith(color: corporate.textPrimary),
            ),
          ),
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

/// Users and roles.
///
/// ## Roles here are descriptive, not enforced
///
/// The directory is demonstration data, and the roles attached to it grant
/// nothing. Saying so once in the banner is not enough: each row carries the
/// role as a plain label rather than a badge, because a badge reads as a
/// credential the system issued.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final users = AdminDemoCatalog.users();

    return SafetyScaffold(
      title: 'Users and roles',
      subtitle: '${users.length} demonstration entries',
      children: [
        const DemoDataBanner(
          message:
              'No identity or access management system is connected. Roles '
              'shown here are demonstration values and grant nothing — the '
              'prototype’s role selector is a review convenience, not '
              'access control.',
        ),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Directory'),
        for (final user in users)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: InfoCard(
              onTap: () => context.push('/admin/users/${user.userId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name,
                          style: t.bodyStrong.copyWith(
                            color: corporate.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        user.role.label,
                        style: t.caption.copyWith(
                          color: corporate.textSecondary,
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: corporate.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  RecordRow(label: 'User ID', value: user.userId, mono: true),
                  RecordRow(label: 'Employment', value: user.employmentLabel),
                  if (user.contractorCompany case final company?)
                    RecordRow(label: 'Contractor', value: company),
                  RecordRow(label: 'Department', value: user.department),
                ],
              ),
            ),
          ),

        const SectionHeader(title: 'Roles'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final role in AdminRole.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          role.label,
                          style: t.body.copyWith(color: corporate.textPrimary),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          role.permissions.map((p) => p.label).join(', '),
                          textAlign: TextAlign.end,
                          style: t.caption.copyWith(
                            color: corporate.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.sm),
              Text(
                'These describe what each role would be allowed to do. None '
                'is enforced: anyone can select any role at sign-in and '
                'nothing checks.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
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

/// Devices.
class AdminDevicesScreen extends StatelessWidget {
  const AdminDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final devices = AdminDemoCatalog.devices();

    return SafetyScaffold(
      title: 'Devices',
      subtitle: '${devices.length} registered · none validated',
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'A handset is registered as soon as it runs DoseBand. Whether it '
            'can make a valid measurement is a separate question, and no '
            'device has been assessed against it.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
        const SizedBox(height: Space.base),
        for (final d in devices)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: InfoCard(
              onTap: () => context.push('/admin/devices/${d.deviceId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.name,
                          style: t.bodyStrong.copyWith(
                            color: corporate.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        d.platform,
                        style: t.caption.copyWith(
                          color: corporate.textSecondary,
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: corporate.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  RecordRow(label: 'Device ID', value: d.deviceId, mono: true),
                  RecordRow(label: 'Operating system', value: d.osVersion),
                  RecordRow(
                    label: 'App version',
                    value: d.appVersion,
                    mono: true,
                  ),
                  RecordRow(
                    label: 'Last seen',
                    value: Fmt.stamp(d.lastSeen),
                    mono: true,
                  ),
                  // No certification is claimed: nothing has assessed whether
                  // a given handset's camera can make a valid measurement.
                  RecordRow(
                    label: 'Measurement validation',
                    value: d.validation.label,
                  ),
                ],
              ),
            ),
          ),
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
