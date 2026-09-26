import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/env/environment.dart';
import '../../../core/util/format.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';
import '../../workflow/data/work_context_repository.dart';
import '../data/admin_demo_catalog.dart';

/// One person in the demonstration directory.
///
/// ## What a role means here
///
/// The permissions listed describe what this role *would* be allowed to do.
/// They grant nothing. The prototype routes by whichever role was picked on
/// the selection screen, and routing is not authorisation — anyone can pick
/// any role, and nothing checks.
///
/// That distinction is the whole point of showing permissions at all: an
/// administration screen that listed them without saying so would read as
/// evidence that access control exists.
class AdminUserDetailScreen extends StatelessWidget {
  const AdminUserDetailScreen({required this.user, super.key});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: user.name,
      subtitle: '${user.userId} · ${user.role.label}',
      children: [
        const DemoDataBanner(
          message:
              'A demonstration directory entry. No identity provider is '
              'connected, so nothing about this person has been established '
              'by anything.',
        ),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Identity'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Name', value: user.name),
              RecordRow(label: 'User ID', value: user.userId, mono: true),
              RecordRow(label: 'Employment', value: user.employmentLabel),
              if (user.contractorCompany case final company?)
                RecordRow(label: 'Contractor', value: company),
              RecordRow(label: 'Department', value: user.department),
              const RecordRow(label: 'Site', value: 'Mangalore Refinery'),
              RecordRow(
                label: 'Last activity',
                value: Fmt.stamp(user.lastActivity),
                mono: true,
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Authentication'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Identity source',
                      style: t.caption.copyWith(color: corporate.textSecondary),
                    ),
                  ),
                  const OriginChip(DataOrigin.notConnected),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                user.identitySource,
                style: t.body.copyWith(color: corporate.textPrimary),
              ),
              const SizedBox(height: Space.sm),
              // No invented enterprise identity state.
              const RecordRow(label: 'Directory', value: 'Not connected'),
              const RecordRow(
                label: 'Multi-factor',
                value: 'Not applicable — no identity provider',
              ),
              const RecordRow(
                label: 'Account state',
                value: 'Demonstration entry',
              ),
            ],
          ),
        ),

        const SectionHeader(
          title: 'Permissions',
          subtitle: 'What this role would allow',
        ),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final permission in AdminPermission.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Row(
                    children: [
                      Icon(
                        user.role.permissions.contains(permission)
                            ? Icons.check_circle_outline
                            : Icons.remove_circle_outline,
                        size: 17,
                        color: corporate.textSecondary,
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          permission.label,
                          style: t.body.copyWith(
                            color: user.role.permissions.contains(permission)
                                ? corporate.textPrimary
                                : corporate.textSecondary,
                          ),
                        ),
                      ),
                      // Neither state is coloured green or red: this is a
                      // description of a future model, not a live grant.
                      Text(
                        user.role.permissions.contains(permission)
                            ? 'Would allow'
                            : 'Would not',
                        style: t.caption.copyWith(
                          color: corporate.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.sm),
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: corporate.surfaceMuted,
                  borderRadius: BorderRadius.circular(CorporateRadii.sm),
                  border: Border.all(color: corporate.border),
                ),
                child: Text(
                  'Production authorisation is not connected. The role '
                  'selector in this prototype is a review convenience: '
                  'anyone can pick any role, nothing checks, and none of the '
                  'permissions above is enforced.',
                  style: t.caption.copyWith(color: corporate.textPrimary),
                ),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Administration'),
        const _DisabledActions(
          actions: ['Change role', 'Suspend account', 'Remove user'],
          reason:
              'No identity or access management system exists, so nothing '
              'here could be written anywhere.',
        ),
      ],
    );
  }
}

/// Organisation-level configuration.
class OrganisationConfigurationScreen extends StatelessWidget {
  const OrganisationConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Organisation',
      subtitle: 'Configuration and terminology',
      children: [
        InfoCard(
          child: Text(
            'These settings adapt DoseBand to an organisation’s own '
            'vocabulary and processes. The values below are prototype '
            'configuration; none has been confirmed against any MRPL '
            'standard.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Organisation'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(
                label: 'Name',
                value: 'Mangalore Refinery and Petrochemicals Limited',
                origin: DataOrigin.uiDemo,
              ),
              RecordRow(label: 'Sites configured', value: '4'),
              RecordRow(label: 'Primary site', value: 'Mangalore Refinery'),
            ],
          ),
        ),

