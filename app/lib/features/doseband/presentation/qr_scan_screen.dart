import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/product_fields.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../operations/application/operations_repository.dart';
import '../../operations/data/presentation_dataset.dart';
import '../../operations/domain/assignment.dart';
import '../../presentation/domain/presentation_qr.dart';
import '../../presentation/application/presentation_controller.dart';
import '../../workflow/application/workflow_controller.dart';
import '../application/doseband_providers.dart';
import '../domain/doseband_qr.dart';

/// Why the scanner is open.
enum QrScanPurpose {
  /// Start of a period: find a fresh DoseBand to check and claim.
  claim,

  /// End of a period: confirm the band in hand is the one assigned, before
  /// the final photograph (§19: "assigned DoseBand identity verified").
  finalRead;

  static QrScanPurpose parse(String? s) =>
      s == 'final' ? QrScanPurpose.finalRead : QrScanPurpose.claim;
}

/// Scan a DoseBand's QR code (PRODUCT BUILD v1 §7, §19).
///
/// The real camera, decoding frames in pure Dart off the UI thread. A code
/// that is not a DoseBand is named as such and scanning continues — a wrong
/// label never traps the worker. Typing the serial is always available, for
/// a label that will not scan.
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({this.purpose = QrScanPurpose.claim, super.key});

  final QrScanPurpose purpose;

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen>
    with WidgetsBindingObserver {
  CameraSource? _camera;
  StreamSubscription<Object?>? _frames;
  String? _error;
  String? _notice;
  bool _decoding = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setPreferredOrientations(const []));
    unawaited(_stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_stop());
      case AppLifecycleState.resumed:
        if (_camera == null && !_done) unawaited(_start());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _start() async {
    try {
      final camera = ref.read(qrCameraProvider)();
      await camera.port.open();
      if (!mounted) {
        await camera.port.close();
        return;
      }
      final decode = ref.read(qrDecoderProvider);
      _frames = camera.port.previewFrames().listen((frame) async {
        if (_decoding || _done) return;
        _decoding = true;
        try {
          final text = await decode(frame.image);
          if (text != null && mounted) _onText(text);
        } finally {
          _decoding = false;
        }
      });
      setState(() {
        _camera = camera;
        _error = null;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _stop() async {
    final camera = _camera;
    _camera = null;
    await _frames?.cancel();
    _frames = null;
    if (camera != null) await camera.port.close();
  }

  void _onText(String text) {
    switch (DoseBandQr.parse(text)) {
      case QrDoseBand(:final dosebandId):
        _accept(dosebandId);
      case QrUnsupportedVersion(:final version):
        _say(
          'This DoseBand label uses format $version, which this version of '
          'the app does not read. Update the app, or type the serial.',
        );
      case QrMalformed():
        _say(
          'This label looks damaged or incomplete. Type the serial instead.',
        );
      case QrNotDoseBand():
        unawaited(_unrecognised(text));
    }
  }

  /// A QR that is not a DoseBand code. Claiming: in presentation mode it may
  /// be today's printed prototype QR, mapped to the presentation DoseBand
  /// (PresentationQrResolver). Final read: accepted only if it is the very
  /// payload the active assignment was claimed with.
  Future<void> _unrecognised(String raw) async {
    if (_done) return;
    if (widget.purpose == QrScanPurpose.finalRead) {
      final assignment = await _activeAssignment();
      if (PresentationQrResolver.matchesAssignment(
        rawPayload: raw,
        assignment: assignment,
      )) {
        await _accept(assignment!.dosebandId);
      } else {
        _sayWrongBand(assignment?.dosebandId);
      }
      return;
    }
    final serial = PresentationQrResolver.resolveForClaim(
      rawPayload: raw,
      active: ref.read(activeFallbackProvider),
    );
    if (serial == null) {
      _say('That QR code is not a DoseBand. Point at the DoseBand label.');
      return;
    }
    await _accept(
      serial,
      via: BandIdentification.presentationQrMapping,
      payload: raw,
    );
  }

  Future<DoseBandAssignment?> _activeAssignment() async {
    final id = ref.read(shiftSessionProvider).value?.assignmentId;
    if (id == null) return null;
    final snapshot = await ref.read(operationsProvider.future);
    return snapshot.assignment(id);
  }

  void _sayWrongBand(String? assigned) => _say(
    'Wrong DoseBand. This DoseBand is not assigned to your active monitoring '
    'session. Use the DoseBand assigned to you'
    '${assigned == null ? '' : ' ($assigned)'}.',
  );

  void _say(String message) {
    if (_notice != message) setState(() => _notice = message);
  }

  Future<void> _accept(
    String dosebandId, {
    BandIdentification via = BandIdentification.qrCode,
    String? payload,
  }) async {
    if (_done) return;
    if (widget.purpose == QrScanPurpose.finalRead) {
      final assigned = ref
          .read(shiftSessionProvider)
          .value
          ?.physicalBadge
          ?.badgeId;
      // The same band, or no measurement: a photograph of another DoseBand
      // must never be attached to this session.
      if (assigned != dosebandId) {
        _sayWrongBand(assigned);
        return;
      }
    }
    _done = true;
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    // Leave at once; replacing this route disposes it, and dispose releases
    // the camera. Waiting on the camera first only delays the worker.
    if (widget.purpose == QrScanPurpose.finalRead) {
      context.pushReplacement('/read');
    } else {
      context.pushReplacement(
        Uri(
          path: '/doseband/check/$dosebandId',
          queryParameters: {
            if (via != BandIdentification.qrCode) 'via': via.name,
            'qr': ?payload,
          },
        ).toString(),
      );
    }
  }

  Future<void> _typeSerial() async {
    final typed = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _TypeSerialSheet(),
    );
    if (typed != null) {
      await _accept(typed, via: BandIdentification.typedSerial);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.purpose == QrScanPurpose.finalRead
        ? 'Scan your assigned DoseBand'
        : 'Scan a new DoseBand';
    final preview = _camera?.preview();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // The theme's title style names its own (dark) colour, which wins
        // over foregroundColor; on the camera's black it has to be white.
        titleTextStyle: context.type.heading.copyWith(color: Colors.white),
        title: Semantics(header: true, child: Text(title)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? _CameraProblem(message: _error!, onRetry: _start)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      if (preview != null && preview.value.isInitialized)
                        Center(child: CameraPreview(preview))
                      else
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      const ExcludeSemantics(
                        child: CustomPaint(painter: _ViewfinderPainter()),
                      ),
                    ],
                  ),
          ),
          _ScanPanel(
            purpose: widget.purpose,
            notice: _notice,
            onType: _typeSerial,
            // Presentation fallback (Presentation Controls, level 1+): the
            // presentation DoseBand enters the same path a scanned code
            // takes — including the final-read identity check.
            onPresentation:
                ref.watch(activeFallbackProvider)?.usesPresentationIdentity ??
                    false
                ? () => _accept(
                    PresentationDataset.presentationBandId,
                    via: BandIdentification.presentationBand,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _ScanPanel extends StatelessWidget {
  const _ScanPanel({
    required this.purpose,
    required this.notice,
    required this.onType,
    this.onPresentation,
  });

  final QrScanPurpose purpose;
  final String? notice;
  final VoidCallback onType;

  /// Only while the presentation fallback is on.
  final VoidCallback? onPresentation;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return Container(
      width: double.infinity,
      color: p.surfacePage,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Gaps.screenGutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                purpose == QrScanPurpose.finalRead
                    ? 'Point the camera at the QR code on the DoseBand you '
                          'have been wearing.'
                    : 'Point the camera at the QR code on an unused DoseBand.',
                style: t.body.copyWith(color: p.textPrimary),
              ),
              if (notice != null) ...[
                const SizedBox(height: Space.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    notice!,
                    style: t.bodyStrong.copyWith(color: p.warning),
                  ),
                ),
              ],
              const SizedBox(height: Space.md),
              _TypeSerialButton(onPressed: onType),
              if (onPresentation != null) ...[
                const SizedBox(height: Space.sm),
                DoseBandButton.tertiary(
                  label: 'Use Presentation DoseBand',
                  icon: Icons.co_present_outlined,
                  onPressed: onPresentation,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Type the serial" — a secondary action, big enough for a gloved thumb.
class _TypeSerialButton extends StatelessWidget {
  const _TypeSerialButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DoseBandButton.secondary(
    label: 'Type the serial instead',
    icon: Icons.keyboard_outlined,
    onPressed: onPressed,
  );
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.product.surfacePage,
      padding: const EdgeInsets.all(Gaps.screenGutter),
      child: ListView(
        children: [
          Text(
            'The camera could not be opened',
            style: context.type.heading.copyWith(
              color: context.product.textPrimary,
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'If camera access was refused, allow it in the phone’s settings '
            'for DoseBand. You can also type the serial printed under the QR '
            'code.',
            style: context.type.body.copyWith(
              color: context.product.textPrimary,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            message,
            style: context.type.caption.copyWith(
              color: context.product.textSecondary,
            ),
          ),
          const SizedBox(height: Space.base),
          DoseBandButton.secondary(label: 'Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _TypeSerialSheet extends StatefulWidget {
  const _TypeSerialSheet();

  @override
  State<_TypeSerialSheet> createState() => _TypeSerialSheetState();
}

class _TypeSerialSheetState extends State<_TypeSerialSheet> {
  final _serial = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _serial.dispose();
    super.dispose();
  }

  void _submit() {
    final id = DoseBandQr.normaliseTyped(_serial.text);
    if (id == null) {
      setState(() => _error = 'A serial looks like DB-2609-0101.');
      return;
    }
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Gaps.screenGutter,
        right: Gaps.screenGutter,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Type the DoseBand serial',
            style: context.type.heading.copyWith(
              color: context.product.textPrimary,
            ),
          ),
          const SizedBox(height: Space.md),
          ProductTextField(
            label: 'Serial',
            hint: 'DB-2609-0101',
            controller: _serial,
            error: _error,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.md),
          DoseBandButton.primary(label: 'Continue', onPressed: _submit),
        ],
      ),
    );
  }
}

/// A square window with a solid translucent scrim around it — no gradient
/// (§66). The scrim is decoration; the frame analysed is the whole preview.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.66;
    final window = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: side,
        height: side,
      ),
      const Radius.circular(Radii.md),
    );
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(window);
    canvas
      ..drawPath(scrim, Paint()..color = Colors.black.withValues(alpha: 0.45))
      ..drawRRect(
        window,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white,
      );
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) => false;
}
