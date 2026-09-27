import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart';

import '../../core/components/identity.dart';
import '../../core/components/product_page.dart';
import '../../core/components/workspace_components.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/env/environment.dart';
import '../account/presentation/workspace_more_screen.dart';
import '../auth/application/auth_controller.dart';
import '../operations/application/operations_providers.dart';

/// The worker's profile (PRODUCT BUILD v1 §29, §30).
///
/// A company record, shown read-only: ID, department, site, supervisor and
/// role are the organisation's to change, not the worker's (§29). Photograph
/// only when an approved one exists; otherwise initials — never a generated
/// or stock face (§30).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(availableSitesProvider);
    return ProductPage(
      title: 'Profile',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(ownProfileProvider),
          builder: (context, profile) {
            final p = profile.person;
            final site = sites.where((s) => s.id == p.siteId).firstOrNull;
            final photo = p.photoAsset == null
                ? null
                : AssetImage(p.photoAsset!);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  children: [
                    IdentityHeader(
                      name: p.displayName,
                      subtitle: '${p.personId} · ${p.designation}',
                      detail: p.contractorCompany ?? profile.departmentName,
                      photo: photo,
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.section),
                PageSection(
                  title: 'Company record',
                  children: [
                    SectionCard(
                      children: [
                        FactRow(label: 'Full name', value: p.displayName),
                        FactRow(
                          label: 'Worker ID',
                          value: p.personId,
                          mono: true,
                        ),
                        FactRow(
                          label: 'Worker type',
                          value: p.workerType.label,
                        ),
                        if (p.contractorCompany != null)
                          FactRow(
                            label: 'Contractor company',
                            value: p.contractorCompany!,
                          ),
                        FactRow(label: 'Site', value: site?.name ?? p.siteId),
                        FactRow(
                          label: 'Department',
                          value: profile.departmentName ?? p.departmentId,
                        ),
                        FactRow(label: 'Designation', value: p.designation),
                        if (profile.teamName != null)
                          FactRow(label: 'Team', value: profile.teamName!),
                        if (profile.supervisorName != null)
                          FactRow(
                            label: 'Supervisor',
                            value: profile.supervisorName!,
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      'These details come from the company record and cannot '
                      'be edited here. If something is wrong, ask your '
                      'supervisor or administrator to correct it. This build '
                      'uses presentation data, not an MRPL directory.',
                      style: context.type.caption.copyWith(
                        color: context.product.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        PageSection(
          title: 'This build',
          children: [
            BuildFacts(config: config),
            const SizedBox(height: Space.sm),
            const _EngineFacts(),
          ],
        ),
        if (config.simulationAvailable) ...[
          // Developer and research tools live behind /dev, outside every
          // workspace, and this entry exists only where simulation does.
          ActionCard(
            icon: Icons.build_outlined,
            title: 'Developer and research tools',
            message: 'Development builds only',
            onTap: () => context.push('/dev'),
          ),
          const SizedBox(height: Gaps.section),
        ],
        const SignOutButton(),
      ],
    );
  }
}

/// Versions read from the engine that actually runs.
class _EngineFacts extends StatelessWidget {
  const _EngineFacts();

  @override
  Widget build(BuildContext context) => const SectionCard(
    children: [
      FactRow(label: 'Algorithm', value: algorithmVersion, mono: true),
      FactRow(label: 'Features', value: featureDefinitionVersion, mono: true),
      FactRow(label: 'Geometry', value: 'badge-v1-research', mono: true),
    ],
  );
}
