import 'package:meta/meta.dart';

import '../capture/guidance.dart';
import '../contract/research_pipeline.dart';
import '../geometry/badge_geometry.dart';
import '../geometry/geometry_validation.dart';
import '../validity/result_status.dart';

/// The state of one quality check. MEASUREMENT-INTEGRATION-02 §49.
enum CheckState {
  /// Met its threshold.
  pass,

  /// Met it, with a caveat worth recording.
  warn,

  /// Did not meet its threshold.
  fail,

  /// Could not be evaluated — the data it needs does not exist for this
  /// capture, e.g. withheld references when no correction could be fitted.
  unavailable,

  /// Measured, but **no threshold has been established**, so there is no
  /// basis for calling the value good or bad. Never presented as a pass.
  notValidated,
}

/// Where a check's threshold came from.
enum ThresholdStatus {
  /// Chosen against synthetic renders; not yet set against a physical
  /// photograph. Every acquisition threshold is in this state today.
  synthetic,

  /// A structural rule rather than a tuned number — "four fiducials were
  /// found", "the normal equations were full rank".
  structural,

  /// No threshold exists.
  none,
}

/// One quality check on one capture.
@immutable
final class QualityCheck {
  const QualityCheck({
    required this.id,
    required this.state,
    required this.thresholdStatus,
    required this.reason,
    required this.workerAction,
    required this.blocksMeasurement,
    this.metrics = const <String, double?>{},
    this.threshold,
  });

  /// Stable identifier, e.g. `focus`, `withheld_references`.
  final String id;
  final CheckState state;
  final ThresholdStatus thresholdStatus;

  /// For diagnostics: what was measured and against what.
  final String reason;

  /// For the worker: one plain instruction, or empty when there is nothing
  /// the worker can do. Never contains a metric. §15, §50.
  final String workerAction;

  /// Whether a failure here invalidates the acquisition. Checks with no
  /// threshold cannot block — there is no basis on which to refuse.
  final bool blocksMeasurement;

  final Map<String, double?> metrics;

  /// Human-readable threshold, e.g. `≥ 1.0e-4`. Null when there is none.
  final String? threshold;

  bool get failedAndBlocks => blocksMeasurement && state == CheckState.fail;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'state': state.name,
    'threshold_status': thresholdStatus.name,
    'threshold': threshold,
    'metrics': metrics,
    'reason': reason,
    'worker_action': workerAction,
    'blocks_measurement': blocksMeasurement,
  };
}

/// Every quality check on one capture, kept separate. §48.
///
/// ## Why there is no combined score
///
/// A single "image quality 87%" would hide which dimension failed, and would
/// average a destroyed reference patch against a sharp focus. Each check is
/// reported on its own; the only aggregate is [acceptable], which is a plain
/// conjunction — any blocking failure refuses.
///
/// ## What "acceptable" does and does not mean
///
/// It means no measurement-critical check failed **against thresholds that are
/// themselves synthetic**. It is the best available statement, not a validated
/// one, and every check that has no threshold is reported as `notValidated`
/// rather than silently counted as a pass.
@immutable
final class AcquisitionQuality {
  const AcquisitionQuality(this.checks);

  final List<QualityCheck> checks;

  /// No measurement-critical check failed.
  bool get acceptable => !checks.any((c) => c.failedAndBlocks);

  /// The first blocking failure, in the order the checks were made — framing
  /// before lighting before references, so the worker fixes one thing at a
  /// time.
  QualityCheck? get primaryFailure {
    for (final c in checks) {
      if (c.failedAndBlocks) return c;
    }
    return null;
  }

  /// The refusal status a primary failure maps to.
  ResultStatus? get refusalStatus => switch (primaryFailure?.id) {
    null => null,
    'reference_fit' ||
    'withheld_references' => ResultStatus.referencePatchFailure,
    _ => ResultStatus.poorImage,
  };

  QualityCheck? byId(String id) {
    for (final c in checks) {
      if (c.id == id) return c;
    }
    return null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 'doseband-acquisition-quality/1',
    'acceptable': acceptable,
    'primary_failure': primaryFailure?.id,
    'checks': checks.map((c) => c.toJson()).toList(),
  };
}

