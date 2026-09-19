import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// Where the marker sits, if anywhere.
enum ScaleMarker {
  /// A point inside the measurable range.
  value,

  /// Past the upper limit. The marker leaves the scale rather than pinning.
  aboveRange,

  /// Below the quantification limit.
  belowRange,

  /// No marker at all. The scale is drawn empty.
  none,
}

/// The signature component: a dose shown as a point on a printed scale that
/// **always displays its own limits**.
///
/// The quantification limit and the saturation point are drawn as hard stops on
/// every result, valid or not. The instrument shows the boundaries of what it
/// can know, every time.
///
/// The axis is logarithmic. The validated dose range spans roughly two decades
/// (0.5 to 40 ppm-h) and the sensitive region sits at the bottom of it; on a
/// linear axis a 1 ppm-h reading would land at about 1% of the bar and be
/// unreadable. The scale's job is showing position relative to the limits, not
/// supporting magnitude arithmetic — the number itself is the hero above it.
class MeasurementScale extends StatelessWidget {
  const MeasurementScale({
    required this.loq,
    required this.saturation,
    required this.marker,
    required this.colour,
    this.value,
    this.ticks = const [1, 2, 5, 10, 20],
    this.animate = true,
    super.key,
  });

  /// Limit of quantification — the lower hard stop.
  final double loq;

  /// Saturation — the upper hard stop.
  final double saturation;

  final ScaleMarker marker;
  final double? value;
  final List<double> ticks;
  final Color colour;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final shouldAnimate = animate && !reduceMotion;

    // Text painted on a canvas does not inherit MediaQuery scaling, so the
    // scaler is passed in explicitly. Without it the axis labels stay at 13px
    // however large the user has set their type, which is an accessibility
    // failure that compiles perfectly well.
    final scaler = MediaQuery.textScalerOf(context);

    final painter = _ScalePainter(
      loq: loq,
      saturation: saturation,
      ticks: ticks,
      marker: marker,
      value: value,
      markerColour: colour,
      axisColour: c.borderStrong,
      tickColour: c.textSecondary,
      labelStyle: context.type.readoutSmall.copyWith(color: c.textSecondary),
      capLabelStyle: context.type.caption.copyWith(color: c.textSecondary),
      scaler: scaler,
    );

    final scale = SizedBox(
      height: 24 + scaler.scale(40),
      width: double.infinity,
      child: shouldAnimate
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Motion.reveal,
              curve: Curves.easeOutQuint,
              builder: (context, t, _) =>
                  CustomPaint(painter: painter.withProgress(t)),
            )
          : CustomPaint(painter: painter.withProgress(1)),
    );

    return Semantics(
      label: _semanticLabel(),
      excludeSemantics: true,
      child: scale,
    );
  }

  String _semanticLabel() {
    final range = 'Measurable range $loq to $saturation ppm hours.';
    return switch (marker) {
      ScaleMarker.value => '$range Reading at ${value ?? 0} ppm hours.',
      ScaleMarker.aboveRange => '$range Reading is above the upper limit.',
      ScaleMarker.belowRange => '$range Reading is below the lower limit.',
      ScaleMarker.none => '$range No reading.',
    };
  }
}

class _ScalePainter extends CustomPainter {
  _ScalePainter({
    required this.loq,
    required this.saturation,
    required this.ticks,
    required this.marker,
    required this.value,
    required this.markerColour,
    required this.axisColour,
    required this.tickColour,
    required this.labelStyle,
    required this.capLabelStyle,
    required this.scaler,
    this.progress = 1,
  });

  final double loq;
  final double saturation;
  final List<double> ticks;
  final ScaleMarker marker;
  final double? value;
  final Color markerColour;
  final Color axisColour;
  final Color tickColour;
  final TextStyle labelStyle;
  final TextStyle capLabelStyle;
  final TextScaler scaler;
  final double progress;

  _ScalePainter withProgress(double t) => _ScalePainter(
    loq: loq,
    saturation: saturation,
    ticks: ticks,
    marker: marker,
    value: value,
    markerColour: markerColour,
    axisColour: axisColour,
    tickColour: tickColour,
    labelStyle: labelStyle,
    capLabelStyle: capLabelStyle,
    scaler: scaler,
    progress: t,
  );

  double get _labelY => 10;
  double get _capY => 10 + scaler.scale(20);

  static const double _capHeight = 14;
  static const double _tickHeight = 6;
  static const double _overshoot = 22;