        const SectionHeader(
          title: 'Terminology',
          subtitle: 'What each concept is called here',
        ),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(label: 'Worker identifier', value: 'Worker ID'),
              RecordRow(label: 'Contractor', value: 'Contractor'),
              RecordRow(label: 'Permit', value: 'Permit to Work (PTW)'),
              RecordRow(label: 'Job safety', value: 'Job Safety Analysis'),
              RecordRow(label: 'Briefing', value: 'Toolbox talk'),
              RecordRow(label: 'Badge', value: 'DoseBand'),
            ],
          ),
        ),

        const SectionHeader(title: 'Workflow'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(
                label: 'Badge assignment',
                value: 'Manual selection (QR not connected)',
              ),
              RecordRow(label: 'Report template', value: 'Internal HSE'),
              RecordRow(
                label: 'Emergency information',
                value: 'Not configured',
                origin: DataOrigin.notConnected,
              ),
              RecordRow(
                label: 'Occupational health',
                value: 'Not connected',
                origin: DataOrigin.notConnected,
              ),
              RecordRow(
                label: 'Hazard reporting',
                value: 'Not connected',
                origin: DataOrigin.notConnected,
              ),
            ],
          ),
        ),

        const SizedBox(height: Space.base),
        const _DisabledActions(
          actions: ['Edit configuration'],
          reason:
              'No configuration store exists, so an edit could not be '
              'persisted.',
        ),
      ],
    );
  }
}

/// One integration, in detail.
class IntegrationDetailScreen extends StatelessWidget {
  const IntegrationDetailScreen({required this.integration, super.key});

  final AdminIntegration integration;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: integration.name,
      subtitle: integration.state.label,
      children: [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.link_off,
                    size: 19,
                    color: corporate.textSecondary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Not connected',
                        style: t.bodyStrong.copyWith(
                          color: corporate.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const OriginChip(DataOrigin.notConnected),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                integration.blockedBy,
                style: t.body.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Purpose'),
        InfoCard(
          child: Text(
            integration.purpose,
            style: t.body.copyWith(color: corporate.textSecondary),
          ),
        ),

        const SectionHeader(title: 'Configuration'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(
                label: 'Integration',
                value: integration.id,
                mono: true,
              ),
              const RecordRow(label: 'Provider', value: 'Not configured'),
              const RecordRow(label: 'Endpoint', value: 'Not configured'),
              const RecordRow(label: 'Authentication', value: 'Not configured'),
              RecordRow(
                label: 'Data direction',
                value: integration.dataDirection,
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Activity'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Null, and shown as such. A timestamp here would be a
              // fabricated event, and it is the field a reviewer would most
              // readily believe.
              RecordRow(
                label: 'Last attempt',
                value: integration.lastAttempt == null
                    ? 'Never'
                    : Fmt.stamp(integration.lastAttempt!),
              ),
              RecordRow(
                label: 'Last success',
                value: integration.lastSuccess == null
                    ? 'Never'
                    : Fmt.stamp(integration.lastSuccess!),
              ),
              const RecordRow(label: 'Last error', value: 'None recorded'),
              const SizedBox(height: Space.xs),
              Text(
                'Never attempted. DoseBand holds no endpoint for this '
                'integration and makes no network request.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SizedBox(height: Space.base),
        const _DisabledActions(
          actions: ['Configure', 'Test connection'],
          reason: 'There is nothing to configure or test.',
        ),
      ],
    );
  }
}

/// One device.
class AdminDeviceDetailScreen extends StatelessWidget {
  const AdminDeviceDetailScreen({required this.device, super.key});

  final AdminDevice device;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: device.name,
      subtitle: '${device.deviceId} · ${device.platform}',
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Device'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Device ID', value: device.deviceId, mono: true),
              RecordRow(label: 'Platform', value: device.platform),
              RecordRow(label: 'Operating system', value: device.osVersion),
              RecordRow(
                label: 'App version',
                value: device.appVersion,
                mono: true,
              ),
              RecordRow(
                label: 'Last seen',
                value: Fmt.stamp(device.lastSeen),
                mono: true,
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Capture capability'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecordRow(
                label: 'Camera capability',
                value: device.captureCapability,
              ),
              const RecordRow(label: 'Exposure lock', value: 'Not assessed'),
              const RecordRow(
                label: 'White-balance lock',
                value: 'Not assessed',
              ),
              const RecordRow(label: 'Focus lock', value: 'Not assessed'),
              const SizedBox(height: Space.xs),
              Text(
                'Capture capabilities are read from the device at runtime '
                'and are not recorded here. "Not assessed" is not the same '
                'as "supported".',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Measurement validation'),
        InfoCard(
          emphasis: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecordRow(
                label: 'Validation state',
                value: device.validation.label,
              ),
              const SizedBox(height: Space.xs),
              Text(
                device.validation.explanation,
                style: t.body.copyWith(color: corporate.textSecondary),
              ),
              const SizedBox(height: Space.sm),
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: corporate.surfaceMuted,
                  borderRadius: BorderRadius.circular(CorporateRadii.sm),
                  border: Border.all(color: corporate.border),
                ),
                child: Text(
                  'Physical device validation is incomplete. No smartphone '
                  'has yet photographed a printed target through this '
                  'application, so no device can be marked validated — and '
                  'this screen will not mark one.',
                  style: t.caption.copyWith(color: corporate.textPrimary),
                ),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Versions and sync'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(
                label: 'Geometry version',
                value: 'badge-v1-research',
                mono: true,
              ),
              RecordRow(
                label: 'Calibration compatibility',
                value: 'No calibration exists',
              ),
              RecordRow(label: 'Sync state', value: 'Local only'),
              RecordRow(label: 'Last synchronised', value: 'Never'),
            ],
          ),
        ),
      ],
    );
  }
}