/// Assesses a final still. The authoritative quality statement for a capture.
///
/// [still] is the still's own guidance assessment, made against the same
/// [limits] — this function re-expresses that single verdict one dimension at
/// a time, so it applies the very same comparisons rather than new ones. A
/// test holds the two together: they may never disagree about readiness.
///
/// [observation] and [geometryValidation] are null when the pipeline stopped
/// before producing them; the checks that need them report `unavailable`.
AcquisitionQuality assessAcquisition({
  required GuidanceAssessment still,
  required AcquisitionLimits limits,
  required BadgeGeometry geometry,
  ResearchObservation? observation,
  GeometryValidation? geometryValidation,
}) {
  final checks = <QualityCheck>[];
  final q = still.quality;
  final tuned = limits.provisional
      ? ThresholdStatus.synthetic
      : ThresholdStatus.structural;

  QualityCheck compare({
    required String id,
    required bool ok,
    required String threshold,
    required Map<String, double?> metrics,
    required String failReason,
    required String action,
    ThresholdStatus? status,
    bool blocks = true,
  }) => QualityCheck(
    id: id,
    state: ok ? CheckState.pass : CheckState.fail,
    thresholdStatus: status ?? tuned,
    threshold: threshold,
    metrics: metrics,
    reason: ok ? 'within $threshold' : failReason,
    workerAction: ok ? '' : action,
    blocksMeasurement: blocks,
  );

  QualityCheck unavailable(String id, String why, {bool blocks = true}) =>
      QualityCheck(
        id: id,
        state: CheckState.unavailable,
        thresholdStatus: ThresholdStatus.none,
        reason: why,
        workerAction: '',
        blocksMeasurement: blocks,
      );

  // ------------------------------------------------------------ target
  checks.add(
    QualityCheck(
      id: 'target_found',
      state: still.badgeFound ? CheckState.pass : CheckState.fail,
      thresholdStatus: ThresholdStatus.structural,
      reason: still.badgeFound
          ? 'all primary fiducials found and a pose recovered'
          : 'the badge could not be located',
      workerAction: still.badgeFound
          ? ''
          : 'Show the whole badge, flat, inside the frame.',
      blocksMeasurement: true,
    ),
  );

  final scale = still.pixelsPerMm;
  if (scale == null || q == null) {
    // Nothing else about the frame can be judged without a pose.
    for (final id in const <String>[
      'scale',
      'framing',
      'perspective',
      'glare',
      'highlight_clipping',
      'exposure',
      'focus',
    ]) {
      checks.add(unavailable(id, 'no pose recovered'));
    }
  } else {
    checks
      ..add(
        compare(
          id: 'scale',
          ok:
              scale >= limits.minimumPixelsPerMm &&
              scale <= limits.maximumPixelsPerMm,
          threshold:
              '${limits.minimumPixelsPerMm}–${limits.maximumPixelsPerMm} px/mm',
          metrics: {'pixels_per_mm': scale},
          failReason: 'badge sampled at ${scale.toStringAsFixed(1)} px/mm',
          action: scale < limits.minimumPixelsPerMm
              ? 'Move closer to the badge.'
              : 'Move the phone farther from the badge.',
        ),
      )
      ..add(
        compare(
          id: 'framing',
          ok:
              (still.centreOffsetFraction ?? 0) <=
              limits.maximumCentreOffsetFraction,
          threshold: '≤ ${limits.maximumCentreOffsetFraction} of frame width',
          metrics: {'centre_offset_fraction': still.centreOffsetFraction},
          failReason: 'badge off-centre',
          action: 'Centre the badge in the frame.',
        ),
      )
      ..add(
        compare(
          id: 'perspective',
          ok: (still.tiltRatio ?? 1) <= limits.maximumTiltRatio,
          // The ratio is of squared edge lengths — see assessFrame.
          threshold: '≤ ${limits.maximumTiltRatio} (squared edge ratio)',
          metrics: {'tilt_ratio_squared_edges': still.tiltRatio},
          failReason: 'badge viewed at an angle',
          action: 'Hold the phone parallel to the badge.',
        ),
      )
      ..add(
        compare(
          id: 'glare',
          ok: q.specularFraction <= limits.maximumSpecularFraction,
          threshold: '≤ ${limits.maximumSpecularFraction} specular fraction',
          metrics: {'specular_fraction': q.specularFraction},
          failReason: 'specular highlights on the badge',
          action: 'Tilt the phone slightly to remove the reflection.',
        ),
      )
      ..add(
        compare(
          id: 'highlight_clipping',
          ok: q.highClipFraction <= limits.maximumHighClipFraction,
          threshold: '≤ ${limits.maximumHighClipFraction} clipped fraction',
          metrics: {'high_clip_fraction': q.highClipFraction},
          failReason: 'highlights clipped — colour information destroyed',
          action: 'Reduce the light on the badge.',
        ),
      )
      // Measured but not gated: AcquisitionLimits has no shadow-clipping
      // limit, and inventing one here would be a new threshold.
      ..add(
        QualityCheck(
          id: 'shadow_clipping',
          state: CheckState.notValidated,
          thresholdStatus: ThresholdStatus.none,
          metrics: {'low_clip_fraction': q.lowClipFraction},
          reason: 'measured; no shadow-clipping limit has been established',
          workerAction: '',
          blocksMeasurement: false,
        ),
      )
      ..add(
        compare(
          id: 'exposure',
          ok:
              q.luma.mean >= limits.minimumLumaMean &&
              q.luma.mean <= limits.maximumLumaMean,
          threshold:
              'luma mean ${limits.minimumLumaMean}–${limits.maximumLumaMean}',
          metrics: {'luma_mean': q.luma.mean},
          failReason: 'overall exposure outside range',
          action: q.luma.mean < limits.minimumLumaMean
              ? 'Move to better light.'
              : 'Reduce the light on the badge.',
        ),
      )
      ..add(
        compare(
          id: 'focus',
          ok:
              q.laplacianVariance.isFinite &&
              q.laplacianVariance >= limits.minimumLaplacianVariance,
          threshold: '≥ ${limits.minimumLaplacianVariance} Laplacian variance',
          metrics: {'laplacian_variance': q.laplacianVariance},
          failReason: 'image not sharp enough',
          action: 'Hold the phone steady and retake.',
        ),
      );
  }

  // ---------------------------------------------------------- geometry
  if (observation == null) {
    checks.add(unavailable('homography', 'no observation was made'));
  } else {
    checks.add(
      QualityCheck(
        id: 'homography',
        state: CheckState.pass,
        thresholdStatus: ThresholdStatus.structural,
        metrics: {'reprojection_rms_px': observation.reprojectionRmsPx},
        // Four points always fit a projective map exactly, so this residual
        // says nothing about planarity. Deformation is the check for that.
        reason:
            'pose recovered from four fiducials; a four-point fit is exact '
            'and is not evidence of a flat, undistorted badge',
        workerAction: '',
        blocksMeasurement: true,
      ),
    );
  }

  // Recorded, never gating: no residual limit has been established (G-07).
  checks.add(
    geometryValidation == null
        ? unavailable(
            'deformation',
            geometry.supportsDeformationValidation
                ? 'not assessed for this capture'
                : 'geometry carries no withheld control points',
            blocks: false,
          )
        : QualityCheck(
            id: 'deformation',
            state: geometryValidation.hasUsableRedundancy
                ? CheckState.notValidated
                : CheckState.unavailable,
            thresholdStatus: ThresholdStatus.none,
            metrics: {
              'rms_mm': geometryValidation.rmsMm,
              'maximum_mm': geometryValidation.maximumMm,
              'matched_control_points': geometryValidation.matchedControlPoints
                  .toDouble(),
            },
            reason:
                'secondary-marker residuals measured; no rejection limit has '
                'been established, so a bent badge is not yet refused',
            workerAction: '',
            blocksMeasurement: false,
          ),
  );

  // -------------------------------------------------------- references
  final fit = observation?.correctionFit;
  if (observation == null || fit == null) {
    checks.add(unavailable('reference_fit', 'no observation was made'));
  } else {
    checks.add(
      QualityCheck(
        id: 'reference_fit',
        state: fit.isOk ? CheckState.pass : CheckState.fail,
        thresholdStatus: ThresholdStatus.structural,
        threshold: 'full rank, condition number within limit',
        metrics: {
          'condition_number': fit.conditioning?.conditionNumber,
          'effective_rank': fit.conditioning?.effectiveRank.toDouble(),
        },
        reason: fit.isOk
            ? 'correction ${fit.correction!.form.name} fitted'
            : 'no correction could be fitted: ${fit.rejection?.name}',
        workerAction: fit.isOk
            ? ''
            : 'The colour references could not be read. Check they are '
                  'clean, uncovered and evenly lit.',
        blocksMeasurement: true,
      ),
    );
  }

  final validation = observation?.referenceValidation;
  if (validation == null) {
    checks.add(unavailable('withheld_references', 'no correction to validate'));
  } else {
    checks.add(
      QualityCheck(
        id: 'withheld_references',
        state: validation.passed ? CheckState.pass : CheckState.fail,
        thresholdStatus: validation.thresholdIsProvisional
            ? ThresholdStatus.synthetic
            : ThresholdStatus.structural,
        threshold: 'max ΔE00 ≤ ${validation.threshold}',
        metrics: {
          'maximum_delta_e00': validation.maximumDeltaE00,
          'mean_delta_e00': validation.meanDeltaE00,
        },
        // Against design-space targets: a print that does not match its
        // design file can fail here with a perfectly good correction.
        reason: validation.passed
            ? 'withheld patches predicted within threshold'
            : 'withheld patches not predicted by the correction '
                  '(max ΔE00 ${validation.maximumDeltaE00.toStringAsFixed(2)}); '
                  'targets are design-space values, not measured print',
        workerAction: validation.passed
            ? ''
            : 'Lighting across the badge is uneven. Move to even light and '
                  'retake.',
        blocksMeasurement: true,
      ),
    );
  }

  // --------------------------------------------------------- regions
  // Recorded, not gated: no usable-fraction limit has been established.
  for (final (id, kind) in const <(String, RoiKind)>[
    ('sensor_region', RoiKind.sensor),
    ('blank_region', RoiKind.blank),
    ('expiry_region', RoiKind.expiry),
  ]) {
    final roi = geometry.ofKind(kind).firstOrNull;
    final sample = roi == null ? null : observation?.samples[roi.id];
    checks.add(
      sample == null
          ? unavailable(id, 'region not sampled', blocks: false)
          : QualityCheck(
              id: id,
              state: CheckState.notValidated,
              thresholdStatus: ThresholdStatus.none,
              metrics: {
                'usable_fraction': sample.usableFraction,
                'maximum_channel_iqr': sample.maximumChannelIqr,
              },
              reason:
                  'sampled; no usable-fraction or uniformity limit has been '
                  'established',
              workerAction: '',
              blocksMeasurement: false,
            ),
    );
  }

  return AcquisitionQuality(checks);
}
