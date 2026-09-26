import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:measurement/measurement.dart';

import '../../capture/domain/capture_outcome.dart';

/// What the operator chose to do with a capture.
enum DiagnosticsAction { save, discard }

/// Research diagnostics for one capture. APP-INTEGRATION-01 §14.
///
/// ## Who this is for
///
/// The person at the bench tomorrow, holding a phone over a printed target —
/// so that each capture can be judged *on the phone*, without copying it to a
/// laptop. It is a development surface: reachable only where simulation is
/// available, and never part of a worker's flow.
///
/// ## What it deliberately does not do
///
/// It computes nothing. Every number is read from the engine's own output —
/// the observation, the assessment, the validation — and every overlay is
/// drawn by mapping geometry through the engine's homography. A diagnostics
/// view that recomputed values would be a second implementation, and it would
/// show what it computed rather than what the measurement used.
///
/// Every threshold behind these numbers is `SYNTHETIC ONLY`. The screen says
/// so, because tomorrow's captures are what will replace them.
class CaptureDiagnosticsScreen extends StatefulWidget {
  const CaptureDiagnosticsScreen({
    required this.outcome,
    required this.geometry,
    required this.specimenId,
    super.key,
  });

  final CaptureOutcome outcome;
  final BadgeGeometry geometry;
  final String specimenId;

  @override
  State<CaptureDiagnosticsScreen> createState() =>
      _CaptureDiagnosticsScreenState();
}

class _CaptureDiagnosticsScreenState extends State<CaptureDiagnosticsScreen> {
  Uint8List? _stillPng;
  Uint8List? _rectifiedPng;

