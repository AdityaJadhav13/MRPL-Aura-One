import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/measurement_readout.dart';
import 'package:h2s_doseband/core/components/result_card.dart';
import 'package:h2s_doseband/core/design/theme.dart';
import 'package:measurement/measurement.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: buildDoseBandTheme(brightness: brightness),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('a failure is never shown as a number', () {
    testWidgets('a refusal shows the empty slot, not a zero', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ResultCard(
            status: ResultStatus.referencePatchFailure,
            loq: 0.5,
            saturation: 40,
            animate: false,
          ),
        ),
      );

      expect(find.text(MeasurementReadout.noReading), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('below the quantification limit is not zero', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ResultCard(
            status: ResultStatus.belowQuantificationLimit,
            loq: 0.5,
            saturation: 40,
            animate: false,
          ),
        ),
      );

      expect(find.text(MeasurementReadout.noReading), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
      expect(find.text('Below measurable range'), findsOneWidget);
    });

    testWidgets('above range keeps its bound rather than capping', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ResultCard(
            status: ResultStatus.aboveRange,
            loq: 0.5,
            saturation: 40,
            prefix: '>',
            value: '40',
            animate: false,
          ),
        ),
      );

      expect(find.text('> 40'), findsOneWidget);
      expect(find.text('Above measurable range'), findsOneWidget);
    });

    testWidgets('a valid result shows value and uncertainty together', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ResultCard(
            status: ResultStatus.valid,
            loq: 0.5,
            saturation: 40,
            value: '3.2',
            uncertainty: '0.8',
            animate: false,
          ),
        ),
      );

      expect(find.text('3.2'), findsOneWidget);
      expect(find.text('± 0.8'), findsOneWidget);
      expect(find.text(MeasurementReadout.noReading), findsNothing);
    });
  });

  group('status is never conveyed by colour alone', () {
    testWidgets('every result carries an icon and a text label', (
      tester,
    ) async {
      for (final status in [
        ResultStatus.valid,
        ResultStatus.aboveRange,
        ResultStatus.referencePatchFailure,
        ResultStatus.unsupportedCalibration,
      ]) {
        await tester.pumpWidget(
          _wrap(
            ResultCard(
              status: status,
              loq: 0.5,
              saturation: 40,
              animate: false,
              value: status.carriesDose ? '3.2' : null,
              uncertainty: status.carriesDose ? '0.8' : null,
            ),
          ),
        );
        expect(find.byType(Icon), findsWidgets, reason: '$status has no icon');
        expect(find.byType(Text), findsWidgets);
      }
    });
  });

  group('layout survives real conditions', () {
    testWidgets('renders on a small screen without overflow', (tester) async {
      // A 320x640 logical window is a realistic low-end Android device.
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const ResultCard(
            status: ResultStatus.valid,
            loq: 0.5,
            saturation: 40,
            value: '3.2',
            uncertainty: '0.8',
            animate: false,
            traceability: {
              'Coverage': '7 h 52 min',
              'Badge': 'DB-4K7M2',
              'Model': 'cal-1.2.0',
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at 200% text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(400 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDoseBandTheme(brightness: Brightness.light),
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: 2,
            maxScaleFactor: 2,
            child: const Scaffold(
              body: SingleChildScrollView(
                child: ResultCard(
                  status: ResultStatus.valid,
                  loq: 0.5,
                  saturation: 40,
                  value: '3.2',
                  uncertainty: '0.8',
                  animate: false,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ResultCard(
            status: ResultStatus.valid,
            loq: 0.5,
            saturation: 40,
            value: '3.2',
            uncertainty: '0.8',
            animate: false,
          ),
          brightness: Brightness.dark,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
