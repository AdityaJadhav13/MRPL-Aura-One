import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_models.dart';
import '../widgets/auth_controls.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/selection_cards.dart';

/// Choose an application role.
///
/// **Application role modelling only.** These roles are not entitlements and
/// map to no identity provider; what a role grants is enforced nowhere yet.
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(authControllerProvider).role;
    final allowSkip = ref.watch(authDemoConfigProvider).allowSkip;

    return AuthScaffold(
      title: 'Select Your Role',
      subtitle: 'Choose your role to continue',
      onSkip: allowSkip ? () => _skip(context, ref) : null,
      footerAction: AuthPrimaryButton(
        label: 'Continue',
        onPressed: selected == null ? null : () => _continue(context, selected),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final role in AppRole.values) ...<Widget>[
            SelectableRoleCard(
              role: role,
              selected: selected == role,
              onTap: () =>
                  ref.read(authControllerProvider.notifier).selectRole(role),
            ),
            const SizedBox(height: Space.md),
          ],
        ],
      ),
    );
  }

  /// Every role continues somewhere. A role whose shell is not built reaches
  /// a placeholder that says so — never a dead button, and never somebody
  /// else's interface.
  void _continue(BuildContext context, AppRole role) =>
      context.go(role.landingRoute);

  void _skip(BuildContext context, WidgetRef ref) {
    ref.read(authControllerProvider.notifier).skipAuthentication();
    context.go('/home');
  }
}
