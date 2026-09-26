import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:measurement/measurement.dart';

import '../domain/capture_outcome.dart';
import '../domain/capture_port.dart';

/// What the capture screen shows right now.
@immutable
final class CaptureUiState {
  const CaptureUiState({
    required this.guidance,
    required this.arming,
    required this.capabilities,
    required this.isCapturing,
    this.outcome,
    this.error,
  });

  const CaptureUiState.initial()
    : guidance = null,
      arming = null,
      capabilities = const CameraCapabilities.unknown(),
      isCapturing = false,
      outcome = null,
      error = null;

  final GuidanceAssessment? guidance;
  final ArmingDecision? arming;
  final CameraCapabilities capabilities;
  final bool isCapturing;
  final CaptureOutcome? outcome;
  final String? error;

  GuidanceState get state => guidance?.state ?? GuidanceState.badgeNotFound;

  /// Whether the shutter may fire by itself.
  bool get autoCaptureArmed => (arming?.isArmed ?? false) && !isCapturing;

  CaptureUiState copyWith({
    GuidanceAssessment? guidance,
    ArmingDecision? arming,
    CameraCapabilities? capabilities,
    bool? isCapturing,
    CaptureOutcome? outcome,
    String? error,
    bool clearOutcome = false,
  }) => CaptureUiState(
    guidance: guidance ?? this.guidance,
    arming: arming ?? this.arming,
    capabilities: capabilities ?? this.capabilities,
    isCapturing: isCapturing ?? this.isCapturing,
    outcome: clearOutcome ? null : (outcome ?? this.outcome),
    error: error,
  );
}

/// Drives acquisition: guidance on preview frames, arming, and capture.
///
/// **No scientific calculation happens here or in any widget.** Every optical
/// decision is delegated to `package:measurement`, which cannot import Flutter
/// (ADR-0004). This class owns camera lifecycle and app state, nothing more.
final class CaptureController extends ChangeNotifier {
  CaptureController({
    required this.port,
    required this.geometry,
    required this.referenceTargets,
    required this.fitPatchIds,
    required this.holdoutPatchIds,
    required this.appVersion,
    this.limits = const AcquisitionLimits(),
    this.autoCapture = true,
    this.previewDownscale = 1,
    this.calibration = const NoCalibration(),
    AutoCaptureGate? gate,
  }) : _gate = gate ?? AutoCaptureGate(),
       _previewLimits = _scaledForPreview(limits, previewDownscale);

  final CameraPort port;
  final BadgeGeometry geometry;
  final Map<String, LinearRgb> referenceTargets;
  final List<String> fitPatchIds;
  final List<String> holdoutPatchIds;
  final String appVersion;
  final AcquisitionLimits limits;
  final AutoCaptureGate _gate;

  /// Whether the shutter may fire by itself once the gate arms.
  final bool autoCapture;

  /// How much smaller a preview frame is than the still, per side.
  ///
  /// Preview frames are downscaled before analysis, and pixels-per-millimetre
  /// is measured in image pixels — so on a ¼-scale preview it reads a quarter
  /// of the still's value. Assessing that against still-scale limits meant
  /// guidance could never report *ready*: at 1080p the preview is 480×270, and
  /// a 60×40 mm badge at the 8 px/mm floor needs 480×320. G-03.
  ///
  /// **Assumes the preview's native resolution matches the still's.** That
  /// holds for the camera plugin's shared resolution preset, but it is a
  /// device fact, not a guarantee — which is why both assessments are kept
  /// on every record, and the preview/still ratio is a dossier question.
  final int previewDownscale;

  /// What turns an observation into a result. Only [NoCalibration] exists.
  final Calibration calibration;

  final AcquisitionLimits _previewLimits;

  static AcquisitionLimits _scaledForPreview(
    AcquisitionLimits l,
    int downscale,
  ) {
    if (downscale <= 1) return l;
    // Only the two limits in image-pixel units are rescaled. Offsets, tilt,
    // clip and specular fractions and luma are ratios and do not change.
    return AcquisitionLimits(
      minimumPixelsPerMm: l.minimumPixelsPerMm / downscale,
      maximumPixelsPerMm: l.maximumPixelsPerMm / downscale,
      maximumCentreOffsetFraction: l.maximumCentreOffsetFraction,
      maximumTiltRatio: l.maximumTiltRatio,
      maximumHighClipFraction: l.maximumHighClipFraction,
      maximumSpecularFraction: l.maximumSpecularFraction,
      minimumLumaMean: l.minimumLumaMean,
      maximumLumaMean: l.maximumLumaMean,
      minimumLaplacianVariance: l.minimumLaplacianVariance,
      provisional: l.provisional,
    );
  }

  /// The last preview assessment before the shutter. Kept for the record:
  /// it is half of the preview-versus-still comparison. §41.
  GuidanceAssessment? _lastPreview;

  StreamSubscription<PreviewFrame>? _subscription;
  CaptureUiState _state = const CaptureUiState.initial();

  CaptureUiState get state => _state;

  Future<void> start() async {
    try {
      final capabilities = await port.open();
      await port.applyMeasurementSettings();
      _state = _state.copyWith(capabilities: capabilities);
      notifyListeners();
      _subscription = port.previewFrames().listen(_onFrame);
    } on CameraUnavailable catch (e) {
      _state = _state.copyWith(error: e.reason);
      notifyListeners();
    }
  }

