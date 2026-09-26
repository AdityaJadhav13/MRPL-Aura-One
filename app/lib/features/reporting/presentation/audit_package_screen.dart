import 'package:flutter/material.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../../safety/presentation/widgets/safety_scaffold.dart';
import '../data/reporting_demo_catalog.dart';
import '../domain/report_models.dart';

/// Assembling an audit package.
///
/// An auditor's question is not "what was the exposure" but "show me the
/// chain and the evidence". So a package is a selection of sections plus a
/// manifest that pins the versions everything was produced under — that is
/// what makes a historical report reproducible when software changes.
///
/// Nothing is generated. The preview shows what a package would contain and
/// the manifest shows what it would pin; the distinction between that and an
/// archive existing is the whole honesty of this screen.
class AuditPackageScreen extends StatefulWidget {
  const AuditPackageScreen({super.key});

  @override
  State<AuditPackageScreen> createState() => _AuditPackageScreenState();
}

class _AuditPackageScreenState extends State<AuditPackageScreen> {
  final Set<ReportSection> _sections = ReportSection.values.toSet();
  ReportTemplateProfile _profile = ReportTemplateProfile.internalHse;
  String _period = 'Last 30 days';

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final records = ReportingDemoCatalog.records();

    final manifest = AuditPackageManifest(
      // Not an official identifier. Nothing has been created, so the field
      // says what it is rather than inventing something that looks filed.
      packageId: 'Not assigned — no package has been created',
      createdAt: DateTime.now(),
      createdBy: 'DoseBand prototype',
      periodLabel: _period,
      sections: _sections,
      recordCount: records.length,
      profile: _profile,
    );

    return SafetyScaffold(
      title: 'Audit package',
      subtitle: 'Assemble evidence for review',
      children: [
        const DemoDataBanner(),
        const SizedBox(height: Space.base),

        const SectionHeader(title: 'Period'),
        InfoCard(
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final period in const [
                'Last 7 days',
                'Last 30 days',
                'This quarter',
              ])
                ChoiceChip(
                  label: Text(period),
                  selected: _period == period,
                  showCheckmark: true,
                  onSelected: (_) => setState(() => _period = period),
                ),
            ],
          ),
        ),

        const SectionHeader(
          title: 'Contents',
          subtitle: 'What the package would include',
        ),
        InfoCard(
          child: Column(
            children: [
              for (final section in ReportSection.values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _sections.contains(section),
                  onChanged: (on) => setState(() {
                    if (on ?? false) {
                      _sections.add(section);
                    } else {
                      _sections.remove(section);
                    }
                  }),
                  title: Text(
                    section.label,
                    style: t.body.copyWith(color: corporate.textPrimary),
                  ),
                ),
              const Divider(),
              // Organisation documents would be included if a repository were
              // connected. It is not, so the row says so rather than offering
              // a checkbox that includes nothing.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 17,
                      color: corporate.textSecondary,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        'Referenced organisation documents',
                        style: t.body.copyWith(color: corporate.textSecondary),
                      ),
                    ),
                    const OriginChip(DataOrigin.notConnected, compact: true),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Template profile'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final profile in ReportTemplateProfile.values)
                    ChoiceChip(
                      label: Text(profile.label),
                      selected: _profile == profile,
                      showCheckmark: true,
                      onSelected: (_) => setState(() => _profile = profile),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                _profile.caveat,
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(
          title: 'Manifest',
          subtitle: 'What the package would declare about itself',
        ),
        InfoCard(
          child: Column(
            children: [
              RecordRow(label: 'Package ID', value: manifest.packageId),
              RecordRow(
                label: 'Created',
                value: Fmt.stamp(manifest.createdAt),
                mono: true,
              ),
              RecordRow(label: 'Created by', value: manifest.createdBy),
              RecordRow(label: 'Period', value: manifest.periodLabel),
              RecordRow(
                label: 'Sections',
                value: '${manifest.sections.length}',
              ),
              RecordRow(label: 'Records', value: '${manifest.recordCount}'),
              RecordRow(
                label: 'Template profile',
                value: manifest.profile.label,
              ),
              RecordRow(
                label: 'Data source',
                value: 'Demonstration records',
                origin: DataOrigin.uiDemo,
              ),
            ],
          ),
        ),

        const SectionHeader(
          title: 'Pinned versions',
          subtitle: 'So a historical package stays reproducible',
        ),
        InfoCard(
          child: Column(
            children: [
              for (final entry in manifest.versions.entries)
                RecordRow(
                  label: entry.key,
                  value: entry.value,
                  mono: !entry.value.startsWith('None'),
                ),
            ],
          ),
        ),

        const SectionHeader(title: 'Integrity'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecordRow(label: 'Signature', value: manifest.signatureState),
              const SizedBox(height: Space.xs),
              Text(
                'DoseBand holds no signing keys. A package that claimed to be '
                'signed would assert an integrity guarantee nothing backs, '
                'and an auditor would reasonably rely on it.',
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),

        const SectionHeader(title: 'Create'),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Create audit package'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(kMinTouchTarget),
                  ),
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                'Unavailable. No archive or export service exists, so nothing '
                'has been created, generated or submitted.',
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: corporate.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Previously generated reports and packages.
///
/// There are none, and the screen says so rather than inventing plausible
/// report identifiers. A populated history would be the clearest possible lie
/// about export: it asserts that reports have been produced and filed.
class ExportHistoryScreen extends StatelessWidget {
  const ExportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final history = ReportingDemoCatalog.reportHistory();

    return SafetyScaffold(
      title: 'Report history',
      subtitle: 'Generated reports and packages',
      children: [
        if (history.isEmpty)
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 19,
                      color: corporate.textSecondary,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'No reports have been generated',
                          style: t.bodyStrong.copyWith(
                            color: corporate.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'No report or export service exists, so nothing has been '
                  'produced. This list stays empty rather than showing '
                  'invented report identifiers.',
                  style: t.body.copyWith(color: corporate.textSecondary),
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.base),

        const SectionHeader(
          title: 'What a history entry will hold',
          subtitle: 'Once a report service exists',
        ),
        InfoCard(
          child: Column(
            children: const [
              RecordRow(label: 'Report ID', value: 'Unavailable'),
              RecordRow(label: 'Type', value: 'Unavailable'),
              RecordRow(label: 'Period', value: 'Unavailable'),
              RecordRow(label: 'Created', value: 'Unavailable'),
              RecordRow(label: 'Created by', value: 'Unavailable'),
              RecordRow(label: 'Template profile', value: 'Unavailable'),
              RecordRow(label: 'Status', value: 'Unavailable'),
              RecordRow(label: 'Export format', value: 'Unavailable'),
              RecordRow(label: 'Supersedes', value: 'Unavailable'),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'A superseding report references the one it replaces rather than '
            'overwriting it, so an earlier conclusion can still be read '
            'alongside the evidence it was drawn from.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}