  double _fraction(double v) {
    final lo = math.log(loq);
    final hi = math.log(saturation);
    return ((math.log(v) - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final left = 0.0;
    final right = size.width - _overshoot;
    final axisY = 18.0;
    final span = right - left;

    final axisPaint = Paint()
      ..color = axisColour
      ..strokeWidth = Borders.hairline
      ..strokeCap = StrokeCap.square;

    // Axis, drawn left to right as the reveal progresses.
    canvas.drawLine(
      Offset(left, axisY),
      Offset(left + span * progress, axisY),
      axisPaint,
    );

    // Hard stops at both limits. These are drawn on every result.
    if (progress > 0.02) {
      canvas.drawLine(
        Offset(left, axisY - _capHeight / 2),
        Offset(left, axisY + _capHeight / 2),
        axisPaint..strokeWidth = Borders.emphasis,
      );
    }
    if (progress > 0.98) {
      canvas.drawLine(
        Offset(right, axisY - _capHeight / 2),
        Offset(right, axisY + _capHeight / 2),
        axisPaint..strokeWidth = Borders.emphasis,
      );
    }

    // The limit labels are drawn first and always win: a scale whose job is to
    // show its own limits must never drop them. Intermediate ticks are then
    // culled where they would collide, which is what any real axis does as
    // space runs out.
    final loqLabel = _measure(_fmt(loq), labelStyle);
    final satLabel = _measure(_fmt(saturation), labelStyle);
    _draw(canvas, loqLabel, left, axisY + _labelY);
    _draw(canvas, satLabel, right - satLabel.width, axisY + _labelY);
    _draw(canvas, _measure('LoQ', capLabelStyle), left, axisY + _capY);
    final satCap = _measure('saturation', capLabelStyle);
    _draw(canvas, satCap, right - satCap.width, axisY + _capY);

    const gap = 6.0;
    final occupied = <({double lo, double hi})>[
      (lo: left, hi: left + loqLabel.width),
      (lo: right - satLabel.width, hi: right),
    ];

    final tickPaint = Paint()
      ..color = tickColour
      ..strokeWidth = Borders.hairline;
    for (final t in ticks) {
      if (t <= loq || t >= saturation) continue;
      final x = left + span * _fraction(t);
      if (x > left + span * progress) continue;

      final label = _measure(_fmt(t), labelStyle);
      final lo = x - label.width / 2;
      final hi = x + label.width / 2;
      final collides = occupied.any((o) => lo < o.hi + gap && hi > o.lo - gap);
      if (collides) continue;

      canvas.drawLine(
        Offset(x, axisY - _tickHeight / 2),
        Offset(x, axisY + _tickHeight / 2),
        tickPaint,
      );
      _draw(canvas, label, lo, axisY + _labelY);
      occupied.add((lo: lo, hi: hi));
    }

    if (progress < 0.99) return;

    switch (marker) {
      case ScaleMarker.value:
        final v = value;
        if (v == null) return;
        final x = left + span * _fraction(v);
        canvas
          ..drawCircle(Offset(x, axisY), 7, Paint()..color = markerColour)
          ..drawLine(
            Offset(x, axisY - _capHeight),
            Offset(x, axisY + _capHeight),
            Paint()
              ..color = markerColour
              ..strokeWidth = Borders.emphasis,
          );
      case ScaleMarker.aboveRange:
        _arrow(canvas, right + 6, axisY, pointsRight: true);
      case ScaleMarker.belowRange:
        _arrow(canvas, left - 6, axisY, pointsRight: false);
      case ScaleMarker.none:
        // Nothing. The scale is shown empty, which is the point: the reader can
        // see there is a slot for a reading and that it has not been filled.
        break;
    }
  }

  void _arrow(Canvas canvas, double x, double y, {required bool pointsRight}) {
    final dir = pointsRight ? 1.0 : -1.0;
    final paint = Paint()
      ..color = markerColour
      ..strokeWidth = Borders.emphasis
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, y), Offset(x + dir * 12, y), paint);
    final head = Path()
      ..moveTo(x + dir * 18, y)
      ..lineTo(x + dir * 9, y - 5)
      ..lineTo(x + dir * 9, y + 5)
      ..close();
    canvas.drawPath(head, Paint()..color = markerColour);
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  TextPainter _measure(String s, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
  }

  void _draw(Canvas canvas, TextPainter tp, double x, double y) {
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(_ScalePainter old) =>
      old.progress != progress ||
      old.marker != marker ||
      old.value != value ||
      old.markerColour != markerColour;
}
