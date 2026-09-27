import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/brand_assets.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/router/route_gate.dart';
import '../../application/auth_controller.dart';
import '../widgets/mrpl_brandmark.dart';

/// Launch (PRODUCT BUILD v1 §55; corrective §3A).
///
/// The approved splash composition — refinery at dusk, the organisation's
/// mark and name, the site's safety message, the DoseBand lockup — rebuilt
/// without the gradients it used to rely on (§66): the sky side sits on a
/// solid translucent plate, the foreground on a solid translucent panel.
///
/// It stays up while the stored session is read and for a short minimum so
/// the composition is seen rather than flashed; a tap anywhere continues at
/// once. No skip control, no video, no sign-in bypass.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({this.from, super.key});

  /// Where a deep link was headed before the session was known.
  final String? from;

  /// Long enough to read the lockup, short enough not to be a wait.
  static const Duration minimumShown = Duration(milliseconds: 1400);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _left = false;
  bool _restored = false;
  Timer? _minimum;

  @override
  void initState() {
    super.initState();
    _minimum = Timer(SplashScreen.minimumShown, _continue);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authControllerProvider.notifier).restore();
      _restored = true;
      if (!(_minimum?.isActive ?? false)) _continue();
    });
  }

  @override
  void dispose() {
    _minimum?.cancel();
    super.dispose();
  }

  /// Leaves once the session has been read — and, unless the person tapped,
  /// once the minimum has passed.
  void _continue() {
    if (_left || !mounted || !_restored) return;
    _left = true;
    _minimum?.cancel();
    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      context.go('/sign-in');
      return;
    }
    final from = widget.from;
    context.go(
      from != null && RouteGate.allows(session: session, location: from)
          ? from
          : session.activeRole.landingRoute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;

    // A composition shown for a moment, whose one sentence is also announced
    // by the semantics label: its lettering stops at 130 %, where it still
    // breaks between words rather than inside them.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Scaffold(
        backgroundColor: Brand.refineryNight,
        body: Semantics(
          button: true,
          label: 'DoseBand is starting. Tap to continue.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _continue,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(
                  child: Image.asset(
                    BrandAssets.refineryBackdrop,
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                SafeArea(
                  bottom: false,
                  // Proportional spacing while the composition fits; scrolling,
                  // not overflow, when it cannot (200 % text on 320 × 568).
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Spacer(flex: 40),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.lg,
                                ),
                                // Sized from the layout, not MediaQuery: a
                                // nested MediaQuery can report no size.
                                // Bounded by height as well, so a landscape
                                // phone does not get a mark half the screen
                                // tall; the plate stops growing on a tablet.
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 480,
                                    ),
                                    child: _IdentityPlate(
                                      markSize: math.max(
                                        0,
                                        [
                                          (constraints.maxWidth -
                                                  Space.lg * 2) *
                                              0.30,
                                          constraints.maxHeight * 0.16,
                                          136.0,
                                        ].reduce(math.min),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(flex: 150),
                              // The safety message is a statement: left
                              // aligned, on its own.
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.lg,
                                ),
                                child: _SafetyMessage(accent: corporate.accent),
                              ),
                              const SizedBox(height: Space.lg),
                              // Full bleed: the approved splash's dark
                              // foreground, as one solid band.
                              _ProductPanel(accent: corporate.accent),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mark and organisation on a solid translucent plate over the sky.
class _IdentityPlate extends StatelessWidget {
  const _IdentityPlate({required this.markSize});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.base,
        vertical: Space.base,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MrplBrandmark(size: markSize, cornerRadius: 8),
          const SizedBox(height: Space.md),
          Text(
            'Mangalore Refinery\nand Petrochemicals Limited',
            textAlign: TextAlign.center,
            style: t.heading.copyWith(
              color: Brand.identityInk,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'A subsidiary of ONGC\n'
            'Ministry of Petroleum and Natural Gas\n'
            'Government of India',
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: Neutral.l20, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SafetyMessage extends StatelessWidget {
  const _SafetyMessage({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Safe People\nSustainable Operations',
          style: t.display.copyWith(
            color: Colors.white,
            fontSize: 24,
            height: 1.28,
            shadows: const [Shadow(blurRadius: 10, color: Colors.black54)],
          ),
        ),
        const SizedBox(height: Space.md),
        Container(
          width: 66,
          height: 5,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ],
    );
  }
}

/// The product lockup on a solid translucent panel of the refinery's night
/// green — the old version faded into it with a gradient.
class _ProductPanel extends StatelessWidget {
  const _ProductPanel({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      padding: EdgeInsets.fromLTRB(
        Space.base,
        Space.lg,
        Space.base,
        Space.xl + MediaQuery.paddingOf(context).bottom,
      ),
      color: Brand.refineryNight.withValues(alpha: 0.80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              'DoseBand',
              textAlign: TextAlign.center,
              style: t.display.copyWith(
                color: Colors.white,
                fontSize: 36,
                height: 1.08,
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'OCCUPATIONAL EXPOSURE MONITORING',
            textAlign: TextAlign.center,
            style: t.caption.copyWith(
              color: Colors.white,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: Space.base),
          SizedBox(
            width: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.30),
                color: accent,
                semanticsLabel: 'Starting',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