/// App, algorithm and data versions.
class AdminVersionsScreen extends StatelessWidget {
  const AdminVersionsScreen({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Versions',
      subtitle: 'Reproducibility and traceability',
      children: [
        InfoCard(
          child: Text(
            'A measurement is reproducible only if the versions that produced '
            'it are known. Every exposure record pins these, and a future '
            'change supersedes for new readings rather than restating old '
            'ones.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Application'),
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
              const RecordRow(label: 'Release state', value: 'Prototype'),
            ],
          ),
        ),

        const SectionHeader(title: 'Measurement'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(label: 'Algorithm version', value: 'sim-0', mono: true),
              RecordRow(
                label: 'Feature definition',
                value: 'fdv-0.2.0-m0b',
                mono: true,
              ),
              RecordRow(
                label: 'Geometry version',
                value: 'badge-v1-research',
                mono: true,
              ),
              RecordRow(
                label: 'Calibration version',
                value: 'None — no production calibration exists',
              ),
              RecordRow(label: 'Data domain', value: 'simulated'),
            ],
          ),
        ),

        const SectionHeader(title: 'Data'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(label: 'Workflow schema', value: '2', mono: true),
              RecordRow(
                label: 'Report template version',
                value: 'rt-0.1.0',
                mono: true,
              ),
              RecordRow(label: 'Record database', value: 'Not implemented'),
            ],
          ),
        ),

        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'No production release history exists. This is a prototype '
            'build, and no version above has been released to anyone.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Calibration administration.
///
/// ## What this screen governs, and what it must not do
///
/// It governs the *lifecycle* of a calibration package: which exists, which
/// is active, which superseded which. It does not create calibration science,
/// and it must not offer a working control that activates a production
/// calibration when none exists — an administration screen that could switch
/// on quantitative output would be a path around scientific validation.
class CalibrationAdministrationScreen extends StatelessWidget {
  const CalibrationAdministrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Calibration',
      subtitle: 'Package governance',
      children: [
        InfoCard(
          emphasis: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 21,
                    color: corporate.textSecondary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'No production H₂S calibration available',
                        style: t.heading.copyWith(color: corporate.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                'No validated calibration model exists. No laboratory data '
                'has been collected, and the scientific gates that would '
                'justify one are open.',
                style: t.body.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Installed packages'),
        const InfoCard(
          child: Text(
            'No calibration package is installed. This list stays empty '
            'rather than showing a research placeholder that could be '
            'mistaken for one.',
          ),
        ),

        const SectionHeader(
          title: 'Package metadata',
          subtitle: 'The shape a package will take',
        ),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(label: 'Calibration ID', value: 'Unavailable'),
              RecordRow(label: 'Version', value: 'Unavailable'),
              RecordRow(label: 'Formulation', value: 'Unavailable'),
              RecordRow(
                label: 'Geometry',
                value: 'badge-v1-research',
                mono: true,
              ),
              RecordRow(label: 'Model type', value: 'Unavailable'),
              RecordRow(label: 'Validated domain', value: 'Unavailable'),
              RecordRow(label: 'Device domain', value: 'Unavailable'),
              RecordRow(label: 'Environmental domain', value: 'Unavailable'),
              RecordRow(label: 'Evidence', value: 'Unavailable'),
              RecordRow(label: 'Created', value: 'Unavailable'),
              RecordRow(label: 'Status', value: 'None exists'),
              RecordRow(label: 'Supersedes', value: 'Not applicable'),
              RecordRow(label: 'Integrity', value: 'No signing service'),
            ],
          ),
        ),

