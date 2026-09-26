import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/app_version.dart';

void main() {
  test('the stamped app version matches pubspec.yaml', () {
    // Research records carry appVersion. If it drifted from the build's real
    // version, captures from different builds would claim the same origin.
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(appVersion, line.substring('version:'.length).trim());
  });
}
