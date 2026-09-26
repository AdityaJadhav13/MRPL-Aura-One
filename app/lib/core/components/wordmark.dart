import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// The DoseBand wordmark.
///
/// The mark is the instrument, not a mascot: a miniature of the signature
/// measurement scale — an axis with two hard end-stops and a marker settled
/// between them — over the name. The brand *is* "a reading shown with its own
/// limits", which is the product's whole thesis. Drawn, not an image asset, so
/// it is crisp at any size and needs no network.
class Wordmark extends StatelessWidget {
  const Wordmark({this.compact = false, super.key});

  /// A tighter form for app bars and dense headers.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final markWidth = compact ? 88.0 : 132.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(markWidth, compact ? 10 : 14),
          painter: _ScaleMarkPainter(
            axis: c.borderStrong,
            marker: c.measurementAccent,
          ),
        ),
        SizedBox(height: compact ? Space.xs : Space.sm),
        Text(
          'DoseBand',
          style: (compact ? t.heading : t.display).copyWith(
            color: c.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _ScaleMarkPainter extends CustomPainter {
  _ScaleMarkPainter({required this.axis, required this.marker});

  final Color axis;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;

    // The axis.
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), axisPaint);
    // Two hard end-stops — the limits the instrument always shows.
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, size.height),
      axisPaint,
    );

    // The settled marker, a little past centre.
    final markerPaint = Paint()..color = marker;
    canvas.drawCircle(Offset(size.width * 0.62, midY), 3.5, markerPaint);
  }

  @override
  bool shouldRepaint(_ScaleMarkPainter old) =>
      old.axis != axis || old.marker != marker;
}
