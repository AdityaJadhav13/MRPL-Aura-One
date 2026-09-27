import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/components/product_page.dart';
import '../../../../core/components/product_status.dart';
import '../../../../core/design/brand_assets.dart';
import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../../operations/application/operations_repository.dart';
import '../../../workflow/domain/worker_identity.dart';
import '../../application/auth_controller.dart';
import '../../application/onboarding_controller.dart';
import '../../domain/auth_models.dart';
import '../../domain/identity.dart';
import '../widgets/auth_form_fields.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/corporate_brand.dart';
import '../widgets/selection_cards.dart';

/// Sign In (Worker directive §16–§21), rebuilt from the approved design.
///
/// Kept from the approved screen: the refinery header, the organisation
/// identity, the DoseBand lockup, the white card, the Employee / Contractor
/// selector, User ID, Password with its visibility control, Remember me,
/// Forgot password and the Sign In button.
///
/// Removed: the DEMO badge, the published-credentials card, Gate Pass and QR
/// sign-in (no such integrations exist) and Skip (nothing bypasses sign-in).
/// No Google sign-in: none is configured, and a button that only pretended
/// to authenticate would be worse than none.
///
/// Two ways in: an existing account signs in and lands in its own workspace;
/// **New user** goes through Select Site → Select Your Role and comes back
/// here in setup mode, where the choices are sent as a *request* that the
/// account must be authorized for.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  WorkerType _accountType = WorkerType.employee;
  bool _obscure = true;
  bool _remember = true;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// The presentation build opens with its presentation account filled in,
  /// so a judge can press Sign In. The password still goes through the
  /// salted verifier like any typed one.
  void _prefill({bool passwordOnly = false}) {
    final creds = ref.read(presentationCredentialsProvider);
    if (creds == null) return;
    _password.text = creds.password;
    if (passwordOnly) return;
    _id.text = creds.loginId;
    _accountType = creds.accountType;
  }

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _id.text.trim();
    final password = _password.text;
    if (id.isEmpty || password.isEmpty) {
      setState(
        () => _formError = id.isEmpty
            ? 'Enter your User ID.'
            : 'Enter your password.',
      );
      return;
    }
    setState(() => _formError = null);
    FocusScope.of(context).unfocus();

    final setup = ref.read(onboardingProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final failure = await auth.signIn(
      loginId: id,
      password: password,
      accountType: _accountType,
      requestedRole: setup.isComplete ? setup.role : null,
      siteId: setup.isComplete ? setup.site!.id : null,
      remember: _remember,
    );
    if (!mounted) return;
    // The typed password leaves the screen whatever happened; the
    // presentation one is put back so a judge can try again.
    _password.clear();
    if (failure != null) {
      setState(() => _prefill(passwordOnly: true));
      return;
    }
    ref.read(onboardingProvider.notifier).reset();
    final state = ref.read(authControllerProvider);
    final session = state.session;
    if (session == null) return;
    context.go(
      state.awaitingRoleChoice
          ? '/select-role'
          : session.activeRole.landingRoute,
    );
  }

  void _startSetup() {
    ref.read(onboardingProvider.notifier).reset();
    context.go('/select-site');
  }

  Future<void> _forgotPassword() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.lock_reset_outlined),
      title: const Text('Password recovery'),
      content: const Text(
        'Account recovery is not available in this environment. Passwords '
        'are reset by your account administrator. No message has been sent.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  Future<void> _presentationAccounts() async {
    final choice = await showModalBottomSheet<(String, WorkerType)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _PresentationAccountsSheet(),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _id.text = choice.$1;
      _accountType = choice.$2;
      _prefill(passwordOnly: true);
      _formError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final auth = ref.watch(authControllerProvider);
    final setup = ref.watch(onboardingProvider);
    final notConnected =
        ref.watch(identityProviderProvider) is NotConnectedIdentityProvider;
    final presentation = ref.watch(presentationAccessProvider);
    final busy = auth.status == AuthStatus.signingIn;
    final contractor = _accountType == WorkerType.contractor;

    final card = Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: corporate.surface,
        borderRadius: BorderRadius.circular(CorporateRadii.lg),
        border: Border.all(color: corporate.border),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Sign In',
                style: t.heading.copyWith(
                  color: corporate.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Access your DoseBand workspace',
              style: t.body.copyWith(color: corporate.textSecondary),
            ),
            const SizedBox(height: Space.base),
            if (setup.isComplete) ...[
              _SetupSummary(
                selection: setup,
                onChange: () => context.go('/select-site'),
                onCancel: () => ref.read(onboardingProvider.notifier).reset(),
              ),
              const SizedBox(height: Space.base),
            ],
            if (notConnected) ...[
              const StatusBanner(
                tone: StatusTone.info,
                icon: Icons.link_off,
                title: 'Organisation sign-in is not connected',
                message:
                    'This build has no identity service to check accounts '
                    'against, so nobody can sign in yet.',
              ),
              const SizedBox(height: Space.base),
            ],
            AccountTypeToggle(
              options: [WorkerType.employee.label, WorkerType.contractor.label],
              selectedIndex: _accountType.index,
              onChanged: (i) =>
                  setState(() => _accountType = WorkerType.values[i]),
            ),
            const SizedBox(height: Space.base),
            AuthTextField(
              controller: _id,
              label: contractor ? 'Contractor ID' : 'User ID / Employee ID',
              icon: Icons.person_outline,
              enabled: !busy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
            ),
            const SizedBox(height: Space.md),
            AuthTextField(
              controller: _password,
              label: 'Password',
              icon: Icons.lock_outline,
              enabled: !busy,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Space.xs),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: Space.xs,
              children: [
                _RememberMe(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v),
                ),
                TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, kMinInteractive),
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                    foregroundColor: corporate.primaryDeep,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: t.caption.copyWith(color: corporate.primaryDeep),
                  ),
                ),
              ],
            ),
            if (_formError case final message?) ...[
              const SizedBox(height: Space.sm),
              StatusBanner(
                tone: StatusTone.attention,
                icon: Icons.info_outline,
                title: message,
                message: 'Both fields are needed to sign in.',
              ),
            ] else if (auth.failure case final failure?) ...[
              const SizedBox(height: Space.sm),
              _FailureBanner(
                failure: failure,
                onChangeRole: () => context.go('/select-role'),
                onChangeSite: () => context.go('/select-site'),
              ),
            ],
            const SizedBox(height: Space.base),
            AuthPrimaryButton(
              label: 'Sign In',
              busy: busy,
              onPressed: notConnected ? null : _submit,
            ),
            if (!setup.isComplete && !notConnected) ...[
              const SizedBox(height: Space.sm),
              _NewUser(onPressed: busy ? null : _startSetup),
            ],
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: corporate.surface,
      body: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            // The form, then the footer wave: at the foot of the screen when
            // the form is short, after it when it is not — never over it.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const _PhotoBand(),
                    Transform.translate(
                      // The card overlaps the photograph's lower edge.
                      offset: const Offset(0, -Space.lg),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.lg,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                card,
                                if (presentation) ...[
                                  const SizedBox(height: Space.sm),
                                  _PresentationFootnote(
                                    onAccounts: busy
                                        ? null
                                        : _presentationAccounts,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                CorporateFooterWave(
                  height: 56 + MediaQuery.paddingOf(context).bottom,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The approved sign-in header: organisation identity and the DoseBand
/// lockup over a faint photograph of the refinery. The photograph is at a
/// fixed low opacity on white — the approved screen faded it out with a
/// gradient mask, which is not used (§51); the card overlaps its lower edge.
class _PhotoBand extends StatelessWidget {
  const _PhotoBand();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.corporate.surface,
        image: const DecorationImage(
          image: AssetImage(BrandAssets.refineryBackdrop),
          fit: BoxFit.cover,
          alignment: Alignment(0, 0.35),
          opacity: 0.22,
          filterQuality: FilterQuality.medium,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        top + Space.lg,
        Space.lg,
        Space.lg + Space.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthBrandHeader(markSize: 52),
              SizedBox(height: Space.lg),
              DoseBandLockup(fontSize: 34),
            ],
          ),
        ),
      ),
    );
  }
}

