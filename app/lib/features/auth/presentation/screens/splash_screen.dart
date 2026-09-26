import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/brand_assets.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../application/auth_controller.dart';
import '../widgets/auth_controls.dart';
import '../widgets/mrpl_brandmark.dart';

/// The corporate splash.
///
/// Full-bleed refinery photograph, corporate identity over the bright sky at
/// the top, product lockup over the darkened water at the bottom.
///
/// The two text blocks sit on very different parts of the image, so they are
/// coloured differently: the identity is deep green on the pale sky, the
/// product lockup is white on the darkened foreground. A single colour would
/// fail on one of them.
///
/// Proportions follow the approved design: the layout is driven by flexible
/// gaps rather than fixed offsets, so the same composition holds from a 360
/// to a 430 point phone.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    // Local state only; nothing is fetched. When session restoration exists
    // this waits on it instead of on a timer, and the screen does not change.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) context.go('/sign-in');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final allowSkip = ref.watch(authDemoConfigProvider).allowSkip;

    // The fade is decoration, and decoration is what this setting exists to
    // switch off.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final fade = reduceMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    return Scaffold(
      backgroundColor: _deepGreen,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            BrandAssets.refineryBackdrop,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.medium,
          ),

          // A soft light scrim over the sky, so the deep-green identity text
          // keeps its contrast whatever the photograph does up there.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x59FFFFFF),
                  Color(0x1AFFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: <double>[0.0, 0.26, 0.46],
              ),
            ),
          ),

          // The foreground sinks into corporate green so the product lockup
          // reads as part of the brand rather than as text on a photo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x000B3325),
                  Color(0x000B3325),
                  Color(0x4D0B3325),
                  Color(0xB80A2F22),
                  Color(0xF2082B20),
                  Color(0xFF06231A),
                ],
                stops: <double>[0.0, 0.50, 0.66, 0.80, 0.90, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: fade,
              // Proportional spacers while the composition fits; a scroll
              // instead of an overflow when it cannot — at 200% text on a
              // 320×568 phone the lockup alone is taller than the screen.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Spacer(flex: 52),

                            Center(
                              child: MrplBrandmark(
                                // A third of the content width, as in the
                                // approved design. From the screen width, not
                                // a LayoutBuilder: the scroll-safe column
                                // measures its children intrinsically.
                                size: math.max(
                                  0,
                                  (MediaQuery.sizeOf(context).width -
                                          Space.lg * 2) *
                                      0.345,
                                ),
                                cornerRadius: 8,
                              ),
                            ),

                            const SizedBox(height: Space.base),
                            const _IdentityBlock(),

                            const Spacer(flex: 168),

                            // Left-aligned, unlike everything else on the screen: the
                            // safety message is a statement, not a label.
                            const _SafetyMessage(),

                            const Spacer(flex: 50),

                            const _ProductLockup(),

                            const SizedBox(height: Space.lg),
                            Center(
                              child: SizedBox(
                                width: 190,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    minHeight: 5,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.32,
                                    ),
                                    color: corporate.accent,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: Space.sm),
                            SizedBox(
                              height: 44,
                              child: allowSkip
                                  ? Align(
                                      alignment: Alignment.centerRight,
                                      child: AuthSkipButton(
                                        onDark: true,
                                        onPressed: _skip,
                                      ),
                                    )
                                  : null,
                            ),
                            const Spacer(flex: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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

/// Deep corporate green, matched to the supplied logo's field.
const Color _deepGreen = Color(0xFF082B20);

/// The identity text that sits on the sky.
class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Mangalore Refinery\nand Petrochemicals Limited',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 21,
            height: 1.26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF14532D),
          ),
        ),
        SizedBox(height: Space.md),
        Text(
          'A subsidiary of ONGC\n'
          'Ministry of Petroleum and Natural Gas\n'
          'Government of India',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 13.5,
            height: 1.52,
            fontWeight: FontWeight.w400,
            color: Color(0xFF2F3A34),
          ),
        ),
      ],
    );
  }
}

class _SafetyMessage extends StatelessWidget {
  const _SafetyMessage();

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'Safe People\nSustainable Operations',
          style: TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 23,
            height: 1.28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: <Shadow>[Shadow(blurRadius: 12, color: Color(0x8A000000))],
          ),
        ),
        const SizedBox(height: Space.md),
        Container(
          width: 66,
          height: 5,
          decoration: BoxDecoration(
            color: corporate.accent,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ],
    );
  }
}

class _ProductLockup extends StatelessWidget {
  const _ProductLockup();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'DoseBand',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'OCCUPATIONAL EXPOSURE MONITORING',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 10.5,
            height: 1.2,
            letterSpacing: 1.15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
