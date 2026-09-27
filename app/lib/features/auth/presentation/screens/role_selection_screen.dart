import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../application/auth_controller.dart';
import '../../application/onboarding_controller.dart';
import '../../domain/auth_models.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/selection_cards.dart';

/// Select Your Role (Worker directive §24–§26, §31), rebuilt from the
/// approved design. It serves two moments, and in neither does tapping a
/// card grant anything:
///
/// * **Setup, signed out** — every role is offered. The choice is carried
///   to Sign In as a *requested* role, and refused there if the account
///   does not hold it.
/// * **Signed in to an account with several roles** — only that account's
///   own roles are offered, and [AuthController.confirmRole] re-checks the
///   choice against the session.
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  /// The account-mode choice; setup keeps its choice in [onboardingProvider].
  AppRole? _accountChoice;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final session = auth.isSignedIn ? auth.session : null;
    final accountMode = session != null;

    final roles = accountMode
        ? [
            for (final r in AppRole.selectionOrder)
              if (session.roles.contains(r)) r,
          ]
        : AppRole.selectionOrder;
    final selected = accountMode
        ? _accountChoice
        : ref.watch(onboardingProvider).role;

    return AuthScaffold(
      title: 'Select Your Role',
      subtitle: 'Choose your role to continue',
      onBack: accountMode ? null : () => context.go('/select-site'),
      footerAction: AuthPrimaryButton(
        label: 'Continue',
        busy: _busy,
        onPressed: selected == null
            ? null
            : () => accountMode ? _confirm(selected) : _request(selected),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final role in roles) ...[
            SelectableRoleCard(
              role: role,
              selected: selected == role,
              onTap: () => accountMode
                  ? setState(() => _accountChoice = role)
                  : ref.read(onboardingProvider.notifier).selectRole(role),
            ),
            const SizedBox(height: Space.md),
          ],
        ],
      ),
    );
  }

  /// Setup: the role travels to Sign In as a request.
  void _request(AppRole role) {
    ref.read(onboardingProvider.notifier).selectRole(role);
    context.go('/sign-in');
  }

  /// Signed in: open the chosen one of the account's own workspaces.
  Future<void> _confirm(AppRole role) async {
    setState(() => _busy = true);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .confirmRole(role);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.go(role.landingRoute);
  }
}
