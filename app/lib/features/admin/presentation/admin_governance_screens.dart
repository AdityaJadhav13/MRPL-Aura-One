import 'package:flutter/material.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/env/environment.dart';
import '../../../core/util/format.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';
import '../data/admin_demo_catalog.dart';

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

/// A detail route whose identifier matches nothing.
///
/// Reachable by typing a URL or by following a stale deep link. It says the
/// record was not found rather than rendering an empty detail screen, which
/// would read as a record that exists and happens to be blank.
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
