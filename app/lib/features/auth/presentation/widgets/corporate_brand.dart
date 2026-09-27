import 'package:flutter/material.dart';

import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import 'mrpl_brandmark.dart';

/// The organisation header and the refinery footer of the entry screens,
/// recovered from the approved role-entry design (corrective §3B). The
/// footer's sweep was a gradient; it is now one solid brand green.

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    this.markSize = 46,
    this.showTagline = true,
    super.key,
  });

  final double markSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    // The organisation's name is identity, not content a task depends on,
    // and at 200 % it broke inside "Petrochemicals" and filled a small
    // phone. It stops at 130 %; everything below it scales in full.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          MrplBrandmark(size: markSize),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Mangalore Refinery\nand Petrochemicals Limited',
                  style: t.bodyStrong.copyWith(
                    color: corporate.primary,
                    height: 1.22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showTagline) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Refining for a Brighter Tomorrow',
                    style: t.caption.copyWith(color: corporate.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The product lockup: DoseBand over its descriptor.

class CorporateFooterWave extends StatelessWidget {
  const CorporateFooterWave({this.height = 72, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _FooterWavePainter(
            primary: corporate.primary,
            deep: corporate.primaryDeep,
            accent: corporate.accent,
            muted: corporate.primaryMuted,
          ),
        ),
      ),
    );
  }
}

class _FooterWavePainter extends CustomPainter {
  _FooterWavePainter({
    required this.primary,
    required this.deep,
    required this.accent,
    required this.muted,
  });

  final Color primary;
  final Color deep;
  final Color accent;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;

    // A pale plant silhouette behind the sweep: towers, stacks and blocks.
    // Very low contrast — it should register as texture at the bottom of the
    // screen, not as a picture competing with the content above it.
    final skyline = Paint()..color = muted;
    final horizon = h * 0.82;

    void block(double x, double width, double height, {double cap = 0}) {
      canvas.drawRect(
        Rect.fromLTWH(x, horizon - height, width, height),
        skyline,
      );
      if (cap > 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            x - width * 0.22,
            horizon - height - cap,
            width * 1.44,
            cap,
          ),
          skyline,
        );
      }
    }

    void taper(double cx, double width, double height) {
      final top = horizon - height;
      canvas.drawPath(
        Path()
          ..moveTo(cx - width * 0.60, horizon)
          ..lineTo(cx - width * 0.34, top)
          ..lineTo(cx + width * 0.34, top)
          ..lineTo(cx + width * 0.60, horizon)
          ..close(),
        skyline,
      );
    }

    // Many narrow elements rather than a few wide ones: a handful of fat
    // blocks reads as a bar chart, which is the last thing to put under a
    // screen whose card list includes "Reports and dashboards".
    final u = w / 100;
    block(u * 1, u * 2.5, h * 0.22);
    block(u * 5, u * 1.6, h * 0.40, cap: h * 0.035);
    block(u * 8, u * 3.0, h * 0.17);
    taper(u * 13, u * 4.5, h * 0.20);
    block(u * 17, u * 2.0, h * 0.34, cap: h * 0.035);
    block(u * 21, u * 3.4, h * 0.15);
    block(u * 26, u * 1.8, h * 0.38, cap: h * 0.035);
    block(u * 30, u * 2.6, h * 0.20);
    block(u * 35, u * 1.6, h * 0.30);
    taper(u * 40, u * 5.0, h * 0.17);
    block(u * 45, u * 2.2, h * 0.36, cap: h * 0.035);
    block(u * 49, u * 3.2, h * 0.14);
    block(u * 54, u * 1.7, h * 0.42, cap: h * 0.035);
    block(u * 58, u * 2.8, h * 0.19);
    block(u * 63, u * 1.9, h * 0.32);
    taper(u * 68, u * 4.6, h * 0.18);
    block(u * 73, u * 2.1, h * 0.35, cap: h * 0.035);
    block(u * 77, u * 3.0, h * 0.15);
    block(u * 82, u * 1.7, h * 0.40, cap: h * 0.035);
    block(u * 86, u * 2.6, h * 0.21);
    block(u * 91, u * 1.8, h * 0.31);
    block(u * 95, u * 3.2, h * 0.16);
    canvas.drawRect(Rect.fromLTWH(0, horizon - 1.5, w, 1.5), skyline);

    // The orange flash, low and narrow: an accent, never a band.
    final flash = Path()
      ..moveTo(w * 0.30, h)
      ..quadraticBezierTo(w * 0.68, h * 0.70, w, h * 0.54)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(flash, Paint()..color = accent);

    // The green sweep sits over most of the flash, leaving a sliver showing.
    final sweep = Path()
      ..moveTo(0, h * 0.70)
      ..quadraticBezierTo(w * 0.44, h * 0.50, w, h * 0.80)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    // One solid brand green — the original swept a gradient across it.
    canvas.drawPath(sweep, Paint()..color = deep);
  }

  @override
  bool shouldRepaint(_FooterWavePainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.accent != accent;
}