  static const double _rectifiedScale = 8;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    final evidence = widget.outcome.evidence;
    // The decoded still, not the original bytes: the original may carry an
    // EXIF rotation that a platform image decoder would apply and ours does
    // not, and the overlays are drawn in the coordinates the engine used.
    final still = await compute(encodePng, evidence.still);
    Uint8List? rectified;
    final h = evidence.homography;
    if (h != null) {
      final image = rectifyBadge(
        image: evidence.still,
        badgeToImage: h,
        geometry: widget.geometry,
        pixelsPerMm: _rectifiedScale,
      );
      if (image != null) rectified = await compute(encodePng, image);
    }
    if (!mounted) return;
    setState(() {
      _stillPng = still;
      _rectifiedPng = rectified;
    });
  }

  @override
  Widget build(BuildContext context) {
    final outcome = widget.outcome;
    final evidence = outcome.evidence;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Capture · ${widget.specimenId}'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: <Widget>[
          _Verdict(outcome: outcome),
          const SizedBox(height: 8),
          const _ProvisionalNote(),
          const SizedBox(height: 16),

          _Section(
            title: 'Original, with detected geometry',
            child: _ImageWithOverlay(
              png: _stillPng,
              width: evidence.still.width.toDouble(),
              height: evidence.still.height.toDouble(),
              painter: _OriginalOverlay(
                geometry: widget.geometry,
                homography: evidence.homography,
                imageWidth: evidence.still.width.toDouble(),
                imageHeight: evidence.still.height.toDouble(),
              ),
            ),
          ),

          if (evidence.homography != null)
            _Section(
              title: 'Rectified — canonical badge coordinates',
              subtitle:
                  'Evidence only. The pipeline samples the original directly '
                  'and never reads this image.',
              child: _ImageWithOverlay(
                png: _rectifiedPng,
                width: widget.geometry.widthMm * _rectifiedScale,
                height: widget.geometry.heightMm * _rectifiedScale,
                painter: _RectifiedOverlay(
                  geometry: widget.geometry,
                  scale: _rectifiedScale,
                ),
              ),
            ),

          if (outcome is CaptureObserved) ...<Widget>[
            _Section(
              title: 'Sensor, blank and expiry regions',
              child: _RegionTable(
                samples: outcome.observation.samples,
                kinds: const <RoiKind>{
                  RoiKind.sensor,
                  RoiKind.blank,
                  RoiKind.expiry,
                },
              ),
            ),
            _Section(
              title: 'Reference correction',
              child: _CorrectionSummary(observation: outcome.observation),
            ),
            _Section(
              title: 'Reference patches',
              child: _RegionTable(
                samples: outcome.observation.samples,
                kinds: const <RoiKind>{RoiKind.reference},
              ),
            ),
            _Section(
              title: 'Optical features',
              subtitle:
                  'Feature definition '
                  '${outcome.observation.featureVector.definitionVersion}',
              child: _FeatureTable(
                features: outcome.observation.featureVector.features,
              ),
            ),
            _Section(
              title: 'Deformation — withheld markers',
              subtitle:
                  'Recorded, not gating. No residual limit has been '
                  'established, so a bent badge is not yet refused on this '
                  'evidence.',
              child: _JsonBlock(value: outcome.geometryValidation?.toJson()),
            ),
          ],

          _Section(
            title: 'Image quality — still',
            child: _JsonBlock(value: evidence.stillQuality.toJson()),
          ),
          _Section(
            title: 'Guidance — preview versus still',
            subtitle:
                'Both kept. Whether a preview metric can stand in for the '
                'still is an open M0C question.',
            child: _PreviewVersusStill(
              preview: evidence.previewAssessment,
              still: evidence.stillAssessment,
            ),
          ),
          _Section(
            title: 'Device',
            child: _JsonBlock(
              value: switch (outcome) {
                CaptureObserved(:final metadata) => metadata.toJson(),
                CaptureRefused(:final metadata) => metadata.toJson(),
              },
            ),
          ),
          Text(
            'Algorithm $algorithmVersion · geometry ${widget.geometry.version}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(DiagnosticsAction.discard),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(DiagnosticsAction.save),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  // A refusal is saved as readily as an acceptance: it is
                  // evidence of what the reader rejects.
                  child: const Text('Save capture'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// Verdict
// ===================================================================

class _Verdict extends StatelessWidget {
  const _Verdict({required this.outcome});

  final CaptureOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String title, String detail, IconData icon) = switch (outcome) {
      CaptureObserved(:final result) => (
        'Optical acquisition valid',
        result is Refused
            ? 'Calibration not available — ${result.status.name}. Optical '
                  'features were extracted; no exposure can be derived.'
            : 'Result: ${result.status.name}',
        Icons.check_circle_outline,
      ),
      CaptureRefused(:final result) => (
        'Acquisition refused',
        result is Refused && result.reasons.isNotEmpty
            ? '${result.reasons.first.code}'
                  '${result.reasons.first.detail == null ? '' : ' — ${result.reasons.first.detail}'}'
            : result.status.name,
        Icons.block_outlined,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 4),
                Text(detail, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvisionalNote extends StatelessWidget {
  const _ProvisionalNote();

  @override
  Widget build(BuildContext context) => Text(
    'Research diagnostics. Every acquisition threshold is SYNTHETIC ONLY and '
    'has not been set against a physical photograph. Reference colours are '
    'design-space values, not measured print — Lab and ΔE here support '
    'relative comparison only. No H₂S calibration exists.',
    style: Theme.of(context).textTheme.bodySmall,
  );
}

// ===================================================================
// Images and overlays
// ===================================================================

class _ImageWithOverlay extends StatelessWidget {
  const _ImageWithOverlay({
    required this.png,
    required this.width,
    required this.height,
    required this.painter,
  });

  final Uint8List? png;
  final double width;
  final double height;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    final bytes = png;
    return AspectRatio(
      aspectRatio: width / height,
      child: bytes == null
          ? const ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
                CustomPaint(painter: painter),
              ],
            ),
    );
  }
}

Color _colourFor(RoiKind kind) => switch (kind) {
  RoiKind.sensor => const Color(0xFFFF00FF),
  RoiKind.blank => const Color(0xFF00E5FF),
  RoiKind.expiry => const Color(0xFFFFD600),
  RoiKind.reference => const Color(0xFF76FF03),
  _ => const Color(0xFFFFFFFF),
};

/// ROI outlines and fiducial centres, mapped through the engine's homography
/// into the original image's pixel space.
class _OriginalOverlay extends CustomPainter {
  _OriginalOverlay({
    required this.geometry,
    required this.homography,
    required this.imageWidth,
    required this.imageHeight,
  });

  final BadgeGeometry geometry;
  final Homography? homography;

  /// The still's pixel dimensions. The homography maps into these, and the
  /// image is drawn scaled to the widget, so both are needed to place an
  /// outline on the pixels the engine actually sampled.
  final double imageWidth;
  final double imageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final h = homography;
    if (h == null) return;
    // The image is drawn scaled to fill [size]; map image pixels to it.
    final sx = size.width / imageWidth;
    final sy = size.height / imageHeight;
    Offset map(double xMm, double yMm) {
      final (px, py) = h.mapXy(xMm, yMm);
      return Offset(px * sx, py * sy);
    }

    for (final roi in geometry.rois) {
      final path = Path()
        ..moveTo(map(roi.xMm, roi.yMm).dx, map(roi.xMm, roi.yMm).dy);
      for (final (x, y) in <(double, double)>[
        (roi.xMm + roi.widthMm, roi.yMm),
        (roi.xMm + roi.widthMm, roi.yMm + roi.heightMm),
        (roi.xMm, roi.yMm + roi.heightMm),
      ]) {
        final o = map(x, y);
        path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _colourFor(roi.kind),
      );
    }
    for (final f in geometry.fiducials) {
      canvas.drawCircle(
        map(f.centreMm.x, f.centreMm.y),
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = f.role == FiducialRole.primary
              ? Colors.redAccent
              : Colors.orangeAccent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OriginalOverlay old) =>
      old.homography != homography;
}

/// ROI outlines in canonical badge millimetres, on the rectified view.
class _RectifiedOverlay extends CustomPainter {
  _RectifiedOverlay({required this.geometry, required this.scale});

  final BadgeGeometry geometry;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / (geometry.widthMm * scale) * scale;
    for (final roi in geometry.rois) {
      canvas.drawRect(
        Rect.fromLTWH(
          roi.xMm * k,
          roi.yMm * k,
          roi.widthMm * k,
          roi.heightMm * k,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _colourFor(roi.kind),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RectifiedOverlay old) => false;
}

// ===================================================================
// Tables
// ===================================================================

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleSmall),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

String _n(double? v, [int digits = 4]) =>
    v == null ? '—' : (v.isFinite ? v.toStringAsFixed(digits) : '$v');

class _RegionTable extends StatelessWidget {
  const _RegionTable({required this.samples, required this.kinds});

  final Map<String, RoiSample> samples;
  final Set<RoiKind> kinds;

  @override
  Widget build(BuildContext context) {
    final rows = samples.values.where((s) => kinds.contains(s.kind)).toList()
      ..sort((a, b) => a.roiId.compareTo(b.roiId));
    if (rows.isEmpty) return const Text('None sampled.');
    final mono = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontFamily: 'monospace');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 32,
        columnSpacing: 14,
        columns: const <DataColumn>[
          DataColumn(label: Text('ROI')),
          DataColumn(label: Text('lin R')),
          DataColumn(label: Text('lin G')),
          DataColumn(label: Text('lin B')),
          DataColumn(label: Text('L*')),
          DataColumn(label: Text('a*')),
          DataColumn(label: Text('b*')),
          DataColumn(label: Text('usable')),
        ],
        rows: <DataRow>[
          for (final s in rows)
            DataRow(
              cells: <DataCell>[
                DataCell(Text(s.roiId, style: mono)),
                DataCell(Text(_n(s.trimmedMeanLinear.r), style: mono)),
                DataCell(Text(_n(s.trimmedMeanLinear.g), style: mono)),
                DataCell(Text(_n(s.trimmedMeanLinear.b), style: mono)),
                DataCell(Text(_n(s.lab.lStar, 2), style: mono)),
                DataCell(Text(_n(s.lab.aStar, 2), style: mono)),
                DataCell(Text(_n(s.lab.bStar, 2), style: mono)),
                DataCell(Text(_n(s.usableFraction, 3), style: mono)),
              ],
            ),
        ],
      ),
    );
  }
}

class _CorrectionSummary extends StatelessWidget {
  const _CorrectionSummary({required this.observation});

  final ResearchObservation observation;

  @override
  Widget build(BuildContext context) {
    final fit = observation.correctionFit;
    final validation = observation.referenceValidation;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          fit == null
              ? 'No correction attempted.'
              : fit.isOk
              ? 'Form ${fit.correction!.form.name} · fitted on '
                    '${fit.correction!.fitPatchIds.length} patches · '
                    'condition number '
                    '${_n(fit.conditioning?.conditionNumber, 1)}'
              : 'Not fitted — ${fit.rejection?.name}: ${fit.detail ?? ''}',
          style: theme.textTheme.bodyMedium,
        ),
        if (validation != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Withheld patches: mean ΔE00 ${_n(validation.meanDeltaE00, 2)}, '
            'max ΔE00 ${_n(validation.maximumDeltaE00, 2)}'
            '${validation.thresholdIsProvisional ? ' (limit provisional)' : ''}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          for (final r in validation.residuals)
            Text(
              '  ${r.patchId}: ΔE00 ${_n(r.deltaE00, 2)} · '
              'ΔE76 ${_n(r.deltaE76, 2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Against design-space targets, not measured print colour.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _FeatureTable extends StatelessWidget {
  const _FeatureTable({required this.features});

  final List<Feature> features;

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontFamily: 'monospace');
    return Column(
      children: <Widget>[
        for (final f in features)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(f.name, style: mono)),
                Text(_n(f.value), style: mono),
              ],
            ),
          ),
      ],
    );
  }
}

class _PreviewVersusStill extends StatelessWidget {
  const _PreviewVersusStill({required this.preview, required this.still});

  final GuidanceAssessment? preview;
  final GuidanceAssessment? still;

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontFamily: 'monospace');
    String line(String label, GuidanceAssessment? a) => a == null
        ? '$label: not assessed'
        : '$label: ${a.state.name} · px/mm ${_n(a.pixelsPerMm, 2)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(line('preview (¼ scale)', preview), style: mono),
        Text(line('still', still), style: mono),
      ],
    );
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.value});

  final Map<String, Object?>? value;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return const Text('Not assessed.');
    final mono = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontFamily: 'monospace');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final e in v.entries)
          if (e.value is! Map && e.value is! List)
            Text('${e.key}: ${_fmt(e.value)}', style: mono),
      ],
    );
  }

  static String _fmt(Object? v) => v is double ? _n(v) : '$v';
}
