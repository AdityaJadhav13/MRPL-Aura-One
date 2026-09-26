import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/theme.dart';

/// A painted refinery skyline.
///
/// **Not a photograph, and deliberately so.** No licensed refinery image
/// exists in this repository, and one must not be fetched from the network —
/// both because the licence would be unknown and because the authentication
/// flow must work with no connectivity at all.
///
/// So the backdrop is drawn: a dusk gradient over a silhouetted process
/// skyline of columns, stacks and flare towers. It reads as industrial without
/// pretending to be a specific plant. If a licensed photograph is supplied
/// later it can be layered underneath this painter's foreground, or replace it
/// entirely — the screens position it by fraction, not by pixel.
class RefinerySkyline extends StatelessWidget {
  const RefinerySkyline({this.dusk = true, this.opacity = 1.0, super.key});

  /// Warm sunset palette when true; cool daylight when false.
  final bool dusk;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        painter: _SkylinePainter(
          dusk: dusk,
          deep: corporate.primaryDeep,
          accent: corporate.accent,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  _SkylinePainter({
    required this.dusk,
    required this.deep,
    required this.accent,
  });

  final bool dusk;
  final Color deep;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dusk
              ? <Color>[
                  const Color(0xFF7E8FA6),
                  const Color(0xFFC9A184),
                  const Color(0xFFE8B183),
                  const Color(0xFF6E5A52),
                  deep,
                ]
              : <Color>[const Color(0xFFBCCBD8), const Color(0xFFD9E2E8), deep],
          stops: dusk
              ? const <double>[0.0, 0.22, 0.4, 0.62, 1.0]
              : const <double>[0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    final horizon = size.height * 0.60;
    final w = size.width;
    final ink = Paint()..color = deep.withValues(alpha: 0.88);
    final far = Paint()..color = deep.withValues(alpha: 0.42);
    final light = Paint()..color = accent.withValues(alpha: 0.85);

    // A distant plant band for depth.
    final rng = math.Random(11);
    var fx = -20.0;
    while (fx < w + 20) {
      final fw = w * (0.03 + rng.nextDouble() * 0.05);
      final fh = size.height * (0.02 + rng.nextDouble() * 0.05);
      canvas.drawRect(Rect.fromLTWH(fx, horizon - fh, fw * 0.92, fh), far);
      fx += fw;
    }

    // Warm point lights scattered through a structure, which is what actually
    // reads as "plant at dusk" rather than "city skyline".
    void lights(double left, double width, double top, double height) {
      final rows = (height / (size.height * 0.035)).clamp(1, 7).toInt();
      for (var i = 0; i < rows; i++) {
        final y = top + height * (0.12 + 0.78 * i / rows);
        canvas.drawCircle(Offset(left + width * 0.28, y), 1.4, light);
        if (width > w * 0.05) {
          canvas.drawCircle(Offset(left + width * 0.72, y), 1.4, light);
        }
      }
    }

    /// A distillation column: tall cylinder, banded, with a capped head.
    void column(double cx, double width, double height) {
      final left = cx - width / 2;
      final top = horizon - height;
      canvas.drawRect(Rect.fromLTWH(left, top, width, height + 2), ink);
      // Head cap, slightly wider.
      canvas.drawRect(
        Rect.fromLTWH(
          left - width * 0.16,
          top - size.height * 0.008,
          width * 1.32,
          size.height * 0.010,
        ),
        ink,
      );
      // Tray bands: the horizontal detail that says "process column".
      final bands = (height / (size.height * 0.045)).clamp(2, 8).toInt();
      for (var i = 1; i < bands; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            left - width * 0.08,
            top + height * i / bands,
            width * 1.16,
            1.4,
          ),
          far,
        );
      }
      lights(left, width, top, height);
    }

    /// A flare stack: thin, very tall, with a flame.
    void flare(double cx, double height) {
      final width = w * 0.012;
      final top = horizon - height;
      canvas.drawRect(
        Rect.fromLTWH(cx - width / 2, top, width, height + 2),
        ink,
      );
      // Flame.
      final flame = Path()
        ..moveTo(cx - width * 1.4, top)
        ..quadraticBezierTo(
          cx - width * 0.4,
          top - size.height * 0.030,
          cx + width * 0.2,
          top - size.height * 0.048,
        )
        ..quadraticBezierTo(
          cx + width * 0.5,
          top - size.height * 0.018,
          cx + width * 1.5,
          top,
        )
        ..close();
      canvas.drawPath(flame, Paint()..color = accent.withValues(alpha: 0.92));
      canvas.drawPath(
        flame,
        Paint()
          ..color = accent.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    /// A spherical storage vessel on legs.
    void sphere(double cx, double radius) {
      final centre = Offset(cx, horizon - radius * 1.25);
      canvas.drawCircle(centre, radius, ink);
      for (final dx in <double>[-0.62, -0.2, 0.2, 0.62]) {
        canvas.drawRect(
          Rect.fromLTWH(cx + radius * dx, centre.dy, 2.2, radius * 1.3),
          ink,
        );
      }
    }

    /// A cooling tower: trapezoid with a flared top.
    void tower(double cx, double width, double height) {
      final top = horizon - height;
      final path = Path()
        ..moveTo(cx - width * 0.62, horizon + 2)
        ..lineTo(cx - width * 0.34, top + height * 0.28)
        ..lineTo(cx - width * 0.46, top)
        ..lineTo(cx + width * 0.46, top)
        ..lineTo(cx + width * 0.34, top + height * 0.28)
        ..lineTo(cx + width * 0.62, horizon + 2)
        ..close();
      canvas.drawPath(path, ink);
    }

    // The plant, laid out with deliberate rhythm rather than randomly.
    tower(w * 0.08, w * 0.11, size.height * 0.15);
    column(w * 0.19, w * 0.042, size.height * 0.26);
    sphere(w * 0.28, w * 0.042);
    column(w * 0.355, w * 0.055, size.height * 0.21);
    flare(w * 0.44, size.height * 0.255);
    column(w * 0.525, w * 0.048, size.height * 0.29);
    sphere(w * 0.60, w * 0.036);
    column(w * 0.675, w * 0.038, size.height * 0.24);
    tower(w * 0.775, w * 0.10, size.height * 0.13);
    column(w * 0.88, w * 0.050, size.height * 0.28);
    column(w * 0.955, w * 0.034, size.height * 0.19);

    // Pipe racks, at ground level only — they connect the units rather than
    // striping the sky.
    for (final f in <double>[0.045, 0.085]) {
      canvas.drawRect(Rect.fromLTWH(0, horizon - size.height * f, w, 2.0), ink);
    }

    // Ground haze, so the silhouette sits in the scene rather than on it.
    final hazeTop = horizon - size.height * 0.10;
    canvas.drawRect(
      Rect.fromLTWH(0, hazeTop, w, size.height - hazeTop),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            deep.withValues(alpha: 0.0),
            deep.withValues(alpha: 0.75),
            deep,
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(0, hazeTop, w, size.height - hazeTop)),
    );
  }

  @override
  bool shouldRepaint(_SkylinePainter oldDelegate) =>
      oldDelegate.dusk != dusk ||
      oldDelegate.deep != deep ||
      oldDelegate.accent != accent;
}

/// The corporate footer: a soft green sweep with an orange flash.
///
/// It appears at the bottom of every authentication screen and is what makes
/// the four screens read as one product rather than four pages.
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
    canvas.drawPath(
      sweep,
      Paint()
        ..shader = LinearGradient(colors: <Color>[deep, primary])
            .createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(_FooterWavePainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.accent != accent;
}
