import 'package:measurement/measurement.dart';
import 'package:test/test.dart';

/// A stand-in assessment at a given badge-centre position.
GuidanceAssessment _ready({double cx = 400, double cy = 300}) =>
    GuidanceAssessment(
      state: GuidanceState.ready,
      badgeFound: true,
      limitsWereProvisional: true,
      homography: Homography(
        Matrix.fromRows(<List<double>>[
          <double>[14, 0, cx],
          <double>[0, 14, cy],
          <double>[0, 0, 1],
        ]),
        nullSpaceMargin: 1,
      ),
    );

const GuidanceAssessment _notReady = GuidanceAssessment(
  state: GuidanceState.reduceGlare,
  badgeFound: true,
  limitsWereProvisional: true,
);

void main() {
  final start = DateTime.utc(2026, 9, 24, 12);
  DateTime at(int ms) => start.add(Duration(milliseconds: ms));

  group('auto-capture does not arm on one good frame', () {
    test('a single ready frame is not enough', () {
      final gate = AutoCaptureGate();
      final decision = gate.update(_ready(), at(0));
      expect(decision.isArmed, isFalse);
      expect(decision.state, ArmingState.warmingUp);
      expect(decision.consecutiveReadyFrames, 1);
    });

    test('arms only after enough frames AND enough elapsed time', () {
      final gate = AutoCaptureGate();
      // Five frames, but crammed into 100 ms: that is a burst, not stability.
      ArmingDecision? last;
      for (var i = 0; i < 5; i++) {
        last = gate.update(_ready(), at(i * 25));
      }
      expect(last!.consecutiveReadyFrames, 5);
      expect(
        last.isArmed,
        isFalse,
        reason: 'the run is long enough but too brief in time',
      );

      // Same run spread over 600 ms.
      final patient = AutoCaptureGate();
      ArmingDecision? decision;
      for (var i = 0; i < 5; i++) {
        decision = patient.update(_ready(), at(i * 150));
      }
      expect(decision!.isArmed, isTrue);
      expect(decision.windowSpan.inMilliseconds, greaterThanOrEqualTo(600));
    });
  });

  group('a transient pass does not survive', () {
    test('one failing frame clears the run', () {
      // Autofocus and auto-exposure both sweep through briefly-correct states
      // on the way to converging. Capturing on one of those produces an image
      // that would fail the same check a moment later.
      final gate = AutoCaptureGate();
      for (var i = 0; i < 4; i++) {
        gate.update(_ready(), at(i * 150));
      }
      final interrupted = gate.update(_notReady, at(600));
      expect(interrupted.state, ArmingState.unstable);
      expect(interrupted.consecutiveReadyFrames, 0);

      // And the window has to refill from scratch.
      final next = gate.update(_ready(), at(750));
      expect(next.consecutiveReadyFrames, 1);
      expect(next.isArmed, isFalse);
    });

    test('a ready state with no recovered pose is treated as unstable', () {
      final gate = AutoCaptureGate();
      final decision = gate.update(
        const GuidanceAssessment(
          state: GuidanceState.ready,
          badgeFound: true,
          limitsWereProvisional: true,
        ),
        at(0),
      );
      expect(decision.state, ArmingState.unstable);
    });
  });

  group('the pose must have stopped moving', () {
    test('a drifting badge does not arm even with a long clean run', () {
      final gate = AutoCaptureGate();
      ArmingDecision? decision;
      for (var i = 0; i < 6; i++) {
        // 20 px per frame: a hand still moving.
        decision = gate.update(_ready(cx: 400 + i * 20.0), at(i * 150));
      }
      expect(decision!.consecutiveReadyFrames, greaterThanOrEqualTo(5));
      expect(decision.poseDriftPx, greaterThan(6.0));
      expect(decision.isArmed, isFalse);
    });

    test('sub-threshold jitter still arms', () {
      final gate = AutoCaptureGate();
      ArmingDecision? decision;
      for (var i = 0; i < 6; i++) {
        decision = gate.update(
          _ready(cx: 400 + (i.isEven ? 1.0 : -1.0)),
          at(i * 150),
        );
      }
      expect(decision!.poseDriftPx, lessThan(6.0));
      expect(decision.isArmed, isTrue);
    });
  });

  group('lifecycle', () {
    test('reset discards the run', () {
      final gate = AutoCaptureGate();
      for (var i = 0; i < 5; i++) {
        gate.update(_ready(), at(i * 150));
      }
      gate.reset();
      final decision = gate.update(_ready(), at(900));
      expect(decision.consecutiveReadyFrames, 1);
      expect(decision.isArmed, isFalse);
    });

    test('the limits are marked provisional', () {
      expect(AutoCaptureGate().provisional, isTrue);
    });

    test('a run of one frame is not a run', () {
      expect(
        () => AutoCaptureGate(requiredFrames: 1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