  void _onFrame(PreviewFrame frame) {
    if (_state.isCapturing) return;

    // Guidance only. A preview frame may differ from the still in resolution,
    // crop, exposure and colour pipeline, so nothing decided here stands in
    // for the checks run on the captured image (directive §11).
    final guidance = assessFrame(
      frame: frame.image,
      geometry: geometry,
      limits: _previewLimits,
    );
    _lastPreview = guidance;
    final arming = _gate.update(guidance, frame.at);

    _state = _state.copyWith(guidance: guidance, arming: arming);
    notifyListeners();

    if (autoCapture && arming.isArmed) {
      unawaited(capture());
    }
  }

  /// Returns to live guidance after a capture.
  ///
  /// Taking a still stops the camera's image stream, and nothing restarted
  /// it — so from the second capture onward there was no guidance at all.
  /// For a session of dozens of captures that is the difference between a
  /// guided workflow and a blind one.
  Future<void> resume() async {
    await _subscription?.cancel();
    _gate.reset();
    _lastPreview = null;
    _state = _state.copyWith(clearOutcome: true, isCapturing: false);
    notifyListeners();
    try {
      _subscription = port.previewFrames().listen(_onFrame);
    } on CameraUnavailable catch (e) {
      _state = _state.copyWith(error: e.reason);
      notifyListeners();
    }
  }

  /// Takes a still and runs the authoritative checks on it.
  ///
  /// Reached identically by the auto-capture gate and by the worker pressing
  /// the shutter. **A manual shutter does not bypass validation** — it decides
  /// *when* the still is taken, never whether it is acceptable (directive §10).
  Future<void> capture() async {
    if (_state.isCapturing) return;
    _state = _state.copyWith(isCapturing: true, clearOutcome: true);
    notifyListeners();

    try {
      final still = await port.captureStill();
      _state = _state.copyWith(outcome: _evaluate(still), isCapturing: false);
    } on CameraUnavailable catch (e) {
      _state = _state.copyWith(isCapturing: false, error: e.reason);
    } finally {
      // The scene has changed and any run of ready frames is stale.
      _gate.reset();
      notifyListeners();
    }
  }

  CaptureOutcome _evaluate(CapturedStill still) {
    MeasurementResult refusal(String code, String detail) => Refused(
      status: ResultStatus.poorImage,
      reasons: <ReasonCode>[ReasonCode(code, detail: detail)],
      provenance: Provenance(
        algorithmVersion: algorithmVersion,
        geometryVersion: geometry.version,
        calibrationModelId: null,
        referenceProfileId: null,
        appVersion: appVersion,
        deviceModel: still.metadata.deviceModel,
      ),
    );

    final quality = measureImageQuality(still.image);

    // Re-assess the FINAL image against full-resolution limits. This is the
    // authoritative check; the preview only ever advised.
    final assessment = assessFrame(
      frame: still.image,
      geometry: geometry,
      limits: limits,
    );

    CaptureEvidence evidence({Homography? homography}) => CaptureEvidence(
      originalBytes: still.originalBytes,
      still: still.image,
      previewAssessment: _lastPreview,
      stillAssessment: assessment,
      stillQuality: quality,
      homography: homography,
    );

    if (!assessment.state.isReady) {
      return CaptureRefused(
        result: refusal(
          'STILL_FAILED_ACQUISITION_CHECKS',
          'the captured image did not meet acquisition requirements '
              '(${assessment.state.name}); preview guidance is not a '
              'substitute for checking the still',
        ),
        metadata: still.metadata,
        assessment: assessment,
        evidence: evidence(),
      );
    }

    final detection = detectPrimaryFiducials(still.image, geometry);
    if (!detection.isOk) {
      return CaptureRefused(
        result: refusal(
          'FIDUCIALS_NOT_FOUND_IN_STILL',
          detection.detail ?? detection.rejection!.name,
        ),
        metadata: still.metadata,
        assessment: assessment,
        evidence: evidence(),
      );
    }

    final correspondences = <Correspondence>[
      for (final f in geometry.primaryFiducials)
        Correspondence(f.centreMm, detection.primaries[f.id]!.centroid),
    ];
    final homography = estimateHomography(correspondences).homography;

    final ResearchObservation observation;
    try {
      observation = observe(
        image: still.image,
        geometry: geometry,
        correspondences: correspondences,
        // Photographs of physical targets and coupons are laboratory data:
        // controlled and traceable. Never `field`, which is reserved for a
        // badge worn by a worker, and never `simulated`, because a camera
        // took them.
        dataDomain: DataDomain.lab,
        referenceTargets: referenceTargets,
        fitPatchIds: fitPatchIds,
        holdoutPatchIds: holdoutPatchIds,
      );
    } on ObservationFailure catch (e) {
      return CaptureRefused(
        result: refusal(e.reason.code, e.reason.detail ?? ''),
        metadata: still.metadata,
        assessment: assessment,
        evidence: evidence(homography: homography),
      );
    }

    // Deformation can only be assessed where the geometry carries markers
    // withheld from the pose fit. Where it does not, it is not claimed.
    //
    // Computed and recorded, NOT gating: no residual limit that would turn a
    // bent badge into a refusal has been established, and inventing one
    // before physical captures exist would be tuning on nothing. G-07.
    final geometryValidation =
        geometry.supportsDeformationValidation && homography != null
        ? validateGeometry(
            geometry: geometry,
            homography: homography,
            detectedBlobs: detection.allBlobs,
          )
        : null;

    return CaptureObserved(
      observation: observation,
      metadata: still.metadata,
      geometryValidation: geometryValidation,
      // Through the calibration interface rather than a direct call, so a
      // real model plugs in here without this class changing. Today the
      // only implementation is NoCalibration, which refuses. G-05, §16.
      result: calibration.interpret(
        observation,
        appVersion: appVersion,
        deviceModel: still.metadata.deviceModel,
      ),
      evidence: evidence(homography: homography),
    );
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await port.close();
    super.dispose();
  }
}
