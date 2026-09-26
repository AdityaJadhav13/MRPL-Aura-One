import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/brand_assets.dart';
import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/tokens.dart';
import '../../application/auth_controller.dart';
import '../../data/demo_account.dart';
import '../../data/demo_auth_repository.dart';
import '../../domain/auth_models.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/auth_controls.dart';
import '../widgets/auth_form_fields.dart';
import '../widgets/demo_access_card.dart';

/// Sign in.
///
/// **UI-only. No identity verification occurs.** Required fields are checked
/// for emptiness and the flow advances; nothing is sent anywhere, and the
/// password is never stored, logged or persisted. See [DemoAuthRepository].
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _userId = TextEditingController();
  final _company = TextEditingController();
  final _password = TextEditingController();

  AuthUserType _userType = AuthUserType.employee;
  bool _obscure = true;
  bool _remember = true;
  Map<String, String> _errors = const <String, String>{};

  /// Set when the form was complete but the values were not the demo account.
  /// Separate from [_errors], which is per-field.
  String? _rejection;

  @override
  void dispose() {
    _userId.dispose();
    _company.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _isContractor => _userType == AuthUserType.contractor;

  void _submit() {
    final result = ref
        .read(authControllerProvider.notifier)
        .submitSignIn(
          userType: _userType,
          userId: _userId.text,
          password: _password.text,
          contractorCompany: _company.text,
        );

    switch (result) {
      case DemoAuthIncomplete(:final fieldErrors):
        setState(() {
          _errors = fieldErrors;
          _rejection = null;
        });
      case DemoAuthRejected(:final message):
        setState(() {
          _errors = const <String, String>{};
          _rejection = message;
        });
        _password.clear();
      case DemoAuthAccepted():
        setState(() {
          _errors = const <String, String>{};
          _rejection = null;
        });
        // The password controller is cleared immediately: there is no reason
        // for it to outlive the submission, and a field left populated is a
        // field that can be read off a resumed screen.
        _password.clear();
        FocusScope.of(context).unfocus();
        context.go('/select-site');
    }
  }

  /// Fills the form with the published demo account.
  ///
  /// Present so an evaluator never has to guess credentials. It switches the
  /// segmented control too, because the demo account is a contractor and a
  /// half-filled form would be worse than none.
  void _useDemoCredentials() {
    setState(() {
      _userType = DemoAccount.userType;
      _userId.text = DemoAccount.workerId;
      _company.text = DemoAccount.contractorCompany;
      _password.text = DemoAccount.password;
      _errors = const <String, String>{};
      _rejection = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final allowSkip = ref.watch(authDemoConfigProvider).allowSkip;

    return Scaffold(
      backgroundColor: corporate.surface,
      // The card must ride up with the keyboard rather than be covered by it.
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          // A restrained industrial band behind the identity block. Low
          // opacity: it should register as texture, not as a photograph
          // competing with the form.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.white,
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const <double>[0.10, 0.62],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Opacity(
                opacity: 0.30,
                child: Image.asset(
                  BrandAssets.refineryBackdrop,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.35),
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const CorporateFooterWave(height: 88),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.base,
                      Space.lg,
                      Space.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const AuthBrandHeader(),
                        const SizedBox(height: Space.lg),
                        const DoseBandLockup(fontSize: 32),
                        const SizedBox(height: Space.lg),
                        _signInCard(context, corporate, t),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: allowSkip
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: Space.md),
                            child: AuthSkipButton(onPressed: _skip),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _signInCard(
    BuildContext context,
    MrplCorporateColors corporate,
    DoseBandTypography t,
  ) {
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: corporate.surface,
        borderRadius: BorderRadius.circular(CorporateRadii.lg),
        border: Border.all(color: corporate.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Sign In',
                    style: t.heading.copyWith(
                      color: corporate.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const DemoModeBadge(compact: true),
            ],
          ),
          const SizedBox(height: 2),
          // Full width, so it does not wrap around the badge.
          Text(
            'Access your DoseBand workspace',
            style: t.body.copyWith(color: corporate.textSecondary),
          ),
          const SizedBox(height: Space.base),

          EmployeeContractorToggle(
            options: <String>[
              AuthUserType.employee.label,
              AuthUserType.contractor.label,
            ],
            selectedIndex: _userType.index,
            onChanged: (i) => setState(() {
              _userType = AuthUserType.values[i];
              _errors = const <String, String>{};
            }),
          ),
          const SizedBox(height: Space.base),

          AuthTextField(
            controller: _userId,
            icon: Icons.person_outline,
            hintText: _isContractor
                ? 'Worker / Contractor ID'
                : 'User ID / Employee ID',
            errorText: _errors[AuthField.userId],
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.username],
          ),

          if (_isContractor) ...<Widget>[
            const SizedBox(height: Space.md),
            AuthTextField(
              controller: _company,
              icon: Icons.business_outlined,
              hintText: 'Contractor Company',
              errorText: _errors[AuthField.contractorCompany],
              textInputAction: TextInputAction.next,
            ),
          ],

          const SizedBox(height: Space.md),
          AuthTextField(
            controller: _password,
            icon: Icons.lock_outline,
            hintText: 'Password',
            errorText: _errors[AuthField.password],
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),

          const SizedBox(height: Space.sm),
          // Wrap rather than Row: at large text scales these two controls
          // cannot share a line on a narrow phone, and reflowing to two lines
          // is better than truncating "Remember me" to "Rem...".
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.sm,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Semantics(
                    label: 'Remember me',
                    checked: _remember,
                    child: Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                      activeColor: corporate.selectedBorder,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Text(
                    'Remember me',
                    style: t.caption.copyWith(color: corporate.textPrimary),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => showNotConnectedSheet(
                  context,
                  icon: Icons.lock_reset_outlined,
                  title: 'Password recovery',
                  message:
                      'Password recovery will be available when organisation '
                      'identity integration is connected. Nothing has been '
                      'sent, and no account exists to recover — this '
                      'prototype signs in against a published demo account '
                      'only.',
                  integration: 'Organisation identity',
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: corporate.primary,
                ),
                child: Text(
                  'Forgot password?',
                  style: t.caption.copyWith(color: corporate.primary),
                ),
              ),
            ],
          ),

          if (_rejection case final message?) ...[
            const SizedBox(height: Space.md),
            SignInRejectionNotice(message: message),
          ],

          const SizedBox(height: Space.sm),
          AuthPrimaryButton(label: 'Sign In', onPressed: _submit),

          const SizedBox(height: Space.base),
          DemoAccessCard(onUseCredentials: _useDemoCredentials),

          const SizedBox(height: Space.base),
          Row(
            children: <Widget>[
              Expanded(child: Divider(color: corporate.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Text(
                  'or',
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ),
              Expanded(child: Divider(color: corporate.border)),
            ],
          ),
          const SizedBox(height: Space.base),

          AuthSecondaryButton(
            label: 'Sign in with Gate Pass QR',
            icon: Icons.qr_code_2,
            // Shown because the layout must accommodate it, but it verifies
            // nothing. Tapping says so rather than faking a scan.
            onPressed: () => showNotConnectedSheet(
              context,
              icon: Icons.qr_code_2,
              title: 'Gate Pass sign-in',
              message:
                  'A gate pass is issued by site security. DoseBand cannot '
                  'read or verify one: no gate-pass integration exists, so '
                  'scanning a code here could only claim an identity it had '
                  'not checked. The control is shown because the flow is '
                  'designed around it.',
              integration: 'Gate pass',
            ),
          ),

          const SizedBox(height: Space.base),
          Text(
            'Access is subject to organization security and acceptable-use '
            'requirements. This prototype performs no identity verification.',
            textAlign: TextAlign.center,
            style: t.caption.copyWith(
              color: corporate.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _skip() {
    ref.read(authControllerProvider.notifier).skipAuthentication();
    context.go('/home');
  }
}
