@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/components/markers.dart';
import 'package:h2s_doseband/core/design/theme.dart';
import 'package:h2s_doseband/features/gallery/gallery_specimens.dart';

/// Goldens for the states a reviewer must be able to check at a glance.
///
/// They are the regression guard, but they are also how the states get *looked
/// at*: the generated PNGs are the visual inspection artefact. They use the
/// same specimens as the gallery, so what a reviewer sees on a device and what
/// CI guards cannot drift apart.
Widget _harness(
  Widget child, {
  required Brightness brightness,
  double textScale = 1,
  double width = 390,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildDoseBandTheme(brightness: brightness),
    home: MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    final mode = brightness.name;

    group('result states · $mode', () {
      for (final specimen in resultSpecimens) {
        final slug = specimen.name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');

        testWidgets(specimen.name, (tester) async {
          tester.view.physicalSize = const Size(390 * 2, 1000 * 2);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            _harness(Builder(builder: specimen.build), brightness: brightness),
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/result-$slug-$mode.png'),
          );
        });
      }
    });

    testWidgets('markers · $mode', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 300 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(
          const Column(
            children: [
              SimulationMarker(),
              SizedBox(height: 12),
              OfflineMarker(pendingCount: 2),
              SizedBox(height: 12),
              OfflineMarker(),
            ],
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/markers-$mode.png'),
      );
    });
  }

  testWidgets('valid at 200% text scale', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(
        Builder(builder: resultSpecimens.first.build),
        brightness: Brightness.light,
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/result-valid-textscale200.png'),
    );
  });

  testWidgets('refusal on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(
        Builder(builder: resultSpecimens[4].build),
        brightness: Brightness.light,
        width: 320,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/result-refused-small.png'),
    );
  });
}
