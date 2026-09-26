import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_models.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/auth_controls.dart';
import '../widgets/selection_cards.dart';

/// Where a role without an interface lands.
///
/// Deliberately a finished-looking screen that says nothing is finished. The
/// alternative — routing an HSE officer into the worker journey — would show
/// them an interface built for a different job and let them believe it was
/// theirs.
class RoleWorkspacePlaceholder extends ConsumerWidget {
  const RoleWorkspacePlaceholder({required this.role, super.key});

  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corporate = context.corporate;
    final t = context.type;

    return Scaffold(
      backgroundColor: corporate.surface,
      body: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const CorporateFooterWave(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const AuthBrandHeader(),
                  const SizedBox(height: Space.xxl),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: corporate.primaryMuted,
                      borderRadius: BorderRadius.circular(CorporateRadii.lg),
                    ),
                    child: Icon(
                      SelectableRoleCard.iconFor(role),
                      size: 30,
                      color: corporate.primary,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  Text(
                    '${role.label} workspace',
                    textAlign: TextAlign.center,
                    style: t.heading.copyWith(
                      color: corporate.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Interface under development.\n${role.description}.',
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(
                      color: corporate.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  const Align(child: DemoModeBadge()),
                  const SizedBox(height: Space.xxl),
                  AuthSecondaryButton(
                    label: 'Choose a different role',
                    icon: Icons.arrow_back,
                    onPressed: () => context.go('/select-role'),
                  ),
                  const SizedBox(height: Space.md),
                  TextButton(
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).signOut();
                      context.go('/sign-in');
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: corporate.textSecondary,
                    ),
                    child: const Text('Sign out'),
                  ),
                  const SizedBox(height: Space.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
