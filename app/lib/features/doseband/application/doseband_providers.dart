import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart';

import '../../../core/env/app_version.dart';
import '../../capture/data/camera_port_impl.dart';
import '../../capture/domain/capture_port.dart';
import '../../../core/domain/doseband.dart';
import '../../presentation/application/presentation_controller.dart';
import '../data/qr_codec.dart';
import '../domain/pre_use.dart';

/// A camera for one screen: the port, and the live preview widget's
/// controller when there is a real one.
typedef CameraSource = ({
  CameraPort port,
  CameraController? Function() preview,
});

/// The camera the QR scanner opens. Preview frames at half resolution — a
/// label is small in the frame, and the measurement preview's quarter scale
/// loses it. Overridden in tests with a fake port.
final qrCameraProvider = Provider<CameraSource Function()>(
  (_) => () {
    final port = CameraPortImpl(
      appVersion: appVersion,
      resolution: ResolutionPreset.high,
      previewDownscale: 2,
    );
    return (port: port, preview: () => port.controller);
  },
);

/// Decodes a frame off the UI thread. Overridden in widget tests, which
/// cannot wait on a real isolate.
final qrDecoderProvider = Provider<Future<String?> Function(RgbImage)>(
  (_) =>
      (image) => compute(QrCodec.decode, image),
);

/// Runs the optical half of the pre-use check for [band] and returns what it
/// found. The app opens the pre-use camera; tests substitute a result.
///
/// For the presentation DoseBand with the presentation fallback at level 2
/// or above, the outcome is the fixture's deterministic READY. At level 2
/// the real pre-use photograph is still taken (and archived by the capture
/// screen) first; at level 3 there is no camera. The engine's thresholds are
/// never touched: the fallback sits beside the engine, not inside it.
final opticalCheckProvider =
    Provider<Future<OpticalResult?> Function(BuildContext, DoseBand)>(
      (ref) => (context, band) async {
        final level = fallbackFor(
          ref.read(activeFallbackProvider),
          band.dosebandId,
        );
        if (level != null && level.usesPresentationInterpretation) {
          if (!level.skipsCamera) {
            final taken = await context.push<OpticalResult>(
              '/doseband/check/${band.dosebandId}/photo',
            );
            // Backed out of the camera: no check was made.
            if (taken == null) return null;
          }
          return const OpticalReadable(presentation: true);
        }
        return context.push<OpticalResult>(
          '/doseband/check/${band.dosebandId}/photo',
        );
      },
    );
