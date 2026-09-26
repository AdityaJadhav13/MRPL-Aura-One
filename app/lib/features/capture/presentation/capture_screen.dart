import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/design/semantic_colors.dart';
import '../../../core/design/tokens.dart';
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
  const CaptureScreen({required this.controller, this.preview, super.key});

  final CaptureController controller;

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
  });

  final CaptureUiState state;
  final Color accent;
  final Future<void> Function() onShutter;

  @override
  Widget build(BuildContext context) {
    final guidance = state.state;
    final detail = guidance.detail;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      color: Colors.black.withValues(alpha: 0.72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            guidance.instruction,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: guidance.isReady ? accent : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 18),
          if (state.outcome != null) _OutcomeLine(outcome: state.outcome!),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: state.isCapturing ? null : onShutter,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(kMinTouchTarget),
            ),
            child: Text(state.isCapturing ? 'Working…' : 'Take photo'),
          ),
          const SizedBox(height: 8),
          const Text(
            // The shutter is always available, and it never overrides the
            // measurement standard. Directive §10.
            'You can take the photo at any time. It is still checked before '
            'it is used.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
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
