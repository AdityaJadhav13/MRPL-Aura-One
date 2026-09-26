import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';

/// Guided badge scan — simulated.
///
/// The real capture UI (live camera, fiducial detection, auto-capture arming)
/// is Phase 3. This is a faithful *simulation* of the guidance experience: the
/// badge frame, the quality checks locking one by one, and auto-capture when
/// they are all met — with no camera behind it, and a persistent SIMULATED
/// mark so it is never mistaken for a live capture. Computer-vision confidence
/// is never faked as if it were real; here it is openly scripted.
class GuidedScanScreen extends StatefulWidget {
  const GuidedScanScreen({super.key});

  @override
  State<GuidedScanScreen> createState() => _GuidedScanScreenState();
}

class _GuidedScanScreenState extends State<GuidedScanScreen> {
  static const _checks = <String>[
    'Distance',
    'Focus',
    'Lighting',
    'Glare',
    'Alignment',
    'Reference patches',
    'Badge complete',
  ];

  int _locked = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (t) {
      if (!mounted) return;
      if (_locked < _checks.length) {
        setState(() => _locked++);
        HapticFeedback.selectionClick();
      } else {
        t.cancel();
        HapticFeedback.mediumImpact();
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.pushReplacement('/processing');
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final ready = _locked >= _checks.length;
    // True-black viewfinder surround: the correct backdrop for judging a badge.
    const onDark = Neutral.l96;
    const onDarkMuted = Neutral.l74;

    return Scaffold(
      backgroundColor: Neutral.l0,
      body: SafeArea(
        child: Column(
          children: [
            // Simulated marker on the dark surround.
            Container(
              width: double.infinity,
              color: context.colours.statusSimulated,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.base,
                vertical: Space.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.science_outlined,
                    size: 16,
                    color: Neutral.l100,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'Simulated scan — not a real capture',
                      style: t.label.copyWith(color: Neutral.l100),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(child: _BadgeFrame(ready: ready)),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                children: [
                  // The instruction is this screen's heading, and it is also
                  // the thing that changes when the state does, so it carries
                  // liveRegion as well: a screen-reader user is holding a
                  // phone over a badge and cannot be watching the text.
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      ready ? 'Ready — hold steady' : 'Line up the badge',
                      style: t.heading.copyWith(color: onDark),
                    ),
                  ),
                  const SizedBox(height: Space.base),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < _checks.length; i++)
                        _QualityChip(label: _checks[i], locked: i < _locked),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  Text(
                    ready
                        ? 'Capturing…'
                        : 'Auto-capture when every check is met',
                    style: t.caption.copyWith(color: onDarkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeFrame extends StatelessWidget {
  const _BadgeFrame({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final accent = context.colours.measurementAccent;
    return AnimatedContainer(
      duration: Motion.control,
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        border: Border.all(
          color: ready ? accent : Neutral.l58,
          width: ready ? Borders.emphasis : Borders.hairline,
        ),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Center(
        child: Icon(
          Icons.credit_card,
          size: 96,
          color: ready ? accent : Neutral.l42,
        ),
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.label, required this.locked});

  final String label;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final accent = context.colours.measurementAccent;
    final colour = locked ? accent : Neutral.l58;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: locked ? accent.withValues(alpha: 0.15) : Neutral.l14,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: colour),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.check : Icons.radio_button_unchecked,
            size: 14,
            color: colour,
          ),
          const SizedBox(width: Space.xs),
          Text(label, style: context.type.caption.copyWith(color: colour)),
        ],
      ),
    );
  }
}
