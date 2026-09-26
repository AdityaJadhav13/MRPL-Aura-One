import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/geometry/geometry_assets.dart';
import 'package:h2s_doseband/features/capture/application/capture_controller.dart';
import 'package:h2s_doseband/features/capture/domain/capture_outcome.dart';
import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

import 'fake_camera.dart';

/// Loaded through the real asset loader, not read off disk. The test then
/// exercises the same checksum-verified path the app uses, so a stale export
/// fails here too.
late final BadgeGeometry badgeV1;

Map<String, LinearRgb> get _targets => <String, LinearRgb>{
  for (final e in badgeV1Colours.entries)
    e.key: SrgbColor.fromBytes(e.value[0], e.value[1], e.value[2]).toLinear(),
};

const _fit = <String>[
  'REF-LIGHT',
  'REF-RED',
  'REF-GREEN',
  'REF-BLUE',
  'REF-CYAN',
  'REF-YELLOW',
];
const _holdout = <String>['REF-BLACK', 'REF-DARK', 'REF-MID', 'REF-MAGENTA'];

RgbImage _badgeImage({
  double pixelsPerMm = 14.0,
  Illuminant illuminant = Illuminant.neutral,
  int width = 900,
  int height = 620,
}) {
  final cx = badgeV1.widthMm / 2, cy = badgeV1.heightMm / 2;
  final h = placeBadge(
    pixelsPerMm: pixelsPerMm,
    translateX: width / 2 - pixelsPerMm * cx,
    translateY: height / 2 - pixelsPerMm * cy,
  );
  return renderBadge(
    geometry: badgeV1,
    badgeToImage: h,
    width: width,
    height: height,
    illuminant: illuminant,
    colours: badgeV1Colours,
    background: const <int>[96, 98, 102],
  );
}

