import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/product_page.dart';
import '../../core/components/workspace_components.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../auth/application/auth_controller.dart';
import '../operations/application/operations_providers.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/data/work_context_repository.dart';
import '../workflow/domain/workflow_state.dart';
import 'presentation/profile_cards.dart';

/// Worker Profile (Worker directive §6–§10, §32–§34).
///
/// The authoritative worker screen: who they are, what they are assigned
/// to, and the work they recorded. Built from the rich Home it replaces.
///
/// Every value resolves from the signed-in person's directory record —
/// the same identity the monitoring session, the history and the DoseBand
/// assignment use — or from the work context they recorded. Nothing is
/// written into this widget, and a missing value reads "Not recorded".
///
/// App and technical information is in Settings, not here.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(availableSitesProvider);
    final session = ref.watch(shiftSessionProvider).value ?? ShiftSession.none;

    return ProductPage(
      title: 'Profile',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(ownProfileProvider),
          builder: (context, profile) {
            final p = profile.person;
            const repo = DemoWorkContextRepository();
            final site = sites.where((s) => s.id == p.siteId).firstOrNull;
            // A context from a finished period is history, not today's.
            final recorded = session.stage == ShiftStage.complete
                ? null
                : session.context;
            final gatePass = recorded?.worker.gatePass?.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkerIdentityCard(
                  name: p.displayName,
                  typeAndId: '${p.workerType.label} · ID ${p.personId}',
                  company: p.contractorCompany,
                  photo: p.photoAsset == null
                      ? null
                      : AssetImage(p.photoAsset!),
                ),
                const SizedBox(height: Space.md),
                ProfileSectionCard(
                  title: 'Work assignment',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileFieldGrid(
                        fields: [
                          ('Site', orNotRecorded(site?.name), false),
                          (
                            'Department',
                            orNotRecorded(profile.departmentName),
                            false,
                          ),
                          (
                            'Shift',
                            orNotRecorded(
                              repo.shiftById(p.defaultShiftId ?? '')?.name,
                            ),
                            false,
                          ),
                          (
                            'Work area',
                            orNotRecorded(
                              repo
                                  .workAreaById(p.defaultWorkAreaId ?? '')
                                  ?.name,
                            ),
                            false,
                          ),
                          ('Worker type', p.workerType.label, false),
                          if (p.contractorCompany != null)
                            ('Contractor', p.contractorCompany!, false),
                          ('Designation', p.designation, false),
                          if (profile.teamName != null)
                            ('Team', profile.teamName!, false),
                          if (profile.supervisorName != null)
                            ('Supervisor', profile.supervisorName!, false),
                          if (gatePass != null)
                            ('Gate pass', _mask(gatePass), true),
                        ],
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        'From your company record. It cannot be edited here; '
                        'ask your supervisor or administrator to correct '
                        'anything that is wrong.',
                        style: context.type.caption.copyWith(
                          color: context.corporate.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                ProfileSectionCard(
                  title: 'Work context',
                  actionLabel: recorded == null ? 'Record' : 'View all',
                  onAction: () => context.push('/work-context'),
                  child: recorded == null
                      ? const ProfileContextRows(
                          rows: [
                            ('Job', 'Not recorded', false),
                            ('PTW', 'Not recorded', false),
                            ('JSA', 'Not recorded', false),
                            ('Toolbox talk', 'Not recorded', false),
                          ],
                          footnote:
                              'Recorded before a DoseBand is assigned, so '
                              'its record says where and on what it was '
                              'worn.',
                        )
                      : ProfileContextRows(
                          rows: [
                            ('Job', recorded.job.title, false),
                            ('PTW', recorded.permit.reference.value, true),
                            ('JSA', recorded.jsa.reference.value, true),
                            // Acknowledged, never "completed": a tap on a
                            // phone is not evidence a talk happened.
                            ('Toolbox talk', 'Acknowledged', false),
                            (
                              'Supervisor',
                              orNotRecorded(profile.supervisorName),
                              false,
                            ),
                          ],
                          footnote:
                              'Recorded by you. DoseBand references these; it '
                              'does not approve permits or authorise work.',
                        ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: Space.md),
        ActionCard(
          icon: Icons.settings_outlined,
          title: 'Settings',
          message: 'Account, privacy and about DoseBand',
          onTap: () => context.push('/profile/settings'),
        ),
      ],
    );
  }

  /// A gate pass is a credential reference: only the last four characters.
  static String _mask(String value) =>
      value.length <= 4 ? value : '•••• ${value.substring(value.length - 4)}';
}