class _RememberMe extends StatelessWidget {
  const _RememberMe({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(CorporateRadii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinInteractive),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact box; the whole row is the 48-point target.
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: corporate.selectedBorder,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  'Remember me',
                  style: context.type.caption.copyWith(
                    color: corporate.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
            ],
          ),
        ),
      ),
    );
  }
}

/// "New user? Set up account" — the start of first-time setup.
class _NewUser extends StatelessWidget {
  const _NewUser({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'New user?',
          style: t.body.copyWith(color: corporate.textSecondary),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, kMinInteractive),
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            foregroundColor: corporate.primaryDeep,
          ),
          child: Text(
            'Set up account',
            style: t.bodyStrong.copyWith(color: corporate.primaryDeep),
          ),
        ),
      ],
    );
  }
}

/// In setup mode: what was chosen, with a way back. The choice is a
/// request; it is checked when Sign In is pressed.
class _SetupSummary extends StatelessWidget {
  const _SetupSummary({
    required this.selection,
    required this.onChange,
    required this.onCancel,
  });

  final OnboardingSelection selection;
  final VoidCallback onChange;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final role = selection.role!;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.sm,
        Space.xs,
        Space.sm,
      ),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        border: Border.all(color: corporate.border),
      ),
      child: Row(
        children: [
          Icon(
            SelectableRoleCard.iconFor(role),
            color: role == AppRole.worker
                ? corporate.accent
                : corporate.primary,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setting up as ${role.label}',
                  style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                ),
                Text(
                  selection.site!.name,
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, kMinInteractive),
              foregroundColor: corporate.primaryDeep,
            ),
            child: const Text('Change'),
          ),
          IconButton(
            tooltip: 'Cancel setup',
            onPressed: onCancel,
            icon: Icon(Icons.close, color: corporate.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// What the person is signing in against, stated once, small, under the
/// card — plus the list of presentation accounts. Never in production.
class _PresentationFootnote extends StatelessWidget {
  const _PresentationFootnote({required this.onAccounts});

  final VoidCallback? onAccounts;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return Column(
      children: [
        Text(
          'Presentation accounts on this device. MRPL sign-in is not connected.',
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: corporate.textSecondary),
        ),
        TextButton.icon(
          onPressed: onAccounts,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, kMinInteractive),
            foregroundColor: corporate.primaryDeep,
          ),
          icon: const Icon(Icons.people_outline, size: 18),
          label: const Text('Presentation accounts'),
        ),
      ],
    );
  }
}