CaptureController _controller(FakeCameraPort port, {bool autoCapture = true}) =>
    CaptureController(
      port: port,
      geometry: badgeV1,
      referenceTargets: _targets,
      fitPatchIds: _fit,
      holdoutPatchIds: _holdout,
      appVersion: '0.1.0',
      autoCapture: autoCapture,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    badgeV1 = await GeometryAssets().load('badge-v1-research');
  });

  test('records what the camera could actually do', () async {
    final port = FakeCameraPort(
      previewImages: <RgbImage>[_badgeImage()],
      stillImage: _badgeImage(),
      capabilities: const CameraCapabilities(
        focusLockSupported: true,
        exposureLockSupported: true,
        // A phone with no manual white balance. It is NOT rejected: whether
        // the control is needed is an experimental question, and the printed
        // references exist to make the illuminant recoverable without it.
        whiteBalanceLockSupported: false,
        exposureCompensationSupported: true,
        manualIsoSupported: false,
        manualExposureDurationSupported: false,
        torchSupported: false,
        sensorMetadataAvailable: false,
      ),
    );
    final controller = _controller(port);
    await controller.start();

    expect(port.opened, isTrue);
    expect(controller.state.capabilities.whiteBalanceLockSupported, isFalse);
    expect(controller.state.capabilities.lockScore, 2);
    await controller.dispose();
  });

  test(
    'guidance runs on preview frames and arms only after a stable run',
    () async {
      final port = FakeCameraPort(
        previewImages: <RgbImage>[_badgeImage()],
        stillImage: _badgeImage(),
      );
      final controller = _controller(port, autoCapture: false);
      await controller.start();

      await port.emit(1);
      expect(controller.state.state, GuidanceState.ready);
      expect(
        controller.state.autoCaptureArmed,
        isFalse,
        reason: 'one good frame is not stability',
      );

      await port.emit(6);
      expect(controller.state.autoCaptureArmed, isTrue);
      await controller.dispose();
    },
  );

  test('auto-capture fires once armed', () async {
    final port = FakeCameraPort(
      previewImages: <RgbImage>[_badgeImage()],
      stillImage: _badgeImage(),
    );
    final controller = _controller(port);
    await controller.start();
    await port.emit(7);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(port.captureCount, greaterThanOrEqualTo(1));
    expect(controller.state.outcome, isA<CaptureObserved>());
    await controller.dispose();
  });

  group('a capture never yields a dose', () {
    test('a good still produces an observation and a refusal', () async {
      final port = FakeCameraPort(
        previewImages: <RgbImage>[_badgeImage()],
        stillImage: _badgeImage(illuminant: Illuminant.warm),
      );
      final controller = _controller(port, autoCapture: false);
      await controller.start();
      await controller.capture();

      final outcome = controller.state.outcome;
      expect(outcome, isA<CaptureObserved>());
      final observed = outcome! as CaptureObserved;

      expect(
        observed.observation.featureVector.definitionVersion,
        featureDefinitionVersion,
      );
      expect(observed.result, isA<Refused>());
      expect(observed.result.status, ResultStatus.unsupportedCalibration);
      expect(observed.result.status.carriesDose, isFalse);
      expect(observed.result.provenance.calibrationModelId, isNull);
      await controller.dispose();
    });

    test(
      'deformation is reported because badge v1 has withheld markers',
      () async {
        final port = FakeCameraPort(
          previewImages: <RgbImage>[_badgeImage()],
          stillImage: _badgeImage(),
        );
        final controller = _controller(port, autoCapture: false);
        await controller.start();
        await controller.capture();

        final observed = controller.state.outcome! as CaptureObserved;
        expect(observed.geometryValidation, isNotNull);
        expect(observed.geometryValidation!.hasUsableRedundancy, isTrue);
        await controller.dispose();
      },
    );
  });

  group('manual capture cannot bypass validation', () {
    test(
      'a bad still is refused even though the shutter was pressed',
      () async {
        // The preview looked fine; the still did not. Directive §10: a manual
        // shutter decides WHEN the still is taken, never whether it is
        // acceptable.
        final port = FakeCameraPort(
          previewImages: <RgbImage>[_badgeImage()],
          stillImage: RgbImage.filled(900, 620, 120, 120, 120),
        );
        final controller = _controller(port, autoCapture: false);
        await controller.start();
        await port.emit(6);
        expect(controller.state.state, GuidanceState.ready);

        await controller.capture();
        final outcome = controller.state.outcome;
        expect(outcome, isA<CaptureRefused>());
        final refused = outcome! as CaptureRefused;
        expect(refused.result, isA<Refused>());
        expect(
          refused.result.reasons.map((r) => r.code),
          contains(
            anyOf(
              'STILL_FAILED_ACQUISITION_CHECKS',
              'FIDUCIALS_NOT_FOUND_IN_STILL',
            ),
          ),
        );
        await controller.dispose();
      },
    );

    test(
      'preview guidance is not accepted as evidence about the still',
      () async {
        // Deliberately staged: a perfectly framed preview and a still where the
        // badge is far too small. Only re-checking the still catches it.
        final port = FakeCameraPort(
          previewImages: <RgbImage>[_badgeImage()],
          stillImage: _badgeImage(pixelsPerMm: 4.0),
        );
        final controller = _controller(port, autoCapture: false);
        await controller.start();
        await port.emit(6);
        expect(
          controller.state.state,
          GuidanceState.ready,
          reason: 'the preview is fine',
        );

        await controller.capture();
        expect(controller.state.outcome, isA<CaptureRefused>());
        await controller.dispose();
      },
    );

    test('a refusal still records how the photograph was taken', () async {
      final port = FakeCameraPort(
        previewImages: <RgbImage>[_badgeImage()],
        stillImage: RgbImage.filled(900, 620, 120, 120, 120),
      );
      final controller = _controller(port, autoCapture: false);
      await controller.start();
      await controller.capture();

      final refused = controller.state.outcome! as CaptureRefused;
      expect(refused.metadata.deviceModel, 'FakePhone 1');
      // Never fabricated: unsupported and unavailable stay distinct.
      expect(
        refused.metadata.isoSensitivity.availability,
        MetadataAvailability.unsupported,
      );
      expect(
        refused.metadata.exposureTimeSeconds.availability,
        MetadataAvailability.unavailable,
      );
      expect(refused.metadata.isoSensitivity.value, isNull);
      await controller.dispose();
    });
  });

  test('closes the camera on dispose', () async {
    final port = FakeCameraPort(
      previewImages: <RgbImage>[_badgeImage()],
      stillImage: _badgeImage(),
    );
    final controller = _controller(port);
    await controller.start();
    await controller.dispose();
    expect(port.closed, isTrue);
  });
}
