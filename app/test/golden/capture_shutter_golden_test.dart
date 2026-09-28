@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/design/theme.dart';
import 'package:h2s_doseband/features/capture/application/capture_controller.dart';
import 'package:h2s_doseband/features/capture/domain/badge_v1_references.dart';
import 'package:h2s_doseband/features/capture/presentation/capture_screen.dart';
import 'package:measurement/measurement.dart';

import '../capture/fake_camera.dart';

/// The worker's camera: the manual shutter, bottom centre (directive: the
/// worker, not an automatic trigger, takes the measurement photograph).
void main() {
  for (final (name, busy) in <(String, bool)>[
    ('capture-shutter', false),
    ('capture-shutter-busy', true),
  ]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final geometry = BadgeGeometry.parse(
        File('../measurement-engine/geometry/badge-v1.geometry.json')
            .readAsStringSync(),
      );
      final frame = RgbImage.filled(400, 300, 60, 60, 60);
      final controller = CaptureController(
        port: FakeCameraPort(previewImages: [frame], stillImage: frame),
        geometry: geometry,
        referenceTargets: badgeV1ReferenceTargets(geometry),
        fitPatchIds: badgeV1FitPatchIds,
        holdoutPatchIds: badgeV1HoldoutPatchIds,
        appVersion: 't',
        autoCapture: false,
      );
      await tester.runAsync(controller.start);
      addTearDown(() => tester.runAsync(controller.dispose));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildDoseBandTheme(brightness: Brightness.light),
          home: CaptureScreen(
            controller: controller,
            workerMode: true,
            busy: busy,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }
}