        const SectionHeader(
          title: 'Performance metrics',
          subtitle: 'Produced by experiments, not by software',
        ),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(label: 'Accuracy', value: 'Unavailable'),
              RecordRow(label: 'Limit of detection', value: 'Unavailable'),
              RecordRow(label: 'Limit of quantification', value: 'Unavailable'),
              RecordRow(label: 'RMSE', value: 'Unavailable'),
              RecordRow(label: 'R²', value: 'Unavailable'),
              RecordRow(label: 'Uncertainty', value: 'Unavailable'),
              RecordRow(label: 'Validated range', value: 'Unavailable'),
            ],
          ),
        ),

        const SectionHeader(title: 'Open scientific gates'),
        InfoCard(
          child: Column(
            children: const [
              _Gate(
                code: 'S1',
                question: 'Passive uptake at a known, reproducible rate',
              ),
              _Gate(
                code: 'S2',
                question: 'Colour change as a faithful integral of exposure',
              ),
              _Gate(
                code: 'S3',
                question: 'Selectivity and interference behaviour',
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Actions'),
        const _DisabledActions(
          actions: [
            'Import calibration package',
            'Activate calibration',
            'Supersede calibration',
          ],
          reason:
              'There is no package to import, activate or supersede. These '
              'controls stay disabled rather than offering a route around '
              'scientific validation.',
        ),
      ],
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({required this.code, required this.question});

  final String code;
  final String question;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              code,
              style: t.readoutSmall.copyWith(color: corporate.textPrimary),
            ),
          ),
          Expanded(
            child: Text(
              question,
              style: t.caption.copyWith(color: corporate.textSecondary),
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(
            'OPEN',
            style: t.caption.copyWith(
              color: corporate.accent,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge geometry, formulation and batch configuration.
class BadgeConfigurationScreen extends StatelessWidget {
  const BadgeConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Badge configuration',
      subtitle: 'Geometry, formulation and batches',
      children: [
        const SectionHeader(title: 'Geometry'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RecordRow(
                label: 'Active geometry',
                value: 'badge-v1-research',
                mono: true,
              ),
              const RecordRow(
                label: 'Source',
                value: 'packages/measurement (canonical)',
              ),
              const RecordRow(label: 'Verified by', value: 'SHA-256 manifest'),
              const SizedBox(height: Space.xs),
              Text(
                'Geometry is defined in the measurement package and exported '
                'to the application with a checksum manifest, which the app '
                'verifies before parsing. It is shown here, not edited here: '
                'a geometry changed from an administration text field would '
                'be a second source of truth for where a sensor region is.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Formulation'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(
                label: 'Active formulation',
                value: 'Bi-based colorimetric (sim)',
                origin: DataOrigin.uiDemo,
              ),
              RecordRow(label: 'Reference profile', value: 'ref-sim-1'),
              RecordRow(
                label: 'Calibration compatibility',
                value: 'No calibration exists',
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Batches'),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(
                label: 'Batches configured',
                value: '2',
                origin: DataOrigin.uiDemo,
              ),
              RecordRow(label: 'Manufacture records', value: 'None exist'),
              RecordRow(label: 'Quality release', value: 'None exist'),
              RecordRow(label: 'Shelf life', value: 'Not established'),
              RecordRow(label: 'Expiry policy', value: 'Not established'),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'No DoseBand badge has been manufactured. There is no supply '
            'chain, no quality release and no expiry policy, so those fields '
            'stay empty rather than being filled with plausible values.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),

        const SizedBox(height: Space.base),
        const _DisabledActions(
          actions: ['Register batch', 'Import geometry'],
          reason:
              'No badge inventory service exists, and geometry is owned by '
              'the measurement package rather than by administration.',
        ),
      ],
    );
  }
}

/// Development-only demo dataset controls.
class DemoDataControlsScreen extends StatelessWidget {
  const DemoDataControlsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    const config = DemoWorkContextRepository();

    return SafetyScaffold(
      title: 'Demo data',
      subtitle: 'Development only',
      children: [
        // Emphasis, not the simulated magenta. This banner is about which
        // build you are running, not about measurement provenance, and the
        // magenta is reserved so that it means exactly one thing wherever it
        // appears: this quantity is not a real H2S measurement.
        InfoCard(
          emphasis: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 19,
                color: corporate.textSecondary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Development build only',
                        style: t.bodyStrong.copyWith(
                          color: corporate.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This screen exists so the interface can be reviewed '
                      'without walking every workflow by hand. It is '
                      'compiled out of production builds.',
                      style: t.caption.copyWith(color: corporate.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Datasets in this build'),
        InfoCard(
          child: Column(
            children: [
              RecordRow(
                label: 'Worker previews',
                value: 'Available',
                origin: DataOrigin.uiDemo,
              ),
              const RecordRow(
                label: 'Simulation specimens',
                value: '6 badge outcomes',
              ),
              const RecordRow(label: 'HSE records', value: '10 records'),
              const RecordRow(
                label: 'Reporting records',
                value: '10 occupational records',
              ),
              const RecordRow(label: 'Safety documents', value: '11 entries'),
              RecordRow(
                label: 'Departments',
                value: '${config.departments().length}',
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Previews'),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              NavigationRow(
                icon: Icons.preview_outlined,
                title: 'Worker screen previews',
                subtitle: 'Seed any Home or workflow state',
                onTap: () => context.go('/dev/worker-previews'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Divider(height: 1, color: corporate.border),
              ),
              NavigationRow(
                icon: Icons.palette_outlined,
                title: 'Design system gallery',
                onTap: () => context.go('/dev/gallery'),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'System mode'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RecordRow(label: 'Mode', value: 'Development'),
              const RecordRow(
                label: 'Production services',
                value: 'Not connected',
                origin: DataOrigin.notConnected,
              ),
              const SizedBox(height: Space.sm),
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: corporate.surfaceMuted,
                  borderRadius: BorderRadius.circular(CorporateRadii.sm),
                  border: Border.all(color: corporate.border),
                ),
                child: Text(
                  'There is no switch from development to production here, '
                  'and there should not be. Production readiness is a '
                  'property of the backend, the calibration and the '
                  'integrations — not a flag this screen could set.',
                  style: t.caption.copyWith(color: corporate.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A row of controls that cannot do anything yet, and the reason.
///
/// Disabled rather than absent: the action is part of the design, and hiding
/// it would make the administration surface look thinner than it is. Disabled
/// rather than silently inert: a control that appears to save and does not is
/// the worst of the three.
class _DisabledActions extends StatelessWidget {
  const _DisabledActions({required this.actions, required this.reason});

  final List<String> actions;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: null, child: Text(action)),
              ),
            ),
          Semantics(
            label: 'These actions are unavailable. $reason',
            excludeSemantics: true,
            child: Text(
              reason,
              style: t.caption.copyWith(color: corporate.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A detail route whose identifier matches nothing.
///
/// Reachable by typing a URL or by following a stale deep link. It says the
/// record was not found rather than rendering an empty detail screen, which
/// would read as a record that exists and happens to be blank.
class AdminRecordNotFoundScreen extends StatelessWidget {
  const AdminRecordNotFoundScreen({
    required this.recordKind,
    required this.identifier,
    super.key,
  });

  final String recordKind;
  final String identifier;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return SafetyScaffold(
      title: 'Not found',
      children: [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'No $recordKind with this identifier',
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                identifier,
                style: t.readoutSmall.copyWith(color: corporate.textSecondary),
              ),
              const SizedBox(height: Space.sm),
              Text(
                'Nothing matches it in the demonstration directory.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
