import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:measurement/measurement.dart';

import '../../core/components/product_page.dart';
import '../../core/components/workspace_components.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/env/app_info.dart';
import '../../core/env/environment.dart';
import '../account/presentation/workspace_more_screen.dart';

import 'package:go_router/go_router.dart';

import '../auth/application/auth_controller.dart';
import '../presentation/application/presentation_controller.dart';

/// Worker Settings (Worker directive §10, §11, §45, §48).
///
/// Account, privacy and information about the app — moved off Profile so
/// the worker's own screen is not a page of configuration. Every row here
/// states a fact the app actually holds; there are no switches, because no
/// user preference is implemented yet and a switch that did nothing would
/// be a lie. The version and build come from the installed package's
/// metadata, not from a string in this file.
///
/// Developer and research tools are not reachable from here.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final remembered = ref
        .read(authControllerProvider.notifier)
        .remembersSession;
    final provider = ref.watch(identityProviderProvider);
    final installed = ref.watch(installedPackageProvider);
    final presentationBuild = ref.watch(presentationAccessProvider);
    final presentation = ref.watch(presentationModeProvider);
    final t = context.type;
    final p = context.product;

    String pkg(String Function(InstalledPackage) f) => installed.when(
      data: f,
      loading: () => 'Reading…',
      error: (_, _) => 'Unavailable',
    );

    return ProductPage(
      title: 'Settings',
      children: [
        PageSection(
          title: 'Account',
          children: [
            SectionCard(
              children: [
                FactRow(
                  label: 'Signed in as',
                  value: session?.displayName ?? 'Nobody',
                ),
                if (session != null) ...[
                  FactRow(
                    label: 'User ID',
                    value: session.personId,
                    mono: true,
                  ),
                  FactRow(label: 'Role', value: session.activeRole.label),
                ],
                FactRow(label: 'Signed in with', value: provider.description),
                FactRow(
                  label: 'Session',
                  value: remembered
                      ? 'Remembered on this phone until you sign out'
                      : 'Ends when the app is closed',
                ),
              ],
            ),
          ],
        ),
        PageSection(
          title: 'Privacy',
          children: [
            SectionCard(
              children: const [
                FactRow(
                  label: 'Your records',
                  value:
                      'Stored on this phone. Not synced: no central server '
                      'is connected.',
                ),
                FactRow(
                  label: 'Camera',
                  value:
                      'Used only to scan DoseBand QR codes and photograph '
                      'DoseBands.',
                ),
                FactRow(
                  label: 'Location',
                  value:
                      'Not used. Your site is your assignment; it is not '
                      'tracked.',
                ),
                FactRow(
                  label: 'Signing out',
                  value:
                      'Ends the session only. Monitoring records stay on '
                      'this phone.',
                ),
              ],
            ),
          ],
        ),
        PageSection(
          title: 'About DoseBand',
          children: [
            SectionCard(
              children: [
                FactRow(
                  label: 'Version',
                  value: pkg((i) => i.version),
                  mono: true,
                ),
                FactRow(
                  label: 'Build',
                  value: pkg(
                    (i) => i.buildNumber.isEmpty ? '—' : i.buildNumber,
                  ),
                  mono: true,
                ),
                FactRow(label: 'Environment', value: config.environment.name),
                const FactRow(
                  label: 'Measurement engine',
                  value: algorithmVersion,
                  mono: true,
                ),
                const FactRow(
                  label: 'Connection',
                  value: 'Not connected — records stay on this phone',
                ),
                if (presentationBuild)
                  FactRow(
                    label: 'Presentation mode',
                    value: presentation.enabled
                        ? 'On — ${presentation.level.label}'
                        : 'Off',
                  ),
              ],
            ),
            if (presentationBuild) ...[
              const SizedBox(height: Space.md),
              ActionCard(
                icon: Icons.co_present_outlined,
                title: 'Presentation controls',
                message: 'Demonstration fallback (presentation builds only)',
                onTap: () => context.push('/profile/settings/presentation'),
              ),
            ],
            const SizedBox(height: Space.sm),
            Text(
              'DoseBand is a passive, cumulative occupational-exposure '
              'record. It does not replace certified H₂S detectors, site '
              'alarms, PPE, permit-to-work controls or emergency '
              'procedures, and it never reports that an area is safe.',
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: Space.md),
            ActionCard(
              icon: Icons.description_outlined,
              title: 'Open-source licences',
              message: 'Software this app is built with',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'DoseBand',
                applicationVersion: pkg((i) => i.full),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        const SignOutButton(),
      ],
    );
  }
}
