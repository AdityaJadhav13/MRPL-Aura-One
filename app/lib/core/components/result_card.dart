import 'package:flutter/material.dart';
import 'package:measurement/measurement.dart';

import '../design/status_presentation.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import 'measurement_readout.dart';
import 'measurement_scale.dart';
import 'status_header.dart';
import 'surfaces.dart';

/// A result, presented.
///
/// Composes the status treatment, the readout and the scale. The three vary
/// together and are meaningless apart, which is why this is one widget rather
/// than a layout each screen assembles for itself and gets subtly wrong.
class ResultCard extends StatelessWidget {
  const ResultCard({
    required this.status,
    required this.loq,
    required this.saturation,
    this.value,
    this.prefix,
    this.uncertainty,
    this.reason,
    this.traceability = const {},
    this.animate = true,
    super.key,
  });

  final ResultStatus status;
  final double loq;
  final double saturation;
  final String? value;
  final String? prefix;
  final String? uncertainty;
  final ReasonPanel? reason;
  final Map<String, String> traceability;
  final bool animate;

  ScaleMarker get _marker {
    if (status.carriesDose) return ScaleMarker.value;
    return switch (status) {
      ResultStatus.aboveRange ||
      ResultStatus.saturated => ScaleMarker.aboveRange,
      ResultStatus.belowQuantificationLimit => ScaleMarker.belowRange,
      _ => ScaleMarker.none,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = StatusPresentation.of(status, context.colours);
    final numeric = double.tryParse(value ?? '');

    return DoseBandSurface(
      measurement: true,
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusHeader(presentation: p),
          const SizedBox(height: Space.lg),
          MeasurementReadout(
            value: value,
            prefix: prefix,
            uncertainty: uncertainty,
            unit: 'ppm·h',
            colour: status.carriesDose ? p.colour : null,
          ),
          const SizedBox(height: Space.lg),
          MeasurementScale(
            loq: loq,
            saturation: saturation,
            marker: _marker,
            value: numeric,
            colour: p.colour,
            animate: animate,
          ),
          if (reason != null) ...[const SizedBox(height: Space.lg), reason!],
          if (traceability.isNotEmpty) ...[
            const SizedBox(height: Space.lg),
            Divider(height: Space.lg, color: context.colours.border),
            for (final e in traceability.entries)
              TraceabilityRow(label: e.key, value: e.value),
          ],
        ],
      ),
    );
  }
}
