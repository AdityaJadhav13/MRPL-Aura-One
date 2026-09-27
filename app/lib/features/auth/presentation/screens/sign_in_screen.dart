import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/components/buttons.dart';
import '../../../../core/components/identity.dart';
import '../../../../core/components/product_fields.dart';
import '../../../../core/components/product_page.dart';
import '../../../../core/components/product_status.dart';
import '../../../../core/components/step_scaffold.dart';
import '../../../../core/components/wordmark.dart';
import '../../../../core/design/brand_assets.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../../operations/application/operations_repository.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_models.dart';
import '../../domain/identity.dart';
import '../widgets/mrpl_brandmark.dart';

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
    final personId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _PresentationAccountsSheet(),
    );
    if (personId == null || !mounted) return;
    final failure = await ref
        .read(authControllerProvider.notifier)
        .signInAsPresentation(personId);
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: Gaps.screenGutter,
                vertical: Space.lg,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Masthead(),
                      const SizedBox(height: Space.xl),
                      Semantics(
                        header: true,
                        child: Text(
                          'Sign in',
                          style: t.display.copyWith(color: p.textPrimary),
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'Use your employee or contractor ID.',
                        style: t.body.copyWith(color: p.textSecondary),
                      ),
                      const SizedBox(height: Space.lg),
                      if (notConnected) ...[
                        const StatusBanner(
                          tone: StatusTone.info,
                          icon: Icons.link_off,
                          title: 'Organisation sign-in is not connected',
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
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
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
                              style: t.caption.copyWith(color: p.textSecondary),
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
                            onPressed: busy ? null : _presentationAccounts,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The refinery, cropped to a strip, above the brand on white. No overlay:
/// nothing is printed on the photograph, so it needs no scrim (§132).
class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: SizedBox(
              height: 120,
              child: Image.asset(
                BrandAssets.refineryBackdrop,
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.3),
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            const MrplBrandmark(size: 44),
            const SizedBox(width: Space.md),
            // Scales down rather than wrapping: a brand name broken across
            // two lines at large text reads as a defect.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: const Wordmark(compact: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Occupational H₂S exposure monitoring',
          style: t.caption.copyWith(color: p.textSecondary),
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
            'Sample accounts for demonstrating each workspace. Not MRPL '
            'accounts.',
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: Space.base),
          for (final person in people)
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: kMinTouchTarget,
              leading: IdentityAvatar(name: person.displayName, size: 40),
              title: Text(person.displayName),
              subtitle: Text(person.roles.map((r) => r.label).join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(person.personId),
            ),
        ],
      ),
    );
  }
}
