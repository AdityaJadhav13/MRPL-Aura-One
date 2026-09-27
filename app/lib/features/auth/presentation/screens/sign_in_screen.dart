import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/components/buttons.dart';
import '../../../../core/components/product_fields.dart';
import '../../../../core/components/product_page.dart';
import '../../../../core/components/product_status.dart';
import '../../../../core/components/step_scaffold.dart';
import '../../../../core/design/brand_assets.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../../operations/application/operations_repository.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_models.dart';
import '../../domain/identity.dart';
import '../widgets/corporate_brand.dart';

/// Sign in (PRODUCT BUILD v1 §56).
///
/// White-first, one form: ID and password. No role picker — the role comes
/// from the account — and no block of printed credentials. What the person is
/// signing in against is stated in one plain line, because it is not the
/// organisation's identity system and must not look like it.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _idError;
  String? _passwordError;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _id.text.trim();
    final password = _password.text;
    setState(() {
      _idError = id.isEmpty ? 'Enter your employee or contractor ID' : null;
      _passwordError = password.isEmpty ? 'Enter your password' : null;
    });
    if (_idError != null || _passwordError != null) return;
    FocusScope.of(context).unfocus();
    final failure = await ref
        .read(authControllerProvider.notifier)
        .signIn(loginId: id, password: password);
    // The password leaves the screen's memory whatever happened.
    _password.clear();
    if (!mounted) return;
    _land(failure);
  }

  void _land(SignInFailure? failure) {
    final session = ref.read(authControllerProvider).session;
    if (failure == null && session != null) {
      context.go(session.activeRole.landingRoute);
    }
  }

  Future<void> _presentationAccounts() async {
    final choice = await showModalBottomSheet<(String, AppRole)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _PresentationAccountsSheet(),
    );
    if (choice == null || !mounted) return;
    final auth = ref.read(authControllerProvider.notifier);
    final failure = await auth.signInAsPresentation(choice.$1);
    // A multi-role account lands in its first workspace; the card chosen may
    // be its other one, which is a controlled switch between its own roles.
    if (failure == null) await auth.switchWorkspace(choice.$2);
    if (mounted) _land(failure);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final auth = ref.watch(authControllerProvider);
    final provider = ref.watch(identityProviderProvider);
    final presentation = ref.watch(presentationAccessProvider);
    final busy = auth.status == AuthStatus.signingIn;
    final notConnected = provider is NotConnectedIdentityProvider;

    // Corporate register: the primary action is brand green, as everywhere
    // outside a measurement screen.
    return StepRegisterScope(
      register: StepRegister.corporate,
      child: Scaffold(
        backgroundColor: p.surfacePage,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                // The form, then the refinery skyline and brand sweep of the
                // approved entry screens: at the foot of the screen when the
                // form is short, after it when it is not — never over it.
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Gaps.screenGutter,
                        Space.lg,
                        Gaps.screenGutter,
                        Space.lg,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _Masthead(),
                                const SizedBox(height: Space.lg),
                                Semantics(
                                  header: true,
                                  child: Text(
                                    'Sign in',
                                    style: t.heading.copyWith(
                                      color: p.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: Space.xs),
                                Text(
                                  'Use your employee or contractor ID.',
                                  style: t.body.copyWith(
                                    color: p.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: Space.lg),
                                if (notConnected) ...[
                                  const StatusBanner(
                                    tone: StatusTone.info,
                                    icon: Icons.link_off,
                                    title:
                                        'Organisation sign-in is not connected',
                                    message:
                                        'This build has no identity service to check '
                                        'accounts against, so nobody can sign in yet.',
                                  ),
                                  const SizedBox(height: Space.base),
                                ],
                                if (auth.failure case final failure?) ...[
                                  _FailureBanner(failure: failure),
                                  const SizedBox(height: Space.base),
                                ],
                                ProductTextField(
                                  label: 'Employee or contractor ID',
                                  controller: _id,
                                  error: _idError,
                                  enabled: !busy,
                                  prefixIcon: Icons.badge_outlined,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                ),
                                const SizedBox(height: Space.base),
                                ProductTextField(
                                  label: 'Password',
                                  controller: _password,
                                  error: _passwordError,
                                  enabled: !busy,
                                  obscureText: _obscure,
                                  prefixIcon: Icons.lock_outline,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onSubmitted: (_) => _submit(),
                                  suffix: IconButton(
                                    tooltip: _obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: Space.lg),
                                DoseBandButton.primary(
                                  label: busy ? 'Signing in…' : 'Sign in',
                                  loading: busy,
                                  onPressed: busy ? null : _submit,
                                ),
                                const SizedBox(height: Space.lg),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: p.textSecondary,
                                    ),
                                    const SizedBox(width: Space.sm),
                                    Expanded(
                                      child: Text(
                                        notConnected
                                            ? 'MRPL identity integration is not '
                                                  'connected.'
                                            : 'Signing in to ${provider.description.toLowerCase()}. '
                                                  'MRPL identity integration is not '
                                                  'connected.',
                                        style: t.caption.copyWith(
                                          color: p.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (presentation) ...[
                                  const SizedBox(height: Space.sm),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: DoseBandButton.tertiary(
                                      label: 'Presentation accounts',
                                      icon: Icons.people_outline,
                                      onPressed: busy
                                          ? null
                                          : _presentationAccounts,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    CorporateFooterWave(
                      height: 64 + MediaQuery.paddingOf(context).bottom,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The organisation header over a refinery strip carrying the DoseBand
/// lockup — the same identity as the splash and the Home header. The lockup
/// sits on a solid scrim, not a gradient (§132).
class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthBrandHeader(markSize: 48),
        const SizedBox(height: Space.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Image.asset(
                      BrandAssets.refineryBackdrop,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.35),
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(color: context.product.scrim),
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DoseBand',
                        style: t.display.copyWith(
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'OCCUPATIONAL EXPOSURE MONITORING',
                        style: t.caption.copyWith(
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.corporate.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure});

  final SignInFailure failure;

  @override
  Widget build(BuildContext context) => switch (failure) {
    SignInFailure.invalidCredentials => const StatusBanner(
      tone: StatusTone.critical,
      icon: Icons.error_outline,
      title: 'ID or password not recognised',
      message: 'Check both and try again.',
    ),
    SignInFailure.accountSuspended => const StatusBanner(
      tone: StatusTone.attention,
      icon: Icons.block,
      title: 'This account is suspended',
      message: 'Ask your administrator to restore it.',
    ),
    SignInFailure.offline => const StatusBanner(
      tone: StatusTone.info,
      icon: Icons.cloud_off_outlined,
      title: "You're offline",
      message: 'Signing in needs a connection. Try again when online.',
    ),
    SignInFailure.serverUnavailable => const StatusBanner(
      tone: StatusTone.info,
      icon: Icons.dns_outlined,
      title: 'Sign-in service not responding',
      message: 'Nothing is wrong with your account. Try again shortly.',
    ),
    SignInFailure.notConnected => const StatusBanner(
      tone: StatusTone.info,
      icon: Icons.link_off,
      title: 'Organisation sign-in is not connected',
      message: 'This build cannot check organisation accounts.',
    ),
  };
}

/// The presentation accounts, one tap each. Offered only where the build
/// allows it — never in production — and presented as what it is.
class _PresentationAccountsSheet extends ConsumerWidget {
  const _PresentationAccountsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.product;
    final t = context.type;
    final people = ref.watch(operationsProvider).value?.people ?? const [];
    // One card per workspace, in the approved role-entry style. Each card
    // opens a presentation account that *holds* that role — the role is
    // still the account's, never chosen freely.
    final entries = [
      for (final role in AppRole.values)
        for (final person in people)
          if (person.roles.contains(role)) (role, person),
    ];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          Gaps.screenGutter,
          0,
          Gaps.screenGutter,
          Space.lg,
        ),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Presentation accounts',
              style: t.heading.copyWith(color: p.textPrimary),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Sample accounts on this device for demonstrating each workspace. '
            'Not MRPL accounts; no organisation sign-in is connected.',
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: Space.base),
          for (final (role, person) in entries) ...[
            _RoleCard(
              role: role,
              name: person.displayName,
              onTap: () => Navigator.of(context).pop((person.personId, role)),
            ),
            const SizedBox(height: Space.sm),
          ],
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.name,
    required this.onTap,
  });

  final AppRole role;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return Material(
      color: corporate.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: corporate.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTouchTarget + 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.base,
              vertical: Space.md,
            ),
            child: Row(
              children: [
                Icon(
                  switch (role) {
                    AppRole.worker => Icons.engineering,
                    AppRole.supervisor => Icons.groups,
                    AppRole.hseOfficer => Icons.verified_user,
                    AppRole.management => Icons.bar_chart,
                    AppRole.administrator => Icons.settings,
                  },
                  size: 30,
                  color: role == AppRole.worker
                      ? corporate.accent
                      : corporate.primaryDeep,
                ),
                const SizedBox(width: Space.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.label,
                        style: t.heading.copyWith(color: corporate.textPrimary),
                      ),
                      Text(
                        '$name · ${role.description}',
                        style: t.caption.copyWith(
                          color: corporate.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: corporate.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
