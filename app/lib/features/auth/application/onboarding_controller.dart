import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_models.dart';

/// What a person chose while setting up on a new device: the site they work
/// at and the role they intend to use.
///
/// **A choice, not a grant.** Neither value authorizes anything. Both are
/// carried to Sign In as a *request*, and [AuthController.signIn] checks the
/// request against the account's directory record after the credentials are
/// accepted. A role picked here that the account does not hold is refused.
@immutable
final class OnboardingSelection {
  const OnboardingSelection({this.site, this.role, this.presentation = false});

  static const OnboardingSelection none = OnboardingSelection();

  final Site? site;
  final AppRole? role;

  /// Reached with Skip on Sign In (presentation builds only): the flow ends
  /// by opening the presentation account that holds the chosen role, not
  /// by returning to Sign In.
  final bool presentation;

  /// True once both steps have been completed: Sign In is then in setup
  /// mode and sends the request with the credentials.
  bool get isComplete => site != null && role != null;
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingSelection>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<OnboardingSelection> {
  @override
  OnboardingSelection build() => OnboardingSelection.none;

  void selectSite(Site site) => state = OnboardingSelection(
    site: site,
    role: state.role,
    presentation: state.presentation,
  );

  void selectRole(AppRole role) => state = OnboardingSelection(
    site: state.site,
    role: role,
    presentation: state.presentation,
  );

  /// Skip on Sign In: Select Site → Select Your Role → that role's
  /// workspace, as a presentation account.
  void startPresentation() =>
      state = const OnboardingSelection(presentation: true);

  /// Back to an ordinary sign-in, e.g. after setup succeeds or is abandoned.
  void reset() => state = OnboardingSelection.none;
}
