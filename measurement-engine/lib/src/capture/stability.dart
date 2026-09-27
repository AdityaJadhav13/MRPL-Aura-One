import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'guidance.dart';

/// Why auto-capture is or is not armed.
enum ArmingState {
  /// Not enough frames yet to judge.
  warmingUp,

  /// A recent frame failed, and the window must refill.
  unstable,

  /// Every frame in the window passed, and the pose has stopped moving.
  armed,
}

/// The decision for one frame, with the evidence behind it.
@immutable
final class ArmingDecision {
  const ArmingDecision({
    required this.state,
    required this.consecutiveReadyFrames,
    required this.requiredFrames,
    required this.poseDriftPx,
    required this.maximumPoseDriftPx,
    required this.windowSpan,
    required this.requiredSpan,
  });

  final ArmingState state;
  final int consecutiveReadyFrames;
  final int requiredFrames;

  /// Largest movement of the badge centre across the window, in pixels. Null
  /// until at least two ready frames exist.
  final double? poseDriftPx;
  final double maximumPoseDriftPx;

  /// Elapsed time covered by the current run of ready frames.
  final Duration windowSpan;
  final Duration requiredSpan;

  bool get isArmed => state == ArmingState.armed;

  Map<String, Object?> toJson() => <String, Object?>{
    'state': state.name,
    'consecutive_ready_frames': consecutiveReadyFrames,
    'required_frames': requiredFrames,
    'pose_drift_px': poseDriftPx,
    'maximum_pose_drift_px': maximumPoseDriftPx,
    'window_span_ms': windowSpan.inMilliseconds,
    'required_span_ms': requiredSpan.inMilliseconds,
  };
}

/// Arms auto-capture only after acquisition has been good for a while.
///
/// A single passing frame is not evidence that the scene is stable. Autofocus
/// and auto-exposure both sweep through briefly-correct states on their way to
/// converging; a marker can be detected for one frame as a hand moves through;
/// a specular highlight can vanish for a frame as the phone tilts. Capturing
/// on any of those produces an image that passed a check it would fail again
/// a moment later.
///
/// Three conditions, all required: a run of consecutive passing frames, a
/// minimum elapsed time, and a pose that has stopped moving.
///
/// **The thresholds are provisional**, chosen to be defensible rather than
/// measured. Dossier V0 sets them.
final class AutoCaptureGate {
  AutoCaptureGate({
    this.requiredFrames = 5,
    this.requiredSpan = const Duration(milliseconds: 600),
    this.maximumPoseDriftPx = 6.0,
    this.provisional = true,
  }) : assert(requiredFrames >= 2, 'a run of one frame is not a run');

  final int requiredFrames;
  final Duration requiredSpan;
  final double maximumPoseDriftPx;

  /// Whether these limits are still development placeholders. They are.
  final bool provisional;

  final List<({DateTime at, double cx, double cy})> _run =
      <({DateTime at, double cx, double cy})>[];

  /// Discards the current run. Call on any user interaction that invalidates
  /// the scene — a tap to refocus, a mode change, the shutter firing.
  void reset() => _run.clear();

  /// Feeds one assessed frame and returns the current decision.
  ArmingDecision update(GuidanceAssessment assessment, DateTime at) {
    if (!assessment.state.isReady || assessment.homography == null) {
      _run.clear();
      return ArmingDecision(
        state: ArmingState.unstable,
        consecutiveReadyFrames: 0,
        requiredFrames: requiredFrames,
        poseDriftPx: null,
        maximumPoseDriftPx: maximumPoseDriftPx,
        windowSpan: Duration.zero,
        requiredSpan: requiredSpan,
      );
    }

    // Track the badge centre rather than a corner: a corner moves under both
    // translation and rotation, which would make a steady hand look jittery.
    final centre = assessment.homography!.mapXy(0, 0);
    _run.add((at: at, cx: centre.$1, cy: centre.$2));
    while (_run.length > requiredFrames) {
      _run.removeAt(0);
    }

    final span = _run.length < 2
        ? Duration.zero
        : _run.last.at.difference(_run.first.at);

    double? drift;
    if (_run.length >= 2) {
      var worst = 0.0;
      for (var i = 1; i < _run.length; i++) {
        final dx = _run[i].cx - _run[i - 1].cx;
        final dy = _run[i].cy - _run[i - 1].cy;
        final d = dx * dx + dy * dy;
        if (d > worst) worst = d;
      }
      drift = math.sqrt(worst);
    }

    final enough = _run.length >= requiredFrames && span >= requiredSpan;
    final steady = drift != null && drift <= maximumPoseDriftPx;

    return ArmingDecision(
      state: enough && steady ? ArmingState.armed : ArmingState.warmingUp,
      consecutiveReadyFrames: _run.length,
      requiredFrames: requiredFrames,
      poseDriftPx: drift,
      maximumPoseDriftPx: maximumPoseDriftPx,
      windowSpan: span,
      requiredSpan: requiredSpan,
    );
  }
}