/// Authentication and authorization failures are different sentences:
/// "those credentials did not work" is not "this account may not do that".
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({
    required this.failure,
    required this.onChangeRole,
    required this.onChangeSite,
  });

  final SignInFailure failure;
  final VoidCallback onChangeRole;
  final VoidCallback onChangeSite;

  @override
  Widget build(BuildContext context) => switch (failure) {
    SignInFailure.invalidCredentials => const StatusBanner(
      tone: StatusTone.critical,
      icon: Icons.error_outline,
      title: 'Unable to sign in with those credentials',
      message: 'Check your User ID and password and try again.',
    ),
    SignInFailure.roleNotAuthorised => StatusBanner(
      tone: StatusTone.critical,
      icon: Icons.gpp_bad_outlined,
      title: 'This account is not authorized for the selected role.',
      message: 'Select your assigned role and try again.',
      action: TextButton(
        onPressed: onChangeRole,
        child: const Text('Change role'),
      ),
    ),
    SignInFailure.siteNotAuthorised => StatusBanner(
      tone: StatusTone.critical,
      icon: Icons.gpp_bad_outlined,
      title: 'This account is not assigned to the selected site.',
      message: 'Select your assigned site and try again.',
      action: TextButton(
        onPressed: onChangeSite,
        child: const Text('Change site'),
      ),
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

/// The presentation accounts. Choosing one fills the form; the password is
/// still checked when Sign In is pressed — this is not a way around it.
/// Offered only where the build allows it, never in production.
class _PresentationAccountsSheet extends ConsumerWidget {
  const _PresentationAccountsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corporate = context.corporate;
    final t = context.type;
    final people = ref.watch(operationsProvider).value?.people ?? const [];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Presentation accounts',
              style: t.heading.copyWith(color: corporate.textPrimary),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Sample accounts on this device. Choosing one fills in the form; '
            'you still sign in. Not MRPL accounts.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
          const SizedBox(height: Space.base),
          for (final person in people) ...[
            _AccountRow(
              name: person.displayName,
              detail:
                  '${person.personId} · '
                  '${person.roles.map((r) => r.label).join(' · ')}',
              role: person.roles.first,
              onTap: () =>
                  Navigator.of(context)
                      .pop((person.personId, person.workerType)),
            ),
            const SizedBox(height: Space.sm),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.name,
    required this.detail,
    required this.role,
    required this.onTap,
  });

  final String name;
  final String detail;
  final AppRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    return Material(
      color: corporate.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CorporateRadii.lg),
        side: BorderSide(color: corporate.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.base,
              vertical: Space.md,
            ),
            child: Row(
              children: [
                Icon(
                  SelectableRoleCard.iconFor(role),
                  size: 28,
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
                        name,
                        style: t.bodyStrong.copyWith(
                          color: corporate.textPrimary,
                        ),
                      ),
                      Text(
                        detail,
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
