import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'markers.dart';

/// Which visual register a step belongs to.
///
/// The split is scientific, not decorative. DoseBand measures colour, so any
/// screen showing the badge, a reference patch or a colorimetric readout must
/// not sit inside a saturated field — simultaneous contrast and chromatic
/// adaptation act on whoever is judging the capture, and a green frame is a
/// measurement error dressed as branding.
enum StepRegister {
  /// Corporate workflow: MRPL green, off-white ground, white cards. Work
  /// context, badge assignment, pre-work, monitoring.
  corporate,

  /// Measurement instrument: chromatically neutral. Capture review, result,
  /// refusal, anything rendering the badge.
  instrument,
}

/// Publishes the current [StepRegister] to descendants.
///
/// Buttons need it: a primary action on a corporate workflow screen is MRPL
/// orange, and the same widget on a measurement screen is the instrument
/// accent. Passing it down through every call site would mean every new
/// screen gets one more chance to forget.
class StepRegisterScope extends InheritedWidget {
  const StepRegisterScope({
    required this.register,
    required super.child,
    super.key,
  });

  final StepRegister register;

  /// Defaults to the instrument register when no scaffold is above: the
  /// measurement surfaces are the ones where getting this wrong has a cost
  /// beyond looking untidy.
  static StepRegister of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StepRegisterScope>()
          ?.register ??
      StepRegister.instrument;

  @override
  bool updateShouldNotify(StepRegisterScope oldWidget) =>
      oldWidget.register != register;
}

/// The common frame for a workflow step.
///
/// A title bar, a scrollable body, and a pinned action area at the bottom within
/// thumb reach — the worker may be one-handed and gloved, so the primary action
/// never scrolls away. [simulated] shows the persistent magenta marker: in this
/// phase every step is simulated data and must say so.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    required this.title,
    required this.children,
    this.primaryAction,
    this.secondaryAction,
    this.simulated = true,
    this.register = StepRegister.corporate,
    this.padding = const EdgeInsets.all(Space.base),
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final bool simulated;

  /// Defaults to [StepRegister.corporate]: most workflow steps are corporate
  /// surfaces. A screen that renders the badge must pass
  /// [StepRegister.instrument] explicitly, which makes the choice visible in
  /// the call site rather than buried here.
  final StepRegister register;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final corporate = context.corporate;
    final isCorporate = register == StepRegister.corporate;
    final hasActions = primaryAction != null || secondaryAction != null;

    final background = isCorporate ? corporate.surfaceMuted : c.surfacePrimary;
    final bar = isCorporate ? corporate.surface : c.surfacePrimary;
    final border = isCorporate ? corporate.border : c.border;

    return StepRegisterScope(
      register: register,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          // Explicit, because AppBar's own heading semantics vary by
          // target platform and this must hold on both.
          title: Semantics(header: true, child: Text(title)),
          backgroundColor: bar,
          foregroundColor: isCorporate ? corporate.textPrimary : c.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: Border(bottom: BorderSide(color: border)),
        ),
        body: Column(
          children: [
            if (simulated) const SimulationMarker(),
            Expanded(
              child: ListView(padding: padding, children: children),
            ),
            if (hasActions)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  Space.base,
                  Space.md,
                  Space.base,
                  Space.base,
                ),
                decoration: BoxDecoration(
                  color: bar,
                  border: Border(top: BorderSide(color: border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?primaryAction,
                      if (primaryAction != null && secondaryAction != null)
                        const SizedBox(height: Space.sm),
                      ?secondaryAction,
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
