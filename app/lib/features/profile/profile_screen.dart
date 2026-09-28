import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/product_page.dart';
import '../../core/components/workspace_components.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/format.dart';
import '../auth/application/auth_controller.dart';
import '../home/domain/home_presentation.dart';
import '../operations/application/operations_providers.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/data/work_context_repository.dart';
import '../workflow/domain/workflow_state.dart';
import 'presentation/profile_cards.dart';

/// Worker Profile, in the approved rich layout: the refinery header, the
/// identity card overlapping it, Today's shift and Work context — then the
/// way into Settings.
///
/// Every value resolves from the signed-in person's directory record or the
/// work context they recorded; a missing value reads "Not recorded".
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(shiftSessionProvider).value ?? ShiftSession.none;
    final now = ref.watch(clockProvider)();
    final presentation = HomePresentation.from(session: session, now: now);
    final sites = ref.watch(availableSitesProvider);

    // Today's work: what the worker recorded, or — until they do — the usual
    // site, department, area and shift from their company record. A context
    // from a period completed on an earlier day is not today's.
    final recorded =
        session.stage == ShiftStage.complete &&
            presentation.stage != HomeStage.completed
        ? null
        : session.context;

    return ProfileLayout(
      children: [
        OpsView(
          value: ref.watch(ownProfileProvider),
          builder: (context, profile) {
            final p = profile.person;
            const repo = DemoWorkContextRepository();
            final siteName =
                recorded?.site.name ??
                sites.where((s) => s.id == p.siteId).firstOrNull?.name;
            final department =
                recorded?.department.name ?? profile.departmentName;
            final shift =
                recorded?.shift.name ??
                repo.shiftById(p.defaultShiftId ?? '')?.name;
            final area =
                recorded?.workArea.name ??
                repo.workAreaById(p.defaultWorkAreaId ?? '')?.name;
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
                  title: 'Today’s shift',
                  actionLabel: recorded == null ? 'Record' : 'View details',
                  onAction: () => context.push('/work-context'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileFieldGrid(
                        fields: [
                          ('Site', orNotRecorded(siteName), false),
                          ('Department', orNotRecorded(department), false),
                          ('Shift', orNotRecorded(shift), false),
                          ('Work area', orNotRecorded(area), false),
                          if (gatePass != null)
                            ('Gate pass', _mask(gatePass), true),
                          ('Date', Fmt.date(now), true),
                        ],
                      ),
                      if (recorded == null) ...[
                        const SizedBox(height: Space.sm),
                        Text(
                          'Usual assignment from your company record. '
                          'Confirm today’s work before a DoseBand is '
                          'assigned.',
                          style: context.type.caption.copyWith(
                            color: context.corporate.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                ProfileSectionCard(
                  title: 'Work context',
                  actionLabel: recorded == null ? null : 'View all',
                  onAction: () => context.push('/work-context'),
                  child: recorded == null
                      ? ProfileContextRows(
                          rows: [
                            ('PTW', 'Not recorded', false),
                            ('JSA', 'Not recorded', false),
                            ('Toolbox talk', 'Not recorded', false),
                            (
                              'Supervisor',
                              orNotRecorded(profile.supervisorName),
                              false,
                            ),
                          ],
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
                              'Recorded by you. Not checked against a permit '
                              'system; DoseBand does not authorise work.',
                        ),
                ),
              ],
            );
          },
        ),
        if (_currentBand(session, presentation) case final band?) ...[
          const SizedBox(height: Space.md),
          ProfileSectionCard(
            title: 'Current DoseBand',
            child: ProfileFieldGrid(
              fields: [
                ('DoseBand', band.id, true),
                ('Monitoring', band.state, false),
                if (session.startedAt != null)
                  ('Started', Fmt.stamp(session.startedAt!), true),
              ],
            ),
          ),
        ],
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

  /// The DoseBand the worker is wearing, while a period is open.
  static ({String id, String state})? _currentBand(
    ShiftSession session,
    HomePresentation presentation,
  ) {
    final id = session.assignedBadge?.badgeId;
    if (id == null) return null;
    return switch (presentation.stage) {
      HomeStage.monitoringActive => (id: id, state: 'Active'),
      HomeStage.readyForFinalRead => (id: id, state: 'Ready for final read'),
      HomeStage.doseBandAssigned => (id: id, state: 'Assigned'),
      HomeStage.requiresAttention => (id: id, state: 'Needs attention'),
      _ => null,
    };
  }

  /// A gate pass is a credential reference: only the last four characters.
  static String _mask(String value) =>
      value.length <= 4 ? value : '•••• ${value.substring(value.length - 4)}';
}
