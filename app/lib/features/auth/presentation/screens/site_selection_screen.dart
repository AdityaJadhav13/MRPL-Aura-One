import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../application/auth_controller.dart';
import '../../application/onboarding_controller.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/selection_cards.dart';

/// Select Site — first step of setting up on a new device (Worker directive
/// §22, §23), rebuilt from the approved design.
///
/// The list comes from the site repository, not from this widget. Choosing
/// a site is an organisational assignment, not location tracking: no GPS,
/// no location permission. The choice is a request that Sign In checks
/// against the account's assigned site.
class SiteSelectionScreen extends ConsumerWidget {
  const SiteSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(availableSitesProvider);
    final selected = ref.watch(onboardingProvider).site;

    return AuthScaffold(
      title: 'Select Site',
      subtitle: 'Choose your location to continue',
      onBack: () => context.go('/sign-in'),
      footerAction: AuthPrimaryButton(
        label: 'Continue',
        onPressed: selected == null ? null : () => context.go('/select-role'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final site in sites) ...[
            SelectableSiteCard(
              site: site,
              selected: selected == site,
              onTap: () =>
                  ref.read(onboardingProvider.notifier).selectSite(site),
            ),
            const SizedBox(height: Space.md),
          ],
        ],
      ),
    );
  }
}
