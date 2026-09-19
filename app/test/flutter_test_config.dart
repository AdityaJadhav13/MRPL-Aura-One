import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled IBM Plex fonts into the test binding.
///
/// Without this, goldens render in Ahem boxes and prove nothing about
/// typography — which is most of what these goldens exist to check.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(
        File(p).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }

  // Material icons too: a status is icon + label + colour together, so a
  // golden that renders icons as empty boxes cannot check that contract.
  final materialIcons = _findMaterialIcons();
  if (materialIcons != null) {
    await load('MaterialIcons', [materialIcons]);
  }

  await load('IBMPlexSans', ['assets/fonts/IBMPlexSans-Variable.ttf']);
  await load('IBMPlexMono', [
    'assets/fonts/IBMPlexMono-Regular.ttf',
    'assets/fonts/IBMPlexMono-Medium.ttf',
  ]);

  await testMain();
}

/// The icon font ships with the Flutter SDK rather than the project, so its
/// location is discovered by walking up from the test runner instead of being
/// hardcoded to one engine layout.
String? _findMaterialIcons() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final candidate = File(
      '${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}
