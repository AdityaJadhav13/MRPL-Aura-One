@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/design/theme.dart';
import 'package:h2s_doseband/features/history/domain/measurement_record.dart';
import 'package:h2s_doseband/features/result/result_screen.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:measurement/measurement.dart';

/// Goldens for the full result screen — the journey's payoff — in the states a
/// reviewer must be able to check: a clean dose, an above-range censor, and a
/// refusal that shows the empty slot rather than a zero.
Provenance _prov({String? cal}) => Provenance(
  algorithmVersion: 'sim-0',
  geometryVersion: 'geo-sim-3',
  calibrationModelId: cal,
  referenceProfileId: cal == null ? null : 'ref-sim-1',
  appVersion: '0.1.0+1',
  deviceModel: 'demo',
);

MeasurementRecord _record(MeasurementResult result) {
  final now = DateTime(2026, 9, 19, 14);
  return MeasurementRecord(
    id: 'M-golden',
    result: result,
    badge: SimulationCatalog.specimens().first,
    context: SimulationCatalog.demoContext(),
    startedAt: now.subtract(const Duration(hours: 7, minutes: 52)),
    endedAt: now,
    scannedAt: now,
  );
}

void main() {
  final cases = <String, MeasurementResult>{
    'valid': Valid(
      dose: Dose.ppmHours(3.2),
      uncertainty: const Uncertainty(halfWidth: 0.8, basis: 'sim'),
      coverage: const Duration(hours: 7, minutes: 52),
      provenance: _prov(cal: 'cal-sim-1.2.0'),
    ),
    'above-range': Censored(
      status: ResultStatus.aboveRange,
      direction: CensorDirection.above,
      bound: Dose.ppmHours(40),
      reasons: const [ReasonCode('ABOVE_RANGE')],
      provenance: _prov(),
    ),
    'refused': Refused(
      status: ResultStatus.referencePatchFailure,
      reasons: const [ReasonCode('REFERENCE_PATCH_FAILURE', detail: 'glare')],
      provenance: _prov(),
    ),
  };

  for (final brightness in Brightness.values) {
    for (final entry in cases.entries) {
      testWidgets('result ${entry.key} · ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildDoseBandTheme(brightness: brightness),
            home: ResultScreen(record: _record(entry.value)),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/result-screen-${entry.key}-${brightness.name}.png',
          ),
        );
      });
    }
  }
}
