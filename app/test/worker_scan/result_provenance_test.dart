// A real scan's result must never be labelled simulated, and must never
// offer a rescan that crashes a closed monitored period.
//
// MEASUREMENT-INTEGRATION-02 hostile review.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/markers.dart';
import 'package:h2s_doseband/core/design/theme.dart';
import 'package:h2s_doseband/features/history/domain/measurement_record.dart';
import 'package:h2s_doseband/features/result/measurement_detail_screen.dart';
import 'package:h2s_doseband/features/result/result_screen.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/domain/physical_badge.dart';
import 'package:measurement/measurement.dart';

MeasurementRecord _record({required bool physical}) {
  final at = DateTime.utc(2026, 9, 26, 16);
  final result = Refused(
    status: ResultStatus.unsupportedCalibration,
    reasons: const <ReasonCode>[ReasonCode('NO_CALIBRATION_MODEL')],
    provenance: const Provenance(
      algorithmVersion: 'm0a',
      geometryVersion: 'badge-v1-research',
      calibrationModelId: null,
      referenceProfileId: null,
      appVersion: 't',
      deviceModel: 't',
    ),
  );
  return MeasurementRecord(
    id: 'r',
    result: result,
    badge: physical
        ? PhysicalBadge(badgeId: 'DB-PHYS-0001', identifiedAt: at)
        : SimulationCatalog.specimens().first,
    context: SimulationCatalog.demoContext(),
    startedAt: at.subtract(const Duration(hours: 8)),
    endedAt: at,
    scannedAt: at,
    domain: physical ? DataDomain.field : DataDomain.simulated,
    captureId: physical ? 'DB-PHYS-0001__20260926T160000000Z' : null,
  );
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390 * 2, 2400 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildDoseBandTheme(brightness: Brightness.light),
      home: screen,
    ),
  );
  await tester.pump();
}

void main() {
  group('result screen', () {
    testWidgets('a real scan is not marked simulated', (tester) async {
      await _pump(tester, ResultScreen(record: _record(physical: true)));
      expect(find.byType(SimulationMarker), findsNothing);
    });

    testWidgets('a real scan offers Done, never a rescan', (tester) async {
      // Reopening the camera on a completed period threw.
      await _pump(tester, ResultScreen(record: _record(physical: true)));
      expect(find.text('Scan again'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('a simulated result keeps its marker and rescan', (
      tester,
    ) async {
      await _pump(tester, ResultScreen(record: _record(physical: false)));
      expect(find.byType(SimulationMarker), findsOneWidget);
      expect(find.text('Scan again'), findsOneWidget);
    });
  });

  group('measurement details', () {
    testWidgets('a real scan states its real domain and photograph', (
      tester,
    ) async {
      await _pump(
        tester,
        MeasurementDetailScreen(record: _record(physical: true)),
      );
      expect(find.byType(SimulationMarker), findsNothing);
      expect(find.text('Simulated'), findsNothing);
      expect(find.text(DataDomain.field.disclosure), findsOneWidget);
      expect(find.text('DB-PHYS-0001__20260926T160000000Z'), findsOneWidget);
    });

    testWidgets('a simulated record keeps its marker', (tester) async {
      await _pump(
        tester,
        MeasurementDetailScreen(record: _record(physical: false)),
      );
      expect(find.byType(SimulationMarker), findsOneWidget);
    });
  });
}
