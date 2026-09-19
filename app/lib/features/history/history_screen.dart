import 'package:flutter/material.dart';

import '../../core/components/measurement_readout.dart';
import '../../core/design/status_presentation.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';

import 'package:measurement/measurement.dart';

/// History.
///
/// Entries are never a flat list of numbers: each carries its class, so a
/// refusal is visibly not a reading. Refused scans appear here rather than
/// being hidden — omitting them would misrepresent the coverage record, which
/// is exactly the quiet omission that produces false reassurance at review.
///
/// Phase 1: static sample rows.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _rows = <(String, ResultStatus, String?)>[
    ('18 Sep · Day shift', ResultStatus.valid, '3.2'),
    ('17 Sep · Day shift', ResultStatus.belowQuantificationLimit, null),
    ('16 Sep · Night shift', ResultStatus.referencePatchFailure, null),
    ('15 Sep · Day shift', ResultStatus.aboveRange, null),
    ('14 Sep · Day shift', ResultStatus.partialShift, null),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
        itemBuilder: (context, i) {
          final (label, status, value) = _rows[i];
          final p = StatusPresentation.of(status, c);
          return Semantics(
            label:
                '$label. ${p.label}.'
                '${value != null ? ' $value ppm hours.' : ' No reading.'}',
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(minHeight: kMinTouchTarget),
              padding: const EdgeInsets.symmetric(
                horizontal: Space.base,
                vertical: Space.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: Borders.statusRule,
                    height: 36,
                    color: p.colour,
                  ),
                  const SizedBox(width: Space.md),
                  Icon(p.icon, size: 18, color: p.colour),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: t.body.copyWith(color: c.textPrimary),
                        ),
                        Text(
                          p.label,
                          style: t.caption.copyWith(color: p.colour),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Text(
                    value ?? MeasurementReadout.noReading,
                    style: t.readoutBody.copyWith(
                      color: value != null ? c.textPrimary : c.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
