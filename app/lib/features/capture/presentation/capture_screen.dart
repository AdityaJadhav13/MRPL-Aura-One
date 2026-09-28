import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/semantic_colors.dart';
import '../application/capture_controller.dart';
import '../domain/capture_outcome.dart';
import 'guidance_copy.dart';

/// Live acquisition.
///
/// The widget layer does no scientific calculation. It renders the preview,
/// shows one instruction, and offers a shutter; every optical decision comes
/// from `package:measurement` by way of [CaptureController], which is what
/// makes it a compile error to turn a colour into a reading in a widget
/// (ADR-0004).
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    required this.controller,
    this.preview,
    this.workerMode = false,
    this.busy = false,
    super.key,
  });

  final CaptureController controller;

  /// Worker wording for the guidance under the shutter. It never gates the
  /// shutter: the **worker** takes the photograph, whenever they judge the
  /// DoseBand is in position. Live detection only advises — the ring turns
  /// to the accent colour when the preview is ready and steady — and it
  /// never fires the shutter itself. Whatever the preview said, the still is
  /// re-checked in full after it is taken; a failed acquisition means Retake.
  final bool workerMode;

  /// The host is still handling the last photograph (saving it, recording
  /// the result). The shutter stays disabled so one tap can never produce
  /// two measurements.
  final bool busy;

  /// The live preview widget, supplied by the caller so this screen can be
  /// rendered in tests without a camera.
  final CameraController? preview;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final colours = Theme.of(context).extension<DoseBandColors>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (widget.preview?.value.isInitialized ?? false)
              CameraPreview(widget.preview!)
            else
              const ColoredBox(color: Colors.black),

            // The badge outline the worker aims at.
            const _AimingFrame(),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _GuidancePanel(
                state: state,
                accent:
                    colours?.measurementAccent ??
                    Theme.of(context).colorScheme.primary,
                onShutter: widget.controller.capture,
                workerMode: widget.workerMode,
                busy: widget.busy,
              ),
            ),

            if (state.error != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _Banner(text: state.error!),
              ),
          ],
        ),
      ),
    );
  }
}

class _AimingFrame extends StatelessWidget {
  const _AimingFrame();

  @override
  Widget build(BuildContext context) => Center(
    child: FractionallySizedBox(
      widthFactor: 0.84,
      child: AspectRatio(
        // Badge v1 is 60 x 40 mm.
        aspectRatio: 60 / 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    ),
  );
}

class _GuidancePanel extends StatelessWidget {
  const _GuidancePanel({
    required this.state,
    required this.accent,
    required this.onShutter,
    required this.workerMode,
    required this.busy,
  });

  final CaptureUiState state;
  final Color accent;
  final Future<void> Function() onShutter;
  final bool workerMode;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final guidance = state.state;
    final detail = guidance.detail;
    // Ready AND stable over consecutive frames — advice only.
    final ready = state.arming?.isArmed ?? false;
    final working = state.isCapturing || busy;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      color: Colors.black.withValues(alpha: 0.72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            guidance.instruction,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: guidance.isReady ? accent : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
          ],
          if (state.outcome != null) ...<Widget>[
            const SizedBox(height: 10),
            _OutcomeLine(outcome: state.outcome!),
          ],
          const SizedBox(height: 16),
          Center(
            child: ShutterButton(
              ready: ready,
              working: working,
              accent: accent,
              onPressed: onShutter,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            working
                ? 'Analysing the photograph…'
                : workerMode
                ? (ready
                      ? 'In position. Tap the shutter to take the photo.'
                      : 'Fit the DoseBand in the frame, hold steady, then tap '
                            'the shutter.')
                : 'You can take the photo at any time.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 2),
          const Text(
            // The shutter never overrides the measurement standard: the
            // still is checked after it is taken. §10, §52.
            'The photo is checked in full after you take it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// The manual shutter: a large round button, bottom centre.
///
/// Only the worker's tap takes the photograph. Disabled while a photo is
/// being taken, analysed or recorded, and taps closer together than
/// [debounce] are ignored, so one intention is one photograph.
class ShutterButton extends StatefulWidget {
  const ShutterButton({
    required this.ready,
    required this.working,
    required this.accent,
    required this.onPressed,
    super.key,
  });

  /// The preview says the DoseBand is in position and steady (advice).
  final bool ready;

  /// A capture or its processing is under way: the shutter is disabled.
  final bool working;

  final Color accent;
  final Future<void> Function() onPressed;

  static const double size = 84;
  static const Duration debounce = Duration(milliseconds: 800);

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  /// Monotonic, not the wall clock: time since the last accepted tap.
  final Stopwatch _sinceLast = Stopwatch();

  void _tap() {
    if (widget.working) return;
    if (_sinceLast.isRunning && _sinceLast.elapsed < ShutterButton.debounce) {
      return;
    }
    _sinceLast
      ..reset()
      ..start();
    HapticFeedback.mediumImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.working;
    final ring = widget.ready ? widget.accent : Colors.white;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.working
          ? 'Analysing the photograph'
          : 'Take the measurement photo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? _tap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: ShutterButton.size,
          height: ShutterButton.size,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? ring : Colors.white38,
              width: 5,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? Colors.white : Colors.white24,
            ),
            child: widget.working
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _OutcomeLine extends StatelessWidget {
  const _OutcomeLine({required this.outcome});

  final CaptureOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (text, colour) = switch (outcome) {
      CaptureObserved() => (
        'Photo accepted. No exposure value can be produced yet.',
        Colors.white,
      ),
      CaptureRefused(result: final result) => (
        'Photo not usable: ${result.reasons.first.code}',
        Colors.orangeAccent,
      ),
    };
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: colour, fontSize: 13),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.shade900,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white)),
  );
}
