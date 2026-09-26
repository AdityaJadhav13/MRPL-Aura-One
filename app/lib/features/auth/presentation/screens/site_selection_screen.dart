import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../application/auth_controller.dart';
import '../widgets/auth_controls.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/selection_cards.dart';

/// Choose a work location.
///
/// Sites come from [SiteRepository], not from this file, and nothing infers
/// location: no GPS is read and no permission is requested. A worker's site is
/// something they know and the system does not.
class SiteSelectionScreen extends ConsumerWidget {
  const SiteSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(availableSitesProvider);
    final selected = ref.watch(authControllerProvider).site;
    final allowSkip = ref.watch(authDemoConfigProvider).allowSkip;

    return AuthScaffold(
      title: 'Select Site',
      subtitle: 'Choose your location to continue',
      onSkip: allowSkip ? () => _skip(context, ref) : null,
      footerAction: AuthPrimaryButton(
        label: 'Continue',
        onPressed: selected == null ? null : () => context.go('/select-role'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final site in sites) ...<Widget>[
            SelectableSiteCard(
              site: site,
              selected: selected == site,
              onTap: () =>
                  ref.read(authControllerProvider.notifier).selectSite(site),
            ),
            const SizedBox(height: Space.md),
          ],
        ],
      ),
    );
  }

  void _skip(BuildContext context, WidgetRef ref) {
    ref.read(authControllerProvider.notifier).skipAuthentication();
    context.go('/home');
  }
}
