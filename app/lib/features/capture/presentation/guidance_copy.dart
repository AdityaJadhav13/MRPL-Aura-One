import 'package:measurement/measurement.dart';

/// Worker-facing wording for each guidance state.
///
/// Directive §8: do not expose raw technical metrics to ordinary workers.
/// Nothing here mentions a Laplacian, a residual or a homography. The worker
/// is at the end of a shift and needs one instruction at a time.
extension GuidanceCopy on GuidanceState {
  String get instruction => switch (this) {
    GuidanceState.badgeNotFound => 'Point the camera at the badge',
    GuidanceState.moveCloser => 'Move closer',
    GuidanceState.moveFarther => 'Move back',
    GuidanceState.moveLeft => 'Move left',
    GuidanceState.moveRight => 'Move right',
    GuidanceState.moveUp => 'Move up',
    GuidanceState.moveDown => 'Move down',
    GuidanceState.holdParallel => 'Hold the phone flat above the badge',
    GuidanceState.reduceGlare => 'Reduce glare — tilt away from the light',
    GuidanceState.improveLighting => 'Move somewhere better lit',
    GuidanceState.holdSteady => 'Hold steady',
    GuidanceState.ready => 'Hold still',
  };

  /// A short explanation, shown only where there is room. Still no numbers.
  String? get detail => switch (this) {
    GuidanceState.badgeNotFound => 'All four corner markers must be visible.',
    GuidanceState.reduceGlare => 'A bright reflection hides part of the badge.',
    GuidanceState.improveLighting =>
      'There is not enough even light on the badge.',
    GuidanceState.ready => 'Keep the badge in frame.',
    _ => null,
  };
}
