import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/identity.dart';
import '../../../core/components/product_page.dart';
import '../../../core/components/workspace_components.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/env/app_info.dart';
import '../../../core/env/app_version.dart';
import '../../../core/env/environment.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../operations/application/operations_providers.dart';

/// A link on a workspace's More page.
@immutable
class MoreLink {
  const MoreLink({
    required this.icon,
    required this.title,
    required this.message,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String message;
  final String route;
}

/// "More", for every workspace: who is signed in, the controlled workspace
/// switch for a multi-role account, the workspace's secondary pages, what
/// this build is, and sign-out.
class WorkspaceMoreScreen extends ConsumerWidget {
  const WorkspaceMoreScreen({
    required this.config,
    this.links = const [],
    super.key,
  });

  final EnvironmentConfig config;
  final List<MoreLink> links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    return ProductPage(
      title: 'More',
      showBack: false,
      children: [
        const AccountCard(),
        const SizedBox(height: Gaps.section),
        if (session != null && session.canSwitchWorkspace)
          PageSection(
            title: 'Workspace',
            children: [WorkspaceSwitcher(session: session)],
          ),
        if (links.isNotEmpty)
          PageSection(
            title: 'In this workspace',
            children: [
              for (final l in links) ...[
                ActionCard(
                  icon: l.icon,
                  title: l.title,
                  message: l.message,
                  onTap: () => context.push(l.route),
                ),
                const SizedBox(height: Space.sm),
              ],
            ],
          ),
        PageSection(
          title: 'This build',
          children: [BuildFacts(config: config)],
        ),
        const SignOutButton(),
      ],
    );
  }
}

/// The signed-in person, from the directory.
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    return OpsView(
      value: ref.watch(ownProfileProvider),
      builder: (context, profile) {
        final p = profile.person;
        return SectionCard(
          children: [
            IdentityHeader(
              name: p.displayName,
              subtitle: '${session?.activeRole.label ?? ''} · ${p.personId}',
              detail: [p.designation, ?profile.departmentName].join(' · '),
            ),
          ],
        );
      },
    );
  }
}

/// Moves between the person's own roles, and only those (§54).
class WorkspaceSwitcher extends ConsumerWidget {
  const WorkspaceSwitcher({required this.session, super.key});

  final AppSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.product;
    return RowList(
      children: [
        for (final role in session.roles)
          ListTile(
            minTileHeight: kMinTouchTarget,
            leading: Icon(
              role == session.activeRole
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: role == session.activeRole
                  ? p.brandPrimary
                  : p.textSecondary,
            ),
            title: Text(role.label),
            subtitle: Text(role.description),
            selected: role == session.activeRole,
            onTap: role == session.activeRole
                ? null
                : () async {
                    await ref
                        .read(authControllerProvider.notifier)
                        .switchWorkspace(role);
                    if (context.mounted) context.go(role.landingRoute);
                  },
          ),
      ],
    );
  }
}

/// What this build is, from the installed package — not typed into a screen.
class BuildFacts extends ConsumerWidget {
  const BuildFacts({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedPackageProvider).value;
    return SectionCard(
      children: [
        FactRow(
          label: 'Version',
          value: installed == null
              ? '$appVersion (stamped)'
              : installed.matchesStamp
              ? installed.full
              : '${installed.full} — stamped $appVersion',
          mono: true,
        ),
        if (installed != null)
          FactRow(label: 'Package', value: installed.packageName, mono: true),
        FactRow(label: 'Environment', value: config.environment.name),
        FactRow(
          label: 'Sign-in',
          value: config.simulationAvailable
              ? 'Presentation accounts on this device'
              : 'Organisation sign-in (not connected)',
        ),
        const FactRow(
          label: 'Records',
          value: 'Stored on this device. No central server is connected.',
        ),
        const FactRow(
          label: 'H₂S calibration',
          value: 'None validated — quantitative results are not available.',
        ),
      ],
    );
  }
}

class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DoseBandButton.secondary(
      label: 'Sign out',
      icon: Icons.logout,
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              'Anything already saved stays on this device, including an '
              'open monitoring period.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await ref.read(authControllerProvider.notifier).signOut();
        if (context.mounted) context.go('/sign-in');
      },
    );
  }
}
