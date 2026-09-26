import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart';

import '../../../core/env/app_version.dart';
import '../../../core/geometry/geometry_assets.dart';
import '../../capture/application/capture_controller.dart';
import '../../capture/data/camera_port_impl.dart';
import '../../capture/domain/badge_v1_references.dart';
import '../../capture/presentation/capture_screen.dart';
import '../application/research_providers.dart';
import '../application/research_recorder.dart';
import '../domain/research_settings.dart';
import 'capture_diagnostics_screen.dart';

/// The app version stamped on research records.
const researchAppVersion = appVersion;

/// Physical Capture Test — the bench workflow for M0C. §40.
///
/// Specimen → camera → capture → inspect → save → next. No worker, no shift,
/// no PTW: a laboratory image does not need an operational context, and
/// requiring one would slow the session down enough that fewer captures get
/// taken.
///
/// **Development only.** Reachable only where simulation is available, which
/// is compiled out of production. Nothing here produces a dose.
class PhysicalCaptureSetupScreen extends ConsumerStatefulWidget {
  const PhysicalCaptureSetupScreen({super.key});

  @override
  ConsumerState<PhysicalCaptureSetupScreen> createState() =>
      _PhysicalCaptureSetupScreenState();
}

class _PhysicalCaptureSetupScreenState
    extends ConsumerState<PhysicalCaptureSetupScreen> {
  late final TextEditingController _specimen;
  late final TextEditingController _badge;
  late final TextEditingController _batch;
  late final TextEditingController _formulation;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final s = ref.read(researchSettingsProvider);
    _specimen = TextEditingController(text: s.specimenId);
    _badge = TextEditingController(text: s.badgeId);
    _batch = TextEditingController(text: s.batchId);
    _formulation = TextEditingController(text: s.formulationId);
    _note = TextEditingController(text: s.operatorNote);
  }

  @override
  void dispose() {
    for (final c in [_specimen, _badge, _batch, _formulation, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _commit(ResearchSettings Function(ResearchSettings) change) {
    final notifier = ref.read(researchSettingsProvider.notifier);
    notifier.update(change(ref.read(researchSettingsProvider)));
  }

  void _syncText() => _commit(
    (s) => s.copyWith(
      specimenId: _specimen.text,
      badgeId: _badge.text,
      batchId: _batch.text,
      formulationId: _formulation.text,
      operatorNote: _note.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(researchSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: Text('Physical capture test')),
        actions: <Widget>[
          IconButton(
            tooltip: 'Saved captures',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () => context.push('/profile/research-captures'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: <Widget>[
          Text(
            'Research workflow. Photographs a physical specimen through the '
            'real camera and the full measurement pipeline, and archives the '
            'original image with every intermediate value. No H₂S '
            'calibration exists, so no exposure is produced.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _specimen,
            onChanged: (_) => _syncText(),
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Specimen ID *',
              hintText: 'P0-X1-01',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Text('Series level', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'An intended order only. X1 is not a known exposure until a '
            'reference instrument measures one.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final level in const ['—', 'X0', 'X1', 'X2', 'X3'])
                ChoiceChip(
                  label: Text(level),
                  selected: level == '—'
                      ? settings.seriesLevel.isEmpty
                      : settings.seriesLevel == level,
                  onSelected: (_) => _commit(
                    (s) => s.copyWith(seriesLevel: level == '—' ? '' : level),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _batch,
                  onChanged: (_) => _syncText(),
                  decoration: const InputDecoration(
                    labelText: 'Batch',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _formulation,
                  onChanged: (_) => _syncText(),
                  decoration: const InputDecoration(
                    labelText: 'Formulation',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _badge,
            onChanged: (_) => _syncText(),
            decoration: const InputDecoration(
              labelText: 'Badge ID (optional)',
              helperText:
                  'Product identity, if this specimen is an issued '
                  'badge. Kept separate from the specimen ID.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: settings.illuminationClass,
            decoration: const InputDecoration(
              labelText: 'Lighting, as you would describe it',
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String>>[
              for (final c in illuminationClasses)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => _commit((s) => s.copyWith(illuminationClass: v)),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            initialValue: settings.deliberateFailure,
            decoration: const InputDecoration(
              labelText: 'Staged failure',
              helperText:
                  'Set when a capture is meant to be refused. Keeps '
                  'it out of every acceptance statistic.',
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem(value: null, child: Text('None')),
              for (final c in deliberateFailureClasses)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => _commit(
              (s) => v == null
                  ? s.copyWith(clearDeliberateFailure: true)
                  : s.copyWith(deliberateFailure: v),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            onChanged: (_) => _syncText(),
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: settings.isComplete
                ? () => context.push('/profile/physical-capture/camera')
                : null,
            icon: const Icon(Icons.photo_camera_outlined),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            label: Text(
              settings.isComplete ? 'Open camera' : 'Enter a specimen ID',
            ),
          ),
        ),
      ),
    );
  }
}

/// The camera, wired to the recorder.
class PhysicalCaptureSessionScreen extends ConsumerStatefulWidget {
  const PhysicalCaptureSessionScreen({super.key});

  @override
  ConsumerState<PhysicalCaptureSessionScreen> createState() =>
      _PhysicalCaptureSessionScreenState();
}

class _PhysicalCaptureSessionScreenState
    extends ConsumerState<PhysicalCaptureSessionScreen> {
  CaptureController? _controller;
  CameraPortImpl? _port;
  BadgeGeometry? _geometry;
  ResearchRecorder? _recorder;
  String? _error;
  bool _reviewing = false;
  int _saved = 0;

  @override
  void initState() {
    super.initState();
    unawaited(
      _start().catchError((Object e) {
        if (mounted) setState(() => _error = '$e');
      }),
    );
  }

  Future<void> _start() async {
    final BadgeGeometry geometry;
    try {
      geometry = await GeometryAssets().load('badge-v1-research');
    } on GeometryAssetException catch (e) {
      // No fallback. A capture analysed against the wrong ROI coordinates is
      // undetectable downstream.
      if (mounted) setState(() => _error = e.detail);
      return;
    }

    final port = CameraPortImpl(appVersion: researchAppVersion);
    final controller = CaptureController(
      port: port,
      geometry: geometry,
      referenceTargets: badgeV1ReferenceTargets(geometry),
      fitPatchIds: badgeV1FitPatchIds,
      holdoutPatchIds: badgeV1HoldoutPatchIds,
      appVersion: researchAppVersion,
      previewDownscale: port.previewDownscale,
      // Manual shutter while the arming thresholds are provisional: an
      // automatic shutter firing on an unvalidated rule makes the rule harder
      // to study, not easier.
      autoCapture: false,
    );
    await controller.start();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onController);
    setState(() {
      _geometry = geometry;
      _port = port;
      _controller = controller;
      _recorder = ResearchRecorder(
        archive: ref.read(captureArchiveProvider),
        geometry: geometry,
      );
    });
  }

  Future<void> _onController() async {
    final controller = _controller;
    final outcome = controller?.state.outcome;
    if (controller == null || outcome == null || _reviewing) return;
    _reviewing = true;

    final settings = ref.read(researchSettingsProvider);
    final action = await Navigator.of(context).push<DiagnosticsAction>(
      MaterialPageRoute(
        builder: (_) => CaptureDiagnosticsScreen(
          outcome: outcome,
          geometry: _geometry!,
          specimenId: settings.specimenId,
        ),
      ),
    );

    if (action == DiagnosticsAction.save && mounted) {
      try {
        final saved = await _recorder!.save(outcome, settings);
        _saved++;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Saved ${saved.captureId}')));
        }
      } on Object catch (e) {
        // Loud. A capture the operator believes was saved and was not is the
        // worst failure this screen can have.
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Capture NOT saved'),
              content: Text('$e'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }

    await controller.resume();
    _reviewing = false;
  }

  @override
  void dispose() {
    _controller?.removeListener(_onController);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera unavailable')),
        body: Padding(padding: const EdgeInsets.all(24), child: Text(error)),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final specimen = ref.watch(researchSettingsProvider).specimenId;
    return Stack(
      children: <Widget>[
        CaptureScreen(controller: controller, preview: _port?.controller),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 12,
          right: 12,
          child: Row(
            children: <Widget>[
              IconButton.filledTonal(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text(
                      '$specimen · $_saved saved',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
