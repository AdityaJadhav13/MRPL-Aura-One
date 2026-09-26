import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/markers.dart';
import 'package:h2s_doseband/core/design/theme.dart';
import 'package:h2s_doseband/features/history/domain/measurement_record.dart';
import 'package:h2s_doseband/features/result/result_screen.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:measurement/measurement.dart';

Provenance _prov({String? cal}) => Provenance(
  algorithmVersion: 'sim-0',
  geometryVersion: 'geo-sim-3',
  calibrationModelId: cal,
  referenceProfileId: cal == null ? null : 'ref-sim-1',
  appVersion: '0.1.0+1',
  deviceModel: 'test',
);

MeasurementRecord _record(MeasurementResult result) {
  final now = DateTime(2026, 9, 19, 14);
  return MeasurementRecord(
    id: 'M-test',
    result: result,
    badge: SimulationCatalog.specimens().first,
    context: SimulationCatalog.demoContext(),
    startedAt: now.subtract(const Duration(hours: 7, minutes: 52)),
    endedAt: now,
    scannedAt: now,
    domain: DataDomain.simulated,
  );
}

Future<void> _pump(WidgetTester tester, MeasurementResult result) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildDoseBandTheme(brightness: Brightness.light),
      home: ResultScreen(record: _record(result)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a refusal shows the empty slot, never 0.0', (tester) async {
    await _pump(
      tester,
      Refused(
        status: ResultStatus.referencePatchFailure,
        reasons: const [ReasonCode('REFERENCE_PATCH_FAILURE')],
        provenance: _prov(),
      ),
    );

    expect(find.text('- - -'), findsOneWidget);
    expect(find.textContaining('0.0'), findsNothing);
  });

  testWidgets('a valid result shows its dose', (tester) async {
    await _pump(
      tester,
      Valid(
        dose: Dose.ppmHours(3.2),
        uncertainty: const Uncertainty(halfWidth: 0.8, basis: 'sim'),
        coverage: const Duration(hours: 7, minutes: 52),
        provenance: _prov(cal: 'cal-sim-1.2.0'),
      ),
    );

    expect(find.text('3.2'), findsOneWidget);
  });

  testWidgets('every result carries the simulation marker', (tester) async {
    await _pump(
      tester,
      Refused(
        status: ResultStatus.badgeExpired,
        reasons: const [ReasonCode('BADGE_EXPIRED')],
        provenance: _prov(),
      ),
    );
    expect(find.byType(SimulationMarker), findsOneWidget);
  });

  testWidgets('valid never renders as "safe"', (tester) async {
    await _pump(
      tester,
      Valid(
        dose: Dose.ppmHours(28.0),
        uncertainty: const Uncertainty(halfWidth: 3, basis: 'sim'),
        coverage: const Duration(hours: 8),
        provenance: _prov(cal: 'cal-sim-1.2.0'),
      ),
    );

    // A high reading is shown as a number, never reassured as safe.
    expect(find.textContaining('Safe', findRichText: true), findsNothing);
    expect(find.textContaining('safe to', findRichText: true), findsNothing);
    expect(find.text('28.0'), findsOneWidget);
  });
}
